import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SalonTeams.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../utils/colors.dart';
import 'AddTeamSelectServices.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';
import 'package:fluttertoast/fluttertoast.dart';

class _OperatingSlot {
  const _OperatingSlot({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

class _ScheduleConflict {
  const _ScheduleConflict({
    required this.day,
    required this.enteredRange,
    required this.branchRange,
  });

  final String day;
  final String enteredRange;
  final String branchRange;
}

class AddTeamChooseTimeSlot extends StatefulWidget {
  final Map<String, dynamic> formData;

  const AddTeamChooseTimeSlot({
    Key? key,
    required this.formData,
  }) : super(key: key);

  @override
  _ChooseTimeSlotState createState() => _ChooseTimeSlotState();
}

class _ChooseTimeSlotState extends State<AddTeamChooseTimeSlot> {
  static const int _maxSlotsPerDay = 3;
  static const int _timeMinuteStep = 10;

  late Map<String, List<Map<String, String>>> weeklySchedule;
  late Map<String, List<Map<String, String>>> mondaySchedule;

  bool _isSubmitting = false;
  bool _useSalonHours = false;
  bool _copyMondayToAllChecked = false;
  bool _isLoadingOperatingSchedule = false;
  bool _isApplyingMondayCopy = false;
  final Map<int, Set<int>> _rememberedSelectedServiceIdsByBranchId = {};

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  Set<int> _normalizeServiceIds(dynamic rawSelected) {
    final ids = <int>{};

    if (rawSelected is List) {
      for (final item in rawSelected) {
        final parsed = _toInt(item);
        if (parsed != null) {
          ids.add(parsed);
        }
      }
    }

    return ids;
  }

  final Set<String> _closedDays = <String>{};
  final Set<String> _memberOffDays = <String>{};
  final Map<String, List<Map<String, String>>> _memberOffDaySnapshots =
      <String, List<Map<String, String>>>{};

  final Map<String, List<_OperatingSlot>> _operatingSlotsByDay =
      <String, List<_OperatingSlot>>{};

  @override
  void initState() {
    super.initState();

    weeklySchedule = {
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
      'Sunday': [],
    };

    mondaySchedule = {};

    _prefillSchedules();

    _useSalonHours = false;

    _loadOperatingSchedule();
  }

  String _dayKey(String day) => day.trim().toLowerCase();

  bool _isClosedDay(String day) => _closedDays.contains(_dayKey(day));

  int _roundDownToStep(int minutes) {
    if (minutes <= 0) return 0;
    return (minutes ~/ _timeMinuteStep) * _timeMinuteStep;
  }

  int _roundUpToStep(int minutes) {
    if (minutes <= 0) return 0;
    final remainder = minutes % _timeMinuteStep;
    if (remainder == 0) return minutes;
    return minutes + (_timeMinuteStep - remainder);
  }

  List<String> get _weekDays => weeklySchedule.keys.toList();

  int _slotSortValue(Map<String, String> slot, String key) {
    return _parseTimeToMinutes(slot[key] ?? '') ?? 0;
  }

  int _slotComparator(Map<String, String> a, Map<String, String> b) {
    final startCompare =
        _slotSortValue(a, 'start').compareTo(_slotSortValue(b, 'start'));
    if (startCompare != 0) return startCompare;
    return _slotSortValue(a, 'end').compareTo(_slotSortValue(b, 'end'));
  }

  void _sortWeeklyScheduleInPlace() {
    for (final day in _weekDays) {
      weeklySchedule[day]?.sort(_slotComparator);
    }
  }

  List<Map<String, String>> _sortedDaySlots(String day) {
    final slots = List<Map<String, String>>.from(
      weeklySchedule[day] ?? const <Map<String, String>>[],
    );
    slots.sort(_slotComparator);
    return slots;
  }

  void _clearWeeklySchedule() {
    for (final day in _weekDays) {
      weeklySchedule[day]?.clear();
    }
  }

  Future<void> _loadOperatingSchedule() async {
    final directSchedule = widget.formData['operatingSchedule'] ??
        widget.formData['branchSchedule'] ??
        widget.formData['salonSchedule'];

    if (_applyOperatingSchedule(directSchedule)) return;

    final branchId = widget.formData['branchId'];
    final salonId = widget.formData['salonId'];

    if (branchId == null && salonId == null) return;

    setState(() => _isLoadingOperatingSchedule = true);

    try {
      final salonListResponse = await ApiService().getSalonListApi();

      final fromSalonList =
          _findScheduleInSalonList(salonListResponse, branchId, salonId);

      if (!_applyOperatingSchedule(fromSalonList) && branchId is int) {
        final branchResponse = await ApiService().getBranchDetail(branchId);
        _applyOperatingSchedule(_extractSchedule(branchResponse));
      }
    } catch (error) {
      debugPrint('Failed to load branch operating schedule: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingOperatingSchedule = false);
      }
    }
  }

  dynamic _findScheduleInSalonList(
    Map<String, dynamic> response,
    dynamic branchId,
    dynamic salonId,
  ) {
    final rawSalons = response['data'];

    if (rawSalons is! List) return null;

    for (final rawSalon in rawSalons.whereType<Map>()) {
      final salon = Map<String, dynamic>.from(rawSalon);
      final branches = salon['branches'];

      if (branches is List) {
        for (final rawBranch in branches.whereType<Map>()) {
          final branch = Map<String, dynamic>.from(rawBranch);

          if (branch['id']?.toString() == branchId?.toString()) {
            return _extractSchedule(branch) ?? _extractSchedule(salon);
          }
        }
      }

      if (salon['id']?.toString() == salonId?.toString()) {
        return _extractSchedule(salon);
      }
    }

    return null;
  }

  dynamic _extractSchedule(dynamic value) {
    if (value is! Map) return value;

    final map = Map<String, dynamic>.from(value);

    for (final key in const [
      'schedule',
      'schedules',
      'workingHours',
      'operatingHours',
    ]) {
      if (map[key] != null) return map[key];
    }

    for (final key in const ['data', 'branch', 'salon']) {
      final nested = map[key];

      if (nested is Map) {
        final schedule = _extractSchedule(nested);
        if (schedule != null) return schedule;
      }
    }

    return null;
  }

  bool _applyOperatingSchedule(dynamic rawSchedule) {
    final schedule = _extractSchedule(rawSchedule);
    final operatingSlots = _operatingSlotsFromSchedule(schedule) ??
        <String, List<_OperatingSlot>>{};
    final explicitClosedDays = _explicitClosedDaysFromSchedule(schedule);

    if (operatingSlots.isEmpty && explicitClosedDays.isEmpty) return false;

    operatingSlots.removeWhere(
      (day, _) => explicitClosedDays.contains(_dayKey(day)),
    );

    final closedDays = _weekDays
        .map(_dayKey)
        .where(
          (day) =>
              explicitClosedDays.contains(day) ||
              !operatingSlots.containsKey(day),
        )
        .toSet();

    void apply() {
      _operatingSlotsByDay
        ..clear()
        ..addAll(operatingSlots);

      _closedDays
        ..clear()
        ..addAll(closedDays);

      for (final day in _closedDays) {
        weeklySchedule[_displayDay(day)]?.clear();
      }

      // Important:
      // If "Use salon open & close time" is selected,
      // always fill visible schedule from salon/branch operating hours.
      // This also fixes edit mode.
      if (_useSalonHours) {
        _clearWeeklySchedule();
        _fillEmptyDaysFromOperatingSlots(operatingSlots);
        return;
      }

      // A day should never be open with no visible timing. If the member
      // has no custom slot for an open day, show the salon/branch timing.
      _fillEmptyDaysFromOperatingSlots(operatingSlots);
      _sortWeeklyScheduleInPlace();
    }

    if (!mounted) {
      apply();
      return true;
    }

    setState(apply);
    return true;
  }

  Set<String> _explicitClosedDaysFromSchedule(dynamic rawSchedule) {
    final schedule = _extractSchedule(rawSchedule);
    final closedDays = <String>{};

    void addClosedDay(dynamic value) {
      if (value is String) {
        final dayKey = _dayKey(value);
        if (_isKnownWeekday(dayKey)) closedDays.add(dayKey);
        return;
      }

      if (value is Map) {
        final dayKey = _dayKeyFromScheduleMap(value);
        if (dayKey != null) closedDays.add(dayKey);
      }
    }

    void addClosedDayEntries(dynamic value) {
      if (value is Iterable) {
        for (final item in value) {
          addClosedDay(item);
        }
      } else {
        addClosedDay(value);
      }
    }

    if (schedule is Map) {
      for (final key in const [
        'closedDays',
        'closedDay',
        'offDays',
        'offDay',
        'weeklyOffs',
        'weeklyOff',
        'dayOffs',
        'dayOff',
        'holidays',
      ]) {
        addClosedDayEntries(schedule[key]);
      }

      final directDay = _dayKeyFromScheduleMap(schedule);
      if (directDay != null && _isExplicitlyClosedScheduleValue(schedule)) {
        closedDays.add(directDay);
      }

      for (final day in _weekDays) {
        final dayKey = _dayKey(day);
        if (schedule.containsKey(dayKey) &&
            _isExplicitlyClosedScheduleValue(schedule[dayKey])) {
          closedDays.add(dayKey);
        }
        if (schedule.containsKey(day) &&
            _isExplicitlyClosedScheduleValue(schedule[day])) {
          closedDays.add(dayKey);
        }
      }
    } else if (schedule is List) {
      for (final item in schedule.whereType<Map>()) {
        final dayKey = _dayKeyFromScheduleMap(item);
        if (dayKey != null && _isExplicitlyClosedScheduleValue(item)) {
          closedDays.add(dayKey);
        }
      }
    }

    return closedDays;
  }

  bool _isKnownWeekday(String dayKey) {
    final normalized = _dayKey(dayKey);
    return _weekDays.map(_dayKey).contains(normalized);
  }

  String? _dayKeyFromScheduleMap(Map value) {
    for (final key in const [
      'day',
      'dayOfWeek',
      'weekDay',
      'weekday',
      'name'
    ]) {
      final day = value[key]?.toString().trim();
      if (day == null || day.isEmpty) continue;
      final dayKey = _dayKey(day);
      if (_isKnownWeekday(dayKey)) return dayKey;
    }
    return null;
  }

  bool? _boolFromScheduleValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (const {'true', 'yes', 'y', '1', 'open', 'opened', 'working'}
          .contains(normalized)) {
        return true;
      }
      if (const {'false', 'no', 'n', '0', 'closed', 'close', 'off', 'inactive'}
          .contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  bool _isExplicitlyClosedScheduleValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return !value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return const {'closed', 'close', 'off', 'holiday', 'inactive'}
          .contains(normalized);
    }
    if (value is Iterable) return value.isEmpty;

    if (value is Map) {
      for (final key in const [
        'closed',
        'isClosed',
        'isDayClosed',
        'dayClosed',
        'isOff',
        'off',
        'isHoliday',
        'holiday',
      ]) {
        final closed = _boolFromScheduleValue(value[key]);
        if (closed == true) return true;
      }

      for (final key in const [
        'isOpen',
        'open',
        'opened',
        'isWorking',
        'working',
        'enabled',
        'isEnabled',
        'active',
        'isActive',
      ]) {
        final open = _boolFromScheduleValue(value[key]);
        if (open == false) return true;
      }

      for (final key in const ['status', 'dayStatus', 'availabilityStatus']) {
        final status = value[key]?.toString().trim().toLowerCase();
        if (status == null) continue;
        if (const {'closed', 'close', 'off', 'holiday', 'inactive'}
            .contains(status)) {
          return true;
        }
      }

      for (final key in const [
        'slots',
        'timeSlots',
        'timings',
        'workingHours'
      ]) {
        final slots = value[key];
        if (slots is Iterable && slots.isEmpty) return true;
      }
    }

    return false;
  }

  Map<String, List<_OperatingSlot>>? _operatingSlotsFromSchedule(
    dynamic schedule,
  ) {
    if (schedule is Map) {
      final result = <String, List<_OperatingSlot>>{};
      var foundAnyDay = false;

      for (final day in _weekDays) {
        final key = _dayKey(day);
        final value = schedule[key] ?? schedule[day];

        if (value == null) continue;

        foundAnyDay = true;

        final slots = _slotsFromValue(value);

        if (slots.isNotEmpty) {
          result[key] = _normalizeOperatingSlots(slots);
        }
      }

      return foundAnyDay ? result : null;
    }

    if (schedule is List) {
      final result = <String, List<_OperatingSlot>>{};
      var foundAnyDay = false;

      for (final item in schedule.whereType<Map>()) {
        final day = _dayKeyFromScheduleMap(item);

        if (day == null || day.isEmpty) continue;

        foundAnyDay = true;

        final slots = _slotsFromValue(item);

        if (slots.isNotEmpty) {
          result[day] = _normalizeOperatingSlots(slots);
        }
      }

      return foundAnyDay ? result : null;
    }

    return null;
  }

  List<_OperatingSlot> _normalizeOperatingSlots(List<_OperatingSlot> slots) {
    if (slots.isEmpty) return const [];

    final sorted = List<_OperatingSlot>.from(slots)
      ..sort((a, b) {
        final startCompare = a.startMinutes.compareTo(b.startMinutes);
        return startCompare != 0
            ? startCompare
            : a.endMinutes.compareTo(b.endMinutes);
      });

    final merged = <_OperatingSlot>[];

    for (final slot in sorted) {
      if (merged.isEmpty) {
        merged.add(slot);
        continue;
      }

      final previous = merged.last;

      if (slot.startMinutes <= previous.endMinutes) {
        merged[merged.length - 1] = _OperatingSlot(
          startMinutes: previous.startMinutes,
          endMinutes: slot.endMinutes > previous.endMinutes
              ? slot.endMinutes
              : previous.endMinutes,
        );
      } else {
        merged.add(slot);
      }
    }

    return merged;
  }

  String _to24h(String input) {
    final text = input.trim();
    if (text.isEmpty) return text;

    final reg24 = RegExp(r'^(\d{1,2}):([0-5]\d)(?::([0-5]\d))?$');
    final match24 = reg24.firstMatch(text);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1) ?? '');
      final minute = int.tryParse(match24.group(2) ?? '');
      final second = int.tryParse(match24.group(3) ?? '') ?? 0;
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        return text;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
    }

    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
    final match12 = reg12.firstMatch(text);
    if (match12 != null) {
      var hour = int.parse(match12.group(1)!);
      final minute = int.parse(match12.group(2)!);
      final meridiem = match12.group(3)!.toUpperCase();
      if (hour == 12) hour = 0;
      if (meridiem == 'PM') hour += 12;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
    }

    return text;
  }

  List<_OperatingSlot> _slotsFromValue(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(_slotFromMap)
          .whereType<_OperatingSlot>()
          .toList();
    }

    if (value is Map) {
      if (_isExplicitlyClosedScheduleValue(value)) return const [];

      final slots = value['slots'];

      if (slots is List) {
        return slots
            .whereType<Map>()
            .map(_slotFromMap)
            .whereType<_OperatingSlot>()
            .toList();
      }

      final directSlot = _slotFromMap(value);

      return directSlot == null ? const [] : [directSlot];
    }

    return const [];
  }

  _OperatingSlot? _slotFromMap(Map value) {
    final start = _parseTimeToMinutes(
      (value['startTime'] ?? value['start'] ?? '').toString(),
    );

    final end = _parseTimeToMinutes(
      (value['endTime'] ?? value['end'] ?? '').toString(),
    );

    if (start == null || end == null || end <= start) return null;

    final roundedStart = _roundDownToStep(start);
    var roundedEnd = _roundDownToStep(end);

    if (roundedEnd <= roundedStart) {
      roundedEnd = roundedStart + _timeMinuteStep;
    }

    if (roundedEnd <= roundedStart) return null;

    return _OperatingSlot(
      startMinutes: roundedStart,
      endMinutes: roundedEnd,
    );
  }

  void _fillEmptyDaysFromOperatingSlots(
    Map<String, List<_OperatingSlot>> operatingSlots,
  ) {
    for (final entry in operatingSlots.entries) {
      final displayDay = _displayDay(entry.key);

      if (_memberOffDays.contains(_dayKey(displayDay))) {
        continue;
      }

      if ((weeklySchedule[displayDay] ?? const []).isNotEmpty) {
        weeklySchedule[displayDay] = weeklySchedule[displayDay]!
            .map((slot) => _normalizeSlotWithinDay(displayDay, slot))
            .toList();
        continue;
      }

      weeklySchedule[displayDay] = entry.value
          .map(
            (slot) => {
              'start': _formatMinutes(slot.startMinutes),
              'end': _formatMinutes(slot.endMinutes),
            },
          )
          .toList();
    }
  }

  Map<String, String> _normalizeSlotWithinDay(
    String day,
    Map<String, String> slot,
  ) {
    final options = _timeOptionsForDay(day);

    if (options.isEmpty) return slot;

    var start = slot['start'] ?? options.first;
    var end = slot['end'] ?? options.last;

    if (!options.contains(start)) start = options.first;
    if (!options.contains(end)) end = options.last;

    final startMinutes = _parseTimeToMinutes(start);
    final endMinutes = _parseTimeToMinutes(end);

    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return {
        'start': options.first,
        'end': options.last,
      };
    }

    return {
      'start': start,
      'end': end,
    };
  }

  String _displayDay(String dayKey) {
    return _weekDays.firstWhere(
      (day) => _dayKey(day) == dayKey,
      orElse: () => dayKey[0].toUpperCase() + dayKey.substring(1),
    );
  }

  int? _parseTimeToMinutes(String input) {
    final text = input.trim();

    if (text.isEmpty) return null;

    final twelveMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);

    if (twelveMatch != null) {
      var hour = int.parse(twelveMatch.group(1)!);
      final minute = int.parse(twelveMatch.group(2)!);
      final suffix = twelveMatch.group(3)!.toUpperCase();

      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;

      return hour * 60 + minute;
    }

    final twentyFourMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);

    if (twentyFourMatch != null) {
      final hour = int.parse(twentyFourMatch.group(1)!);
      final minute = int.parse(twentyFourMatch.group(2)!);

      return hour * 60 + minute;
    }

    return null;
  }

  String _formatMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = ((hour + 11) % 12) + 1;

    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  List<String> _timeOptionsForDay(String day) {
    final slots = _operatingSlotsByDay[_dayKey(day)];

    if (slots == null || slots.isEmpty) return const [];

    final values = <String>[];

    for (final slot in slots) {
      final start = _roundDownToStep(slot.startMinutes);
      final end = _roundDownToStep(slot.endMinutes);
      final effectiveEnd = end <= start ? start + _timeMinuteStep : end;

      for (var minute = start;
          minute <= effectiveEnd;
          minute += _timeMinuteStep) {
        values.add(_formatMinutes(minute));
      }
    }

    return values.toSet().toList();
  }

  List<String> _timeOptionsForField(
    String day,
    int index,
    String timeType,
  ) {
    final options = _timeOptionsForDay(day);

    if (options.isEmpty) return const [];

    final slots = weeklySchedule[day] ?? const <Map<String, String>>[];
    final slot = index >= 0 && index < slots.length ? slots[index] : null;

    final pairedTime = slot == null
        ? null
        : timeType == 'start'
            ? slot['end']
            : slot['start'];

    final pairedMinutes =
        pairedTime == null ? null : _parseTimeToMinutes(pairedTime);

    // Other slots already booked for this day — a candidate time must not
    // produce a range that overlaps any of them.
    final otherRanges = <_OperatingSlot>[];
    for (var i = 0; i < slots.length; i++) {
      if (i == index) continue;
      final start = _parseTimeToMinutes(slots[i]['start'] ?? '');
      final end = _parseTimeToMinutes(slots[i]['end'] ?? '');
      if (start == null || end == null || end <= start) continue;
      otherRanges.add(_OperatingSlot(startMinutes: start, endMinutes: end));
    }

    final dayMaxMinutes = options
        .map((option) => _parseTimeToMinutes(option) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return options.where((option) {
      final minutes = _parseTimeToMinutes(option);

      if (minutes == null) return true;

      if (pairedMinutes != null) {
        final withinSameSlot = timeType == 'start'
            ? minutes < pairedMinutes
            : minutes > pairedMinutes;
        if (!withinSameSlot) return false;
      }

      // A new slot's start must leave room for at least the minimum
      // duration before the day closes.
      if (timeType == 'start' && dayMaxMinutes - minutes < _timeMinuteStep) {
        return false;
      }

      final candidateStart = timeType == 'start' ? minutes : pairedMinutes;
      final candidateEnd = timeType == 'start' ? pairedMinutes : minutes;

      if (candidateStart == null || candidateEnd == null) return true;

      for (final other in otherRanges) {
        // A later slot's start must sit a full gap after an earlier slot's
        // end — not just avoid overlapping it.
        final blockedEnd = timeType == 'start'
            ? other.endMinutes + _timeMinuteStep
            : other.endMinutes;
        if (candidateStart < blockedEnd && other.startMinutes < candidateEnd) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _prefillSchedules() {
    final rawSchedules = widget.formData['schedules'];
    final isEdit = widget.formData['isEdit'] == true;
    final daysWithSchedule = <String>{};
    var foundAny = false;

    if (rawSchedules is List && rawSchedules.isNotEmpty) {
      debugPrint(
        '[TeamSchedule] Prefilling member schedules count=${rawSchedules.length}',
      );

      for (final raw in rawSchedules.whereType<Map>()) {
        final day = (raw['day'] ?? '').toString().trim().toLowerCase();

        if (day.isEmpty) continue;

        final normalizedDay = _displayDay(day);

        if (!weeklySchedule.containsKey(normalizedDay)) continue;

        final startRaw = (raw['startTime'] ?? raw['start'] ?? '').toString();
        final endRaw = (raw['endTime'] ?? raw['end'] ?? '').toString();

        final startMinutes = _parseTimeToMinutes(startRaw);
        final endMinutes = _parseTimeToMinutes(endRaw);

        if (startMinutes == null ||
            endMinutes == null ||
            endMinutes <= startMinutes) {
          continue;
        }

        weeklySchedule[normalizedDay] ??= [];

        weeklySchedule[normalizedDay]!.add({
          'start': _formatMinutes(startMinutes),
          'end': _formatMinutes(endMinutes),
        });

        daysWithSchedule.add(normalizedDay);
        foundAny = true;
      }

      if (foundAny) {
        _sortWeeklyScheduleInPlace();
        debugPrint('[TeamSchedule] Member schedule prefill applied.');
      }
    } else {
      debugPrint('[TeamSchedule] No member schedules found in payload.');
    }

    // A day intentionally marked off is simply absent from the saved
    // schedules (see _buildScheduleData, which skips off days when building
    // the payload) — there's no explicit flag to read back. So in edit mode,
    // any weekday missing a saved schedule must be restored as "off",
    // otherwise _fillEmptyDaysFromOperatingSlots will auto-fill it with the
    // branch's default hours instead of showing it as marked off.
    if (isEdit) {
      for (final day in _weekDays) {
        if (!daysWithSchedule.contains(day)) {
          _memberOffDays.add(_dayKey(day));
        }
      }
    }

    return foundAny;
  }

  List<Map<String, String>> _buildScheduleData() {
    final List<Map<String, String>> scheduleData = [];

    weeklySchedule.forEach((day, slots) {
      if (_isClosedDay(day) || _isMemberOffDay(day)) return;

      final normalizedSlots = slots
          .map((slot) {
            final start = _parseTimeToMinutes(slot['start'] ?? '');
            final end = _parseTimeToMinutes(slot['end'] ?? '');

            if (start == null || end == null || end <= start) return null;

            return _OperatingSlot(startMinutes: start, endMinutes: end);
          })
          .whereType<_OperatingSlot>()
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      final mergedSlots = <_OperatingSlot>[];

      for (final slot in normalizedSlots) {
        if (mergedSlots.isEmpty) {
          mergedSlots.add(slot);
          continue;
        }

        final previous = mergedSlots.last;

        if (slot.startMinutes <= previous.endMinutes) {
          mergedSlots[mergedSlots.length - 1] = _OperatingSlot(
            startMinutes: previous.startMinutes,
            endMinutes: slot.endMinutes > previous.endMinutes
                ? slot.endMinutes
                : previous.endMinutes,
          );
        } else {
          mergedSlots.add(slot);
        }
      }

      for (final slot in mergedSlots) {
        scheduleData.add({
          'day': day.toLowerCase(),
          'startTime': _to24h(_formatMinutes(slot.startMinutes)),
          'endTime': _to24h(_formatMinutes(slot.endMinutes)),
        });
      }
    });

    return scheduleData;
  }

  void addSlot(String day) {
    if (_useSalonHours) return;
    _clearCopyMondaySelectionOnManualEdit(day);
    if (_isMemberOffDay(day)) return;

    if (_isClosedDay(day)) {
      _showClosedDayMessage(day);
      return;
    }

    final currentCount = weeklySchedule[day]?.length ?? 0;
    if (currentCount >= _maxSlotsPerDay) {
      Fluttertoast.showToast(
          msg: translateText(
              'You can add up to $_maxSlotsPerDay slots per day.'));
      return;
    }

    final nextSlot = _nextAvailableSlotForDay(day);

    if (nextSlot == null) {
      _showNoAvailableSlotMessage(day);
      return;
    }

    setState(() {
      weeklySchedule[day]?.add({
        'start': _formatMinutes(nextSlot.startMinutes),
        'end': _formatMinutes(nextSlot.endMinutes),
      });
      _sortWeeklyScheduleInPlace();
    });

    if (day == 'Monday') {
      _syncMondayToAllOpenDays();
    }
  }

  // _OperatingSlot? _nextAvailableSlotForDay(String day) {
  //   final operatingSlots = _operatingSlotsByDay[_dayKey(day)];

  //   final bounds = operatingSlots == null || operatingSlots.isEmpty
  //       ? const [
  //           _OperatingSlot(
  //             startMinutes: 8 * 60,
  //             endMinutes: 20 * 60,
  //           ),
  //         ]
  //       : operatingSlots;

  //   final existing = (weeklySchedule[day] ?? const <Map<String, String>>[])
  //       .map((slot) {
  //         final start = _parseTimeToMinutes(slot['start'] ?? '');
  //         final end = _parseTimeToMinutes(slot['end'] ?? '');

  //         if (start == null || end == null || end <= start) return null;

  //         return _OperatingSlot(
  //           startMinutes: start,
  //           endMinutes: end,
  //         );
  //       })
  //       .whereType<_OperatingSlot>()
  //       .toList()
  //     ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  //   const minimumDuration = _timeMinuteStep;

  //   for (final bound in bounds) {
  //     var cursor = bound.startMinutes;

  //     for (final used in existing) {
  //       if (used.endMinutes <= bound.startMinutes ||
  //           used.startMinutes >= bound.endMinutes) {
  //         continue;
  //       }

  //       final usedStart = used.startMinutes.clamp(
  //         bound.startMinutes,
  //         bound.endMinutes,
  //       );

  //       if (usedStart - cursor >= minimumDuration) {
  //         return _OperatingSlot(
  //           startMinutes: cursor,
  //           endMinutes: usedStart,
  //         );
  //       }

  //       if (used.endMinutes > cursor) {
  //         cursor = used.endMinutes.clamp(
  //           bound.startMinutes,
  //           bound.endMinutes,
  //         );
  //       }
  //     }

  //     if (bound.endMinutes - cursor >= minimumDuration) {
  //       return _OperatingSlot(
  //         startMinutes: cursor,
  //         endMinutes: bound.endMinutes,
  //       );
  //     }
  //   }

  //   return null;
  // }
  _OperatingSlot? _nextAvailableSlotForDay(String day) {
    final operatingSlots = _operatingSlotsByDay[_dayKey(day)];

    if (operatingSlots == null || operatingSlots.isEmpty) {
      return null;
    }

    final existing = (weeklySchedule[day] ?? const <Map<String, String>>[])
        .map((slot) {
          final start = _parseTimeToMinutes(slot['start'] ?? '');
          final end = _parseTimeToMinutes(slot['end'] ?? '');

          if (start == null || end == null || end <= start) return null;

          return _OperatingSlot(
            startMinutes: start,
            endMinutes: end,
          );
        })
        .whereType<_OperatingSlot>()
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    if (existing.isEmpty) {
      final firstBound = operatingSlots.first;
      if (firstBound.endMinutes - firstBound.startMinutes < _timeMinuteStep) {
        return null;
      }

      return _OperatingSlot(
        startMinutes: firstBound.startMinutes,
        endMinutes: firstBound.endMinutes,
      );
    }

    final lastUsed = existing.last;
    final nextStart = _roundUpToStep(lastUsed.endMinutes + _timeMinuteStep);

    for (final bound in operatingSlots) {
      if (nextStart < bound.startMinutes) {
        continue;
      }

      if (nextStart >= bound.endMinutes) {
        continue;
      }

      if (bound.endMinutes - nextStart < _timeMinuteStep) {
        continue;
      }

      return _OperatingSlot(
        startMinutes: nextStart,
        endMinutes: bound.endMinutes,
      );
    }

    return null;
  }

  void deleteSlot(String day, int index) {
    if (_useSalonHours) return;
    _clearCopyMondaySelectionOnManualEdit(day);

    setState(() {
      weeklySchedule[day]?.removeAt(index);
    });

    if (day == 'Monday') {
      _syncMondayToAllOpenDays();
    }
  }

  void updateTime(String day, int index, String timeType, String newTime) {
    if (_useSalonHours) return;

    _clearCopyMondaySelectionOnManualEdit(day);
    String? toastMessage;

    setState(() {
      weeklySchedule[day]?[index][timeType] = newTime;

      final slot = weeklySchedule[day]?[index];

      if (slot == null) return;

      final start = _parseTimeToMinutes(slot['start'] ?? '');
      final end = _parseTimeToMinutes(slot['end'] ?? '');
      final options = _timeOptionsForDay(day);

      if (start == null || end == null || options.isEmpty || end > start) {
        // if (timeType == 'end') {
        //   toastMessage = translateText(
        //     'End time updated. Only 10-minute steps are allowed.',
        //   );
        // }
        return;
      }

      if (timeType == 'start') {
        String? nextEnd;
        for (final option in options) {
          if ((_parseTimeToMinutes(option) ?? 0) > start) {
            nextEnd = option;
            break;
          }
        }
        // No option in the day's bounds is after `start` (e.g. `start` is
        // already the last available time) — never fall back to an option
        // that could equal `start` itself. Just add the minimum gap.
        nextEnd ??= _formatMinutes(start + _timeMinuteStep);

        slot['end'] = nextEnd;
        toastMessage = translateText(
          'End time was adjusted to keep a 10-minute gap.',
        );
      } else {
        String? previousStart;
        for (var i = options.length - 1; i >= 0; i--) {
          if ((_parseTimeToMinutes(options[i]) ?? 0) < end) {
            previousStart = options[i];
            break;
          }
        }
        previousStart ??= _formatMinutes(end - _timeMinuteStep);

        slot['start'] = previousStart;
        toastMessage = translateText(
          'Start time was adjusted to keep a 10-minute gap.',
        );
      }

      _resolveOverlappingSlots(day);
      _sortWeeklyScheduleInPlace();
    });

    if (toastMessage != null) {
      Fluttertoast.showToast(msg: toastMessage!);
    }

    if (day == 'Monday') {
      _syncMondayToAllOpenDays();
    }
  }

  // Editing one slot's time can leave a later slot overlapping it (e.g.
  // widening slot 1 to end at 7 PM after slot 2 was already set to start at
  // 6:40 AM). Push any now-overlapping later slot forward so it never starts
  // before the previous slot's end.
  void _resolveOverlappingSlots(String day) {
    final slots = weeklySchedule[day];
    if (slots == null || slots.length < 2) return;

    slots.sort(_slotComparator);

    for (var i = 1; i < slots.length; i++) {
      final prevEnd = _parseTimeToMinutes(slots[i - 1]['end'] ?? '');
      final currentStart = _parseTimeToMinutes(slots[i]['start'] ?? '');
      final currentEnd = _parseTimeToMinutes(slots[i]['end'] ?? '');

      if (prevEnd == null || currentStart == null || currentEnd == null) {
        continue;
      }

      final requiredStart = prevEnd + _timeMinuteStep;
      if (currentStart >= requiredStart) continue;

      // Never let the pushed-forward slot end up with end <= start —
      // always keep at least the minimum step as a gap.
      final newEnd = currentEnd > requiredStart
          ? currentEnd
          : requiredStart + _timeMinuteStep;

      slots[i]['start'] = _formatMinutes(requiredStart);
      slots[i]['end'] = _formatMinutes(newEnd);
    }
  }

  void _syncMondayToAllOpenDays() {
    if (!_copyMondayToAllChecked) return;

    final mondayIsOff = _isMemberOffDay('Monday');
    final mondaySlots =
        (weeklySchedule['Monday'] ?? const <Map<String, String>>[])
            .map((slot) => Map<String, String>.from(slot))
            .toList();

    setState(() {
      for (final day in _weekDays) {
        if (day == 'Monday' || _isClosedDay(day)) continue;

        final slots = weeklySchedule[day];
        if (slots == null) continue;

        final dayKey = _dayKey(day);
        if (mondayIsOff) {
          if (slots.isNotEmpty) {
            _memberOffDaySnapshots[dayKey] = _cloneSlotList(slots);
          }
          slots.clear();
          _memberOffDays.add(dayKey);
          continue;
        }

        _memberOffDays.remove(dayKey);
        _memberOffDaySnapshots.remove(dayKey);

        // Copy Monday's exact times as-is — do NOT silently snap them to
        // this day's own operating hours. If the branch closes earlier on
        // this day, that mismatch must stay visible so the per-day
        // validation below can flag it, rather than being silently
        // "corrected" without the user noticing.
        slots
          ..clear()
          ..addAll(mondaySlots.map((slot) => Map<String, String>.from(slot)));
      }

      _sortWeeklyScheduleInPlace();
    });
  }

  void _copyMondayToAll(bool value) {
    if (_useSalonHours) return;

    setState(() => _copyMondayToAllChecked = value);

    if (!value) {
      _restoreDaysToBranchDefaults();
      return;
    }

    if (weeklySchedule['Monday']!.isEmpty && !_isMemberOffDay('Monday')) {
      setState(() => _copyMondayToAllChecked = false);
      Fluttertoast.showToast(
        msg: translateText('Please add time slots for Monday first.'),
      );
      return;
    }

    _syncMondayToAllOpenDays();
  }

  // Undo whatever "Copy Monday schedule to all days" applied — every
  // non-Monday working day goes back to the branch's own operating hours
  // for that day, instead of staying stuck on Monday's copied values.
  void _restoreDaysToBranchDefaults() {
    setState(() {
      for (final day in _weekDays) {
        if (day == 'Monday' || _isClosedDay(day) || _isMemberOffDay(day)) {
          continue;
        }

        final windows = _operatingSlotsByDay[_dayKey(day)];

        weeklySchedule[day] = (windows != null && windows.isNotEmpty)
            ? windows
                .map(
                  (slot) => {
                    'start': _formatMinutes(slot.startMinutes),
                    'end': _formatMinutes(slot.endMinutes),
                  },
                )
                .toList()
            : [
                {'start': '08:00 AM', 'end': '08:00 PM'},
              ];
      }

      _sortWeeklyScheduleInPlace();
    });
  }

  void _clearCopyMondaySelectionOnManualEdit(String day) {
    if (!_copyMondayToAllChecked || day == 'Monday') return;
    setState(() => _copyMondayToAllChecked = false);
  }

  void _showClosedDayMessage(String day) {
    Fluttertoast.showToast(
        msg: translateText('$day is closed for appointments.'));
  }

  void _showNoAvailableSlotMessage(String day) {
    Fluttertoast.showToast(msg: translateText('No time left for that day.'));
  }

  List<Map<String, String>> _cloneSlotList(
    List<Map<String, String>> slots,
  ) {
    return slots
        .map((slot) => Map<String, String>.from(slot))
        .toList(growable: true);
  }

  List<Map<String, String>> _defaultOperatingSlotsForDay(String day) {
    final operatingSlots = _operatingSlotsByDay[_dayKey(day)];
    if (operatingSlots == null || operatingSlots.isEmpty) {
      return const [];
    }

    return operatingSlots
        .map(
          (slot) => {
            'start': _formatMinutes(slot.startMinutes),
            'end': _formatMinutes(slot.endMinutes),
          },
        )
        .toList(growable: true);
  }

  bool _isMemberOffDay(String day) => _memberOffDays.contains(_dayKey(day));

  // Days whose entered hours fall outside the branch's own operating
  // hours for that day (e.g. "Copy Monday schedule to all days" copying a
  // wider Monday range onto a day the branch closes earlier). These must
  // be fixed before the team member's schedule can be saved. Carries the
  // actual entered/branch time ranges so the on-screen message can show
  // them — works the same whether one day or several are affected.
  List<_ScheduleConflict> get _scheduleConflicts {
    final conflicts = <_ScheduleConflict>[];

    for (final day in _weekDays) {
      if (_isClosedDay(day) || _isMemberOffDay(day)) continue;

      final slots = weeklySchedule[day] ?? const <Map<String, String>>[];
      if (slots.isEmpty) continue;

      final starts = <int>[];
      final ends = <int>[];
      for (final slot in slots) {
        final start = _parseTimeToMinutes(slot['start'] ?? '');
        final end = _parseTimeToMinutes(slot['end'] ?? '');
        if (start != null) starts.add(start);
        if (end != null) ends.add(end);
      }
      if (starts.isEmpty || ends.isEmpty) continue;

      final operatingWindows = _operatingSlotsByDay[_dayKey(day)];

      final fitsWithinBranchHours = operatingWindows != null &&
          operatingWindows.isNotEmpty &&
          slots.every((slot) {
            final start = _parseTimeToMinutes(slot['start'] ?? '');
            final end = _parseTimeToMinutes(slot['end'] ?? '');
            if (start == null || end == null) return true;

            return operatingWindows.any(
              (window) =>
                  start >= window.startMinutes && end <= window.endMinutes,
            );
          });

      if (fitsWithinBranchHours) continue;

      final enteredStart = starts.reduce((a, b) => a < b ? a : b);
      final enteredEnd = ends.reduce((a, b) => a > b ? a : b);

      final branchRangeText =
          (operatingWindows == null || operatingWindows.isEmpty)
              ? translateText('Closed')
              : operatingWindows
                  .map(
                    (window) =>
                        '${_formatMinutes(window.startMinutes)} - ${_formatMinutes(window.endMinutes)}',
                  )
                  .join(', ');

      conflicts.add(
        _ScheduleConflict(
          day: day,
          enteredRange:
              '${_formatMinutes(enteredStart)} - ${_formatMinutes(enteredEnd)}',
          branchRange: branchRangeText,
        ),
      );
    }

    return conflicts;
  }

  _ScheduleConflict? _conflictForDay(String day) {
    for (final conflict in _scheduleConflicts) {
      if (conflict.day == day) return conflict;
    }
    return null;
  }

  Future<void> _showMondayCopyLoader() async {
    if (!mounted) return;
    setState(() => _isApplyingMondayCopy = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  Future<void> _hideMondayCopyLoader() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _isApplyingMondayCopy = false);
  }

  Future<void> _toggleMarkOff(String day) async {
    if (_useSalonHours || _isClosedDay(day)) return;

    final shouldCopyMonday = day == 'Monday' && _copyMondayToAllChecked;
    if (shouldCopyMonday) {
      await _showMondayCopyLoader();
    } else {
      _clearCopyMondaySelectionOnManualEdit(day);
    }

    final key = _dayKey(day);

    try {
      setState(() {
        if (_memberOffDays.contains(key)) {
          _memberOffDays.remove(key);
          final snapshot = _memberOffDaySnapshots.remove(key);

          if (snapshot != null && snapshot.isNotEmpty) {
            weeklySchedule[day] = _cloneSlotList(snapshot);
          } else {
            weeklySchedule[day] = _defaultOperatingSlotsForDay(day);
          }
        } else {
          final currentSlots =
              weeklySchedule[day] ?? const <Map<String, String>>[];
          if (currentSlots.isNotEmpty) {
            _memberOffDaySnapshots[key] = _cloneSlotList(currentSlots);
          }
          weeklySchedule[day] = [];
          _memberOffDays.add(key);
        }

        _sortWeeklyScheduleInPlace();
      });

      if (day == 'Monday') {
        _syncMondayToAllOpenDays();
      }
    } finally {
      if (shouldCopyMonday) {
        await _hideMondayCopyLoader();
      }
    }
  }

  Future<void> _markWorking(String day) async {
    if (_useSalonHours || _isClosedDay(day)) return;
    if (!_isMemberOffDay(day)) return;

    await _toggleMarkOff(day);
  }

  Widget _timeDropdownField(
    String day,
    int index,
    String timeType,
  ) {
    final currentValue = weeklySchedule[day]?[index][timeType];
    final options = _timeOptionsForField(day, index, timeType);
    final safeValue = options.contains(currentValue) ? currentValue : null;

    return SizedBox(
      height: 34,
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF8D867F),
          size: 16,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: _useSalonHours ? const Color(0xFFF0EDE9) : Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD98A00)),
          ),
        ),
        hint: Text(
          translateText('Select time'),
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: _useSalonHours
            ? null
            : (value) {
                if (value == null) return;
                updateTime(day, index, timeType, value);
              },
      ),
    );
  }

  // Widget _weeklyHoursCard(String day) {
  //   final slots = weeklySchedule[day] ?? const <Map<String, String>>[];
  //   final isClosed = _isClosedDay(day);

  //   return Container(
  //     width: double.infinity,
  //     margin: const EdgeInsets.only(bottom: 14),
  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: const Color(0xFFF0E8DF)),
  //       boxShadow: const [
  //         BoxShadow(
  //           color: Color(0x08000000),
  //           blurRadius: 12,
  //           offset: Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           translateText(day),
  //           style: const TextStyle(
  //             color: Color(0xFF1F1B18),
  //             fontSize: 14,
  //             fontWeight: FontWeight.w800,
  //           ),
  //         ),
  //         const SizedBox(height: 18),
  //         if (isClosed)
  //           Text(
  //             translateText('CLOSED'),
  //             style: const TextStyle(
  //               color: Color(0xFFE54848),
  //               fontSize: 10,
  //               fontWeight: FontWeight.w900,
  //               letterSpacing: 0.8,
  //             ),
  //           )
  //         else ...[
  //           if (slots.isEmpty)
  //             Padding(
  //               padding: const EdgeInsets.only(bottom: 12),
  //               child: Text(
  //                 translateText('No time slots added'),
  //                 style: const TextStyle(
  //                   color: Color(0xFF9A928B),
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           for (var index = 0; index < slots.length; index++)
  //             _weeklySlotRow(day, index),
  //           if (!_useSalonHours)
  //             Align(
  //               alignment: Alignment.centerRight,
  //               child: _addSlotButton(day),
  //             ),
  //         ],
  //       ],
  //     ),
  //   );
  // }
  Widget _weeklyHoursCard(String day) {
    final slots = _sortedDaySlots(day);
    final isClosed = _isClosedDay(day);
    final isOff = _isMemberOffDay(day);
    final markedOff = isClosed || isOff;
    final conflict = _conflictForDay(day);

    return Opacity(
      opacity: _useSalonHours ? 0.55 : 1,
      child: IgnorePointer(
        ignoring: _useSalonHours,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
          decoration: BoxDecoration(
            color: markedOff ? const Color(0xFFFFFBF6) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  markedOff ? const Color(0xFFF3E4D2) : const Color(0xFFE1E5EA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      translateText(day),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isClosed)
                    Expanded(
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFF3E4D2)),
                        ),
                        child: Text(
                          translateText('SALON IS CLOSED'),
                          style: const TextStyle(
                            color: Color(0xFFB8A995),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                    ),
                  if (isClosed) const SizedBox(width: 10),
                  if (!isClosed && isOff)
                    _smallPillButton(
                      text: 'Mark Working',
                      filled: true,
                      onPressed: () => _markWorking(day),
                    ),
                ],
              ),
              if (!markedOff) ...[
                const SizedBox(height: 10),
                if (slots.isEmpty)
                  Row(
                    children: [
                      _addSlotButton(day),
                      const SizedBox(width: 10),
                      _smallPillButton(
                        text: 'Mark Off',
                        onPressed: () => _toggleMarkOff(day),
                      ),
                    ],
                  )
                else ...[
                  for (var index = 0; index < slots.length; index++)
                    _weeklySlotRow(day, index),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (slots.length < _maxSlotsPerDay) _addSlotButton(day),
                      if (slots.length < _maxSlotsPerDay)
                        const SizedBox(width: 10),
                      _smallPillButton(
                        text: 'Mark Off',
                        onPressed: () => _toggleMarkOff(day),
                      ),
                    ],
                  ),
                ],
              ],
              if (conflict != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${conflict.enteredRange} ${translateText("is outside branch hours")} '
                  '(${conflict.branchRange}).',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallPillButton({
    required String text,
    required VoidCallback onPressed,
    bool filled = false,
    IconData? icon,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(
                icon,
                size: 13,
                color:
                    filled ? const Color(0xFFD98A00) : const Color(0xFFBDBDBD),
              ),
        label: Text(
          translateText(text),
          style: TextStyle(
            color: filled ? const Color(0xFF7C5600) : const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor:
              filled ? const Color(0xFFFFF4DC) : const Color(0xFFF9FAFB),
          side: BorderSide(
            color: filled ? const Color(0xFFFFE1A8) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _weeklySlotRow(String day, int index) {
    final isLastSlot = index == ((weeklySchedule[day]?.length ?? 0) - 1);

    return Container(
      margin: EdgeInsets.only(bottom: isLastSlot ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _labeledTimeField(
                  label: 'Start Time',
                  child: _timeDropdownField(day, index, 'start'),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  translateText('to'),
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeledTimeField(
                  label: 'End Time',
                  child: _timeDropdownField(day, index, 'end'),
                ),
              ),
            ],
          ),
          if ((weeklySchedule[day] ?? const []).length > 1) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE54848),
                  size: 18,
                ),
                onPressed: () => deleteSlot(day, index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _labeledTimeField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText(label),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _addSlotButton(String day) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: () => addSlot(day),
        icon: const Icon(
          Icons.add_circle_rounded,
          size: 13,
          color: Color(0xFFD98A00),
        ),
        label: Text(
          translateText('Add Slot'),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD8DEE8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _addTeamMember() async {
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, String>> scheduleData = _buildScheduleData();
      if (scheduleData.isEmpty) {
        Fluttertoast.showToast(
          msg: translateText('At least one day must be working.'),
        );
        return;
      }

      final dynamic rawJoiningDate = widget.formData['joiningDate'];
      String? formattedJoiningDate;

      if (rawJoiningDate is DateTime) {
        formattedJoiningDate = DateFormat('yyyy-MM-dd').format(rawJoiningDate);
      } else if (rawJoiningDate is String && rawJoiningDate.isNotEmpty) {
        formattedJoiningDate = rawJoiningDate;
      }

      final List<dynamic> rawRoles =
          widget.formData['roles'] as List? ?? const [];

      final List<dynamic> rawSpecs = (widget.formData['specialities'] ??
              widget.formData['specializations']) as List? ??
          const [];

      final Map<String, dynamic> teamMemberData = {
        "phoneNumber": widget.formData['phoneNumber'],
        "firstName": _capitalize(widget.formData['firstName']),
        "lastName": _capitalize(widget.formData['lastName']),
        "email": widget.formData['email']?.toString().toLowerCase(),
        "gender": (widget.formData['gender'] ?? '').toString().toLowerCase(),
        "joiningDate": formattedJoiningDate,
        "info": widget.formData['brief'],
        "roles": List<String>.from(rawRoles.map((e) => e.toString())),
        "specialities": List<String>.from(rawSpecs.map((e) => e.toString())),
        "schedules": scheduleData,
        "useSalonHours": _useSalonHours,
        "experience": int.tryParse(
              widget.formData['experience']?.toString() ?? '',
            ) ??
            0,
        "otp": widget.formData['otp']?.toString(),
      };

      final ApiService apiService = ApiService();
      final int branchId = widget.formData['branchId'] as int;

      final Map<String, dynamic> response =
          await apiService.addTeamMember(branchId, teamMemberData);

      if (!mounted) return;

      if (response['success'] == true) {
        Fluttertoast.showToast(msg: 'Team member added successfully');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TeamScreen()),
          (route) => false,
        );
      } else {
        _showErrorDialog(
          extractErrorMessage(
            response['message'],
            fallback: 'Failed to add team member',
          ),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _showErrorDialog(extractErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _goToSelectServices() async {
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, String>> scheduleData = _buildScheduleData();
      if (scheduleData.isEmpty) {
        Fluttertoast.showToast(
          msg: translateText('At least one day must be working.'),
        );
        return;
      }

      widget.formData['schedules'] = scheduleData;

      final dynamic rawJoiningDate = widget.formData['joiningDate'];
      String? formattedJoiningDate;

      if (rawJoiningDate is DateTime) {
        formattedJoiningDate = DateFormat('yyyy-MM-dd').format(rawJoiningDate);
      } else if (rawJoiningDate is String && rawJoiningDate.isNotEmpty) {
        formattedJoiningDate = rawJoiningDate;
      }

      final List<dynamic> rawRoles =
          widget.formData['roles'] as List? ?? const [];

      final List<dynamic> rawSpecs = (widget.formData['specialities'] ??
              widget.formData['specializations']) as List? ??
          const [];

      final int? branchId = _toInt(widget.formData['branchId']);
      final Set<int> rememberedServiceIds = branchId == null
          ? _normalizeServiceIds(widget.formData['branchServiceIds'])
          : (_rememberedSelectedServiceIdsByBranchId[branchId] ??
              _normalizeServiceIds(widget.formData['branchServiceIds']));

      final branchServiceIds = rememberedServiceIds.toList();
      widget.formData['branchServiceIds'] = branchServiceIds;

      final Map<String, dynamic> teamMemberData = {
        "isEdit": widget.formData['isEdit'] == true,
        "userId": widget.formData['userId'],
        "phoneNumber": widget.formData['phoneNumber'],
        "firstName": widget.formData['firstName'],
        "lastName": widget.formData['lastName'],
        "email": widget.formData['email'],
        "gender": (widget.formData['gender'] ?? '').toString().toLowerCase(),
        "joiningDate": formattedJoiningDate,
        "info": widget.formData['brief'],
        "roles": List<String>.from(rawRoles.map((e) => e.toString())),
        "specialities": List<String>.from(rawSpecs.map((e) => e.toString())),
        "schedules": scheduleData,
        "useSalonHours": _useSalonHours,
        "otp": widget.formData['otp']?.toString(),
        "allowOnlineBooking": widget.formData['allowOnlineBooking'] ?? true,
        "branchServiceIds": branchServiceIds,
        if (widget.formData['isEdit'] == true)
          "userBranchServices":
              widget.formData['userBranchServices'] ?? const [],
        "address": widget.formData['address'],
        "branchId": branchId,
        "experience": int.tryParse(
              widget.formData['experience']?.toString() ?? '',
            ) ??
            0,
        "profilePictureUrl": widget.formData['profilePictureUrl'],
        "profileImage": widget.formData['profileImage'],
      };

      if (!mounted) return;

      debugPrint(
        '==================== TEAM MEMBER PAYLOAD SENT TO SELECT SERVICES ====================',
      );

      teamMemberData.forEach((key, value) {
        debugPrint('$key: $value');
      });

      final refresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTeamSelectServices(
            teamMemberData: teamMemberData,
          ),
        ),
      );

      if (!mounted) return;

      if (refresh is Map) {
        final cachedIds = _normalizeServiceIds(refresh['selectedServiceIds']);
        if (branchId != null) {
          _rememberedSelectedServiceIdsByBranchId[branchId] = cachedIds;
        }
        widget.formData['branchServiceIds'] = cachedIds.toList();
        if (refresh['schedules'] is List) {
          widget.formData['schedules'] =
              List<Map<String, String>>.from(refresh['schedules'] as List);
        }

        if (refresh['completed'] == true) {
          Navigator.pop(
            context,
            {
              'completed': true,
              'selectedServiceIds': cachedIds.toList(),
              'schedules': scheduleData,
            },
          );
          return;
        }
      } else if (refresh is List) {
        final cachedIds = _normalizeServiceIds(refresh);
        if (branchId != null) {
          _rememberedSelectedServiceIdsByBranchId[branchId] = cachedIds;
        }
        widget.formData['branchServiceIds'] = cachedIds.toList();
      } else if (refresh == true) {
        Navigator.pop(
          context,
          {
            'completed': true,
            'selectedServiceIds': branchServiceIds,
            'schedules': scheduleData,
          },
        );
        return;
      }
    } catch (e) {
      debugPrint('Failed to prepare team member data: $e');
      _showErrorDialog(extractErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    Fluttertoast.showToast(msg: translateText(message));
  }

  Map<String, dynamic> _currentStateResult({
    required bool completed,
  }) {
    final branchId = _toInt(widget.formData['branchId']);
    final branchServiceIds = branchId == null
        ? _normalizeServiceIds(widget.formData['branchServiceIds']).toList()
        : (_rememberedSelectedServiceIdsByBranchId[branchId]?.toList() ??
            _normalizeServiceIds(widget.formData['branchServiceIds']).toList());

    return {
      'completed': completed,
      'selectedServiceIds': branchServiceIds,
      'schedules': _buildScheduleData(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final navigationDisabled =
        _isSubmitting || _isLoadingOperatingSchedule || _isApplyingMondayCopy;
    final scheduleConflicts = _scheduleConflicts;
    final continueDisabled = navigationDisabled || scheduleConflicts.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationDisabled) return;
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context, _currentStateResult(completed: false));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F1),
        appBar: buildProfileSubpageAppBar(
          title: translateText('Add TimeSlots'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: navigationDisabled
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(
                        context, _currentStateResult(completed: false));
                  },
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MultiStepFlowHeader(
                      currentStep: 2,
                      steps: const [
                        FlowStepItem(
                          stepNumber: 1,
                          label: 'Personal Details',
                        ),
                        FlowStepItem(
                          stepNumber: 2,
                          label: 'Schedule',
                        ),
                        FlowStepItem(
                          stepNumber: 3,
                          label: 'Services',
                        ),
                        FlowStepItem(
                          stepNumber: 4,
                          label: 'Online Availability',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        translateText('Set Weekly Working Hours'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 532),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Text(
                              //   translateText('Set Working Schedule'),
                              //   style: const TextStyle(
                              //     color: Color(0xFF111827),
                              //     fontSize: 16,
                              //     fontWeight: FontWeight.w800,
                              //   ),
                              // ),
                              // const Spacer(),
                              const Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          for (final day in _weekDays) ...[
                            _weeklyHoursCard(day),
                            if (day == 'Monday') ...[
                              Row(
                                children: [
                                  Checkbox(
                                    value: _copyMondayToAllChecked,
                                    activeColor: AppColors.starColor,
                                    onChanged: _isLoadingOperatingSchedule ||
                                            _isApplyingMondayCopy
                                        ? null
                                        : (value) {
                                            _copyMondayToAll(value ?? false);
                                          },
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Expanded(
                                    child: Text(
                                      translateText(
                                        'Copy Monday schedule to all days',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: navigationDisabled
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        context,
                                        _currentStateResult(completed: false),
                                      );
                                    },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2D2926),
                                side: const BorderSide(
                                  color: Color(0xFFE2D3BF),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    translateText('Previous').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: continueDisabled
                                  ? null
                                  : () async {
                                      await _goToSelectServices();
                                    },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: AppColors.starColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            translateText('Save & Continue')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 15,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingOperatingSchedule || _isApplyingMondayCopy)
              _operatingScheduleLoader(),
          ],
        ),
      ),
    );
  }

  Widget _operatingScheduleLoader() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.starColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    translateText('Please wait...'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2B2520),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translateText('Loading...'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
