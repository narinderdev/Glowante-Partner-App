import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
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
    this.onSubmit,
  });

  final String detailsStepLabel;
  final String initialStartTime;
  final String initialEndTime;
  final Map<String, List<Map<String, String>>>? initialSchedule;
  final int totalSteps;
  final String? submitLabel;
  final Future<void> Function(ScheduleStepResult result)? onSubmit;

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
  bool _isSubmitting = false;

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
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Add Salon'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalonFlowStepHeader(
                currentStep: 2,
                detailsLabel: translateText(widget.detailsStepLabel),
                totalSteps: widget.totalSteps,
              ),
              const SizedBox(height: 44),
              Text(
                translateText('Set Weekly Working Hours'),
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1B18),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                translateText(
                  "Configure your salon's operational hours for a seamless booking experience.",
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF5F574F),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _buildCopyMondayControl(),
              const SizedBox(height: 28),
              for (final day in _days) ...[
                _buildDayCard(day),
              ],
              const SizedBox(height: 54),
              _buildScheduleQuote(),
              const SizedBox(height: 38),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFD0A244),
                          width: 1.4,
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFD0A244),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chevron_left_rounded, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            translateText('Back'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        backgroundColor: const Color(0xFF8B6500),
                        foregroundColor: Colors.white,
                        elevation: 10,
                        shadowColor: const Color(0x338B6500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSubmitting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            Flexible(
                              child: Text(
                                translateText(
                                  widget.submitLabel ??
                                      (widget.totalSteps == 2
                                          ? 'Save'
                                          : 'Save & Continue'),
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDE6DF)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              translateText(_capitalize(day)),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF201B17),
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
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '-',
                    style: TextStyle(color: Color(0xFF9B928A)),
                  ),
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
          const SizedBox(width: 10),
          if (config.isClosed)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                translateText('CLOSED'),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B4038),
                ),
              ),
            ),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: !config.isClosed,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF8B6500),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE1DFDD),
              onChanged: (enabled) {
                setState(() {
                  _applyDayConfig(
                    day,
                    config.copyWith(isClosed: !enabled),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyMondayControl() {
    return InkWell(
      onTap: () {
        setState(() {
          _copyMondayToAll = !_copyMondayToAll;
          if (_copyMondayToAll) {
            final mondayConfig = _scheduleByDay['monday']!;
            for (final dayName in _days.skip(1)) {
              _scheduleByDay[dayName] = mondayConfig.copyWith();
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _copyMondayToAll ? const Color(0xFF8B6500) : Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _copyMondayToAll
                    ? const Color(0xFF8B6500)
                    : const Color(0xFFD7C9BC),
              ),
            ),
            child: _copyMondayToAll
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              translateText('Copy Monday schedule to all days'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2F2924),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleQuote() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 174,
            height: 174,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26936D00),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.asset(
                  'assets/images/salonImage.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          translateText(
            '"Time is the ultimate luxury.\nManage it with precision."',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            height: 1.25,
            color: Color(0xFF8B6500),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 2,
          color: const Color(0xFFD0A244),
        ),
        const SizedBox(height: 12),
        Text(
          translateText('SALON EXCELLENCE STANDARD'),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            color: Color(0xFF4B4038),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  Future<void> _submit() async {
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

    final result = ScheduleStepResult(
      startTime: _minutesToApiTime(overallStartMinutes),
      endTime: _minutesToApiTime(overallEndMinutes),
      schedule: schedule,
    );

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      Navigator.pop(context, result);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await onSubmit(result);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Failed: $error'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  String _normalizeDisplayTime(String input) {
    final text = input.trim();
    if (text.isEmpty) return '08:00 AM';
    final twelveMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
            caseSensitive: false)
        .firstMatch(text);
    if (twelveMatch != null) {
      final hour = int.parse(twelveMatch.group(1)!);
      final minute = int.parse(twelveMatch.group(2)!);
      final suffix = twelveMatch.group(3)!.toUpperCase();
      final normalizedHour = hour.toString().padLeft(2, '0');
      final normalizedMinute = minute.toString().padLeft(2, '0');
      return '$normalizedHour:$normalizedMinute $suffix';
    }

    final twentyFourMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF7F5F3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE8E1DC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF2B2520),
            overflow: TextOverflow.ellipsis,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 13,
            color: Color(0xFF8A8178),
          ),
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
                      fontSize: 10,
                      color: Color(0xFF2B2520),
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
