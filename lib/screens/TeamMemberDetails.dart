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

  @override
  Widget build(BuildContext context) {
    final String firstName = (member['firstName'] ?? '').toString();
    final String lastName = (member['lastName'] ?? '').toString();
    final String name = '$firstName $lastName'.trim();
    final roles = _labelList(member['roles'], const ['label', 'name', 'code']);
    final String role = roles.isNotEmpty ? roles.first : 'Staff';
    final specializations = _labelList(
      member['specialities'] ?? member['specializations'],
      const ['name', 'label', 'code'],
    );
    final String rating = professionalRating.toStringAsFixed(1);
    final branches = member['userBranches'];

final String experience = branches is List &&
        branches.isNotEmpty &&
        branches.first is Map
    ? '${branches.first['experience'] ?? 0} year'
    : '${member['experience'] ?? 0} year';

    final assignedBranches = _assignedBranches(member['userBranches']);
    final List userBranches = (member['userBranches'] ?? []) as List;
    final String joinedAt = userBranches.isNotEmpty
        ? (userBranches[0]['joiningDate'] ?? 'N/A').toString()
        : 'N/A';
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
                  maxLines: 1,
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
          const Icon(
            Icons.chevron_right_rounded,
            color: _memberDetailMuted,
            size: 22,
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
