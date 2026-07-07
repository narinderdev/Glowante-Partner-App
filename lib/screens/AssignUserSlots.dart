// lib/screens/AssignUserSlots.dart
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/multi_step_flow_header.dart';
import 'team_online_availability_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class _OperatingSlot {
  const _OperatingSlot({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

class AssignUserSlot extends StatefulWidget {
  final int salonId;
  final int branchId;
  final int userId;
  final String joinedAt;
  final List<int> selectedServiceIds;
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> salons;

  const AssignUserSlot({
    super.key,
    required this.salonId,
    required this.branchId,
    required this.userId,
    required this.joinedAt,
    required this.selectedServiceIds,
    required this.member,
    required this.salons,
  });

  @override
  State<AssignUserSlot> createState() => _AssignUserSlotState();
}

class _AssignUserSlotState extends State<AssignUserSlot> {
  static const int _timeStepMinutes = 10;

  late Map<String, List<Map<String, String>>> weeklySchedule;

  bool isSubmitting = false;
  bool _sameAsBranchTimings = false;
  bool _copyMondayToAllChecked = false;
  bool _isLoadingOperatingSchedule = false;

  final Set<String> _markedOffDays = <String>{};
  final Set<String> _closedDays = <String>{};

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

    _loadOperatingSchedule();
  }

  List<String> get _weekDays => weeklySchedule.keys.toList();

  String _dayKey(String day) => day.trim().toLowerCase();

  bool _isClosedDay(String day) => _closedDays.contains(_dayKey(day));

  bool _isMarkedOff(String day) => _markedOffDays.contains(_dayKey(day));

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

  int _roundDownToStep(int minutes) {
    if (minutes <= 0) return 0;
    return (minutes ~/ _timeStepMinutes) * _timeStepMinutes;
  }

  void _syncMondayToAllOpenDays() {
    if (!_copyMondayToAllChecked) return;

    final mondaySlots =
        (weeklySchedule['Monday'] ?? const <Map<String, String>>[])
            .map((slot) => Map<String, String>.from(slot))
            .toList();

    setState(() {
      for (final day in _weekDays) {
        if (day == 'Monday' || _isClosedDay(day)) continue;

        _markedOffDays.remove(_dayKey(day));

        final slots = weeklySchedule[day];
        if (slots == null) continue;

        slots
          ..clear()
          ..addAll(
            mondaySlots.map((slot) => Map<String, String>.from(slot)),
          );
      }

      _sortWeeklyScheduleInPlace();
    });
  }

  Future<void> _loadOperatingSchedule() async {
    setState(() => _isLoadingOperatingSchedule = true);

    try {
      final salonListResponse = await ApiService().getSalonListApi();

      final fromSalonList = _findScheduleInSalonList(
        salonListResponse,
        widget.branchId,
        widget.salonId,
      );

      if (!_applyOperatingSchedule(fromSalonList)) {
        final branchResponse = await ApiService().getBranchDetail(
          widget.branchId,
        );
        _applyOperatingSchedule(_extractSchedule(branchResponse));
      }

      _applyDefaultBranchSlotsToEmptyDays();
    } catch (error) {
      debugPrint('Failed to load branch operating schedule: $error');
      _applyDefaultBranchSlotsToEmptyDays();
    } finally {
      if (mounted) {
        setState(() => _isLoadingOperatingSchedule = false);
      }
    }
  }

  dynamic _findScheduleInSalonList(
    Map<String, dynamic> response,
    int branchId,
    int salonId,
  ) {
    final rawSalons = response['data'];
    if (rawSalons is! List) return null;

    for (final rawSalon in rawSalons.whereType<Map>()) {
      final salon = Map<String, dynamic>.from(rawSalon);
      final branches = salon['branches'];

      if (branches is List) {
        for (final rawBranch in branches.whereType<Map>()) {
          final branch = Map<String, dynamic>.from(rawBranch);

          if (branch['id']?.toString() == branchId.toString()) {
            return _extractSchedule(branch) ?? _extractSchedule(salon);
          }
        }
      }

      if (salon['id']?.toString() == salonId.toString()) {
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
    final operatingSlots = _operatingSlotsFromSchedule(schedule);

    if (operatingSlots == null) return false;

    final closedDays = _weekDays
        .map(_dayKey)
        .where((day) => !operatingSlots.containsKey(day))
        .toSet();

    void apply() {
      _operatingSlotsByDay
        ..clear()
        ..addAll(operatingSlots);

      _closedDays
        ..clear()
        ..addAll(closedDays);

      for (final dayKey in _closedDays) {
        final day = _displayDay(dayKey);
        weeklySchedule[day]?.clear();
        _markedOffDays.add(dayKey);
      }
    }

    if (!mounted) {
      apply();
      return true;
    }

    setState(apply);
    return true;
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
          result[key] = slots;
        }
      }

      return foundAnyDay ? result : null;
    }

    if (schedule is List) {
      final result = <String, List<_OperatingSlot>>{};
      var foundAnyDay = false;

      for (final item in schedule.whereType<Map>()) {
        final day = item['day']?.toString().trim().toLowerCase();

        if (day == null || day.isEmpty) continue;

        foundAnyDay = true;

        final slots = _slotsFromValue(item);
        if (slots.isNotEmpty) {
          result[day] = slots;
        }
      }

      return foundAnyDay ? result : null;
    }

    return null;
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
      final isClosed = value['closed'] == true ||
          value['isClosed'] == true ||
          value['status']?.toString().toLowerCase() == 'closed';

      if (isClosed) return const [];

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
    final rawStart = _parseTimeToMinutes(
      (value['startTime'] ??
              value['start'] ??
              value['openTime'] ??
              value['openingTime'] ??
              '')
          .toString(),
    );

    final rawEnd = _parseTimeToMinutes(
      (value['endTime'] ??
              value['end'] ??
              value['closeTime'] ??
              value['closingTime'] ??
              '')
          .toString(),
    );

    if (rawStart == null || rawEnd == null || rawEnd <= rawStart) return null;

    final start = _roundDownToStep(rawStart);
    var end = _roundDownToStep(rawEnd);
    if (end <= start) {
      end = start + _timeStepMinutes;
    }
    if (end <= start) return null;

    return _OperatingSlot(
      startMinutes: start,
      endMinutes: end,
    );
  }

  void _applyDefaultBranchSlotsToEmptyDays() {
    if (!mounted) return;

    setState(() {
      for (final day in _weekDays) {
        if (_isClosedDay(day) || _isMarkedOff(day)) continue;

        if ((weeklySchedule[day] ?? const []).isNotEmpty) continue;

        final slots = _operatingSlotsByDay[_dayKey(day)];

        if (slots != null && slots.isNotEmpty) {
          weeklySchedule[day] = slots
              .map(
                (slot) => {
                  'start': _formatMinutes(slot.startMinutes),
                  'end': _formatMinutes(slot.endMinutes),
                },
              )
              .toList();
        } else {
          weeklySchedule[day] = [
            {
              'start': '08:00 AM',
              'end': '08:00 PM',
            },
          ];
        }
      }
    });
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

    final twentyFourWithSeconds =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);

    if (twentyFourWithSeconds != null) {
      final hour = int.parse(twentyFourWithSeconds.group(1)!);
      final minute = int.parse(twentyFourWithSeconds.group(2)!);
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

  String _displayDay(String dayKey) {
    return _weekDays.firstWhere(
      (day) => _dayKey(day) == dayKey,
      orElse: () => dayKey.isEmpty
          ? dayKey
          : dayKey[0].toUpperCase() + dayKey.substring(1),
    );
  }

  List<String> _timeOptionsForDay(String day) {
    final slots = _operatingSlotsByDay[_dayKey(day)];
    final values = <String>[];

    if (slots == null || slots.isEmpty) {
      for (var minute = 8 * 60; minute <= 20 * 60; minute += _timeStepMinutes) {
        values.add(_formatMinutes(minute));
      }
      return values;
    }

    for (final slot in slots) {
      final start = _roundDownToStep(slot.startMinutes);
      final end = _roundDownToStep(slot.endMinutes);
      final effectiveEnd = end <= start ? start + _timeStepMinutes : end;

      for (var minute = start;
          minute <= effectiveEnd;
          minute += _timeStepMinutes) {
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

    final slot = weeklySchedule[day]?[index];

    final pairedTime = slot == null
        ? null
        : (timeType == 'start' ? slot['end'] : slot['start']);

    final pairedMinutes =
        pairedTime == null ? null : _parseTimeToMinutes(pairedTime);

    return options.where((option) {
      final minutes = _parseTimeToMinutes(option);

      if (minutes == null || pairedMinutes == null) return true;

      return timeType == 'start'
          ? minutes < pairedMinutes
          : minutes > pairedMinutes;
    }).toList();
  }

  _OperatingSlot? _nextAvailableSlotForDay(String day) {
    final operatingSlots = _operatingSlotsByDay[_dayKey(day)];

    final bounds = operatingSlots == null || operatingSlots.isEmpty
        ? const [
            _OperatingSlot(
              startMinutes: 8 * 60,
              endMinutes: 20 * 60,
            ),
          ]
        : operatingSlots;

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

    const minimumDuration = _timeStepMinutes;

    for (final bound in bounds) {
      final daySlots = existing.where((slot) {
        return slot.endMinutes > bound.startMinutes &&
            slot.startMinutes < bound.endMinutes;
      }).toList();

      if (daySlots.isEmpty) {
        if (bound.endMinutes - bound.startMinutes >= minimumDuration) {
          return _OperatingSlot(
            startMinutes: bound.startMinutes,
            endMinutes: bound.endMinutes,
          );
        }
        continue;
      }

      final latestEnd = daySlots
          .map(
            (slot) => slot.endMinutes.clamp(
              bound.startMinutes,
              bound.endMinutes,
            ),
          )
          .reduce((a, b) => a > b ? a : b);

      if (bound.endMinutes - latestEnd >= minimumDuration) {
        return _OperatingSlot(
          startMinutes: latestEnd,
          endMinutes: bound.endMinutes,
        );
      }
    }

    return null;
  }

  void _addSlot(String day) {
    if (_sameAsBranchTimings) return;

    if (_isClosedDay(day)) {
      _showClosedDayMessage(day);
      return;
    }

    final nextSlot = _nextAvailableSlotForDay(day);

    if (nextSlot == null) {
      _showNoAvailableSlotMessage(day);
      return;
    }

    setState(() {
      _markedOffDays.remove(_dayKey(day));

      weeklySchedule[day]?.add({
        'start': _formatMinutes(nextSlot.startMinutes),
        'end': _formatMinutes(nextSlot.endMinutes),
      });
    });

    if (day == 'Monday') {
      _syncMondayToAllOpenDays();
    }
  }

  void _deleteSlot(String day, int index) {
    if (_sameAsBranchTimings) return;

    setState(() {
      weeklySchedule[day]?.removeAt(index);
    });

    if (day == 'Monday') {
      _syncMondayToAllOpenDays();
    }
  }

  void _updateTime(String day, int index, String timeType, String newTime) {
    if (_sameAsBranchTimings) return;

    setState(() {
      weeklySchedule[day]?[index][timeType] = newTime;

      final slot = weeklySchedule[day]?[index];
      if (slot == null) return;

      final start = _parseTimeToMinutes(slot['start'] ?? '');
      final end = _parseTimeToMinutes(slot['end'] ?? '');
      final options = _timeOptionsForDay(day);

      if (start == null || end == null || options.isEmpty || end > start) {
        return;
      }

      if (timeType == 'start') {
        final nextEnd = options.firstWhere(
          (option) => (_parseTimeToMinutes(option) ?? 0) > start,
          orElse: () => options.last,
        );

        slot['end'] = nextEnd;
      } else {
        final previousStart = options.lastWhere(
          (option) => (_parseTimeToMinutes(option) ?? 0) < end,
          orElse: () => options.first,
        );

        slot['start'] = previousStart;
      }
    });

    if (day == 'Monday' && _copyMondayToAllChecked) {
      _syncMondayToAllOpenDays();
    }
  }

  void _markOff(String day) {
    if (_sameAsBranchTimings) return;

    setState(() {
      weeklySchedule[day]?.clear();
      _markedOffDays.add(_dayKey(day));
    });

    if (day == 'Monday' && _copyMondayToAllChecked) {
      _syncMondayToAllOpenDays();
    }
  }

  void _markWorking(String day) {
    if (_sameAsBranchTimings) return;

    setState(() {
      _markedOffDays.remove(_dayKey(day));
    });

    _addSlot(day);
  }

  void _copyMondayToAll(bool value) {
    if (_sameAsBranchTimings) return;

    setState(() => _copyMondayToAllChecked = value);

    if (!value) return;

    if ((weeklySchedule['Monday'] ?? const []).isEmpty) {
      setState(() => _copyMondayToAllChecked = false);

      Fluttertoast.showToast(
          msg: translateText('Please add time slots for Monday first.'));
      return;
    }

    _syncMondayToAllOpenDays();
  }

  void _applySameAsBranchTimings(bool value) {
    setState(() {
      _sameAsBranchTimings = value;
      if (value) {
        _copyMondayToAllChecked = false;
      }

      if (!value) return;

      for (final day in _weekDays) {
        weeklySchedule[day]?.clear();

        if (_isClosedDay(day)) {
          _markedOffDays.add(_dayKey(day));
          continue;
        }

        _markedOffDays.remove(_dayKey(day));

        final operatingSlots = _operatingSlotsByDay[_dayKey(day)];

        if (operatingSlots != null && operatingSlots.isNotEmpty) {
          weeklySchedule[day] = operatingSlots
              .map(
                (slot) => {
                  'start': _formatMinutes(slot.startMinutes),
                  'end': _formatMinutes(slot.endMinutes),
                },
              )
              .toList();
        } else {
          weeklySchedule[day] = [
            {
              'start': '08:00 AM',
              'end': '08:00 PM',
            },
          ];
        }
      }
    });
  }

  void _showClosedDayMessage(String day) {
    Fluttertoast.showToast(
      msg: translateText('Salon is closed on $day.'),
    );
  }

  void _showNoAvailableSlotMessage(String day) {
    Fluttertoast.showToast(
      msg: translateText(
        'Salon time is over for $day. Please adjust the existing slots.',
      ),
    );
  }

  List<Map<String, dynamic>> _buildSchedulePayload() {
    final schedules = <Map<String, dynamic>>[];

    weeklySchedule.forEach((day, list) {
      if (_isClosedDay(day) || _isMarkedOff(day)) return;

      for (final slot in list) {
        final start = slot['start']?.trim();
        final end = slot['end']?.trim();

        if (start != null &&
            end != null &&
            start.isNotEmpty &&
            end.isNotEmpty) {
          schedules.add({
            'day': day.toLowerCase(),
            'startTime': start,
            'endTime': end,
          });
        }
      }
    });

    return schedules;
  }

  Future<void> _goToCompleteStep() async {
    final schedules = _buildSchedulePayload();

    debugPrint('➡️ Assign user schedules: $schedules');
    debugPrint('➡️ Assign user services: ${widget.selectedServiceIds}');

    setState(() => isSubmitting = true);

    try {
      final assigned = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TeamOnlineAvailabilityScreen.assignUser(
            branchId: widget.branchId,
            assignUserId: widget.userId,
            assignBranchServiceIds: widget.selectedServiceIds,
            assignSchedules: schedules,
            initialJoiningDate: widget.joinedAt,
          ),
        ),
      );

      if (assigned == true && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pop(context, true);
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;

      Fluttertoast.showToast(msg: '${translateText('Error')}: $e');
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Widget _timeDropdownField(
    String day,
    int index,
    String timeType,
  ) {
    final currentValue = weeklySchedule[day]?[index][timeType];
    final options = _timeOptionsForField(day, index, timeType);
    String? safeValue;

    if (currentValue != null && currentValue.trim().isNotEmpty) {
      final currentMinutes = _parseTimeToMinutes(currentValue);
      if (currentMinutes != null) {
        for (final option in options) {
          if (_parseTimeToMinutes(option) == currentMinutes) {
            safeValue = option;
            break;
          }
        }
      }

      if (safeValue == null && options.contains(currentValue)) {
        safeValue = currentValue;
      }
    }

    if (safeValue == null && options.isNotEmpty) {
      if (timeType == 'start') {
        safeValue = options.first;
      } else {
        final startValue = weeklySchedule[day]?[index]['start'] ?? '';
        final startMinutes = _parseTimeToMinutes(startValue);

        if (startMinutes != null) {
          safeValue = options.firstWhere(
            (option) => (_parseTimeToMinutes(option) ?? 0) > startMinutes,
            orElse: () => options.last,
          );
        } else {
          safeValue = options.first;
        }
      }
    }

    if (safeValue != null && safeValue != currentValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final slot = weeklySchedule[day]?[index];
        if (slot == null) return;
        if (slot[timeType] == safeValue) return;
        setState(() {
          slot[timeType] = safeValue!;
        });
      });
    }

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
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFD98A00)),
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
        onChanged: (value) {
          if (value == null) return;
          _updateTime(day, index, timeType, value);
        },
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

  Widget _smallPillButton({
    required String text,
    required VoidCallback onPressed,
    bool filled = false,
    IconData? icon,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(
                icon,
                size: 13,
                color:
                    enabled ? const Color(0xFFD98A00) : const Color(0xFFBDBDBD),
              ),
        label: Text(
          translateText(text),
          style: TextStyle(
            color: enabled
                ? (filled ? const Color(0xFF7C5600) : const Color(0xFF6B7280))
                : const Color(0xFFBDBDBD),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: enabled
              ? (filled ? const Color(0xFFFFF4DC) : const Color(0xFFF9FAFB))
              : const Color(0xFFF3F4F6),
          side: BorderSide(
            color: enabled
                ? (filled ? const Color(0xFFFFE1A8) : Colors.transparent)
                : const Color(0xFFE5E7EB),
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

  Widget _addSlotButton(String day) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: () => _addSlot(day),
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

  Widget _workingSlotBlock(String day, int index) {
    final isLastSlot = index == (weeklySchedule[day]!.length - 1);

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
                onPressed: () => _deleteSlot(day, index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayScheduleCard(String day) {
    final slots = weeklySchedule[day] ?? const <Map<String, String>>[];
    final markedOff = _isMarkedOff(day) || _isClosedDay(day);
    final closedDay = _isClosedDay(day);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      decoration: BoxDecoration(
        color: markedOff ? const Color(0xFFFFFBF6) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: markedOff ? const Color(0xFFF3E4D2) : const Color(0xFFE1E5EA),
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
              if (closedDay)
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
              if (closedDay) const SizedBox(width: 10),
              if (!closedDay && markedOff)
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
                    onPressed: () => _markOff(day),
                  ),
                ],
              )
            else ...[
              for (var index = 0; index < slots.length; index++)
                _workingSlotBlock(day, index),
              const SizedBox(height: 10),
              Row(
                children: [
                  _addSlotButton(day),
                  const SizedBox(width: 10),
                  _smallPillButton(
                    text: 'Mark Off',
                    onPressed: () => _markOff(day),
                  ),
                ],
              )
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationDisabled = isSubmitting || _isLoadingOperatingSchedule;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Assign User'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            children: [
              MultiStepFlowHeader(
                currentStep: 3,
                useIcons: true,
                steps: const [
                  FlowStepItem(
                    stepNumber: 1,
                    label: 'Select Branches',
                    icon: Icons.place_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 2,
                    label: 'Choose Services',
                    icon: Icons.handyman_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 3,
                    label: 'Schedule',
                    icon: Icons.calendar_today_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 4,
                    label: 'Complete',
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 46),
              Text(
                translateText('Set Weekly Working Hours'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 532),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          translateText('Set Working Schedule'),
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            // children: [
                            //   Checkbox(
                            //     value: _sameAsBranchTimings,
                            //     onChanged: (value) {
                            //       _applySameAsBranchTimings(value ?? false);
                            //     },
                            //     visualDensity: VisualDensity.compact,
                            //     materialTapTargetSize:
                            //         MaterialTapTargetSize.shrinkWrap,
                            //   ),
                            //   Flexible(
                            //     child: Text(
                            //       translateText('Same as branch timings'),
                            //       overflow: TextOverflow.ellipsis,
                            //       style: const TextStyle(
                            //         color: Color(0xFF374151),
                            //         fontSize: 11,
                            //         fontWeight: FontWeight.w500,
                            //       ),
                            //     ),
                            //   ),
                            // ],
                          ),
                        ),
                      ],
                    ),
                    if (_isLoadingOperatingSchedule) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.starColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            translateText('Checking branch timings...'),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    IgnorePointer(
                      ignoring: _sameAsBranchTimings,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _sameAsBranchTimings ? 0.45 : 1,
                        child: Column(
                          children: [
                            for (final day in _weekDays) ...[
                              _dayScheduleCard(day),
                              if (day == 'Monday') ...[
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _copyMondayToAllChecked,
                                      onChanged: _sameAsBranchTimings
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 84),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: const Color(0xFFF7F4F1),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      navigationDisabled ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D2926),
                    side: const BorderSide(color: Color(0xFFE2D3BF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    translateText('Previous').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: navigationDisabled ? null : _goToCompleteStep,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          translateText('Save & Continue').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
