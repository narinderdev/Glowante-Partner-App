import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';

const Color _schBackground = Color(0xFFFBFAF8);
const Color _schBorder = Color(0xFFE8DED6);
const Color _schText = Color(0xFF2B241D);
const Color _schMuted = Color(0xFF8C7A66);

class _WeeklyScheduleEntry {
  const _WeeklyScheduleEntry({
    required this.day,
    required this.statusLabel,
    required this.timeRanges,
    required this.isSalonClosed,
  });

  final String day;
  final String statusLabel;
  final List<String> timeRanges;
  final bool isSalonClosed;
}

/// Narinder's guidance (2026-09-02 Slack): schedule lives under each
/// branch on View Member — inline if it's the branch's own hours, or a
/// "View Schedule" button (this screen) if the member has a custom
/// schedule for that branch.
class TeamMemberScheduleScreen extends StatelessWidget {
  const TeamMemberScheduleScreen({
    super.key,
    required this.memberName,
    required this.branchName,
    required this.branchAssignment,
    this.salons,
  });

  final String memberName;
  final String branchName;

  /// One entry from member['branches'] — carries this branch's
  /// schedules/schedule/workingHours key, whichever the backend sends.
  final Map<String, dynamic> branchAssignment;

  /// The salon/branch hierarchy (for the branch's own posted hours, to
  /// tell "not working" apart from "salon closed that day").
  final List<Map<String, dynamic>>? salons;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _dayKey(String rawDay) {
    switch (rawDay.trim().toLowerCase()) {
      case 'monday':
        return 'monday';
      case 'tuesday':
        return 'tuesday';
      case 'wednesday':
        return 'wednesday';
      case 'thursday':
        return 'thursday';
      case 'friday':
        return 'friday';
      case 'saturday':
        return 'saturday';
      case 'sunday':
        return 'sunday';
      default:
        return '';
    }
  }

  String _formatClock(String rawTime) {
    final value = rawTime.trim();
    if (value.isEmpty || value == '--') return '--';

    final parts = value.split(':');
    if (parts.length < 2) return value;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteText = minute.toString().padLeft(2, '0');
    final suffix = isPm ? 'PM' : 'AM';
    return '$displayHour:$minuteText $suffix';
  }

  String _formatRange(String start, String end) {
    final from = _formatClock(start);
    final to = _formatClock(end);
    if (from == '--' && to == '--') return '';
    return '$from - $to';
  }

  String _scheduleText(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Map<String, List<String>> _scheduleMapFromRaw(dynamic raw) {
    final out = <String, List<String>>{};

    void addRange(String day, String start, String end) {
      final dayKey = _dayKey(day);
      final range = _formatRange(start, end);
      if (dayKey.isEmpty || range.isEmpty) return;
      out.putIfAbsent(dayKey, () => <String>[]).add(range);
    }

    void mergeFromList(List items) {
      for (final item in items) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final day = _scheduleText(
          map,
          const ['day', 'dayName', 'weekDay', 'weekday'],
        );
        final slots = map['slots'];
        if (slots is List && slots.isNotEmpty) {
          for (final slot in slots) {
            if (slot is! Map) continue;
            final slotMap = Map<String, dynamic>.from(slot);
            addRange(
              day,
              _scheduleText(slotMap, const ['startTime', 'start', 'from']),
              _scheduleText(slotMap, const ['endTime', 'end', 'to']),
            );
          }
        } else {
          addRange(
            day,
            _scheduleText(map, const ['startTime', 'start', 'from']),
            _scheduleText(map, const ['endTime', 'end', 'to']),
          );
        }
      }
    }

    void mergeFromMap(Map<String, dynamic> map) {
      for (final entry in map.entries) {
        final day = _dayKey(entry.key.toString());
        final value = entry.value;
        if (value is List) {
          for (final slot in value) {
            if (slot is! Map) continue;
            final slotMap = Map<String, dynamic>.from(slot);
            addRange(
              day,
              _scheduleText(slotMap, const ['startTime', 'start', 'from']),
              _scheduleText(slotMap, const ['endTime', 'end', 'to']),
            );
          }
        } else if (value is Map) {
          final slotMap = Map<String, dynamic>.from(value);
          addRange(
            day,
            _scheduleText(slotMap, const ['startTime', 'start', 'from']),
            _scheduleText(slotMap, const ['endTime', 'end', 'to']),
          );
        }
      }
    }

    if (raw is List) {
      mergeFromList(raw);
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final directDays = const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ].any(map.containsKey);

      if (directDays) {
        mergeFromMap(map);
      } else {
        for (final key in const ['schedule', 'schedules', 'workingHours']) {
          final nested = map[key];
          if (nested != null) {
            final nestedMap = _scheduleMapFromRaw(nested);
            nestedMap.forEach((day, ranges) {
              out.putIfAbsent(day, () => <String>[]).addAll(ranges);
            });
          }
        }
      }
    }

    return out;
  }

  dynamic _scheduleSourceForBranch(int branchId) {
    final salonList = salons ?? const <Map<String, dynamic>>[];
    for (final rawSalon in salonList) {
      final salon = Map<String, dynamic>.from(rawSalon);
      final branches = salon['branches'];
      if (branches is List) {
        for (final rawBranch in branches.whereType<Map>()) {
          final branch = Map<String, dynamic>.from(rawBranch);
          if (_toInt(branch['id']) != branchId) continue;
          for (final key in const ['schedule', 'schedules', 'workingHours']) {
            final value = branch[key];
            if (value != null) return value;
          }
          for (final key in const ['schedule', 'schedules', 'workingHours']) {
            final value = salon[key];
            if (value != null) return value;
          }
        }
      }
    }
    return null;
  }

  List<_WeeklyScheduleEntry> _entries() {
    // Legacy per-branch shape nests branch identity under `branch: {id}`
    // instead of a flat `branchId` — check both.
    final nestedBranch = branchAssignment['branch'];
    final branchId = _toInt(branchAssignment['branchId']) ??
        (nestedBranch is Map
            ? _toInt(nestedBranch['id'] ?? nestedBranch['branchId'])
            : null);
    final memberSchedule = _scheduleMapFromRaw(
      branchAssignment['schedules'] ??
          branchAssignment['schedule'] ??
          branchAssignment['workingHours'],
    );

    Map<String, List<String>>? branchSchedule;
    if (branchId != null) {
      final source = _scheduleSourceForBranch(branchId);
      if (source != null) {
        final map = _scheduleMapFromRaw(source);
        if (map.isNotEmpty) branchSchedule = map;
      }
    }

    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    return days.map((day) {
      final memberRanges = List<String>.from(memberSchedule[day] ?? const []);
      final branchRanges = branchSchedule == null
          ? const <String>[]
          : List<String>.from(branchSchedule[day] ?? const []);
      final salonClosed = branchSchedule != null &&
          branchSchedule.isNotEmpty &&
          branchRanges.isEmpty;

      return _WeeklyScheduleEntry(
        day: day,
        statusLabel: salonClosed
            ? 'Salon closed'
            : (memberRanges.isEmpty ? 'Not working' : 'Working'),
        timeRanges: memberRanges,
        isSalonClosed: salonClosed,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final hasAnySchedule =
        entries.any((e) => e.timeRanges.isNotEmpty || e.isSalonClosed);

    return Scaffold(
      backgroundColor: _schBackground,
      appBar: buildProfileSubpageAppBar(title: translateText('Schedule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            memberName,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _schText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            branchName,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              color: _schMuted,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasAnySchedule)
            Text(
              translateText('No weekly schedule found'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _schMuted,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _schBorder),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    _WeeklyScheduleRow(entry: entries[i]),
                    if (i != entries.length - 1)
                      const Divider(height: 1, color: _schBorder),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeeklyScheduleRow extends StatelessWidget {
  const _WeeklyScheduleRow({required this.entry});

  final _WeeklyScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    final dayLabel = entry.day.isEmpty
        ? 'Day'
        : entry.day[0].toUpperCase() + entry.day.substring(1).toLowerCase();
    final isWorking = entry.timeRanges.isNotEmpty;
    final statusColor = entry.isSalonClosed
        ? const Color(0xFFC44545)
        : isWorking
            ? const Color(0xFF2F8A4C)
            : _schMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              translateText(dayLabel),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _schText,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    translateText(entry.statusLabel),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
                if (isWorking) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final range in entry.timeRanges)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F2EA),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _schBorder),
                          ),
                          child: Text(
                            range,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _schText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
