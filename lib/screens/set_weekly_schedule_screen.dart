import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../widgets/salon_flow_step_header.dart';

class ScheduleStepResult {
  const ScheduleStepResult({
    required this.startTime,
    required this.endTime,
    required this.schedule,
  });

  final String startTime;
  final String endTime;
  final Map<String, List<Map<String, String>>> schedule;
}

class SetWeeklyScheduleScreen extends StatefulWidget {
  const SetWeeklyScheduleScreen({
    super.key,
    required this.detailsStepLabel,
    required this.initialStartTime,
    required this.initialEndTime,
    this.initialSchedule,
    this.totalSteps = 3,
    this.submitLabel,
  });

  final String detailsStepLabel;
  final String initialStartTime;
  final String initialEndTime;
  final Map<String, List<Map<String, String>>>? initialSchedule;
  final int totalSteps;
  final String? submitLabel;

  @override
  State<SetWeeklyScheduleScreen> createState() =>
      _SetWeeklyScheduleScreenState();
}

class _SetWeeklyScheduleScreenState extends State<SetWeeklyScheduleScreen> {
  static const List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late final Map<String, _DayScheduleConfig> _scheduleByDay;
  bool _copyMondayToAll = false;

  @override
  void initState() {
    super.initState();
    final initialStart = _normalizeDisplayTime(widget.initialStartTime);
    final initialEnd = _normalizeDisplayTime(widget.initialEndTime);
    _scheduleByDay = {
      for (final day in _days)
        day: _DayScheduleConfig(
          startTime: initialStart,
          endTime: initialEnd,
          isClosed: false,
        ),
    };
    final initialSchedule = widget.initialSchedule;
    if (initialSchedule != null && initialSchedule.isNotEmpty) {
      for (final day in _days) {
        final slots = initialSchedule[day] ?? const [];
        if (slots.isEmpty) {
          _scheduleByDay[day] = _scheduleByDay[day]!.copyWith(isClosed: true);
          continue;
        }
        final firstSlot = slots.first;
        _scheduleByDay[day] = _scheduleByDay[day]!.copyWith(
          startTime:
              _normalizeDisplayTime((firstSlot['startTime'] ?? '').toString()),
          endTime:
              _normalizeDisplayTime((firstSlot['endTime'] ?? '').toString()),
          isClosed: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Set Schedule'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalonFlowStepHeader(
                currentStep: 2,
                detailsLabel: translateText(widget.detailsStepLabel),
                totalSteps: widget.totalSteps,
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  translateText('Set Weekly Working Hours'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final day in _days) ...[
                _buildDayCard(day),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFE5E7EB),
                        foregroundColor: const Color(0xFF374151),
                      ),
                      child: Text(translateText('Back')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        translateText(
                          widget.submitLabel ??
                              (widget.totalSteps == 2 ? 'Save' : 'Next'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(String day) {
    final config = _scheduleByDay[day]!;
    final isMonday = day == 'monday';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  translateText(_capitalize(day)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeDropdown(
                        value: config.startTime,
                        enabled: !config.isClosed,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _applyDayConfig(
                              day,
                              config.copyWith(startTime: value),
                            );
                          });
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('to'),
                    ),
                    Expanded(
                      child: _TimeDropdown(
                        value: config.endTime,
                        enabled: !config.isClosed,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _applyDayConfig(
                              day,
                              config.copyWith(endTime: value),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  setState(() {
                    _applyDayConfig(
                      day,
                      config.copyWith(isClosed: !config.isClosed),
                    );
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  translateText(config.isClosed ? 'Open' : 'Closed'),
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          if (isMonday) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _copyMondayToAll = !_copyMondayToAll;
                    if (_copyMondayToAll) {
                      for (final dayName in _days.skip(1)) {
                        _scheduleByDay[dayName] = config.copyWith();
                      }
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copyMondayToAll
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: _copyMondayToAll
                          ? AppColors.starColor
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      translateText('Copy Monday schedule to all days'),
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _applyDayConfig(String day, _DayScheduleConfig config) {
    _scheduleByDay[day] = config;
    if (_copyMondayToAll && day == 'monday') {
      for (final dayName in _days.skip(1)) {
        _scheduleByDay[dayName] = config.copyWith();
      }
    }
  }

  void _submit() {
    final openDays = _scheduleByDay.entries
        .where((entry) => !entry.value.isClosed)
        .toList(growable: false);
    if (openDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText('Please keep at least one day open in the schedule.'),
          ),
        ),
      );
      return;
    }

    for (final entry in openDays) {
      final startMinutes = _displayToMinutes(entry.value.startTime);
      final endMinutes = _displayToMinutes(entry.value.endTime);
      if (startMinutes >= endMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translateText(
                '{day} closing time must be after opening time.',
                params: {'day': _capitalize(entry.key)},
              ),
            ),
          ),
        );
        return;
      }
    }

    final schedule = <String, List<Map<String, String>>>{};
    int overallStartMinutes = 24 * 60;
    int overallEndMinutes = 0;

    for (final day in _days) {
      final config = _scheduleByDay[day]!;
      if (config.isClosed) {
        schedule[day] = const [];
        continue;
      }

      final startMinutes = _displayToMinutes(config.startTime);
      final endMinutes = _displayToMinutes(config.endTime);
      if (startMinutes < overallStartMinutes) {
        overallStartMinutes = startMinutes;
      }
      if (endMinutes > overallEndMinutes) {
        overallEndMinutes = endMinutes;
      }

      schedule[day] = [
        {
          'startTime': _displayToApiTime(config.startTime),
          'endTime': _displayToApiTime(config.endTime),
        }
      ];
    }

    Navigator.pop(
      context,
      ScheduleStepResult(
        startTime: _minutesToApiTime(overallStartMinutes),
        endTime: _minutesToApiTime(overallEndMinutes),
        schedule: schedule,
      ),
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  String _normalizeDisplayTime(String input) {
    final text = input.trim();
    if (text.isEmpty) return '08:00 AM';
    final twelveMatch =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$', caseSensitive: false)
            .firstMatch(text);
    if (twelveMatch != null) {
      final hour = int.parse(twelveMatch.group(1)!);
      final minute = int.parse(twelveMatch.group(2)!);
      final suffix = twelveMatch.group(3)!.toUpperCase();
      final normalizedHour = hour.toString().padLeft(2, '0');
      final normalizedMinute = minute.toString().padLeft(2, '0');
      return '$normalizedHour:$normalizedMinute $suffix';
    }

    final twentyFourMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (twentyFourMatch != null) {
      final hour = int.parse(twentyFourMatch.group(1)!);
      final minute = int.parse(twentyFourMatch.group(2)!);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = ((hour + 11) % 12) + 1;
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
    }
    return '08:00 AM';
  }

  int _displayToMinutes(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})\s([AP]M)$').firstMatch(value);
    if (match == null) return 0;
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final suffix = match.group(3)!;
    if (suffix == 'AM' && hour == 12) hour = 0;
    if (suffix == 'PM' && hour != 12) hour += 12;
    return hour * 60 + minute;
  }

  String _displayToApiTime(String value) {
    final totalMinutes = _displayToMinutes(value);
    return _minutesToApiTime(totalMinutes);
  }

  String _minutesToApiTime(int totalMinutes) {
    final hour = (totalMinutes ~/ 60).clamp(0, 23);
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _DayScheduleConfig {
  const _DayScheduleConfig({
    required this.startTime,
    required this.endTime,
    required this.isClosed,
  });

  final String startTime;
  final String endTime;
  final bool isClosed;

  _DayScheduleConfig copyWith({
    String? startTime,
    String? endTime,
    bool? isClosed,
  }) {
    return _DayScheduleConfig(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      if (!_timeOptions.contains(value)) value,
      ..._timeOptions,
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF111827),
            overflow: TextOverflow.ellipsis,
          ),
          icon: const Icon(Icons.arrow_drop_down),
          items: items
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => items
              .map(
                (option) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

final List<String> _timeOptions = List<String>.generate(48, (index) {
  final hour24 = index ~/ 2;
  final minute = index.isEven ? 0 : 30;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = ((hour24 + 11) % 12) + 1;
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
});
