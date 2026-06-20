import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SalonTeams.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'AddTeamSelectServices.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';

class _OperatingSlot {
  const _OperatingSlot({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
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
  late Map<String, List<Map<String, String>>> weeklySchedule;
  late Map<String, List<Map<String, String>>> mondaySchedule;

  Map<String, List<Map<String, String>>>? _manualWeeklyScheduleSnapshot;

  bool _isSubmitting = false;
  bool _useSalonHours = false;
  bool _isLoadingOperatingSchedule = false;
  bool _hasPrefilledMemberSchedule = false;

  bool get _isEditFlow => widget.formData['isEdit'] == true;

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

    mondaySchedule = {};

    _hasPrefilledMemberSchedule = _prefillSchedules();

    // Important:
    // Keep this true in edit mode if member was saved with salon hours.
    _useSalonHours = widget.formData['useSalonHours'] == true;

    _loadOperatingSchedule();
  }

  String _dayKey(String day) => day.trim().toLowerCase();

  bool _isClosedDay(String day) => _closedDays.contains(_dayKey(day));

  List<String> get _weekDays => weeklySchedule.keys.toList();

  Map<String, List<Map<String, String>>> _cloneWeeklySchedule(
    Map<String, List<Map<String, String>>> source,
  ) {
    return source.map(
      (day, slots) => MapEntry(
        day,
        slots.map((slot) => Map<String, String>.from(slot)).toList(),
      ),
    );
  }

  void _clearWeeklySchedule() {
    for (final day in _weekDays) {
      weeklySchedule[day]?.clear();
    }
  }

  void _restoreWeeklyScheduleSnapshot() {
    final snapshot = _manualWeeklyScheduleSnapshot;

    if (snapshot != null) {
      weeklySchedule = _cloneWeeklySchedule(snapshot);
      _manualWeeklyScheduleSnapshot = null;
      return;
    }

    _clearWeeklySchedule();
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

    for (final key in const ['schedule', 'schedules', 'workingHours']) {
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

      // Add flow can default empty days to salon/branch hours.
      // Edit flow keeps member's saved custom slots.
      if (!_isEditFlow && !_hasPrefilledMemberSchedule) {
        _fillEmptyDaysFromOperatingSlots(operatingSlots);
        return;
      }

      // Edit custom schedule: normalize saved slots inside allowed branch hours.
      for (final day in _weekDays) {
        final slots = weeklySchedule[day];

        if (slots == null || slots.isEmpty) continue;

        weeklySchedule[day] =
            slots.map((slot) => _normalizeSlotWithinDay(day, slot)).toList();
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
          result[key] = _normalizeOperatingSlots(slots);
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

  List<_OperatingSlot> _slotsFromValue(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(_slotFromMap)
          .whereType<_OperatingSlot>()
          .toList();
    }

    if (value is Map) {
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

    return _OperatingSlot(
      startMinutes: start,
      endMinutes: end,
    );
  }

  void _fillEmptyDaysFromOperatingSlots(
    Map<String, List<_OperatingSlot>> operatingSlots,
  ) {
    for (final entry in operatingSlots.entries) {
      final displayDay = _displayDay(entry.key);

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
      for (var minute = slot.startMinutes;
          minute <= slot.endMinutes;
          minute += 15) {
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
        : timeType == 'start'
            ? slot['end']
            : slot['start'];

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

  bool _prefillSchedules() {
    final rawSchedules = widget.formData['schedules'];

    if (rawSchedules is! List || rawSchedules.isEmpty) {
      return false;
    }

    var foundAny = false;

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

      foundAny = true;
    }

    return foundAny;
  }

  List<Map<String, String>> _buildScheduleData() {
    final List<Map<String, String>> scheduleData = [];

    weeklySchedule.forEach((day, slots) {
      if (_isClosedDay(day)) return;

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
          'startTime': _formatMinutes(slot.startMinutes),
          'endTime': _formatMinutes(slot.endMinutes),
        });
      }
    });

    return scheduleData;
  }

  void addSlot(String day) {
    if (_useSalonHours) return;

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
      weeklySchedule[day]?.add({
        'start': _formatMinutes(nextSlot.startMinutes),
        'end': _formatMinutes(nextSlot.endMinutes),
      });
    });
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

    const minimumDuration = 15;

    for (final bound in bounds) {
      var cursor = bound.startMinutes;

      for (final used in existing) {
        if (used.endMinutes <= bound.startMinutes ||
            used.startMinutes >= bound.endMinutes) {
          continue;
        }

        final usedStart = used.startMinutes.clamp(
          bound.startMinutes,
          bound.endMinutes,
        );

        if (usedStart - cursor >= minimumDuration) {
          return _OperatingSlot(
            startMinutes: cursor,
            endMinutes: usedStart,
          );
        }

        if (used.endMinutes > cursor) {
          cursor = used.endMinutes.clamp(
            bound.startMinutes,
            bound.endMinutes,
          );
        }
      }

      if (bound.endMinutes - cursor >= minimumDuration) {
        return _OperatingSlot(
          startMinutes: cursor,
          endMinutes: bound.endMinutes,
        );
      }
    }

    return null;
  }

  void deleteSlot(String day, int index) {
    if (_useSalonHours) return;

    setState(() {
      weeklySchedule[day]?.removeAt(index);
    });
  }

  void updateTime(String day, int index, String timeType, String newTime) {
    if (_useSalonHours) return;

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
  }

  void copyMondayScheduleToAll() {
    if (_useSalonHours) return;

    if (weeklySchedule['Monday']!.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Alert'),
            content: const Text('Please add time slots for Monday first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        final mondaySlots = weeklySchedule['Monday']!
            .map((slot) => Map<String, String>.from(slot))
            .toList();

        weeklySchedule.forEach((day, slots) {
          if (day != 'Monday' && !_isClosedDay(day)) {
            slots
              ..clear()
              ..addAll(
                mondaySlots.map(
                  (slot) => _normalizeSlotWithinDay(
                    day,
                    Map<String, String>.from(slot),
                  ),
                ),
              );
          }
        });
      });
    }
  }

  void _showClosedDayMessage(String day) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translateText('$day is closed for appointments.'),
        ),
      ),
    );
  }

  void _showNoAvailableSlotMessage(String day) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translateText('No available time left for $day.'),
        ),
      ),
    );
  }

  Widget _timeDropdownField(
    String day,
    int index,
    String timeType,
  ) {
    final currentValue = weeklySchedule[day]?[index][timeType];
    final options = _timeOptionsForField(day, index, timeType);
    final safeValue = options.contains(currentValue) ? currentValue : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      icon: const Icon(
        Icons.schedule_rounded,
        color: Color(0xFF1F1B18),
        size: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor:
            _useSalonHours ? const Color(0xFFF0EDE9) : const Color(0xFFFAF8F6),
        contentPadding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8C7B3)),
        ),
      ),
      hint: Text(
        currentValue ?? translateText('Select time'),
        style: const TextStyle(
          color: Color(0xFF1F1B18),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: const TextStyle(
                  color: Color(0xFF1F1B18),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
    final slots = weeklySchedule[day] ?? const <Map<String, String>>[];
    final isClosed = _isClosedDay(day);

    return Opacity(
      opacity: _useSalonHours ? 0.55 : 1,
      child: IgnorePointer(
        ignoring: _useSalonHours,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: _useSalonHours ? const Color(0xFFF0EDE9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _useSalonHours
                  ? const Color(0xFFD8D1CA)
                  : const Color(0xFFF0E8DF),
            ),
            boxShadow: _useSalonHours
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translateText(day),
                style: TextStyle(
                  color: _useSalonHours
                      ? const Color(0xFF8D867F)
                      : const Color(0xFF1F1B18),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              if (isClosed)
                Text(
                  translateText('CLOSED'),
                  style: const TextStyle(
                    color: Color(0xFFE54848),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                )
              else ...[
                if (slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      translateText('No time slots added'),
                      style: const TextStyle(
                        color: Color(0xFF9A928B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (var index = 0; index < slots.length; index++)
                  _weeklySlotRow(day, index),
                if (!_useSalonHours)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _addSlotButton(day),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _weeklySlotRow(String day, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _labeledTimeField(
              label: 'FROM',
              child: _timeDropdownField(day, index, 'start'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _labeledTimeField(
              label: 'TO',
              child: _timeDropdownField(day, index, 'end'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            height: 38,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _useSalonHours
                    ? const Color(0xFFBDB7B1)
                    : const Color(0xFFE54848),
                size: 17,
              ),
              onPressed: _useSalonHours ? null : () => deleteSlot(day, index),
            ),
          ),
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
            color: Color(0xFFB5ADA5),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _orDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: Color(0xFFE8DED6),
              thickness: 1,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAD2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD0A244)),
            ),
            child: Text(
              translateText('OR'),
              style: const TextStyle(
                color: Color(0xFF8B6500),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              color: Color(0xFFE8DED6),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addSlotButton(String day) {
    return OutlinedButton.icon(
      onPressed: () => addSlot(day),
      icon: const Icon(Icons.add_rounded, size: 13),
      label: Text(
        translateText('ADD SLOT'),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8B6500),
        side: const BorderSide(color: Color(0xFFE8D8C3)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
        "otp": widget.formData['otp']?.toString(),
      };

      final ApiService apiService = ApiService();
      final int branchId = widget.formData['branchId'] as int;

      final Map<String, dynamic> response =
          await apiService.addTeamMember(branchId, teamMemberData);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team member added successfully'),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TeamScreen()),
          (route) => false,
        );
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to add team member');
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _showErrorDialog('An unexpected error occurred.');
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
        "branchServiceIds": widget.formData['branchServiceIds'] ?? const [],
        "userBranchServices": widget.formData['userBranchServices'] ?? const [],
        "address": widget.formData['address'],
        "branchId": widget.formData['branchId'],
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

      if (refresh == true) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      debugPrint('Failed to prepare team member data: $e');
      _showErrorDialog('Something went wrong while preparing data.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Response'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F1),
        appBar: buildProfileSubpageAppBar(
          title: translateText('Add TimeSlots'),
        ),
        body: SingleChildScrollView(
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
                const SizedBox(height: 20),
                Text(
                  translateText('Set Weekly Working Hours'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
                        translateText('Checking branch closed days...'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useSalonHours,
                  onChanged: (value) {
                    final nextValue = value ?? false;

                    if (nextValue == _useSalonHours) return;

                    setState(() {
                      if (nextValue) {
                        _manualWeeklyScheduleSnapshot =
                            _cloneWeeklySchedule(weeklySchedule);

                        _clearWeeklySchedule();

                        // Fill schedule immediately from salon/branch hours.
                        _fillEmptyDaysFromOperatingSlots(
                          _operatingSlotsByDay,
                        );
                      } else {
                        _restoreWeeklyScheduleSnapshot();
                      }

                      _useSalonHours = nextValue;
                    });
                  },
                  title: Text(
                    translateText('Use salon open & close time'),
                  ),
                  subtitle: Text(
                    translateText(
                      'Apply the salon\'s operating hours instead of defining custom time slots.',
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                // if (_useSalonHours)
                //   Container(
                //     width: double.infinity,
                //     margin: const EdgeInsets.only(top: 16),
                //     padding: const EdgeInsets.all(12),
                //     decoration: BoxDecoration(
                //       color: Colors.grey.shade100,
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //     child: Text(
                //       translateText(
                //         'Salon operating hours will be used for this team member. Uncheck to set custom slots.',
                //       ),
                //       style: const TextStyle(fontSize: 14),
                //     ),
                //   ),

                // // Important:
                // // Always show weekly cards.
                // // If _useSalonHours is true, fields are disabled but visible.
                // const SizedBox(height: 16),
                // ..._weekDays.map(_weeklyHoursCard),
                if (_useSalonHours)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EDE9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD8C7B3)),
                    ),
                    child: Text(
                      translateText(
                        'Salon operating hours will be used for this team member.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5E564F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                _orDivider(),

                Text(
                  translateText('Or set custom working hours below'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _useSalonHours
                        ? const Color(0xFF9A928B)
                        : const Color(0xFF1F1B18),
                  ),
                ),

                const SizedBox(height: 12),

                ..._weekDays.map(_weeklyHoursCard),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context, false),
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
                          onPressed: _isSubmitting
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}
