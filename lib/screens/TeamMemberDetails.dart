import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';

const Color _memberDetailBackground = Color(0xFFFBFAF8);
const Color _memberDetailBorder = Color(0xFFE8DED6);
const Color _memberDetailText = Color(0xFF2B241D);
const Color _memberDetailMuted = Color(0xFF8C7A66);
const Color _memberDetailSurface = Colors.white;

class TeamMemberDetails extends StatelessWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>>? salons;
  final double professionalRating;
  final int professionalReviewCount;
  const TeamMemberDetails({
    super.key,
    required this.member,
    this.salons,
    this.professionalRating = 0,
    this.professionalReviewCount = 0,
  });

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    return (f + l).toUpperCase();
  }

  bool _isDeletedRecord(dynamic raw) {
    if (raw is! Map) return false;

    bool readBool(dynamic value) {
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase() ?? '';
      return text == 'true' || text == '1' || text == 'yes';
    }

    if (readBool(raw['isDeleted']) ||
        readBool(raw['is_deleted']) ||
        readBool(raw['deleted'])) {
      return true;
    }

    final deletedAt =
        (raw['deletedAt'] ?? raw['deleted_at'])?.toString().trim() ?? '';
    if (deletedAt.isNotEmpty && deletedAt.toLowerCase() != 'null') {
      return true;
    }

    for (final key in const ['status', 'state']) {
      final status = raw[key]?.toString().trim().toLowerCase() ?? '';
      if (status.contains('deleted') || status.contains('removed')) {
        return true;
      }
    }

    return false;
  }

  String _branchName(Map branch) {
    return (branch['name'] ?? branch['branchName'] ?? '').toString().trim();
  }

  String _salonName(Map branch) {
    final salon = branch['salon'];
    if (salon is Map && !_isDeletedRecord(salon)) {
      final name = (salon['name'] ?? salon['salonName']).toString().trim();
      if (name.isNotEmpty && name.toLowerCase() != 'null') return name;
    }
    return (branch['salonName'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> _assignedBranches(dynamic rawBranches) {
    if (rawBranches is! List) return const [];

    final assigned = <Map<String, dynamic>>[];
    final seenBranchIds = <String>{};

    for (final item in rawBranches) {
      if (item is! Map) continue;
      if (_isDeletedRecord(item)) continue;

      final rawBranch = item['branch'];
      if (rawBranch is! Map) continue;
      if (_isDeletedRecord(rawBranch) || _isDeletedRecord(rawBranch['salon'])) {
        continue;
      }

      final branchName = _branchName(rawBranch);
      if (branchName.isEmpty) continue;

      final branchId = (rawBranch['id'] ?? item['branchId'] ?? '').toString();
      if (branchId.isNotEmpty && !seenBranchIds.add(branchId)) continue;

      assigned.add({
        'assignment': Map<String, dynamic>.from(item),
        'branch': Map<String, dynamic>.from(rawBranch),
        'name': branchName,
        'salonName': _salonName(rawBranch),
      });
    }

    return assigned;
  }

  bool _isActiveEntity(Map<String, dynamic> map) {
    bool? readBool(dynamic value) {
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
      return null;
    }

    for (final key in const ['active', 'isActive', 'enabled']) {
      final parsed = readBool(map[key]);
      if (parsed == false) return false;
    }

    for (final key in const [
      'status',
      'memberStatus',
      'professionalStatus',
      'state',
    ]) {
      final status = map[key]?.toString().trim().toLowerCase() ?? '';
      if (status.contains('deactiv') ||
          status.contains('inactive') ||
          status.contains('disabled') ||
          status.contains('deleted') ||
          status.contains('terminated') ||
          status.contains('suspended')) {
        return false;
      }
    }

    return true;
  }

  List<String> _labelList(dynamic raw, List<String> keys) {
    if (raw is! List) return const [];

    final values = <String>[];
    for (final item in raw) {
      String value = '';
      if (item is Map) {
        for (final key in keys) {
          value = (item[key] ?? '').toString().trim();
          if (value.isNotEmpty && value.toLowerCase() != 'null') break;
        }
      } else {
        value = item.toString().trim();
      }
      if (value.isNotEmpty &&
          value.toLowerCase() != 'null' &&
          !values.contains(value)) {
        values.add(value);
      }
    }
    return values;
  }

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

  String _textValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = (item[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Map<String, dynamic>? _primaryAssignment() {
    final rawBranches = member['userBranches'];
    if (rawBranches is! List) return null;

    for (final item in rawBranches) {
      if (item is! Map) continue;
      final assignment = Map<String, dynamic>.from(item);
      if (assignment.isEmpty) continue;
      return assignment;
    }

    return null;
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

  Map<String, List<String>> _memberScheduleMap() {
    final out = <String, List<String>>{};

    void merge(Map<String, List<String>> source) {
      source.forEach((day, ranges) {
        out.putIfAbsent(day, () => <String>[]).addAll(ranges);
      });
    }

    merge(_scheduleMapFromRaw(member['schedules']));

    final assignment = _primaryAssignment();
    if (assignment != null) {
      merge(
        _scheduleMapFromRaw(
          assignment['schedules'] ??
              assignment['schedule'] ??
              assignment['workingHours'],
        ),
      );
    }

    return out;
  }

  dynamic _scheduleSourceForBranch(int branchId) {
    final salonList = salons ?? const <Map<String, dynamic>>[];
    for (final rawSalon in salonList.whereType<Map>()) {
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

    final assignment = _primaryAssignment();
    final branch = assignment?['branch'];
    if (branch is Map && _toInt(branch['id']) == branchId) {
      final branchMap = Map<String, dynamic>.from(branch);
      for (final key in const ['schedule', 'schedules', 'workingHours']) {
        final value = branchMap[key];
        if (value != null) return value;
      }
    }

    return null;
  }

  Map<String, List<String>>? _branchOpenScheduleMap() {
    final assignment = _primaryAssignment();
    int? branchId;
    if (assignment != null) {
      final branch = assignment['branch'];
      if (branch is Map) {
        branchId = _toInt(branch['id']);
      }
      branchId ??= _toInt(assignment['branchId']);
    }
    if (branchId == null) return null;

    final source = _scheduleSourceForBranch(branchId);
    if (source == null) return null;
    final map = _scheduleMapFromRaw(source);
    return map.isEmpty ? null : map;
  }

  List<_WeeklyScheduleEntry> _weeklyScheduleEntries() {
    final memberSchedule = _memberScheduleMap();
    final branchSchedule = _branchOpenScheduleMap();

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
    final String firstName = (member['firstName'] ?? '').toString();
    final String lastName = (member['lastName'] ?? '').toString();
    final String name = '$firstName $lastName'.trim();
    final roles = _labelList(member['roles'], const ['label', 'name', 'code']);
    final String role = roles.isNotEmpty ? roles.join(', ') : 'Staff';
    final specializations = _labelList(
  member['specialities'] ??
      member['specializations'] ??
      member['speciality'] ??
      member['specialization'],
  const ['name', 'label', 'code', 'title', 'value'],
);

debugPrint('Member: $member');

debugPrint(member.keys.toList().toString());
debugPrint('Specialities: ${member['specialities']}');
debugPrint('Specializations: ${member['specializations']}');
    final about = _textValue(
      member,
      const [
        'info',
        'brief',
        'description',
        'about',
        'bio',
        'aboutMe',
        'profileSummary',
        'professionalSummary',
        'professionalBio',
      ],
    );
    final String rating = professionalRating.toStringAsFixed(1);
    final branches = member['userBranches'];

    final String experience =
        branches is List && branches.isNotEmpty && branches.first is Map
            ? '${branches.first['experience'] ?? 0} year'
            : '${member['experience'] ?? 0} year';

    final assignedBranches = _assignedBranches(member['userBranches']);
    final List userBranches = (member['userBranches'] ?? []) as List;
    final String joinedAt = userBranches.isNotEmpty
        ? (userBranches[0]['joiningDate'] ?? 'N/A').toString()
        : 'N/A';
    final weeklySchedule = _weeklyScheduleEntries();
    final displayName = name.isEmpty ? translateText('Team Member') : name;
    final initials = _initials(firstName, lastName).isEmpty
        ? 'TM'
        : _initials(firstName, lastName);
    final isActive = _isActiveEntity(member);

    return Scaffold(
      backgroundColor: _memberDetailBackground,
      appBar: buildProfileSubpageAppBar(
        title: translateText('View Member'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Text(
            translateText('Team Member'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            translateText('View profile, expertise, and assigned branches.'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: _memberDetailMuted,
            ),
          ),
          const SizedBox(height: 18),
          _MemberSummaryCard(
            initials: initials,
            name: displayName,
            role: role,
            rating: rating,
            reviewCount: professionalReviewCount,
            isActive: isActive,
          ),
          const SizedBox(height: 14),
          _DetailFactGrid(
            facts: [
              _DetailFactData(label: 'Role', value: role),
              _DetailFactData(label: 'Experience', value: experience),
              _DetailFactData(label: 'Joined At', value: joinedAt),
              _DetailFactData(
                label: 'Assigned Branches',
                value: assignedBranches.length.toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailSectionCard(
            icon: Icons.info_outline_rounded,
            title: 'About',
            child: about.isEmpty
                ? const _EmptyDetailText(text: 'No about information added')
                : Text(
                    about,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      color: _memberDetailText,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          _DetailSectionCard(
            icon: Icons.schedule_outlined,
            title: 'Weekly Schedule',
            child: weeklySchedule.isEmpty
                ? const _EmptyDetailText(text: 'No weekly schedule found')
                : _WeeklyScheduleSection(entries: weeklySchedule),
          ),
          const SizedBox(height: 14),
          _DetailSectionCard(
            icon: Icons.emoji_objects_outlined,
            title: 'Specializations',
            child: specializations.isEmpty
                ? const _EmptyDetailText(text: 'No specializations added')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final specialization in specializations)
                        _DetailChip(label: specialization),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _DetailSectionCard(
            icon: Icons.apartment_outlined,
            title: 'Assigned Branches',
            child: assignedBranches.isEmpty
                ? const _EmptyDetailText(text: 'No branches assigned')
                : Column(
                    children: [
                      for (var i = 0; i < assignedBranches.length; i++) ...[
                        _AssignedBranchRow(branch: assignedBranches[i]),
                        if (i != assignedBranches.length - 1)
                          const Divider(
                            height: 1,
                            color: _memberDetailBorder,
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

class _WeeklyScheduleSection extends StatefulWidget {
  const _WeeklyScheduleSection({required this.entries});

  final List<_WeeklyScheduleEntry> entries;

  @override
  State<_WeeklyScheduleSection> createState() => _WeeklyScheduleSectionState();
}

class _WeeklyScheduleSectionState extends State<_WeeklyScheduleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleEntries =
        _expanded ? widget.entries : widget.entries.take(3).toList();
    final hasOverflow = widget.entries.length > 3;

    return Column(
      children: [
        for (var i = 0; i < visibleEntries.length; i++) ...[
          _WeeklyScheduleRow(entry: visibleEntries[i]),
          if (i != visibleEntries.length - 1)
            const Divider(height: 1, color: _memberDetailBorder),
        ],
        if (hasOverflow) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.starColor,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                translateText(_expanded ? 'See less' : 'See more'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
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
            : _memberDetailMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText(dayLabel),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _memberDetailText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _DetailStatusPill(
                label: translateText(entry.statusLabel),
                color: statusColor,
              ),
              if (isWorking) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final range in entry.timeRanges)
                      _SlotPill(label: range),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberSummaryCard extends StatelessWidget {
  const _MemberSummaryCard({
    required this.initials,
    required this.name,
    required this.role,
    required this.rating,
    required this.reviewCount,
    required this.isActive,
  });

  final String initials;
  final String name;
  final String role;
  final String rating;
  final int reviewCount;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _memberCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: AppColors.starColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _memberDetailText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: _memberDetailMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DetailStatusPill(
                      label: isActive ? 'Active' : 'Inactive',
                      color: isActive
                          ? const Color(0xFF2F8A4C)
                          : _memberDetailMuted,
                    ),
                    _DetailStatusPill(
                      label: reviewCount > 0
                          ? '$rating ($reviewCount)'
                          : '$rating Rating',
                      color: AppColors.starColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailFactGrid extends StatelessWidget {
  const _DetailFactGrid({required this.facts});

  final List<_DetailFactData> facts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _memberCardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth >= 520
              ? (constraints.maxWidth - 18) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 18,
            runSpacing: 14,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: itemWidth,
                  child: _DetailFact(label: fact.label, value: fact.value),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailFactData {
  const _DetailFactData({required this.label, required this.value});

  final String label;
  final String value;
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText(label).toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppColors.starColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _memberDetailText,
          ),
        ),
      ],
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _memberCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.starColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  translateText(title),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _memberDetailText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailStatusPill extends StatelessWidget {
  const _DetailStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        translateText(label),
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2EA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _memberDetailBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _memberDetailText,
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _memberDetailText,
        ),
      ),
    );
  }
}

class _AssignedBranchRow extends StatelessWidget {
  const _AssignedBranchRow({required this.branch});

  final Map<String, dynamic> branch;

  @override
  Widget build(BuildContext context) {
    final salonName = branch['salonName'].toString().trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch['name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _memberDetailText,
                  ),
                ),
                if (salonName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    salonName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: _memberDetailMuted,
                    ),
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

class _EmptyDetailText extends StatelessWidget {
  const _EmptyDetailText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      translateText(text),
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _memberDetailMuted,
      ),
    );
  }
}

BoxDecoration _memberCardDecoration() {
  return BoxDecoration(
    color: _memberDetailSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _memberDetailBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
}
