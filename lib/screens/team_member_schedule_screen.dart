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
/// schedule for that branch. A member on more than one branch can switch
/// between them here rather than needing a separate "View Schedule" tap
/// per branch.
class TeamMemberScheduleScreen extends StatefulWidget {
  const TeamMemberScheduleScreen({
    super.key,
    required this.memberName,
    required this.branches,
    required this.assignmentsByBranchId,
    this.initialBranchId,
    this.salons,
  });

  final String memberName;

  /// Every branch this member is assigned to — {branchId, name} — for the
  /// branch switcher. Only shown when there's more than one.
  final List<Map<String, dynamic>> branches;

  /// Each branch's own raw assignment entry from member['branches'],
  /// keyed by branchId — carries that branch's
  /// schedules/schedule/workingHours key, whichever the backend sends.
  final Map<int, Map<String, dynamic>> assignmentsByBranchId;

  /// Which branch to start on — the one "View Schedule" was tapped from.
  final int? initialBranchId;

  /// The salon/branch hierarchy (for the branch's own posted hours, to
  /// tell "not working" apart from "salon closed that day").
  final List<Map<String, dynamic>>? salons;

  @override
  State<TeamMemberScheduleScreen> createState() =>
      _TeamMemberScheduleScreenState();
}

class _TeamMemberScheduleScreenState extends State<TeamMemberScheduleScreen> {
  late int? _selectedBranchId = widget.initialBranchId ??
      (widget.branches.isNotEmpty
          ? _toInt(widget.branches.first['branchId'])
          : null);

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String get _selectedBranchName {
    final id = _selectedBranchId;
    for (final branch in widget.branches) {
      if (_toInt(branch['branchId']) == id) {
        return (branch['name'] ?? '').toString();
      }
    }
    return '';
  }

  Map<String, dynamic> get _selectedBranchAssignment =>
      widget.assignmentsByBranchId[_selectedBranchId] ??
      const <String, dynamic>{};

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
    final salonList = widget.salons ?? const <Map<String, dynamic>>[];
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
    final branchAssignment = _selectedBranchAssignment;
    // Legacy per-branch shape nests branch identity under `branch: {id}`
    // instead of a flat `branchId` — check both.
    final nestedBranch = branchAssignment['branch'];
    final branchId = _toInt(branchAssignment['branchId']) ??
        (nestedBranch is Map
            ? _toInt(nestedBranch['id'] ?? nestedBranch['branchId'])
            : null) ??
        _selectedBranchId;
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
    final workingDays = entries.where((e) => e.timeRanges.isNotEmpty).length;

    return Scaffold(
      backgroundColor: _schBackground,
      appBar: buildProfileSubpageAppBar(title: translateText('Schedule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _schBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translateText('Working Schedule'),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _schText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_selectedBranchName · ${translateText('Weekly configured hours for this branch')}',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11.5,
                          color: _schMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    workingDays == 1
                        ? translateText('{n} Working Day',
                            params: {'n': '$workingDays'})
                        : translateText('{n} Working Days',
                            params: {'n': '$workingDays'}),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B6500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.branches.length > 1) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _schBorder),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final branch in widget.branches)
                    _BranchFilterChip(
                      label: (branch['name'] ?? '').toString(),
                      selected: _selectedBranchId == _toInt(branch['branchId']),
                      onTap: () => setState(
                        () => _selectedBranchId = _toInt(branch['branchId']),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
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
            Column(
              children: [
                for (final entry in entries) ...[
                  _WeeklyScheduleRow(entry: entry),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BranchFilterChip extends StatelessWidget {
  const _BranchFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B6500) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF8B6500) : _schBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _schText,
          ),
        ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _schBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D5),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: Color(0xFF8B6500),
            ),
          ),
          const SizedBox(width: 10),
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
          if (isWorking)
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
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _schBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: _schMuted),
                        const SizedBox(width: 5),
                        Text(
                          range,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _schText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Text(
              translateText(entry.statusLabel),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    entry.isSalonClosed ? const Color(0xFFC44545) : _schMuted,
              ),
            ),
        ],
      ),
    );
  }
}
