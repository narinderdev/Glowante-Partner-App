// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/app_loader.dart';
import 'team_member_compensation_screen.dart';
import 'team_member_schedule_screen.dart';
import 'team_member_services_screen.dart';

const Color _memberDetailBackground = Color(0xFFFBFAF8);
const Color _memberDetailBorder = Color(0xFFE8DED6);
const Color _memberDetailText = Color(0xFF2B241D);
const Color _memberDetailMuted = Color(0xFF8C7A66);
const Color _memberDetailSurface = Colors.white;

Map<String, dynamic> _detailPayload(dynamic response) {
  if (response is! Map) return const <String, dynamic>{};

  final root = Map<String, dynamic>.from(response);
  final data = root['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  root.removeWhere(
    (key, _) => key == 'success' || key == 'message' || key == 'error',
  );
  return root;
}

Map<String, dynamic> _memberPayloadFromDetail(dynamic response) {
  final payload = _detailPayload(response);
  if (payload.isEmpty) return payload;

  final profile = payload['profile'];
  final user = payload['user'];
  final member = profile is Map
      ? Map<String, dynamic>.from(profile)
      : user is Map
          ? Map<String, dynamic>.from(user)
          : Map<String, dynamic>.from(payload);

  for (final key in const [
    'roles',
    'branches',
    'userBranches',
    'services',
    'schedules',
    'markedOffDays',
    'branchServiceIds',
    'userBranchServices',
    'allowOnlineBooking',
    'joiningDate',
    'leavingDate',
    'experience',
    'careerStartDate',
    'careerExperienceYears',
    'profilePictureUrl',
    'avatarUrl',
    'photoUrl',
  ]) {
    final value = payload[key];
    if (value != null) {
      member[key] = value;
    }
  }

  return member;
}

Map<String, dynamic> _mergeMemberMaps(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  final merged = Map<String, dynamic>.from(base);
  overlay.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    // A narrower source (e.g. the per-branch fallback fetch, which only
    // ever knows about one branch) must not shrink a list already merged
    // in from a fuller source (e.g. the salon-level multi-branch call).
    if (value is List) {
      final existing = merged[key];
      if (existing is List && existing.length > value.length) return;
    }
    merged[key] = value;
  });
  return merged;
}

class TeamMemberDetails extends StatefulWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>>? salons;
  final double professionalRating;
  final int professionalReviewCount;
  final int? branchId;
  final int? salonId;
  const TeamMemberDetails({
    super.key,
    required this.member,
    this.salons,
    this.professionalRating = 0,
    this.professionalReviewCount = 0,
    this.branchId,
    this.salonId,
  });

  @override
  State<TeamMemberDetails> createState() => _TeamMemberDetailsState();
}

class _TeamMemberDetailsState extends State<TeamMemberDetails> {
  late Map<String, dynamic> member = widget.member;
  bool _isRefreshing = false;

  List<Map<String, dynamic>>? get salons => widget.salons;
  double get professionalRating => widget.professionalRating;
  int get professionalReviewCount => widget.professionalReviewCount;

  Future<void> _refresh() async {
    final userId = _toInt(member['userId']);
    final salonId = widget.salonId;
    if (userId == null || salonId == null) return;

    setState(() => _isRefreshing = true);
    try {
      final response =
          await ApiService().getTeamMemberDetailV2(salonId, userId);
      Map<String, dynamic> refreshed = Map<String, dynamic>.from(member);
      if (response['success'] == true) {
        refreshed = _mergeMemberMaps(
          refreshed,
          _memberPayloadFromDetail(response),
        );
      }

      final branchId =
          widget.branchId ?? _toInt(_primaryAssignment()?['branchId']);
      if (branchId != null) {
        final branchResponse =
            await ApiService.getTeamMemberDetails(branchId, userId);
        refreshed = _mergeMemberMaps(
          refreshed,
          _memberPayloadFromDetail(branchResponse),
        );
      }

      if (!mounted) return;
      setState(() {
        member = refreshed;
      });
    } catch (_) {
      // Keep showing the already-loaded details if the refresh fails.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    return (f + l).toUpperCase();
  }

  // Two shapes seen from the backend for a branch assignment entry: the
  // documented flat one ({branchId, branchName, ...}) and a legacy nested
  // one ({branch: {id, name, salon: {id, name}}, schedules, joiningDate,
  // ...} — e.g. GET /salons/{salonId}/team/{userId} returning userBranches
  // in the old branches/{branchId}/team/{userId} shape). Check both.
  Map<String, dynamic>? _nestedBranch(Map item) {
    final nested = item['branch'];
    return nested is Map ? Map<String, dynamic>.from(nested) : null;
  }

  String _branchName(Map branch) {
    final direct =
        (branch['branchName'] ?? branch['name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final nested = _nestedBranch(branch);
    if (nested == null) return '';
    return (nested['name'] ?? nested['branchName'] ?? '').toString().trim();
  }

  int? _branchIdOf(Map item) {
    final direct = _toInt(item['branchId']);
    if (direct != null) return direct;
    final nested = _nestedBranch(item);
    return nested == null ? null : _toInt(nested['id'] ?? nested['branchId']);
  }

  // salon_team_part_1_updated_3.md §6.2: TeamBranchAssignmentSummary is
  // {branchId, branchName, active, allowOnlineBooking} — no embedded salon
  // name. Resolve it from widget.salons (the salon/branch hierarchy the
  // Team screen already loaded separately) by matching branchId.
  String _salonNameForBranch(int? branchId) {
    if (branchId == null) return '';
    for (final rawSalon in (salons ?? const <Map<String, dynamic>>[])) {
      final salonBranches = rawSalon['branches'];
      if (salonBranches is! List) continue;
      final matches = salonBranches.whereType<Map>().any(
            (b) => _toInt(b['branchId'] ?? b['id']) == branchId,
          );
      if (matches) {
        final name =
            (rawSalon['salonName'] ?? rawSalon['name'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _assignmentList(dynamic rawAssignments) {
    if (rawAssignments is! List) return const [];
    return rawAssignments.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  List<Map<String, dynamic>> _assignedBranches(dynamic rawBranches) {
    final assignments = _assignmentList(rawBranches);
    if (assignments.isEmpty) return const [];

    final assigned = <Map<String, dynamic>>[];
    final seenBranchIds = <String>{};

    for (final item in assignments) {
      final branchName = _branchName(item);
      if (branchName.isEmpty) continue;

      final branchId = _branchIdOf(item);
      final branchIdKey = branchId?.toString() ?? '';
      if (branchIdKey.isNotEmpty && !seenBranchIds.add(branchIdKey)) continue;

      final nestedSalon = _nestedBranch(item)?['salon'];
      final nestedSalonName = nestedSalon is Map
          ? (nestedSalon['name'] ?? '').toString().trim()
          : '';

      assigned.add({
        'branchId': branchId,
        'name': branchName,
        'salonName': nestedSalonName.isNotEmpty
            ? nestedSalonName
            : _salonNameForBranch(branchId),
        'allowOnlineBooking': item['allowOnlineBooking'] == true,
        'joiningDate': item['joiningDate'],
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

  // Backend has returned `services` at least three different ways for
  // this member: flat top-level (salon_team_part_1_updated_3.md §6.5),
  // nested under each branches[] entry as `services` (a shape Narinder
  // proposed but hasn't shipped as of 2026-09-02), and nested under each
  // userBranches[] entry as `userBranchServices` (the legacy per-branch
  // shape, e.g. GET /salons/{salonId}/team/{userId} returning userBranches
  // — see _branchIdOf). Aggregate all three, deduped by
  // userBranchServiceId/id, backfilling branchId from the owning
  // assignment when an entry doesn't carry its own.
  List<Map<String, dynamic>> _rawServices() {
    final values = <Map<String, dynamic>>[];
    final seen = <String>{};

    void collect(List items, {int? fallbackBranchId}) {
      for (final item in items) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if (map['branchId'] == null && fallbackBranchId != null) {
          map['branchId'] = fallbackBranchId;
        }
        final key = (map['userBranchServiceId'] ??
                map['branchServiceId'] ??
                map['id'] ??
                '${map['branchId']}-${map['displayName']}')
            .toString();
        if (seen.add(key)) values.add(map);
      }
    }

    final topLevel = member['services'];
    if (topLevel is List) collect(topLevel);

    for (final branch in _rawAssignments()) {
      final branchId = _branchIdOf(branch);
      final rawServices = branch['services'];
      if (rawServices is List) collect(rawServices, fallbackBranchId: branchId);
      final rawBranchServices = branch['userBranchServices'];
      if (rawBranchServices is List) {
        collect(rawBranchServices, fallbackBranchId: branchId);
      }
    }

    return values;
  }

  List<dynamic> _rolesAcrossBranches() {
    final combined = <dynamic>[];
    for (final branch in _rawAssignments()) {
      final rawRoles = branch['roles'];
      if (rawRoles is List) combined.addAll(rawRoles);
    }
    if (combined.isEmpty) {
      final topLevel = member['roles'];
      if (topLevel is List) combined.addAll(topLevel);
    }
    return combined;
  }

  String _avatarUrl() {
    return _cleanText(
      member['profilePictureUrl'] ??
          member['avatarUrl'] ??
          member['photoUrl'] ??
          member['imageUrl'],
    );
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  String _displayValue(dynamic value) {
    final text = _cleanText(value);
    return text.isEmpty ? translateText('N/A') : text;
  }

  String _genderLabel(dynamic value) {
    final text = _cleanText(value);
    if (text.isEmpty) return translateText('N/A');
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _phoneLabel() {
    // The legacy per-branch shape sends a ready-made `fullPhoneNumber`
    // instead of separate countryCode/phoneNumber fields — prefer it when
    // present since it's already correctly combined.
    final full = _cleanText(member['fullPhoneNumber']);
    if (full.isNotEmpty) return full;
    final countryCode = _cleanText(member['countryCode']);
    final phoneNumber = _cleanText(member['phoneNumber']);
    if (countryCode.isEmpty && phoneNumber.isEmpty) return translateText('N/A');
    return '$countryCode $phoneNumber'.trim();
  }

  String _verificationLabel(dynamic value) {
    return value == true
        ? translateText('Verified')
        : translateText('Unverified');
  }

  String _addressLabel() {
    final raw = member['address'];
    if (raw is! Map) return translateText('N/A');
    final address = Map<String, dynamic>.from(raw);
    final formatted = _cleanText(address['formattedAddress']);
    if (formatted.isNotEmpty) return formatted;
    final joined = [
      address['line1'],
      address['line2'],
      address['city'],
      address['village'],
      address['district'],
      address['state'],
      address['country'],
      address['postalCode'],
    ].map(_cleanText).where((part) => part.isNotEmpty).join(', ');
    return joined.isEmpty ? translateText('N/A') : joined;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _primaryAssignment() {
    final assignments = _rawAssignments();
    if (assignments.isEmpty) return null;
    for (final assignment in assignments) {
      if (assignment.isNotEmpty) return assignment;
    }
    return null;
  }

  List<Map<String, dynamic>> _rawAssignments() {
    final userBranches = member['userBranches'];
    final branches = member['branches'];
    final raw = userBranches is List && userBranches.isNotEmpty
        ? userBranches
        : branches;
    return _assignmentList(raw);
  }

  Map<String, dynamic>? _rawAssignmentForBranch(int? branchId) {
    if (branchId == null) return null;
    for (final assignment in _rawAssignments()) {
      if (_branchIdOf(assignment) == branchId) return assignment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = (member['firstName'] ?? '').toString();
    final String lastName = (member['lastName'] ?? '').toString();
    final String name = '$firstName $lastName'.trim();
    final roles =
        _labelList(_rolesAcrossBranches(), const ['label', 'name', 'code']);
    final String role = roles.isNotEmpty ? roles.join(', ') : 'Staff';
    final specialities = _labelList(
      member['specialities'] ??
          member['specializations'] ??
          member['speciality'] ??
          member['specialization'],
      const ['name', 'label', 'code', 'title', 'value'],
    );
    final imageUrl = _avatarUrl();

    debugPrint('Member: $member');

    debugPrint(member.keys.toList().toString());
    debugPrint('Specialities: ${member['specialities']}');
    debugPrint('Specializations: ${member['specializations']}');
    final String rating = professionalRating.toStringAsFixed(1);

    // `careerStartDate`/`careerExperienceYears` (part_2 §3) are a
    // career-wide figure on the profile. `joiningDate` is per-branch —
    // see branches[].joiningDate in _AssignedBranchRow instead of here.
    final careerExperienceYears = member['careerExperienceYears'];
    final String experience = careerExperienceYears == null
        ? translateText('N/A')
        : '$careerExperienceYears ${translateText('year')}';
    final String careerStart = (member['careerStartDate'] ?? '').toString();

    final assignedBranches = _assignedBranches(_rawAssignments());
    final rawServices = _rawServices();
    final displayName = name.isEmpty ? translateText('Team Member') : name;
    final initials = _initials(firstName, lastName).isEmpty
        ? 'TM'
        : _initials(firstName, lastName);
    // isProfileComplete (part_1 §5.4) is the authoritative "Active" vs
    // "Setup Required" signal — the same boolean the list screen's
    // teamDisplayStatus is derived from. There is no separate account-
    // active/deactivated flag on this API.
    final isActive = member.containsKey('isProfileComplete')
        ? member['isProfileComplete'] == true
        : _isActiveEntity(member);

    return Scaffold(
      backgroundColor: _memberDetailBackground,
      appBar: buildProfileSubpageAppBar(
        title: translateText('View Member'),
      ),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: () => RefreshFeedback.playAndDetach(_refresh),
        child: Stack(
          children: [
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                  translateText(
                      'View profile, expertise, and assigned branches.'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: _memberDetailMuted,
                  ),
                ),
                const SizedBox(height: 18),
                _MemberSummaryCard(
                  initials: initials,
                  imageUrl: imageUrl,
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
                    _DetailFactData(
                      label: 'Career Start',
                      value: careerStart.isEmpty
                          ? translateText('N/A')
                          : careerStart,
                    ),
                    _DetailFactData(
                      label: 'Assigned Branches',
                      value: assignedBranches.length.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailSectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Profile',
                  child: _ProfileDetailList(
                    rows: [
                      _ProfileDetailRowData(
                        label: 'Phone',
                        value: _phoneLabel(),
                        trailing: _verificationLabel(member['phoneVerified']),
                      ),
                      _ProfileDetailRowData(
                        label: 'Email',
                        value: _displayValue(member['email']),
                        trailing: _verificationLabel(member['emailVerified']),
                      ),
                      _ProfileDetailRowData(
                        label: 'Gender',
                        value: _genderLabel(member['gender']),
                      ),
                      _ProfileDetailRowData(
                        label: 'Bio',
                        // Legacy per-branch shape calls this field `info`.
                        value: _displayValue(member['bio'] ?? member['info']),
                      ),
                      _ProfileDetailRowData(
                        label: 'Address',
                        value: _addressLabel(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DetailSectionCard(
                  icon: Icons.payments_outlined,
                  title: 'Employment & Compensation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translateText(
                          'Record employment type and monthly base pay for this member.',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: _memberDetailMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final salonId = widget.salonId;
                            final userId = _toInt(member['userId']);
                            if (salonId == null || userId == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamMemberCompensationScreen(
                                  salonId: salonId,
                                  userId: userId,
                                  memberName: displayName,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.starColor),
                            foregroundColor: AppColors.starColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: Text(
                            translateText('Manage Employment & Compensation'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DetailSectionCard(
                  icon: Icons.emoji_objects_outlined,
                  title: 'Specialities',
                  child: specialities.isEmpty
                      ? const _EmptyDetailText(text: 'No specialities added')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final speciality in specialities)
                              _DetailChip(label: speciality),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _DetailSectionCard(
                  icon: Icons.apartment_outlined,
                  title: 'Assigned Branches',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rawServices.isEmpty
                                  ? translateText('No services assigned')
                                  : translateText(
                                      '{n} services assigned',
                                      params: {'n': '${rawServices.length}'},
                                    ),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                color: _memberDetailMuted,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: rawServices.isEmpty
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TeamMemberServicesScreen(
                                          memberName: displayName,
                                          services: rawServices,
                                          branches: assignedBranches,
                                        ),
                                      ),
                                    ),
                            icon: const Icon(
                              Icons.design_services_outlined,
                              size: 15,
                            ),
                            label: Text(
                              translateText('View Services'),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.starColor,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1, color: _memberDetailBorder),
                      const SizedBox(height: 4),
                      if (assignedBranches.isEmpty)
                        const _EmptyDetailText(text: 'No branches assigned')
                      else
                        for (var i = 0; i < assignedBranches.length; i++) ...[
                          _AssignedBranchRow(
                            branch: assignedBranches[i],
                            onViewSchedule: () {
                              final branchId =
                                  _toInt(assignedBranches[i]['branchId']);
                              final assignment =
                                  _rawAssignmentForBranch(branchId) ??
                                      const <String, dynamic>{};
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeamMemberScheduleScreen(
                                    memberName: displayName,
                                    branchName:
                                        (assignedBranches[i]['name'] ?? '')
                                            .toString(),
                                    branchAssignment: assignment,
                                    salons: salons,
                                  ),
                                ),
                              );
                            },
                          ),
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
            if (_isRefreshing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.08),
                    child: AppLoader.page(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberSummaryCard extends StatelessWidget {
  const _MemberSummaryCard({
    required this.initials,
    required this.imageUrl,
    required this.name,
    required this.role,
    required this.rating,
    required this.reviewCount,
    required this.isActive,
  });

  final String initials;
  final String imageUrl;
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
          _MemberAvatar(
            imageUrl: imageUrl,
            initials: initials,
            size: 46,
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
                      label: isActive ? 'Active' : 'Setup Required',
                      color: isActive
                          ? const Color(0xFF2F8A4C)
                          : const Color(0xFFB45309),
                    ),
                    _DetailStatusPill(
                      label: reviewCount > 0
                          ? '$rating ($reviewCount)'
                          : '$rating ${translateText('Rating')}',
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

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.imageUrl,
    required this.initials,
    this.size = 46,
  });

  final String imageUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _MemberInitialsAvatar(initials: initials, size: size),
        ),
      );
    }
    return _MemberInitialsAvatar(initials: initials, size: size);
  }
}

class _MemberInitialsAvatar extends StatelessWidget {
  const _MemberInitialsAvatar({
    required this.initials,
    this.size = 46,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFF3D5),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.starColor,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.34,
        ),
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

class _ProfileDetailRowData {
  const _ProfileDetailRowData({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final String? trailing;
}

class _ProfileDetailList extends StatelessWidget {
  const _ProfileDetailList({required this.rows});

  final List<_ProfileDetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _ProfileDetailRow(row: rows[i]),
          if (i != rows.length - 1)
            const Divider(height: 1, color: _memberDetailBorder),
        ],
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.row});

  final _ProfileDetailRowData row;

  @override
  Widget build(BuildContext context) {
    final trailing = row.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              translateText(row.label),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.starColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _memberDetailText,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            _DetailStatusPill(
              label: trailing,
              color: trailing == translateText('Verified')
                  ? const Color(0xFF2F8A4C)
                  : _memberDetailMuted,
            ),
          ],
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
  const _AssignedBranchRow({required this.branch, this.onViewSchedule});

  final Map<String, dynamic> branch;
  final VoidCallback? onViewSchedule;

  @override
  Widget build(BuildContext context) {
    final salonName = branch['salonName'].toString().trim();
    final joiningDate = branch['joiningDate']?.toString().trim() ?? '';
    final subtitleParts = [
      if (salonName.isNotEmpty) salonName,
      if (joiningDate.isNotEmpty && joiningDate.toLowerCase() != 'null')
        '${translateText('Joined')} $joiningDate',
    ];
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
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitleParts.join(' · '),
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
          if (onViewSchedule != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onViewSchedule,
              icon: const Icon(Icons.schedule_outlined, size: 14),
              label: Text(
                translateText('View Schedule'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.starColor,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
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
