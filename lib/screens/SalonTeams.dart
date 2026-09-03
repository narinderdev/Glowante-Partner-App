// ignore_for_file: file_names, avoid_print, unused_element, unused_element_parameter

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import '../utils/address_formatter.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../widgets/app_loader.dart';
import 'TeamMemberDetails.dart';
import 'complete_profile_flow_constants.dart';
import 'complete_team_member_profile_screen.dart';
import 'AssignUser.dart';
import 'assign_user_flow_constants.dart';
import 'invite_team_member_screen.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _teamGold = Color(0xFF8B6500);
const Color _teamInk = Color(0xFF2D2926);
const Color _teamMuted = Color(0xFF756A61);
const Color _teamBorder = Color(0xFFE8DED6);
const Color _teamSurface = Color(0xFFFBF8F4);
const Color _teamGoldLight = Color(0xFFF3E8D1);

int? _teamAsInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _teamReadBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty || text == 'null') return null;
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

String _teamFirstText(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final text = map[key]?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

bool _teamIsActiveEntity(Map<String, dynamic> map) {
  for (final key in const ['active', 'isActive', 'enabled']) {
    final parsed = _teamReadBool(map[key]);
    if (parsed == false) return false;
  }

  for (final key in const [
    'status',
    'memberStatus',
    'professionalStatus',
    'state',
  ]) {
    final status = map[key]?.toString().trim().toLowerCase() ?? '';
    if (status.isEmpty || status == 'null') continue;
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

class _TeamRatingSummary {
  const _TeamRatingSummary({
    required this.average,
    required this.count,
  });

  static const empty = _TeamRatingSummary(average: 0, count: 0);

  final num average;
  final int count;
}

class _TeamServiceFilterOption {
  const _TeamServiceFilterOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

// A known salon with no specific branch chosen (branchId null) is the
// unfiltered "All Branches" state, not a data-loading placeholder — only
// a genuinely null selection (nothing resolved yet) reads as "Select
// Branch".
String _teamBranchLabel(Map<String, dynamic>? branch) {
  if (branch == null) return translateText('Select Branch');
  final branchName = branch['branchName']?.toString().trim() ?? '';
  if (branchName.isNotEmpty) return branchName;
  final apiName = branch['name']?.toString().trim() ?? '';
  if (apiName.isNotEmpty) return apiName;
  return translateText('Select Branch');
}

Map<String, dynamic> _teamAllBranchesSelectionForSalon({
  required int salonId,
  required String salonName,
}) {
  return {
    'salonId': salonId,
    'salonName': salonName,
    'branchId': null,
    'branchName': null,
  };
}

// Row-actions menu item: icon + label instead of the plain default
// PopupMenuItem text, for the "3 dot" actions dropdown on a team member.
PopupMenuItem<String> _teamMenuItem({
  required String value,
  required IconData icon,
  required String label,
  bool enabled = true,
  Color? color,
}) {
  final effectiveColor =
      !enabled ? _teamMuted.withValues(alpha: 0.45) : (color ?? _teamInk);
  return PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: 19, color: effectiveColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: effectiveColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _teamDetailPayload(dynamic response) {
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

Map<String, dynamic> _teamMemberPayloadFromDetail(dynamic response) {
  final payload = _teamDetailPayload(response);
  if (payload.isEmpty) return payload;

  final profile = payload['profile'];
  final user = payload['user'];
  final member = profile is Map
      ? Map<String, dynamic>.from(profile)
      : user is Map
          ? Map<String, dynamic>.from(user)
          : Map<String, dynamic>.from(payload);

  if (profile is! Map && user is! Map) {
    member.remove('data');
  }

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

Map<String, dynamic> _teamMergeMemberMaps(
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

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<Map<String, dynamic>>> branchOptionsFuture;
  final TextEditingController _teamSearchController = TextEditingController();
  late final VoidCallback _branchSelectionListener;
  bool _suppressBranchSelectionRefresh = false;

  int? selectedBranchId;
  Map<String, dynamic>?
      selectedBranch; // {branchId, branchName, salonId, salonName}
  Future<List<dynamic>>? teamMembersFuture;
  List<Map<String, dynamic>> _salons = const [];
  Map<int, _TeamRatingSummary> _professionalRatings = const {};
  bool _hasTeamMembers = false;
  String _teamStatusFilter = 'all';
  bool? _allowOnlineBookingFilter;
  DateTime? _teamDateFilter;
  List<_TeamServiceFilterOption> _teamServiceOptions =
      const <_TeamServiceFilterOption>[];
  final Set<int> _selectedTeamServiceIds = <int>{};
  bool _isLoadingTeamServices = false;
  bool _showAllTeamServices = false;
  Timer? _teamSearchDebounce;
  final Set<int> _statusUpdatingIds = {};
  final Set<int> _deletingMemberIds = {};
  int? _openingViewMemberId;
  bool _isLoadingTeamMembers = false;

  final Set<int> _cancellingInvitationIds = {};
  // 0 = Active, 1 = Setup Required, 2 = Invited — matches
  // salon_team_part_1_updated_3.md §1 exactly: "the finalized UI has three
  // tabs (Active, Setup Required, Invited) and no combined 'All Members'
  // view." (This screen briefly had a 4th "All Members" tab modeled on an
  // early web mockup; the backend spec is authoritative now.)
  int _selectedTeamTab = 0;
  int _teamMembersPage = 0;
  static const int _teamMembersPageSize = 8;
  String _teamSortOrder = 'name_asc'; // or 'name_desc'

  // ---- salon_team_part_1_updated_3.md data — replaces the old branch-
  // scoped getTeamMembers/getSalonUsers/getSalonTeamInvitations pipeline
  // below (still present but unused; kept for reference). The new
  // endpoints are salon-scoped (branchId is an optional narrowing filter,
  // not a requirement), server-paginated, and server-filtered by status —
  // so "Setup Required" is exactly what the backend says it is, not a
  // client-side heuristic, and unassigned-to-any-branch members no longer
  // need a separate merge (they're just salon members like any other).
  int _teamActiveCount = 0;
  int _teamSetupRequiredCount = 0;
  int _teamInvitedCount = 0;

  List<Map<String, dynamic>> _tabMembers = const [];
  int _tabMembersTotal = 0;
  int _tabMembersTotalPages = 1;
  bool _isLoadingTabMembers = false;

  List<Map<String, dynamic>> _invitationsV2 = const [];
  int _invitationsV2Total = 0;
  int _invitationsV2TotalPages = 1;
  bool _isLoadingInvitationsV2 = false;

  // Invitations are salon-wide, not branch-scoped (see invitation_plan.md
  // §6 — a salon_invitation has no branchId). Tracked separately from
  // selectedBranchId so switching branches within the same salon doesn't
  // spuriously look like it's "filtering" the Invited tab, and so a salon
  // with multiple branches can still show one shared Invited list.
  int? _invitedSalonId;

  @override
  void initState() {
    super.initState();
    _teamSearchController.addListener(_onTeamSearchChanged);
    _branchSelectionListener = () {
      if (!mounted || _suppressBranchSelectionRefresh) return;
      // Only show the full loader for an actual salon/branch switch — the
      // subsequent branch-list refetch (and then the team-members refetch
      // for the new branch) can each take a moment, and without this the
      // screen just keeps showing the previous branch's stale data with no
      // loading indication until the whole async chain resolves.
      final isActualChange =
          StylistBranchSelectionStore.selectionNotifier.value.branchId !=
              selectedBranchId;
      setState(() {
        if (isActualChange) {
          _hasTeamMembers = false;
          _isLoadingTeamMembers = true;
        }
        branchOptionsFuture = _getBranchOptions();
      });
    };
    StylistBranchSelectionStore.selectionNotifier
        .addListener(_branchSelectionListener);
    branchOptionsFuture = _getBranchOptions(); // single list for the dropdown
  }

  @override
  void dispose() {
    StylistBranchSelectionStore.selectionNotifier
        .removeListener(_branchSelectionListener);
    _teamSearchDebounce?.cancel();
    _teamSearchController.dispose();
    super.dispose();
  }

  /// Flattens salons->branches to branch options:
  /// [{branchId, branchName, salonId, salonName}]
  Future<List<Map<String, dynamic>>> _getBranchOptions() async {
    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final List salons = response['data'] ?? [];
        _salons = salons
            .whereType<Map>()
            .map((salon) => Map<String, dynamic>.from(salon))
            .toList();
        final List<Map<String, dynamic>> out = [];
        for (final s in salons) {
          final sid = s['id'];
          final sname = s['name'];
          final List branches = (s['branches'] as List? ?? []);
          for (final b in branches) {
            if (b == null) continue;
            out.add({
              'branchId': b['id'],
              'branchName': b['name'],
              'salonId': sid,
              'salonName': sname,
              'addressSummary': _branchAddressSummary(b['address']),
            });
          }
        }

        final preferredBranchId = selection.branchId;
        if (mounted && out.isNotEmpty) {
          if (selectedBranch == null) {
            // First load: always default to "All Branches" for this salon,
            // using salonId/salonName straight from `out` (this same fetch)
            // rather than the stylist's persisted branch-selection
            // preference — that preference can point at a salonId this
            // fetch never returns a matching branch for (stale/mismatched
            // context), which silently emptied `currentSalonBranches` and
            // hid the branch-filter pill entirely further down.
            _pickBranch(
              _teamAllBranchesSelectionForSalon(
                salonId: _asInt(out.first['salonId']) ?? 0,
                salonName: out.first['salonName']?.toString() ?? '',
              ),
            );
          } else if (preferredBranchId != null &&
              selectedBranchId != preferredBranchId) {
            // Reacts to an actual branch switch made elsewhere in the app
            // while this screen is already open.
            _pickBranch(
              out.firstWhere(
                (item) => _asInt(item['branchId']) == preferredBranchId,
                orElse: () => _teamAllBranchesSelectionForSalon(
                  salonId: _asInt(out.first['salonId']) ?? 0,
                  salonName: out.first['salonName']?.toString() ?? '',
                ),
              ),
            );
          }
        }

        return out;
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("❌ Error fetching salons/branches: $e");
      return [];
    }
  }

  int? _asInt(dynamic value) {
    return _teamAsInt(value);
  }

  String _branchAddressSummary(dynamic rawAddress) {
    return formatAddressSummary(rawAddress);
  }

  // Future<List<dynamic>> _getTeamMembersByBranch(int branchId) async {
  //   try {
  //     final response = await ApiService.getTeamMembers(branchId);
  //     if (response['success'] == true) {
  //       return response['data'] ?? [];
  //     } else {
  //       return [];
  //     }
  //   } catch (e) {
  //     print("❌ Error fetching team members: $e");
  //     return [];
  //   }
  // }
  Future<List<dynamic>> _getTeamMembersByBranch(int branchId) async {
    try {
      final response = await ApiService.getTeamMembers(
        branchId,
        status: _teamStatusFilter,
        allowOnlineBooking: _allowOnlineBookingFilter,
        search: _teamSearchController.text.trim(),
      );

      final rawMembers = response['success'] == true && response['data'] is List
          ? List<dynamic>.from(response['data'] as List)
          : <dynamic>[];
      final members = _applyLocalTeamFilters(rawMembers);
      final ratings = await _loadProfessionalRatings(branchId);

      if (mounted && selectedBranchId == branchId) {
        final hasMembers = members.isNotEmpty;
        setState(() {
          _professionalRatings = ratings;
          _hasTeamMembers = hasMembers;
        });
      }

      return members;
    } catch (e) {
      print("❌ Error fetching team members: $e");

      if (mounted && selectedBranchId == branchId && _hasTeamMembers) {
        setState(() {
          _hasTeamMembers = false;
        });
      }

      return [];
    }
  }

  List<dynamic> _applyLocalTeamFilters(List<dynamic> members) {
    return members.where((rawMember) {
      if (rawMember is! Map) return false;
      final member = Map<String, dynamic>.from(rawMember);
      return _memberMatchesDateFilter(member) &&
          _memberMatchesServiceFilter(member);
    }).toList();
  }

  bool _memberMatchesDateFilter(Map<String, dynamic> member) {
    final selectedDate = _teamDateFilter;
    if (selectedDate == null) return true;

    final normalizedDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final branches = member['userBranches'];
    if (branches is! List || branches.isEmpty) {
      return true;
    }

    var sawMatchingBranch = false;
    for (final rawBranch in branches) {
      if (rawBranch is! Map) continue;
      final branchEntry = Map<String, dynamic>.from(rawBranch);
      final branch = branchEntry['branch'];
      final branchMap = branch is Map
          ? Map<String, dynamic>.from(branch)
          : <String, dynamic>{};
      final branchId = _asInt(branchMap['id']) ??
          _asInt(branchEntry['branchId']) ??
          _asInt(branchEntry['branch_id']);

      if (selectedBranchId != null && branchId != selectedBranchId) continue;
      sawMatchingBranch = true;

      final joiningDate = _teamParseDateOnly(branchEntry['joiningDate']);
      if (joiningDate != null && joiningDate.isAfter(normalizedDate)) {
        continue;
      }

      final leavingDate = _teamParseDateOnly(branchEntry['leavingDate']);
      if (leavingDate != null && leavingDate.isBefore(normalizedDate)) {
        continue;
      }

      return true;
    }

    return !sawMatchingBranch;
  }

  bool _memberMatchesServiceFilter(Map<String, dynamic> member) {
    if (_selectedTeamServiceIds.isEmpty) return true;

    final selectedIds = _selectedTeamServiceIds;
    final sources = <dynamic>[
      member['userBranchServices'],
      member['services'],
      member['branchServices'],
      member['assignedServices'],
      member['assignedBranchServices'],
      member['serviceIds'],
      member['branchServiceIds'],
      member['assignedServiceIds'],
      member['assignedBranchServiceIds'],
    ];

    bool matchesValue(dynamic value) {
      if (value == null) return false;
      final id = _asInt(value);
      if (id != null && selectedIds.contains(id)) return true;

      if (value is List) {
        return value.any(matchesValue);
      }
      if (value is! Map) return false;

      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'branchServiceId',
        'branch_service_id',
        'serviceId',
        'service_id',
        'masterServiceId',
        'master_service_id',
        'id',
      ]) {
        final nestedId = _asInt(map[key]);
        if (nestedId != null && selectedIds.contains(nestedId)) {
          return true;
        }
      }

      for (final key in const ['branchService', 'service', 'masterService']) {
        final nested = map[key];
        if (matchesValue(nested)) return true;
      }

      return false;
    }

    if (sources.any(matchesValue)) return true;

    final branches = member['userBranches'];
    if (branches is! List) return false;
    for (final rawBranch in branches) {
      if (rawBranch is! Map) continue;
      final branchEntry = Map<String, dynamic>.from(rawBranch);
      final branch = branchEntry['branch'];
      final branchMap = branch is Map
          ? Map<String, dynamic>.from(branch)
          : <String, dynamic>{};
      final branchId = _asInt(branchMap['id']) ??
          _asInt(branchEntry['branchId']) ??
          _asInt(branchEntry['branch_id']);

      if (selectedBranchId != null && branchId != selectedBranchId) continue;

      final branchSources = <dynamic>[
        branchEntry['userBranchServices'],
        branchEntry['services'],
        branchEntry['branchServices'],
        branchEntry['assignedServices'],
        branchEntry['assignedBranchServices'],
        branchEntry['serviceIds'],
        branchEntry['branchServiceIds'],
        branchEntry['assignedServiceIds'],
        branchEntry['assignedBranchServiceIds'],
      ];
      if (branchSources.any(matchesValue)) return true;
    }

    return false;
  }

  DateTime? _teamParseDateOnly(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  int? get _currentSalonId => _asInt(selectedBranch?['salonId']);

  // 'active' for tab 0, 'setup_required' for tab 1 — tab 2 (Invited) uses
  // _fetchInvitationsV2 instead, since it's a different resource
  // (SalonInvitation, not User/UserSalon) per §3.6.
  String get _currentTabStatus =>
      _selectedTeamTab == 0 ? 'active' : 'setup_required';

  Future<void> _fetchTeamSummary() async {
    final salonId = _currentSalonId;
    if (salonId == null || !mounted) return;
    try {
      // selectedBranchId is null exactly when "All Branches" is chosen in
      // the top selector (see _teamBranchOptions) — same single dropdown
      // scopes both Active and Setup Required, matching the web reference
      // (one Branch filter, an "All Branches" option included in it).
      final response = await ApiService().getTeamSummaryV2(
        salonId,
        branchId: selectedBranchId,
      );
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        setState(() {
          _teamActiveCount = _asInt(data['active']) ?? 0;
          _teamSetupRequiredCount = _asInt(data['setupRequired']) ?? 0;
          _teamInvitedCount = _asInt(data['invited']) ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Failed to load team summary: $e');
    }
  }

  Future<void> _fetchTabMembers() async {
    final salonId = _currentSalonId;
    if (salonId == null || !mounted) return;
    setState(() => _isLoadingTabMembers = true);
    try {
      final response = await ApiService().getTeamMembersV2(
        salonId,
        status: _currentTabStatus,
        branchId: selectedBranchId,
        search: _teamSearchController.text.trim(),
        sort: _teamSortOrder,
        page: _teamMembersPage + 1, // API is 1-based; UI state is 0-based
        pageSize: _teamMembersPageSize,
      );
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final rawItems = data['items'];
        final pagination = data['pagination'] is Map
            ? Map<String, dynamic>.from(data['pagination'] as Map)
            : const <String, dynamic>{};
        setState(() {
          _tabMembers = (rawItems is List ? rawItems : const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _tabMembersTotal = _asInt(pagination['total']) ?? _tabMembers.length;
          _tabMembersTotalPages = _asInt(pagination['totalPages']) ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Failed to load team members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTabMembers = false);
    }
  }

  Future<void> _fetchInvitationsV2() async {
    // Invited has no picker of its own anymore — it follows the same top
    // branch selector's salon as Active/Setup Required.
    final salonId = _currentSalonId;
    if (salonId == null || !mounted) return;
    setState(() => _isLoadingInvitationsV2 = true);
    try {
      final response = await ApiService().getTeamInvitationsV2(
        salonId,
        search: _teamSearchController.text.trim(),
        sort: _teamSortOrder,
        page: _teamMembersPage + 1,
        pageSize: _teamMembersPageSize,
      );
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final rawItems = data['items'];
        final pagination = data['pagination'] is Map
            ? Map<String, dynamic>.from(data['pagination'] as Map)
            : const <String, dynamic>{};
        setState(() {
          _invitationsV2 = (rawItems is List ? rawItems : const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _invitationsV2Total =
              _asInt(pagination['total']) ?? _invitationsV2.length;
          _invitationsV2TotalPages = _asInt(pagination['totalPages']) ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Failed to load invitations: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInvitationsV2 = false);
    }
  }

  // Refetches whichever tab is currently selected, plus the summary
  // counts (so switching tabs, paging, searching, sorting, or changing
  // the branch filter always reflects the latest server state).
  Future<void> _refreshCurrentTeamTab({bool resetPage = false}) async {
    if (resetPage) _teamMembersPage = 0;
    unawaited(_fetchTeamSummary());
    if (_selectedTeamTab == 2) {
      unawaited(_fetchInvitationsV2());
    } else {
      unawaited(_fetchTabMembers());
    }
  }

  // Assigns the future that drives the team-members list and, unless
  // suppressed, turns on the full-screen loading overlay until it settles.
  // Search typing suppresses it — that reload should feel instant, not
  // flash a spinner on every keystroke.
  void _startTeamMembersFuture(
    Future<List<dynamic>> future, {
    bool showOverlay = true,
  }) {
    if (showOverlay) _isLoadingTeamMembers = true;
    teamMembersFuture = future;
    future.whenComplete(() {
      if (mounted) setState(() => _isLoadingTeamMembers = false);
    });
  }

  // Thin wrapper kept so every existing action-success call site (Edit,
  // Delete, Deactivate, Assign) that already calls this after a mutation
  // keeps working unchanged — it now refetches from the
  // salon_team_part_1_updated_3.md pipeline instead of the old
  // branch-scoped getTeamMembers call.
  Future<void> _refreshTeamMembers({bool showOverlay = true}) async {
    // selectedBranch, not selectedBranchId — the latter is also null in
    // deliberate "All Branches" mode, where this must still refresh.
    if (selectedBranch == null || !mounted) return;
    await _fetchTabMembers();
  }

  // Kept as a no-op wrapper for the same reason as above — "unassigned
  // salon members" isn't a separate concept under the new API; a member
  // with no branch yet just shows up in Active or Setup Required like any
  // other salon member (updated_3 §3.2 doesn't require a branch
  // assignment), so there's nothing left to separately refresh here.
  Future<void> _refreshUnassignedSalonMembers() async {}

  // Pull-to-refresh reloads everything on screen — the salon/branch list
  // and the current tab's data — not just the member list. The loading
  // overlay stays up for the whole thing, covering both API calls.
  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _isLoadingTeamMembers = true);
    try {
      final branchFuture = _getBranchOptions();
      setState(() {
        branchOptionsFuture = branchFuture;
      });
      await branchFuture;
      // selectedBranchId == null now also means "All Branches" is
      // deliberately selected (see _pickBranch) — bailing out on that
      // would make pull-to-refresh silently do nothing in that mode.
      // selectedBranch itself is only null before any selection exists.
      if (selectedBranch == null) return;
      await _refreshCurrentTeamTab();
    } finally {
      if (mounted) setState(() => _isLoadingTeamMembers = false);
    }
  }

  void _reloadTeamMembersForFilters({bool showOverlay = true}) {
    if (_currentSalonId == null || !mounted) return;
    unawaited(_refreshCurrentTeamTab(resetPage: true));
  }

  void _onTeamSearchChanged() {
    _teamSearchDebounce?.cancel();
    _teamSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _reloadTeamMembersForFilters(showOverlay: false),
    );
  }

  void _setStatusFilter(String value) {
    final nextValue =
        _teamStatusFilter == value && value != 'all' ? 'all' : value;
    if (_teamStatusFilter == nextValue) return;
    setState(() => _teamStatusFilter = nextValue);
    _reloadTeamMembersForFilters();
  }

  void _setOnlineBookingFilter(bool? value) {
    final nextValue =
        _allowOnlineBookingFilter == value && value != null ? null : value;
    if (_allowOnlineBookingFilter == nextValue) return;
    setState(() => _allowOnlineBookingFilter = nextValue);
    _reloadTeamMembersForFilters();
  }

  Future<void> _setTeamDateFilter(DateTime picked) async {
    if (_teamDateFilter != null &&
        _teamDateFilter!.year == picked.year &&
        _teamDateFilter!.month == picked.month &&
        _teamDateFilter!.day == picked.day) {
      return;
    }
    setState(() => _teamDateFilter = picked);
    _reloadTeamMembersForFilters();
  }

  void _clearTeamDateFilter() {
    if (_teamDateFilter == null) return;
    setState(() => _teamDateFilter = null);
    _reloadTeamMembersForFilters();
  }

  bool get _hasActiveTeamFilters =>
      _teamStatusFilter != 'all' ||
      _allowOnlineBookingFilter != null ||
      _teamDateFilter != null ||
      _selectedTeamServiceIds.isNotEmpty ||
      _teamSearchController.text.trim().isNotEmpty;

  void _clearTeamFilters() {
    _teamSearchDebounce?.cancel();
    setState(() {
      _teamStatusFilter = 'all';
      _allowOnlineBookingFilter = null;
      _teamDateFilter = null;
      _selectedTeamServiceIds.clear();
      _showAllTeamServices = false;
      _teamSearchController.clear();
    });
    _reloadTeamMembersForFilters();
  }

  Future<void> _showTeamFiltersSheet() async {
    if (selectedBranchId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return _TeamFiltersSheet(
          statusFilter: _teamStatusFilter,
          allowOnlineBookingFilter: _allowOnlineBookingFilter,
          dateFilter: _teamDateFilter,
          serviceOptions: _teamServiceOptions,
          selectedServiceIds: _selectedTeamServiceIds,
          isLoadingServices: _isLoadingTeamServices,
          showAllServices: _showAllTeamServices,
          onStatusChanged: _setStatusFilter,
          onOnlineBookingChanged: _setOnlineBookingFilter,
          onPickDate: _setTeamDateFilter,
          onClearDate: _clearTeamDateFilter,
          onServiceToggled: _toggleTeamServiceFilter,
          onClearServices: _clearTeamServiceFilters,
          onToggleShowAllServices: _toggleShowAllTeamServices,
          onClearAll: _clearTeamFilters,
        );
      },
    );
  }

  void _toggleTeamServiceFilter(int serviceId) {
    setState(() {
      if (_selectedTeamServiceIds.contains(serviceId)) {
        _selectedTeamServiceIds.remove(serviceId);
      } else {
        _selectedTeamServiceIds.add(serviceId);
      }
    });
    _reloadTeamMembersForFilters();
  }

  void _clearTeamServiceFilters() {
    if (_selectedTeamServiceIds.isEmpty) return;
    setState(_selectedTeamServiceIds.clear);
    _reloadTeamMembersForFilters();
  }

  Future<void> _loadTeamServiceOptions(int branchId) async {
    setState(() {
      _isLoadingTeamServices = true;
      _teamServiceOptions = const <_TeamServiceFilterOption>[];
      _selectedTeamServiceIds.clear();
      _showAllTeamServices = false;
    });

    try {
      final response = await ApiService().getBranchService(branchId: branchId);
      final categories = response['data'] is Map
          ? (response['data'] as Map)['categories']
          : null;
      final options = _serviceOptionsFromCategories(categories);

      if (!mounted || selectedBranchId != branchId) return;
      setState(() {
        _teamServiceOptions = options;
        _isLoadingTeamServices = false;
      });
    } catch (error) {
      debugPrint('Failed to load team service filters: $error');
      if (!mounted || selectedBranchId != branchId) return;
      setState(() => _isLoadingTeamServices = false);
    }
  }

  void _toggleShowAllTeamServices() {
    setState(() => _showAllTeamServices = !_showAllTeamServices);
  }

  List<_TeamServiceFilterOption> _serviceOptionsFromCategories(
    dynamic categories,
  ) {
    if (categories is! List) return const <_TeamServiceFilterOption>[];
    final options = <_TeamServiceFilterOption>[];
    final seen = <int>{};

    void addService(dynamic rawService) {
      if (rawService is! Map) return;
      final service = Map<String, dynamic>.from(rawService);
      final serviceId = _asInt(service['id']);
      if (serviceId == null || seen.contains(serviceId)) return;
      final name = (service['displayName'] ??
              service['name'] ??
              service['serviceName'] ??
              "${translateText('Service')} #$serviceId")
          .toString()
          .trim();
      options.add(
        _TeamServiceFilterOption(
          id: serviceId,
          name: name.isEmpty ? "${translateText('Service')} #$serviceId" : name,
        ),
      );
      seen.add(serviceId);
    }

    for (final rawCategory in categories) {
      if (rawCategory is! Map) continue;
      final category = Map<String, dynamic>.from(rawCategory);
      final services = category['services'];
      if (services is List) {
        for (final service in services) {
          addService(service);
        }
      }
      final subCategories = category['subCategories'];
      if (subCategories is! List) continue;
      for (final rawSubCategory in subCategories) {
        if (rawSubCategory is! Map) continue;
        final subCategory = Map<String, dynamic>.from(rawSubCategory);
        final subServices = subCategory['services'];
        if (subServices is List) {
          for (final service in subServices) {
            addService(service);
          }
        }
      }
    }

    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }

  Future<Map<int, _TeamRatingSummary>> _loadProfessionalRatings(
    int branchId,
  ) async {
    try {
      final data = await ApiService.fetchBranchRatings(branchId);
      final appointments = data['data']?['appointments'];
      if (data['success'] != true || appointments is! List) {
        return const {};
      }

      final buckets = <int, List<num>>{};
      for (final appointment in appointments) {
        if (appointment is! Map) continue;
        final reviews = appointment['professionalReviews'];
        if (reviews is! List) continue;

        for (final review in reviews) {
          if (review is! Map) continue;
          final rating = review['rating'];
          if (rating is! num) continue;

          final professional = review['professional'];
          final professionalMap = professional is Map
              ? Map<String, dynamic>.from(professional)
              : const <String, dynamic>{};
          final professionalId = _asInt(review['professionalId']) ??
              _asInt(review['professionalUserId']) ??
              _asInt(professionalMap['id']) ??
              _asInt(professionalMap['userId']);
          if (professionalId == null) continue;

          buckets.putIfAbsent(professionalId, () => <num>[]).add(rating);
        }
      }

      return buckets.map((professionalId, ratings) {
        final total = ratings.fold<num>(0, (sum, rating) => sum + rating);
        return MapEntry(
          professionalId,
          _TeamRatingSummary(
            average: ratings.isEmpty ? 0 : total / ratings.length,
            count: ratings.length,
          ),
        );
      });
    } catch (e) {
      debugPrint('Failed to load professional ratings: $e');
      return const {};
    }
  }

  // Future<void> _toggleMemberActive(int userId, bool makeActive) async {
  //   final branchId = selectedBranchId;
  //   if (branchId == null) return;
  //   setState(() => _statusUpdatingIds.add(userId));
  //   try {
  //     await ApiService().setTeamMemberActive(
  //       branchId: branchId,
  //       userId: userId,
  //       active: makeActive,
  //     );
  //     await _refreshTeamMembers();
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _statusUpdatingIds.remove(userId));
  //     }
  //   }
  // }
  Future<void> _toggleMemberActive(int userId, bool makeActive) async {
    // Only forward a branch id when the user has explicitly selected one.
    final branchId = selectedBranchId;

    if (branchId == null) {
      Fluttertoast.showToast(
          msg: translateText('Please select a branch first'));
      return;
    }

    setState(() => _statusUpdatingIds.add(userId));

    try {
      final response = await ApiService().setTeamMemberActive(
        branchId: branchId,
        userId: userId,
        active: makeActive,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Fluttertoast.showToast(
            msg: translateText(
          makeActive
              ? 'Team member activated successfully'
              : 'Team member deactivated successfully',
        ));
        await _refreshTeamMembers();
      } else {
        Fluttertoast.showToast(
            msg: response['message']?.toString() ??
                translateText(
                  makeActive
                      ? 'Failed to activate team member'
                      : 'Failed to deactivate team member',
                ));
      }
    } catch (e) {
      if (!mounted) return;

      Fluttertoast.showToast(
          msg: e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) {
        setState(() {
          _statusUpdatingIds.remove(userId);
        });
      }
    }
  }
  // Future<void> _deleteMember(int userId) async {
  //   final branchId = selectedBranchId;
  //   if (branchId == null) return;
  //   final shouldDelete = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(translateText('Delete Team Member')),
  //       content: Text(
  //         translateText('Are you sure you want to delete this team member?'),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: Text(translateText('Cancel')),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: Text(
  //             translateText('Delete'),
  //             style: const TextStyle(color: Colors.red),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (shouldDelete != true) return;

  //   setState(() => _deletingMemberIds.add(userId));
  //   try {
  //     await ApiService().deleteTeamMember(
  //       branchId: branchId,
  //       userId: userId,
  //     );
  //     await _refreshTeamMembers();
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _deletingMemberIds.remove(userId));
  //     }
  //   }
  // }
  // Future<void> _deleteMember(int userId) async {
  //   final branchId = selectedBranchId;

  //   if (branchId == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(translateText('Please select a branch first'))),
  //     );
  //     return;
  //   }

  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //       ),
  //       title: Text(translateText('Delete Team Member')),
  //       content: Text(
  //         translateText(
  //           'Are you sure you want to delete this team member? This action cannot be undone.',
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: Text(translateText('Cancel')),
  //         ),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: AppColors.starColor,
  //           ),
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: Text(
  //             translateText('Delete'),
  //             style: const TextStyle(color: Colors.white),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed != true) return;

  //   setState(() => _deletingMemberIds.add(userId));

  //   try {
  //     await ApiService().deleteTeamMember(
  //       branchId: branchId,
  //       userId: userId,
  //     );

  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(translateText('Team member deleted successfully')),
  //       ),
  //     );

  //     await _refreshTeamMembers();
  //   } catch (e) {
  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _deletingMemberIds.remove(userId));
  //     }
  //   }
  // }
  Future<void> _deleteMember(int userId) async {
    final branchId = selectedBranchId;

    if (branchId == null) {
      Fluttertoast.showToast(
          msg: translateText('Please select a branch first'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(translateText('Delete Team Member')),
        content: Text(
          translateText(
            'Are you sure you want to delete this team member? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(translateText('Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              translateText('Delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingMemberIds.add(userId));

    try {
      final response = await ApiService().deleteTeamMember(
        branchId: branchId,
        userId: userId,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Fluttertoast.showToast(
            msg: translateText('Team member deleted successfully'));

        await _refreshTeamMembers();
      } else {
        Fluttertoast.showToast(
            msg: response['message']?.toString() ??
                translateText('Failed to delete team member'));
      }
    } catch (e) {
      if (!mounted) return;

      Fluttertoast.showToast(
          msg: e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) {
        setState(() => _deletingMemberIds.remove(userId));
      }
    }
  }
  // void _pickBranch(Map<String, dynamic> branchOpt) {
  //   selectedBranch = branchOpt;
  //   selectedBranchId = _asInt(branchOpt['branchId']);
  //   if (selectedBranchId != null) {
  //     teamMembersFuture =
  //         _getTeamMembersByBranch(selectedBranchId!); // ✅ always by branchId
  //   } else {
  //     teamMembersFuture = null;
  //   }
  // }

  void _pickBranch(Map<String, dynamic> branchOpt) {
    selectedBranch = branchOpt;
    selectedBranchId = _asInt(branchOpt['branchId']);
    _hasTeamMembers = false;
    _teamServiceOptions = const <_TeamServiceFilterOption>[];
    _selectedTeamServiceIds.clear();
    _teamMembersPage = 0;

    final salonId = _asInt(branchOpt['salonId']);
    final branchId = _asInt(branchOpt['branchId']);
    final salonName = (branchOpt['salonName'] ?? '').toString().trim();
    final branchName = (branchOpt['branchName'] ?? '').toString().trim();
    if (salonId != null && branchId != null) {
      _suppressBranchSelectionRefresh = true;
      unawaited(
        StylistBranchSelectionStore.save(
          salonId: salonId,
          branchId: branchId,
          salonName: salonName.isEmpty ? 'Salon' : salonName,
          branchName: branchName.isEmpty
              ? (salonName.isEmpty ? 'Branch' : salonName)
              : branchName,
        ).whenComplete(() {
          if (mounted) {
            _suppressBranchSelectionRefresh = false;
          }
        }),
      );
    } else if (salonId != null && branchId == null) {
      _suppressBranchSelectionRefresh = true;
      unawaited(
        StylistBranchSelectionStore.save(
          salonId: salonId,
          branchId: null,
          salonName: salonName.isEmpty ? 'Salon' : salonName,
          branchName: branchName,
        ).whenComplete(() {
          if (mounted) {
            _suppressBranchSelectionRefresh = false;
          }
        }),
      );
    }

    // Picking a branch also re-syncs which salon's Invited list is shown,
    // since that's the natural default — but it stays independently
    // switchable afterwards via the Invited tab's own salon selector.
    if (salonId != null) {
      _invitedSalonId = salonId;
      unawaited(_refreshCurrentTeamTab(resetPage: true));
    }
  }

  // Resets "Filter by Branch" back to the salon-wide All Branches state
  // for the currently selected salon.
  void _clearBranchFilter() {
    final salonId = _currentSalonId;
    if (salonId == null) return;
    _pickBranch(
      _teamAllBranchesSelectionForSalon(
        salonId: salonId,
        salonName: selectedBranch?['salonName']?.toString() ?? '',
      ),
    );
  }

  // Switching tabs used to just flip _selectedTeamTab with no refetch, so
  // a member who accepted their invitation elsewhere (e.g. via the email
  // link on web) while this screen sat open wouldn't show up under Team
  // members until a manual pull-to-refresh or a full app restart. Refetch
  // in the background on every tab switch so the tab you land on is never
  // showing data from before that acceptance happened.
  void _onTeamTabSelected(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedTeamTab = index;
      _teamMembersPage = 0;
    });
    unawaited(_refreshCurrentTeamTab());
  }

  /// Unique salons (deduped by id) this owner manages, for the Invited
  /// tab's salon selector — distinct from the branch dropdown, since
  /// invitations don't belong to a branch.
  List<OwnerBranchHeaderSelectorOption<int>> _invitedSalonOptions() {
    final seen = <int>{};
    final options = <OwnerBranchHeaderSelectorOption<int>>[];
    for (final salon in _salons) {
      final id = _asInt(salon['id']);
      if (id == null || !seen.add(id)) continue;
      options.add(
        OwnerBranchHeaderSelectorOption<int>(
          value: id,
          label: (salon['name'] ?? '').toString().trim(),
          subtitle: _salonAddressSummary(salon),
        ),
      );
    }
    return options;
  }

  // The owner-facing salon-list API doesn't return a salon-level address —
  // only each branch under it has one (see _getBranchOptions above, which
  // only ever reads b['address']). So a salon-level 'address' key is
  // usually absent; fall back to the first branch's address in that case.
  String _salonAddressSummary(Map<String, dynamic> salon) {
    final direct = formatAddressSummary(salon['address']);
    if (direct.isNotEmpty) return direct;

    final branches =
        (salon['branches'] as List? ?? const []).whereType<Map>().toList();
    if (branches.isEmpty) return '';
    return formatAddressSummary(branches.first['address']);
  }

  void _onInvitedSalonSelected(int salonId, String salonName) {
    if (_invitedSalonId == salonId) return;
    setState(() {
      _invitedSalonId = salonId;
      _invitationsV2 = const [];
      _teamMembersPage = 0;
    });
    unawaited(_fetchInvitationsV2());
    unawaited(_fetchTeamSummary());
  }

  // Thin wrapper kept for existing call sites (e.g. after sending an
  // invite, and after cancel-invitation success) — delegates to the new
  // salon_team_part_1_updated_3.md invitations endpoint instead of the
  // legacy salons/:id/team-invitations route.
  //
  // _invitedSalonId is only ever set once the user explicitly picks a
  // salon from the Invited tab's own "Filter by Salon" dropdown — which
  // for a single-salon owner never happens at all (that filter pill is
  // hidden when there's only one option). The old `if (_invitedSalonId ==
  // null) return;` guard here silently no-op'd this refresh for exactly
  // that majority case, so a freshly sent invite (or a freshly cancelled
  // one) never showed up until some other action happened to trigger a
  // fetch. _fetchInvitationsV2() already falls back to _currentSalonId on
  // its own, so there's nothing to guard.
  Future<void> _refreshPendingInvitations() async {
    await _fetchInvitationsV2();
    await _fetchTeamSummary();
  }

  Future<void> _cancelPendingInvitation(Map<String, dynamic> invitation) async {
    final salonId = _currentSalonId;
    final invitationId = _asInt(invitation['invitationId']);
    if (salonId == null || invitationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(translateText('Cancel invitation')),
        content: Text(
          translateText(
            'Cancel the invitation sent to {name}?',
            params: {'name': _invitationDisplayName(invitation)},
          ),
        ),
        actions: [
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: _invitationSectionGold),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(translateText('No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              translateText('Yes, cancel'),
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancellingInvitationIds.add(invitationId));
    try {
      final response =
          await ApiService().cancelSalonTeamInvitation(salonId, invitationId);
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Invitation cancelled'));
        await _refreshPendingInvitations();
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(
            response,
            fallback: 'Unable to cancel this invitation',
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(
          e,
          fallback: 'Unable to cancel this invitation',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancellingInvitationIds.remove(invitationId));
      }
    }
  }

  String _invitationDisplayName(Map<String, dynamic> invitation) {
    final firstName = (invitation['firstName'] ?? '').toString().trim();
    final lastName = (invitation['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    return translateText('this invitee');
  }

  bool _memberHasAssignments(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    return rawAssignments is List && rawAssignments.isNotEmpty;
  }

  Map<String, dynamic>? _teamPrimaryAssignment(Map<String, dynamic> member) {
    final branches = member['userBranches'];
    if (branches is! List || branches.isEmpty) return null;
    for (final raw in branches) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  // "Setup Required" (matches the owner web dashboard's status column):
  // no branch yet, or missing what the assign-to-branch step is meant to
  // collect (role, experience, services) once it's been assigned.
  bool _teamNeedsSetup(Map<String, dynamic> member) {
    if (!_memberHasAssignments(member)) return true;
    final assignment = _teamPrimaryAssignment(member);
    final roles = member['roles'] ?? assignment?['roles'];
    final hasRoles = roles is List && roles.isNotEmpty;
    final experienceText =
        (assignment?['experience'] ?? member['experience'] ?? '')
            .toString()
            .trim();
    final services = assignment?['userBranchServices'] ??
        assignment?['branchServiceIds'] ??
        member['userBranchServices'] ??
        member['branchServiceIds'];
    final hasServices = services is List && services.isNotEmpty;
    return !hasRoles || experienceText.isEmpty || !hasServices;
  }

  bool _teamAllowsOnlineBooking(Map<String, dynamic> member) {
    final assignment = _teamPrimaryAssignment(member);
    final value = _teamReadBool(assignment?['allowOnlineBooking']) ??
        _teamReadBool(member['allowOnlineBooking']);
    return value ?? false;
  }

  Widget _buildAssignButtonChild(Map<String, dynamic> member) {
    if (!_memberHasAssignments(member)) {
      return Text(translateText("Assign"));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          translateText("Assign to branch"),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        // if (assignedSalonLabel.isNotEmpty) ...[
        //   const SizedBox(height: 2),
        //   Text(
        //     assignedSalonLabel,
        //     textAlign: TextAlign.center,
        //     maxLines: 2,
        //     overflow: TextOverflow.ellipsis,
        //     style: const TextStyle(fontSize: 9.5, height: 1.15),
        //   ),
        // ],
      ],
    );
  }

  Future<void> _openAddMember() async {
    if (selectedBranch != null) {
      final limitMessage = await _staffLimitBlockMessage();
      if (!mounted) return;
      if (limitMessage != null) {
        Fluttertoast.showToast(msg: translateText(limitMessage));
        return;
      }

      FocusScope.of(context).unfocus();
      final salonId = _teamAsInt(selectedBranch!['salonId']);
      if (salonId == null) return;
      final refresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InviteTeamMemberScreen(
            salonId: salonId,
            salonName: selectedBranch!['salonName']?.toString(),
          ),
        ),
      );
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (refresh == true) {
        await _refreshPendingInvitations();
        await _refreshUnassignedSalonMembers();
      }
    } else {
      Fluttertoast.showToast(
          msg: translateText("Please select a branch first."));
    }
  }

  Future<String?> _staffLimitBlockMessage() async {
    final salonId = _teamAsInt(selectedBranch?['salonId']);
    if (salonId == null) return null;

    try {
      final response = await ApiService().getSalonSubscription(salonId);
      final data = response['data'];
      final root = data is Map ? Map<String, dynamic>.from(data) : null;
      if (response['success'] != true || root == null) return null;

      final staffUsage = root['staffUsage'];
      if (staffUsage is! Map) return null;
      final overLimit = _teamReadBool(staffUsage['overLimit']) ?? false;
      if (!overLimit) return null;

      final usageMessage = _teamFirstText(
        staffUsage,
        const ['message', 'limitMessage', 'staffLimitMessage'],
      );
      if (usageMessage.isNotEmpty) return usageMessage;

      final subscriptionMessage = _teamFirstText(
        root,
        const ['staffLimitMessage', 'limitMessage', 'membershipMessage'],
      );
      if (subscriptionMessage.isNotEmpty) return subscriptionMessage;

      return 'Staff limit reached. Please upgrade your membership to add more team members.';
    } catch (error) {
      debugPrint('Failed to check staff subscription limit: $error');
      return null;
    }
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final firstName = (member['firstName'] ?? '').toString().trim();
    final lastName = (member['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    return translateText('Team Member');
  }

  String _memberRoleLabel(Map<String, dynamic> member) {
    final roles = member['roles'];
    if (roles is List && roles.isNotEmpty) {
      final labels = <String>[];
      for (final role in roles) {
        if (role is! Map) continue;
        final label = (role['label'] ?? role['name'] ?? role['code'] ?? '')
            .toString()
            .trim();
        if (label.isNotEmpty && !labels.contains(label)) {
          labels.add(label);
        }
      }
      if (labels.isNotEmpty) return labels.join(', ');
    }
    return translateText('Not Assigned');
  }

  List<String> _memberRoleList(Map<String, dynamic> member) {
    final roles = member['roles'] ?? _teamPrimaryAssignment(member)?['roles'];
    final labels = <String>[];
    if (roles is List) {
      for (final role in roles) {
        final label = role is Map
            ? (role['label'] ?? role['name'] ?? role['code'] ?? '')
                .toString()
                .trim()
            : role.toString().trim();
        if (label.isNotEmpty && !labels.contains(label)) {
          labels.add(label);
        }
      }
    }
    return labels;
  }

  List<String> _memberBranchList(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    if (rawAssignments is! List || rawAssignments.isEmpty) return const [];
    final labels = <String>[];
    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final branchName = branch is Map
          ? (branch['name'] ?? branch['branchName'] ?? '')
          : assignment['branchName'];
      final text = (branchName ?? '').toString().trim();
      if (text.isNotEmpty && !labels.contains(text)) {
        labels.add(text);
      }
    }
    return labels;
  }

  // salon_team_part_2.md: profile completion is a dedicated fill-missing-
  // only flow against the new PATCH endpoints, not AddTeamScreen's edit
  // mode (which only ever wrote branch-scoped assignment fields anyway).
  Future<void> _openEditMember(Map<String, dynamic> member) async {
    final salonId = _currentSalonId ?? _asInt(member['salonId']);
    final userId = _teamAsInt(member['userId']);
    if (salonId == null || userId == null) return;
    FocusScope.of(context).unfocus();
    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kCompleteProfileRootRouteName),
        builder: (_) => CompleteTeamMemberProfileScreen(
          salonId: salonId,
          userId: userId,
          branchId: selectedBranchId,
          initialMember: Map<String, dynamic>.from(member),
        ),
      ),
    );
    // Popping back to this route can restore whatever had focus before
    // the push — the search field, in which case the keyboard reopens on
    // its own. Unfocus again now that we're actually back.
    FocusManager.instance.primaryFocus?.unfocus();
    if (refresh == true) {
      await _refreshCurrentTeamTab();
    }
  }

  Future<void> _openAssignMember(Map<String, dynamic> member) async {
    if (selectedBranch == null || _salons.isEmpty) return;
    FocusScope.of(context).unfocus();
    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: kAssignUserRootRouteName),
        builder: (_) => AssignUserScreen(
          member: Map<String, dynamic>.from(member),
          salons: _salons,
          salonId: selectedBranch!['salonId'],
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (assigned == true) {
      await _refreshTeamMembers();
      await _refreshUnassignedSalonMembers();
    }
  }

  // salon_team_part_1_updated_3.md §6.5: GET .../team/{userId} returns
  // TeamMemberDetailResponse = { profile, roles, branches, services } —
  // flatten `profile` up to the top level (plus roles/branches/services)
  // so the rest of TeamMemberDetails.dart can keep treating this as one
  // member map. salonId, not branchId, is now what the lookup needs — a
  // member with no branch assignment (e.g. an owner) can still be viewed.
  Future<void> _openViewMember(Map<String, dynamic> member) async {
    if (_openingViewMemberId != null) return;

    final userId = _teamAsInt(member['userId']) ?? 0;
    if (userId == 0) return;

    final salonId = _currentSalonId ?? _asInt(member['salonId']);
    if (salonId == null) return;

    final branchId = selectedBranchId;

    if (mounted) {
      setState(() => _openingViewMemberId = userId);
    }

    final ratingSummary =
        _professionalRatings[userId] ?? _TeamRatingSummary.empty;
    Map<String, dynamic> detailMember = Map<String, dynamic>.from(member);

    try {
      final response =
          await ApiService().getTeamMemberDetailV2(salonId, userId);
      final data = response['data'];
      if (response['success'] == true && data is Map) {
        detailMember = _teamMergeMemberMaps(
          detailMember,
          _teamMemberPayloadFromDetail(response),
        );
      } else {
        debugPrint(
          'Team member detail unavailable, using list payload: ${response['message'] ?? response['error'] ?? response}',
        );
      }
    } catch (error) {
      debugPrint('Failed to load team member details: $error');
    }

    if (branchId != null) {
      try {
        final branchResponse = await ApiService.getTeamMemberDetails(
          branchId,
          userId,
        );
        detailMember = _teamMergeMemberMaps(
          detailMember,
          _teamMemberPayloadFromDetail(branchResponse),
        );
      } catch (error) {
        debugPrint('Failed to load branch team member details: $error');
      }
    }

    try {
      if (!mounted) return;

      FocusScope.of(context).unfocus();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamMemberDetails(
            member: detailMember,
            salons: _salons,
            professionalRating: ratingSummary.average.toDouble(),
            professionalReviewCount: ratingSummary.count,
            branchId: branchId,
            salonId: salonId,
          ),
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
    } finally {
      if (mounted) {
        setState(() => _openingViewMemberId = null);
      }
    }
  }

  dynamic _teamFirstAssignmentBranchId(dynamic rawAssignments) {
    if (rawAssignments is! List) return null;
    for (final item in rawAssignments) {
      if (item is! Map) continue;
      final assignment = Map<String, dynamic>.from(item);
      final branch = assignment['branch'];
      if (branch is Map && branch['id'] != null) {
        return branch['id'];
      }
      if (assignment['branchId'] != null) {
        return assignment['branchId'];
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _teamBranchesForSalon(
    List<Map<String, dynamic>> branches,
    int? salonId,
  ) {
    if (salonId == null) return const [];
    return branches
        .where((branch) => _asInt(branch['salonId']) == salonId)
        .toList();
  }

  // One "All Branches" entry for the active salon (sentinel value
  // -salonId), ahead of that salon's individual branches. Selecting it
  // clears selectedBranchId to null so the V2 reads stay salon-wide.
  List<OwnerBranchHeaderSelectorOption<int>> _teamBranchOptions(
    List<Map<String, dynamic>> branches,
  ) {
    final options = <OwnerBranchHeaderSelectorOption<int>>[];
    final seenSalonIds = <int>{};
    for (final branch in branches) {
      final salonId = _asInt(branch['salonId']);
      if (salonId != null && seenSalonIds.add(salonId)) {
        options.add(
          OwnerBranchHeaderSelectorOption<int>(
            value: -salonId,
            label: translateText('All Branches'),
          ),
        );
      }
      final branchId = _asInt(branch['branchId']);
      if (branchId == null) continue;
      options.add(
        OwnerBranchHeaderSelectorOption<int>(
          value: branchId,
          label: _teamBranchLabel(branch),
          subtitle: (branch['addressSummary'] ?? '').toString(),
        ),
      );
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _teamSurface,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Team Members'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: branchOptionsFuture,
              builder: (context, snapshot) {
                final isBranchesWaiting =
                    snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.connectionState == ConnectionState.none;
                final branchesSoFar =
                    snapshot.data ?? const <Map<String, dynamic>>[];

                // Only fall back to the full-page loader on the very first
                // load, OR when switching to a genuinely different
                // salon/branch (_isLoadingTeamMembers && !_hasTeamMembers,
                // set synchronously the moment that switch is detected). A
                // plain pull-to-refresh of the SAME branch reassigns
                // branchOptionsFuture too, but FutureBuilder keeps the
                // previous data while it's waiting and neither flag gets
                // reset — reuse it so the list (and its RefreshIndicator)
                // stays on screen instead of being torn down mid-refresh.
                if ((isBranchesWaiting && branchesSoFar.isEmpty) ||
                    (_isLoadingTeamMembers && !_hasTeamMembers)) {
                  return AppLoader.page();
                } else if (snapshot.hasError && branchesSoFar.isEmpty) {
                  return Center(
                    child: Text(
                      '${translateText('Error')}: ${snapshot.error}',
                    ),
                  );
                } else if (branchesSoFar.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OwnerBranchHeaderSelector<int>(
                        label: '',
                        options: const [],
                        selectedValue: null,
                        placeholder: translateText('Select Branch'),
                        isInteractive: false,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _NoTeamMembersState(
                          onAddTeamMember: null,
                          message: translateText('No branches available'),
                        ),
                      ),
                    ],
                  );
                } else {
                  final branches = branchesSoFar;

                  return RefreshIndicator(
                    color: AppColors.starColor,
                    onRefresh: () => RefreshFeedback.playAndDetach(_refreshAll),
                    child: Builder(
                      builder: (context) {
                        // salon_team_part_1_updated_3.md: the server tells
                        // us directly which tab a member belongs to (via
                        // status=active|setup_required on the request) and
                        // gives exact stat counts — no more client-side
                        // Active/Setup-Required classification, and no more
                        // separate "unassigned salon members" merge (every
                        // salon member shows up in one of these two lists
                        // regardless of branch assignment).
                        final isCurrentTabInvited = _selectedTeamTab == 2;
                        final isLoadingCurrentTab = isCurrentTabInvited
                            ? _isLoadingInvitationsV2
                            : _isLoadingTabMembers;

                        // True first-ever load: keep showing the exact same
                        // loader, in the exact same spot, as the branch-list
                        // phase above — don't reveal the dropdown/toolbar
                        // until there's something to show underneath them.
                        if (isLoadingCurrentTab &&
                            _tabMembers.isEmpty &&
                            _invitationsV2.isEmpty &&
                            !_hasTeamMembers) {
                          return AppLoader.page();
                        }

                        final salonOptions = _invitedSalonOptions();
                        final currentSalonId = _currentSalonId;
                        final currentSalonLabel =
                            (selectedBranch?['salonName'] ??
                                    salonOptions
                                        .firstWhere(
                                          (option) =>
                                              option.value == currentSalonId,
                                          orElse: () => salonOptions.first,
                                        )
                                        .label)
                                .toString()
                                .trim();
                        final salonSelector = salonOptions.isEmpty
                            ? null
                            : OwnerBranchHeaderSelector<int>(
                                label: currentSalonLabel.isEmpty
                                    ? translateText('Select Salon')
                                    : currentSalonLabel,
                                options: salonOptions
                                    .map(
                                      (option) =>
                                          OwnerBranchHeaderSelectorOption<int>(
                                        value: option.value,
                                        label: option.label,
                                        subtitle: option.subtitle,
                                      ),
                                    )
                                    .toList(),
                                selectedValue: currentSalonId,
                                placeholder: translateText('Select Salon'),
                                isInteractive: true,
                                onSelected: (salonId) {
                                  final option = salonOptions.firstWhere(
                                    (item) => item.value == salonId,
                                    orElse: () => salonOptions.first,
                                  );
                                  setState(
                                    () => _pickBranch(
                                      _teamAllBranchesSelectionForSalon(
                                        salonId: option.value,
                                        salonName: option.label,
                                      ),
                                    ),
                                  );
                                },
                              );

                        final children = <Widget>[
                          if (salonSelector != null) salonSelector,
                          if (salonSelector != null) const SizedBox(height: 16),
                          // Search and Invite sit in the same row at the
                          // very top, matching the web dashboard, instead
                          // of a search field buried lower in a
                          // conditional filters bar and Invite as a
                          // separate floating action button.
                          _TeamSearchAndInviteRow(
                            searchController: _teamSearchController,
                            hasActiveFilters: _hasActiveTeamFilters,
                            onOpenFilters: _showTeamFiltersSheet,
                            onInvite: _openAddMember,
                          ),
                          const SizedBox(height: 16),
                          _TeamStatCardsRow(
                            activeCount: _teamActiveCount,
                            setupRequiredCount: _teamSetupRequiredCount,
                            invitedCount: _teamInvitedCount,
                          ),
                          const SizedBox(height: 16),
                          _TeamSectionTabs(
                            selectedIndex: _selectedTeamTab,
                            activeCount: _teamActiveCount,
                            setupRequiredCount: _teamSetupRequiredCount,
                            invitedCount: _teamInvitedCount,
                            onSelected: _onTeamTabSelected,
                          ),
                          const SizedBox(height: 16),
                        ];

                        final currentSalonBranches =
                            _teamBranchesForSalon(branches, currentSalonId);
                        final branchFilterPill = isCurrentTabInvited ||
                                currentSalonBranches.isEmpty
                            ? null
                            : _TeamCompactDropdown<int?>(
                                icon: Icons.storefront_outlined,
                                prefixLabel: translateText('Filter by Branch'),
                                valueLabel: selectedBranchId == null
                                    ? translateText('All Branches')
                                    : _teamBranchLabel(selectedBranch),
                                selectedValue: selectedBranchId ??
                                    (_currentSalonId == null
                                        ? null
                                        : -_currentSalonId!),
                                options:
                                    _teamBranchOptions(currentSalonBranches)
                                        .map((o) => MapEntry<int?, String>(
                                              o.value,
                                              o.label,
                                            ))
                                        .toList(),
                                onSelected: (branchId) {
                                  if (branchId != null && branchId < 0) {
                                    final salonId = -branchId;
                                    final match =
                                        currentSalonBranches.firstWhere(
                                      (item) =>
                                          _asInt(item['salonId']) == salonId,
                                      orElse: () => currentSalonBranches.first,
                                    );
                                    setState(() => _pickBranch({
                                          'salonId': salonId,
                                          'salonName': match['salonName'],
                                          'branchId': null,
                                          'branchName': null,
                                        }));
                                    return;
                                  }
                                  final branch =
                                      currentSalonBranches.firstWhere(
                                    (item) =>
                                        _asInt(item['branchId']) == branchId,
                                    orElse: () => currentSalonBranches.first,
                                  );
                                  setState(() => _pickBranch(branch));
                                },
                              );

                        final toolbarRow = _TeamToolbarRow(
                          filterPill: branchFilterPill,
                          sortOrder: _teamSortOrder,
                          onSortChanged: (value) {
                            setState(() {
                              _teamSortOrder = value;
                              _teamMembersPage = 0;
                            });
                            unawaited(_refreshCurrentTeamTab());
                          },
                        );

                        void goToPage(int page) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _teamMembersPage = page);
                          unawaited(
                            isCurrentTabInvited
                                ? _fetchInvitationsV2()
                                : _fetchTabMembers(),
                          );
                        }

                        if (isCurrentTabInvited) {
                          if (isLoadingCurrentTab && _invitationsV2.isEmpty) {
                            children.add(
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.72,
                                child: AppLoader.page(),
                              ),
                            );
                          } else if (_invitationsV2.isEmpty) {
                            children.add(
                              _NoTeamMembersState(
                                onAddTeamMember: selectedBranch == null
                                    ? null
                                    : _openAddMember,
                                message:
                                    _teamSearchController.text.trim().isNotEmpty
                                        ? translateText(
                                            'No team members match the selected filters',
                                          )
                                        : null,
                              ),
                            );
                          } else {
                            children.add(toolbarRow);
                            children.add(const SizedBox(height: 16));
                            children.add(
                              _InvitedTab(
                                pendingInvitations: _invitationsV2,
                                isLoading: false,
                                cancellingInvitationIds:
                                    _cancellingInvitationIds,
                                onCancelInvitation: _cancelPendingInvitation,
                              ),
                            );
                            if (_invitationsV2TotalPages > 1) {
                              children.add(const SizedBox(height: 16));
                              children.add(
                                _TeamPaginationFooter(
                                  rangeStart:
                                      _teamMembersPage * _teamMembersPageSize +
                                          1,
                                  rangeEnd:
                                      _teamMembersPage * _teamMembersPageSize +
                                          _invitationsV2.length,
                                  total: _invitationsV2Total,
                                  page: _teamMembersPage,
                                  pageCount: _invitationsV2TotalPages,
                                  onPageSelected: goToPage,
                                ),
                              );
                            }
                          }
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              ...children,
                              const SizedBox(height: 96),
                            ],
                          );
                        }

                        if (isLoadingCurrentTab && _tabMembers.isEmpty) {
                          // Still fetching and nothing to show yet — never
                          // fall through to the empty-state illustration
                          // just because data hasn't arrived.
                          children.add(
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.72,
                              child: AppLoader.page(),
                            ),
                          );
                        } else if (_tabMembers.isEmpty) {
                          // Still show the toolbar (branch filter + sort)
                          // even with zero results — matching the web
                          // reference, where "Filter by Branch" stays
                          // visible above the empty state instead of
                          // disappearing whenever a tab happens to have 0
                          // members.
                          children.add(toolbarRow);
                          children.add(const SizedBox(height: 16));
                          // No forced full-screen-height SizedBox here —
                          // it left a lot of empty space below the Invite
                          // button when the illustration+text content was
                          // shorter than 72% of the screen. Let it size to
                          // its own content instead.
                          children.add(
                            _NoTeamMembersState(
                              onAddTeamMember: selectedBranch == null
                                  ? null
                                  : _openAddMember,
                              message:
                                  _teamSearchController.text.trim().isNotEmpty
                                      ? translateText(
                                          'No team members match the selected filters',
                                        )
                                      : null,
                            ),
                          );
                        } else {
                          children.add(toolbarRow);
                          children.add(const SizedBox(height: 16));
                          // _tabMembers already arrives sorted and paginated
                          // by the server (status/sort/page/pageSize on the
                          // request) — no client-side sort or slicing here.
                          children.add(
                            _TeamMembersGrid(
                              members: _tabMembers,
                              selectedBranch: selectedBranch,
                              hasSelectedBranch: selectedBranchId != null,
                              salons: _salons,
                              statusUpdatingIds: _statusUpdatingIds,
                              deletingMemberIds: _deletingMemberIds,
                              openingViewMemberId: _openingViewMemberId,
                              professionalRatings: _professionalRatings,
                              onEditMember: _openEditMember,
                              onDeleteMember: _deleteMember,
                              onToggleMemberActive: _toggleMemberActive,
                              onViewMember: _openViewMember,
                              onAssignMember: _openAssignMember,
                              assignButtonBuilder: _buildAssignButtonChild,
                              memberNameBuilder: _memberDisplayName,
                              memberRoleBuilder: _memberRoleLabel,
                              needsSetup: (member) =>
                                  (member['teamDisplayStatus'] ?? '')
                                      .toString() ==
                                  'SETUP_REQUIRED',
                            ),
                          );
                          if (_tabMembersTotalPages > 1) {
                            children.add(const SizedBox(height: 16));
                            children.add(
                              _TeamPaginationFooter(
                                rangeStart:
                                    _teamMembersPage * _teamMembersPageSize + 1,
                                rangeEnd:
                                    _teamMembersPage * _teamMembersPageSize +
                                        _tabMembers.length,
                                total: _tabMembersTotal,
                                page: _teamMembersPage,
                                pageCount: _tabMembersTotalPages,
                                onPageSelected: goToPage,
                              ),
                            );
                          }
                        }

                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ...children,
                            const SizedBox(height: 96),
                          ],
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
          // Only overlay a refresh spinner on top of an already-visible
          // list. When there's no existing data yet, the inline loading
          // view rendered inside the FutureBuilder above already covers
          // that case — showing both at once looked like two loaders.
          if (_isLoadingTeamMembers && _hasTeamMembers)
            const Positioned.fill(child: _TeamMembersLoadingOverlay()),
        ],
      ),
    );
  }
}

class _TeamMembersLoadingOverlay extends StatelessWidget {
  const _TeamMembersLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.16),
        alignment: Alignment.center,
        child: AppLoader.page(),
      ),
    );
  }
}

// Real table (Member / Roles / Branches / Status / Online Booking /
// Actions), horizontally scrollable — matches the owner web dashboard's
// Team Members table instead of the mobile card grid this replaces.
class _TeamMembersTable extends StatelessWidget {
  const _TeamMembersTable({
    required this.members,
    required this.selectedBranch,
    required this.salons,
    required this.statusUpdatingIds,
    required this.deletingMemberIds,
    required this.openingViewMemberId,
    required this.onEditMember,
    required this.onDeleteMember,
    required this.onToggleMemberActive,
    required this.onViewMember,
    required this.onAssignMember,
    required this.memberNameBuilder,
    required this.memberRoleListBuilder,
    required this.memberBranchListBuilder,
    required this.needsSetup,
    required this.allowsOnlineBooking,
    required this.hasAssignments,
  });

  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? selectedBranch;
  final List<Map<String, dynamic>> salons;
  final Set<int> statusUpdatingIds;
  final Set<int> deletingMemberIds;
  final int? openingViewMemberId;
  final Future<void> Function(Map<String, dynamic> member) onEditMember;
  final Future<void> Function(int userId) onDeleteMember;
  final Future<void> Function(int userId, bool makeActive) onToggleMemberActive;
  final Future<void> Function(Map<String, dynamic> member) onViewMember;
  final Future<void> Function(Map<String, dynamic> member) onAssignMember;
  final String Function(Map<String, dynamic> member) memberNameBuilder;
  final List<String> Function(Map<String, dynamic> member)
      memberRoleListBuilder;
  final List<String> Function(Map<String, dynamic> member)
      memberBranchListBuilder;
  final bool Function(Map<String, dynamic> member) needsSetup;
  final bool Function(Map<String, dynamic> member) allowsOnlineBooking;
  final bool Function(Map<String, dynamic> member) hasAssignments;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teamBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 760),
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            headingRowColor: WidgetStateProperty.all(_teamSurface),
            headingTextStyle: const TextStyle(
              color: _teamMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
            dataRowMinHeight: 68,
            dataRowMaxHeight: 88,
            columns: [
              DataColumn(label: Text(translateText('MEMBER'))),
              DataColumn(label: Text(translateText('ROLES'))),
              DataColumn(label: Text(translateText('BRANCHES'))),
              DataColumn(label: Text(translateText('STATUS'))),
              DataColumn(label: Text(translateText('ONLINE BOOKING'))),
              DataColumn(label: Text(translateText('ACTIONS'))),
            ],
            rows: members.map((member) {
              final userId = _teamAsInt(member['id']) ?? 0;
              final isActive = _teamIsActiveEntity(member);
              final isDeleting = deletingMemberIds.contains(userId);
              final isStatusUpdating = statusUpdatingIds.contains(userId);
              final memberNeedsSetup = needsSetup(member);
              final roles = memberRoleListBuilder(member);
              final branches = memberBranchListBuilder(member);
              final canAssign = selectedBranch != null && salons.isNotEmpty;
              final blockDeleteOrDeactivate = !hasAssignments(member);

              return DataRow(
                cells: [
                  DataCell(
                    _TeamTableMemberCell(
                      member: member,
                      name: memberNameBuilder(member),
                      roleSubtitle: roles.isEmpty
                          ? translateText('Not Assigned')
                          : roles.join(', '),
                    ),
                  ),
                  DataCell(_TeamTableChips(labels: roles)),
                  DataCell(
                    _TeamTableChips(
                      labels: branches,
                      fallback: translateText('Not assigned'),
                      fallbackColor: AppColors.red,
                    ),
                  ),
                  DataCell(
                    memberNeedsSetup
                        ? _TeamTableStatusChip(
                            label: translateText('Setup Required'),
                            color: const Color(0xFFB45309),
                            background: const Color(0xFFFFF3D5),
                          )
                        : _TeamTableStatusChip(
                            label: translateText(
                              isActive ? 'Active' : 'Inactive',
                            ),
                            color:
                                isActive ? const Color(0xFF18864B) : _teamMuted,
                            background: isActive
                                ? const Color(0xFFE1F4E9)
                                : const Color(0xFFF0EDE8),
                          ),
                  ),
                  DataCell(
                    _TeamTableOnlineBooking(on: allowsOnlineBooking(member)),
                  ),
                  DataCell(
                    memberNeedsSetup
                        ? IconButton(
                            tooltip: translateText('Complete setup'),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            color: _teamGold,
                            onPressed: isDeleting
                                ? null
                                : () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    unawaited(onEditMember(member));
                                  },
                          )
                        : GestureDetector(
                            // Same as the Filter/Sort pills: dismiss the
                            // search keyboard on the initial touch, not
                            // just on picking a menu item — dismissing
                            // without picking anything was reopening it.
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            child: Theme(
                              // Menu-item hover/splash defaults to Material's
                              // blue since this app has no global theme —
                              // tint just this popup gold instead.
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context)
                                    .colorScheme
                                    .copyWith(primary: _teamGold),
                                splashColor: _teamGoldLight,
                                highlightColor: _teamGoldLight,
                                hoverColor: _teamGoldLight,
                              ),
                              child: PopupMenuButton<String>(
                                enabled: !isDeleting && !isStatusUpdating,
                                icon: const Icon(Icons.more_vert_rounded,
                                    color: _teamMuted),
                                elevation: 6,
                                padding: EdgeInsets.zero,
                                offset: const Offset(0, 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: _teamBorder),
                                ),
                                constraints:
                                    const BoxConstraints(minWidth: 200),
                                onCanceled: () => FocusManager
                                    .instance.primaryFocus
                                    ?.unfocus(),
                                onSelected: (action) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  switch (action) {
                                    case 'view':
                                      unawaited(onViewMember(member));
                                      break;
                                    case 'edit':
                                      unawaited(onEditMember(member));
                                      break;
                                    case 'assign':
                                      if (canAssign) {
                                        unawaited(onAssignMember(member));
                                      }
                                      break;
                                    case 'toggleActive':
                                      if (!blockDeleteOrDeactivate) {
                                        unawaited(
                                          onToggleMemberActive(
                                              userId, !isActive),
                                        );
                                      }
                                      break;
                                    case 'delete':
                                      if (!blockDeleteOrDeactivate) {
                                        unawaited(onDeleteMember(userId));
                                      }
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  _teamMenuItem(
                                    value: 'view',
                                    icon: Icons.visibility_outlined,
                                    label: translateText('View'),
                                  ),
                                  _teamMenuItem(
                                    value: 'edit',
                                    icon: Icons.edit_outlined,
                                    label: translateText('Edit'),
                                  ),
                                  _teamMenuItem(
                                    value: 'assign',
                                    icon: Icons.person_add_alt_1_outlined,
                                    label: translateText('Assign to Branch'),
                                    enabled: canAssign,
                                  ),
                                  _teamMenuItem(
                                    value: 'toggleActive',
                                    icon: isActive
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    label: translateText(
                                      isActive ? 'Deactivate' : 'Activate',
                                    ),
                                    enabled: !blockDeleteOrDeactivate,
                                  ),
                                  const PopupMenuDivider(height: 9),
                                  _teamMenuItem(
                                    value: 'delete',
                                    icon: Icons.delete_outline_rounded,
                                    label: translateText('Delete'),
                                    enabled: !blockDeleteOrDeactivate,
                                    color: AppColors.red,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TeamTableMemberCell extends StatelessWidget {
  const _TeamTableMemberCell({
    required this.member,
    required this.name,
    required this.roleSubtitle,
  });

  final Map<String, dynamic> member;
  final String name;
  final String roleSubtitle;

  String get _initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TM';
    final first = parts.first.substring(0, 1).toUpperCase();
    final second = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$second'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (member['profilePictureUrl'] ?? '').toString().trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: _TeamAvatar(imageUrl: imageUrl, initials: _initials),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  roleSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamTableChips extends StatelessWidget {
  const _TeamTableChips({
    required this.labels,
    this.fallback,
    this.fallbackColor,
  });

  final List<String> labels;
  final String? fallback;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      if (fallback == null) return const SizedBox.shrink();
      final color = fallbackColor ?? _teamMuted;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          fallback!,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: labels
            .map((label) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _teamGoldLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _teamGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _TeamTableStatusChip extends StatelessWidget {
  const _TeamTableStatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamTableOnlineBooking extends StatelessWidget {
  const _TeamTableOnlineBooking({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? const Color(0xFF18864B) : _teamMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          on ? translateText('ON') : translateText('OFF'),
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TeamMembersGrid extends StatelessWidget {
  const _TeamMembersGrid({
    required this.members,
    required this.selectedBranch,
    required this.hasSelectedBranch,
    required this.salons,
    required this.statusUpdatingIds,
    required this.deletingMemberIds,
    required this.openingViewMemberId,
    required this.professionalRatings,
    required this.onEditMember,
    required this.onDeleteMember,
    required this.onToggleMemberActive,
    required this.onViewMember,
    required this.onAssignMember,
    required this.assignButtonBuilder,
    required this.memberNameBuilder,
    required this.memberRoleBuilder,
    required this.needsSetup,
  });

  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? selectedBranch;
  final bool hasSelectedBranch;
  final List<Map<String, dynamic>> salons;
  final Set<int> statusUpdatingIds;
  final Set<int> deletingMemberIds;
  final int? openingViewMemberId;
  final Map<int, _TeamRatingSummary> professionalRatings;
  final Future<void> Function(Map<String, dynamic> member) onEditMember;
  final Future<void> Function(int userId) onDeleteMember;
  final Future<void> Function(int userId, bool makeActive) onToggleMemberActive;
  final Future<void> Function(Map<String, dynamic> member) onViewMember;
  final Future<void> Function(Map<String, dynamic> member) onAssignMember;
  final Widget Function(Map<String, dynamic> member) assignButtonBuilder;
  final String Function(Map<String, dynamic> member) memberNameBuilder;
  final String Function(Map<String, dynamic> member) memberRoleBuilder;
  final bool Function(Map<String, dynamic> member) needsSetup;

  @override
  Widget build(BuildContext context) {
    // Wrap, not GridView — a fixed mainAxisExtent forced every card to
    // the same height regardless of its actual content (varying number
    // of branch chips, role, etc.), which is exactly what was causing
    // the "RenderFlex overflowed" error. Wrap lets each card size to its
    // own content while still flowing into columns on wide screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final crossAxisCount = screenWidth >= 1024
            ? 3
            : screenWidth >= 700
                ? 2
                : 1;
        const gap = 14.0;
        final cardWidth = crossAxisCount == 1
            ? screenWidth
            : (screenWidth - gap * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: members.map((member) {
            final userId = _teamAsInt(member['userId']) ?? 0;
            final isActive =
                (member['teamDisplayStatus'] ?? '').toString() == 'ACTIVE';
            final isStatusUpdating = statusUpdatingIds.contains(userId);
            final isDeleting = deletingMemberIds.contains(userId);
            final ratingSummary =
                professionalRatings[userId] ?? _TeamRatingSummary.empty;
            // Delete/Deactivate act on selectedBranchId (see
            // _deleteMember/_toggleMemberActive) — meaningless, and
            // liable to hit the wrong branch's record, for a member with
            // no branch assignment at all. Block just those two actions
            // for them; Edit/View/Assign don't depend on a branch.
            final rawAssignments = member['branches'];
            final hasNoBranch =
                rawAssignments is! List || rawAssignments.isEmpty;
            // teamDisplayStatus (ACTIVE/SETUP_REQUIRED, driving `isActive`
            // above) is about profile completeness, not account state —
            // the Deactivate/Activate button toggles a distinct per-branch
            // `active` flag on member['branches'], so it needs its own
            // derived value rather than reusing `isActive`.
            final selectedBranchId = hasSelectedBranch
                ? _teamAsInt(selectedBranch?['branchId'])
                : null;
            Map<String, dynamic>? matchingBranch;
            if (rawAssignments is List) {
              for (final entry in rawAssignments) {
                if (entry is! Map) continue;
                final branchMap = Map<String, dynamic>.from(entry);
                if (selectedBranchId != null &&
                    _teamAsInt(branchMap['branchId']) == selectedBranchId) {
                  matchingBranch = branchMap;
                  break;
                }
                matchingBranch ??= branchMap;
              }
            }
            final isBranchActive = matchingBranch?['active'] != false;

            return SizedBox(
              width: cardWidth,
              child: _TeamMemberCard(
                member: member,
                name: memberNameBuilder(member),
                role: memberRoleBuilder(member),
                ratingSummary: ratingSummary,
                isActive: isActive,
                isBranchActive: isBranchActive,
                needsSetup: needsSetup(member),
                isDeleting: isDeleting,
                isStatusUpdating: isStatusUpdating,
                isViewOpening: openingViewMemberId != null,
                isViewLoadingThisCard: openingViewMemberId == userId,
                isDeleteBlocked: hasNoBranch || !hasSelectedBranch,
                isDeactivateBlocked: hasNoBranch || !hasSelectedBranch,
                canAssign: selectedBranch != null && salons.isNotEmpty,
                assignButtonChild: assignButtonBuilder(member),
                onEdit: () => onEditMember(member),
                onDelete: () => onDeleteMember(userId),
                onToggleActive: () =>
                    onToggleMemberActive(userId, !isBranchActive),
                onView: () {
                  unawaited(onViewMember(member));
                },
                onAssign: () => onAssignMember(member),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Search and "Invite Team Member" in one row, matching the web
// dashboard's header — instead of search buried in a conditional filters
// bar further down and Invite as a separate floating action button.
class _TeamSearchAndInviteRow extends StatelessWidget {
  const _TeamSearchAndInviteRow({
    required this.searchController,
    required this.hasActiveFilters,
    required this.onOpenFilters,
    required this.onInvite,
  });

  final TextEditingController searchController;
  final bool hasActiveFilters;
  final VoidCallback onOpenFilters;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              final hasSearch = value.text.trim().isNotEmpty;
              return TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: translateText('Search by name, phone, or email'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: hasSearch
                      ? IconButton(
                          tooltip: translateText('Clear search'),
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _teamBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _teamBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.starColor),
                  ),
                ),
              );
            },
          ),
        ),
        // Filter icon commented out for now (not removed) — the "Filter
        // by Branch"/"Sort by" row below already covers filtering.
        // const SizedBox(width: 10),
        // _TeamFilterButton(
        //   hasActiveFilters: hasActiveFilters,
        //   onPressed: onOpenFilters,
        // ),
        const SizedBox(width: 10),
        Tooltip(
          message: translateText('Invite Team Member'),
          child: SizedBox(
            width: 46,
            height: 46,
            child: ElevatedButton(
              onPressed: onInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _teamGold : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _teamGold : _teamBorder,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x268B6500),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: selected
                  ? const Padding(
                      key: ValueKey('selected'),
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('unselected')),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : _teamMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFilterChip extends StatelessWidget {
  const _ServiceFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF2C9) : const Color(0xFFFFFAF1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? _teamGold : const Color(0xFFE8C774),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? _teamGold : _teamInk,
          ),
        ),
      ),
    );
  }
}

class _TeamFilterButton extends StatelessWidget {
  const _TeamFilterButton({
    required this.hasActiveFilters,
    required this.onPressed,
  });

  final bool hasActiveFilters;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: hasActiveFilters ? _teamGoldLight : _teamSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilters ? _teamGold : _teamBorder,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.tune_rounded,
                color: _teamInk,
                size: 22,
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _teamGold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamHeaderPill extends StatelessWidget {
  const _TeamHeaderPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _teamGoldLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _teamBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _teamGold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamFiltersSheet extends StatefulWidget {
  const _TeamFiltersSheet({
    required this.statusFilter,
    required this.allowOnlineBookingFilter,
    required this.dateFilter,
    required this.serviceOptions,
    required this.selectedServiceIds,
    required this.isLoadingServices,
    required this.showAllServices,
    required this.onStatusChanged,
    required this.onOnlineBookingChanged,
    required this.onPickDate,
    required this.onClearDate,
    required this.onServiceToggled,
    required this.onClearServices,
    required this.onToggleShowAllServices,
    required this.onClearAll,
  });

  final String statusFilter;
  final bool? allowOnlineBookingFilter;
  final DateTime? dateFilter;
  final List<_TeamServiceFilterOption> serviceOptions;
  final Set<int> selectedServiceIds;
  final bool isLoadingServices;
  final bool showAllServices;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool?> onOnlineBookingChanged;
  final Future<void> Function(DateTime picked) onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<int> onServiceToggled;
  final VoidCallback onClearServices;
  final VoidCallback onToggleShowAllServices;
  final VoidCallback onClearAll;

  @override
  State<_TeamFiltersSheet> createState() => _TeamFiltersSheetState();
}

class _TeamFiltersSheetState extends State<_TeamFiltersSheet> {
  late String _statusFilter;
  late bool? _allowOnlineBookingFilter;
  DateTime? _dateFilter;
  late final Set<int> _selectedServiceIds;
  late bool _showAllServices;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.statusFilter;
    _allowOnlineBookingFilter = widget.allowOnlineBookingFilter;
    _dateFilter = widget.dateFilter;
    _selectedServiceIds = Set<int>.from(widget.selectedServiceIds);
    _showAllServices = widget.showAllServices;
  }

  String _dateLabel() {
    if (_dateFilter == null) return translateText('Date');
    return DateFormat('EEE, MMM d, yyyy').format(_dateFilter!);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null) return;

    await widget.onPickDate(picked);
    if (!mounted) return;
    setState(() => _dateFilter = picked);
  }

  void _clearDate() {
    if (_dateFilter == null) return;
    widget.onClearDate();
    if (!mounted) return;
    setState(() => _dateFilter = null);
  }

  void _setStatus(String value) {
    final nextValue = _statusFilter == value && value != 'all' ? 'all' : value;
    if (_statusFilter == nextValue) return;
    widget.onStatusChanged(nextValue);
    setState(() => _statusFilter = nextValue);
  }

  void _setOnlineBooking(bool? value) {
    final nextValue =
        _allowOnlineBookingFilter == value && value != null ? null : value;
    if (_allowOnlineBookingFilter == nextValue) return;
    widget.onOnlineBookingChanged(nextValue);
    setState(() => _allowOnlineBookingFilter = nextValue);
  }

  void _toggleService(int serviceId) {
    if (_selectedServiceIds.contains(serviceId)) {
      widget.onServiceToggled(serviceId);
      setState(() => _selectedServiceIds.remove(serviceId));
      return;
    }
    widget.onServiceToggled(serviceId);
    setState(() => _selectedServiceIds.add(serviceId));
  }

  void _clearServices() {
    if (_selectedServiceIds.isEmpty) return;
    widget.onClearServices();
    setState(_selectedServiceIds.clear);
  }

  void _toggleShowAllServices() {
    widget.onToggleShowAllServices();
    setState(() => _showAllServices = !_showAllServices);
  }

  void _clearAll() {
    widget.onClearAll();
    setState(() {
      _statusFilter = 'all';
      _allowOnlineBookingFilter = null;
      _dateFilter = null;
      _selectedServiceIds.clear();
      _showAllServices = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleServices = _showAllServices
        ? widget.serviceOptions
        : widget.serviceOptions.take(4).toList();
    final hiddenServiceCount =
        widget.serviceOptions.length - visibleServices.length;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final activeFilterCount = <bool>[
      _statusFilter != 'all',
      _allowOnlineBookingFilter != null,
      _dateFilter != null,
      _selectedServiceIds.isNotEmpty,
    ].where((value) => value).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _teamBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _teamBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _teamGoldLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: _teamGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            translateText('Filter team members'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _teamInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          _TeamHeaderPill(
                            label:
                                '${translateText('Applied')}: $activeFilterCount',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _bottomSheetSection(
                          icon: Icons.badge_outlined,
                          title: translateText('Status'),
                          subtitle: translateText(
                            'Choose who should appear in the team list.',
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChoiceChip(
                                label: translateText('All'),
                                selected: _statusFilter == 'all',
                                onSelected: () => _setStatus('all'),
                              ),
                              _FilterChoiceChip(
                                label: translateText('Active'),
                                selected: _statusFilter == 'active',
                                onSelected: () => _setStatus('active'),
                              ),
                              _FilterChoiceChip(
                                label: translateText('Inactive'),
                                selected: _statusFilter == 'inactive',
                                onSelected: () => _setStatus('inactive'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _bottomSheetSection(
                          icon: Icons.online_prediction_rounded,
                          title: translateText('Online booking'),
                          subtitle: translateText(
                            'Only members available for booking stay visible.',
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChoiceChip(
                                label: translateText('Yes'),
                                selected: _allowOnlineBookingFilter == true,
                                onSelected: () => _setOnlineBooking(true),
                              ),
                              _FilterChoiceChip(
                                label: translateText('No'),
                                selected: _allowOnlineBookingFilter == false,
                                onSelected: () => _setOnlineBooking(false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _bottomSheetSection(
                          icon: Icons.calendar_month_outlined,
                          title: translateText('Date'),
                          subtitle: translateText(
                            'Joining and leaving dates are checked automatically.',
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 18,
                                  ),
                                  label: Text(_dateLabel()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _teamInk,
                                    side: const BorderSide(color: _teamBorder),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              if (_dateFilter != null) ...[
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: _clearDate,
                                  icon: const Icon(Icons.event_busy_outlined),
                                  color: _teamMuted,
                                  tooltip: translateText('Clear date'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _bottomSheetSection(
                          icon: Icons.design_services_outlined,
                          title: translateText('Services'),
                          subtitle: translateText(
                            'Tap one or more services to filter team members.',
                          ),
                          trailing: widget.serviceOptions.isNotEmpty
                              ? TextButton(
                                  onPressed: _toggleShowAllServices,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.starColor,
                                  ),
                                  child: Text(
                                    _showAllServices
                                        ? translateText('Show less')
                                        : '${translateText('Show more')} ($hiddenServiceCount)',
                                  ),
                                )
                              : null,
                          child: widget.isLoadingServices
                              ? LinearProgressIndicator(
                                  color: AppColors.starColor,
                                  backgroundColor: _teamGoldLight,
                                  minHeight: 3,
                                )
                              : widget.serviceOptions.isEmpty
                                  ? Text(
                                      translateText(
                                        'No services available for this branch',
                                      ),
                                      style: const TextStyle(
                                        color: _teamMuted,
                                        fontSize: 12,
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: visibleServices.length,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            mainAxisExtent: 34,
                                          ),
                                          itemBuilder: (context, index) {
                                            final service =
                                                visibleServices[index];
                                            return _ServiceFilterChip(
                                              label: service.name,
                                              selected: _selectedServiceIds
                                                  .contains(service.id),
                                              onSelected: () =>
                                                  _toggleService(service.id),
                                            );
                                          },
                                        ),
                                        if (_selectedServiceIds.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: _clearServices,
                                              icon: const Icon(
                                                Icons
                                                    .cleaning_services_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                translateText('Clear services'),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: _teamMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (activeFilterCount > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(translateText('Clear all')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _teamMuted,
                              side: const BorderSide(color: _teamBorder),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: activeFilterCount > 0 ? 2 : 1,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_rounded, size: 19),
                          label: Text(
                            activeFilterCount > 0
                                ? '${translateText('Show results')} ($activeFilterCount)'
                                : translateText('Show team list'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teamGold,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0x668B6500),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
      },
    );
  }

  Widget _bottomSheetSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _teamBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _teamGoldLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _teamGold, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: _teamMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// class _TeamListHeader extends StatelessWidget {
//   const _TeamListHeader({
//     required this.count,
//   });

//   final int count;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _teamBorder),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x12000000),
//             blurRadius: 14,
//             offset: Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           const CircleAvatar(
//             radius: 21,
//             backgroundColor: _teamGoldLight,
//             child: Icon(Icons.groups_2_outlined, color: _teamGold, size: 23),
//           ),
//           const SizedBox(width: 12),
//           // Expanded(
//           //   child: Column(
//           //     crossAxisAlignment: CrossAxisAlignment.start,
//           //     children: [
//           //       Text(
//           //         translateText('Team members'),
//           //         style: const TextStyle(
//           //           color: _teamInk,
//           //           fontSize: 16,
//           //           fontWeight: FontWeight.w900,
//           //         ),
//           //       ),
//           //       // const SizedBox(height: 3),
//           //       // Text(
//           //       //   translateText('Total team members'),
//           //       //   maxLines: 1,
//           //       //   overflow: TextOverflow.ellipsis,
//           //       //   style: const TextStyle(
//           //       //     color: _teamMuted,
//           //       //     fontSize: 12,
//           //       //     fontWeight: FontWeight.w600,
//           //       //   ),
//           //       // ),
//           //     ],
//           //   ),
//           // ),
//           // Container(
//           //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//           //   decoration: BoxDecoration(
//           //     color: _teamGoldLight,
//           //     borderRadius: BorderRadius.circular(999),
//           //     border: Border.all(color: _teamBorder),
//           //   ),
//           //   child: Text(
//           //     '$count',
//           //     style: const TextStyle(
//           //       color: _teamGold,
//           //       fontSize: 16,
//           //       fontWeight: FontWeight.w900,
//           //     ),
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
// }

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    required this.name,
    required this.role,
    required this.ratingSummary,
    required this.isActive,
    required this.isBranchActive,
    required this.needsSetup,
    required this.isDeleting,
    required this.isStatusUpdating,
    required this.isViewOpening,
    required this.isViewLoadingThisCard,
    required this.isDeleteBlocked,
    required this.isDeactivateBlocked,
    required this.canAssign,
    required this.assignButtonChild,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onView,
    required this.onAssign,
  });

  final Map<String, dynamic> member;
  final String name;
  final String role;
  final _TeamRatingSummary ratingSummary;
  final bool isActive;
  final bool isBranchActive;
  final bool needsSetup;
  final bool isDeleting;
  final bool isStatusUpdating;
  final bool isViewOpening;
  final bool isViewLoadingThisCard;
  final bool isDeleteBlocked;
  final bool isDeactivateBlocked;
  final bool canAssign;
  final Widget assignButtonChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onView;
  final VoidCallback onAssign;

  bool get _isBusy => isDeleting || isStatusUpdating || isViewOpening;

  String _cleanText(dynamic value) {
    return (value?.toString() ?? '').trim();
  }

  List<String> get _assignedBranchesList {
    final rawAssignments = member['branches'];
    if (rawAssignments is! List || rawAssignments.isEmpty) {
      return const [];
    }

    final labels = <String>[];
    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final text = _cleanText(assignment['branchName']);
      if (text.isNotEmpty && !labels.contains(text)) {
        labels.add(text);
      }
    }

    return labels;
  }

  // Green when active, orange when this member still needs role/
  // experience/services set up, muted grey when deactivated — same
  // meaning as the status pill, used here to tint the avatar ring and
  // the card's top accent stripe so the card reads at a glance.
  Color get _accentColor {
    if (needsSetup) return const Color(0xFFB45309);
    return isActive ? const Color(0xFF18864B) : _teamMuted;
  }

  String get _initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TM';
    final first = parts.first.substring(0, 1).toUpperCase();
    final second = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$second'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (member['profilePictureUrl'] ?? '').toString().trim();
    final branches = _assignedBranchesList;
    final accent = _accentColor;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _teamBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent stripe — green/orange/grey depending on status,
          // so a card reads at a glance without reading any text.
          Container(height: 3, color: accent),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.6),
                      ),
                      child: _TeamAvatar(
                        imageUrl: imageUrl,
                        initials: _initials,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _teamInk,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _teamGoldLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _teamGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (needsSetup) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              translateText('Setup Required'),
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TeamInfoChip(
                  icon: Icons.star_rounded,
                  label: ratingSummary.average.toStringAsFixed(1),
                  value: translateText('Rating'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TeamCompactActionButton(
                        icon: Icons.edit_outlined,
                        label: translateText('Edit'),
                        onPressed: _isBusy ? null : onEdit,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Expanded(
                    //   child: _TeamCompactActionButton(
                    //     icon: isBranchActive
                    //         ? Icons.pause_circle_outline
                    //         : Icons.play_circle_outline,
                    //     label: translateText(
                    //       isBranchActive ? 'Deactivate' : 'Activate',
                    //     ),
                    //     isLoading: isStatusUpdating,
                    //     onPressed: (_isBusy || isDeactivateBlocked)
                    //         ? null
                    //         : onToggleActive,
                    //   ),
                    // ),
                    // const SizedBox(width: 6),
                    Expanded(
                      child: _TeamCompactActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: translateText('Delete'),
                        color: AppColors.red,
                        isLoading: isDeleting,
                        onPressed:
                            (_isBusy || isDeleteBlocked) ? null : onDelete,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  translateText('Assigned branches'),
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                branches.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          translateText('No branch assigned'),
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: branches
                            .map(
                              (branchName) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _teamGoldLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  branchName,
                                  style: const TextStyle(
                                    color: _teamGold,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : onView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        icon: isViewLoadingThisCard
                            ? const SizedBox.shrink()
                            : const Icon(Icons.visibility_outlined, size: 15),
                        label: isViewLoadingThisCard
                            ? AppLoader.inline(
                                size: 18,
                                strokeWidth: 2,
                                color: Colors.white,
                              )
                            : Text(translateText('View')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy || !canAssign ? null : onAssign,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.starColor),
                          foregroundColor: AppColors.starColor,
                          minimumSize: const Size.fromHeight(38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 14,
                        ),
                        label: assignButtonChild,
                      ),
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

class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({
    required this.imageUrl,
    required this.initials,
    this.size = 56,
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
              _InitialsAvatar(initials: initials, size: size),
        ),
      );
    }
    return _InitialsAvatar(initials: initials, size: size);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _teamGoldLight,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: _teamGold,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamInfoChip extends StatelessWidget {
  const _TeamInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _teamSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _teamBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _teamGoldLight,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.starColor, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact Edit/Deactivate/Delete button for the card — icon + short label
// in one small pill, three fitting side by side in a row instead of the
// old mix of tiny icon-only squares next to one oversized text pill.
class _TeamCompactActionButton extends StatelessWidget {
  const _TeamCompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final effectiveColor =
        disabled ? _teamMuted.withValues(alpha: 0.45) : (color ?? _teamGold);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: disabled
                  ? _teamBorder
                  : effectiveColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isLoading
                  ? SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: effectiveColor,
                      ),
                    )
                  : Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
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

class _TeamIconButton extends StatelessWidget {
  const _TeamIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.isLoading = false,
    this.isBlocked = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final actionColor = color ?? AppColors.starColor;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 42,
        width: 42,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: actionColor.withValues(alpha: isBlocked ? 0.22 : 0.35),
            ),
            foregroundColor: actionColor.withValues(
              alpha: isBlocked ? 0.7 : 1,
            ),
            backgroundColor: isBlocked ? const Color(0xFFF5F2EE) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? AppLoader.inline(
                  size: 16,
                  strokeWidth: 2,
                  color: actionColor,
                )
              : Icon(icon, size: 20),
        ),
      ),
    );
  }
}

const Color _invitationSectionBorder = Color(0xFFE8DED6);
const Color _invitationSectionGold = Color(0xFF8B6500);
const Color _invitationSectionGoldLight = Color(0xFFF3E8D1);
const Color _invitationSectionText = Color(0xFF2B241D);
const Color _invitationSectionMuted = Color(0xFF8C7A66);

/// The "Team members / Invited" pill tabs — mirrors the owner web app's
/// Team screen (see screenshot in conversation): a segmented pair of chips
/// with a count badge on each, gold when selected.
// Mirrors the owner web dashboard's Team Members tab strip: Active /
// Setup Required / Invited, each with its own live count. Per
// salon_team_part_1_updated_3.md, the finalized UI has three tabs and no
// combined "All Members" view.
class _TeamStatCardsRow extends StatelessWidget {
  const _TeamStatCardsRow({
    required this.activeCount,
    required this.setupRequiredCount,
    required this.invitedCount,
  });

  final int activeCount;
  final int setupRequiredCount;
  final int invitedCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TeamStatCard(
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF18864B),
            iconBackground: const Color(0xFFE1F4E9),
            label: translateText('Active'),
            count: activeCount,
          ),
          const SizedBox(width: 12),
          _TeamStatCard(
            icon: Icons.schedule_outlined,
            iconColor: const Color(0xFFB45309),
            iconBackground: const Color(0xFFFFF3D5),
            label: translateText('Setup Required'),
            count: setupRequiredCount,
          ),
          const SizedBox(width: 12),
          _TeamStatCard(
            icon: Icons.mail_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBackground: const Color(0xFFDCEAFF),
            label: translateText('Invited'),
            count: invitedCount,
          ),
        ],
      ),
    );
  }
}

class _TeamStatCard extends StatelessWidget {
  const _TeamStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teamBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// "Sort by" control shown alongside the branch filter, matching the web
// toolbar's "Sort by: Name A-Z" dropdown.
// Compact "Filter by Branch: All Branches ▾" style pill, matching the
// web dashboard's toolbar — as opposed to OwnerBranchHeaderSelector, which
// renders as a full-width card and doesn't fit inline next to Sort by.
class _TeamCompactDropdown<T> extends StatelessWidget {
  const _TeamCompactDropdown({
    required this.icon,
    required this.prefixLabel,
    required this.valueLabel,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.onClear,
  });

  final IconData icon;
  final String prefixLabel;
  final String valueLabel;
  final T selectedValue;
  final List<MapEntry<T, String>> options;
  final void Function(T) onSelected;

  /// When set, shows a small clear (×) affordance next to the dropdown —
  /// resets back to the unselected "no filter" state.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    // Opening this menu (or the row-actions menu, or switching tabs)
    // shouldn't leave the search field's keyboard open, or bring it back
    // once the menu closes — dismiss on the initial touch, not just on
    // a selection, since dismissing without picking anything (onCanceled)
    // is exactly the case that was reopening it.
    final pill = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: PopupMenuButton<T>(
        initialValue: selectedValue,
        onSelected: (value) {
          FocusManager.instance.primaryFocus?.unfocus();
          onSelected(value);
        },
        onCanceled: () => FocusManager.instance.primaryFocus?.unfocus(),
        itemBuilder: (context) => options
            .map(
              (entry) => PopupMenuItem<T>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: onClear != null ? 4 : 12,
            top: 9,
            bottom: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: onClear != null
                ? const BorderRadius.horizontal(left: Radius.circular(10))
                : BorderRadius.circular(10),
            border: Border.all(color: _teamBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _teamMuted),
              const SizedBox(width: 6),
              Text(
                '$prefixLabel: ',
                style: const TextStyle(
                  color: _teamMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Flexible(
                child: Text(
                  valueLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _teamMuted),
            ],
          ),
        ),
      ),
    );

    final clearCallback = onClear;
    if (clearCallback == null) return pill;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill,
        InkWell(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            clearCallback();
          },
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(10)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(10)),
              border: const Border(
                top: BorderSide(color: _teamBorder),
                right: BorderSide(color: _teamBorder),
                bottom: BorderSide(color: _teamBorder),
              ),
            ),
            child: const Icon(Icons.close_rounded, size: 15, color: _teamMuted),
          ),
        ),
      ],
    );
  }
}

// Filter-by (branch, or salon on the Invited tab) + Sort by, together in
// one row — shown the same way regardless of which of the four tabs is
// selected, matching the web dashboard's toolbar.
class _TeamToolbarRow extends StatelessWidget {
  const _TeamToolbarRow({
    required this.filterPill,
    required this.sortOrder,
    required this.onSortChanged,
  });

  final Widget? filterPill;
  final String sortOrder;
  final void Function(String) onSortChanged;

  @override
  Widget build(BuildContext context) {
    // Filter and Sort always stay in one row, side by side — scrolls
    // horizontally rather than wrapping onto a second line when the
    // screen is too narrow for both.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (filterPill != null) ...[
            filterPill!,
            const SizedBox(width: 10),
          ],
          _TeamCompactDropdown<String>(
            icon: Icons.sort_rounded,
            prefixLabel: translateText('Sort by'),
            valueLabel: sortOrder == 'name_desc'
                ? translateText('Name Z-A')
                : translateText('Name A-Z'),
            selectedValue: sortOrder,
            options: [
              MapEntry('name_asc', translateText('Name A-Z')),
              MapEntry('name_desc', translateText('Name Z-A')),
            ],
            onSelected: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _TeamSortRow extends StatelessWidget {
  const _TeamSortRow({
    required this.sortOrder,
    required this.onChanged,
  });

  final String sortOrder;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        initialValue: sortOrder,
        onSelected: onChanged,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'name_asc',
            child: Text(translateText('Name A-Z')),
          ),
          PopupMenuItem(
            value: 'name_desc',
            child: Text(translateText('Name Z-A')),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _teamBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${translateText('Sort by')}: ',
                style: const TextStyle(
                  color: _teamMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sortOrder == 'name_desc'
                    ? translateText('Name Z-A')
                    : translateText('Name A-Z'),
                style: const TextStyle(
                  color: _teamInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _teamMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// Pagination footer matching the web table's "Showing X to Y of Z
// members" strip with page-number buttons.
class _TeamPaginationFooter extends StatelessWidget {
  const _TeamPaginationFooter({
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPageSelected,
  });

  final int rangeStart;
  final int rangeEnd;
  final int total;
  final int page;
  final int pageCount;
  final void Function(int) onPageSelected;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) {
      return Text(
        translateText(
          'Showing {start} to {end} of {total} members',
          params: {
            'start': '$rangeStart',
            'end': '$rangeEnd',
            'total': '$total',
          },
        ),
        style: const TextStyle(color: _teamMuted, fontSize: 12.5),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          translateText(
            'Showing {start} to {end} of {total} members',
            params: {
              'start': '$rangeStart',
              'end': '$rangeEnd',
              'total': '$total',
            },
          ),
          style: const TextStyle(color: _teamMuted, fontSize: 12.5),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: _teamGold,
              onPressed: page > 0 ? () => onPageSelected(page - 1) : null,
            ),
            for (var i = 0; i < pageCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onPageSelected(i),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == page ? _teamGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == page ? Colors.white : _teamInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: _teamGold,
              onPressed:
                  page < pageCount - 1 ? () => onPageSelected(page + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamSectionTabs extends StatelessWidget {
  const _TeamSectionTabs({
    required this.selectedIndex,
    required this.activeCount,
    required this.setupRequiredCount,
    required this.invitedCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int activeCount;
  final int setupRequiredCount;
  final int invitedCount;
  final void Function(int) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TeamTabChip(
            label: translateText('Active'),
            count: activeCount,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          const SizedBox(width: 24),
          _TeamTabChip(
            label: translateText('Setup Required'),
            count: setupRequiredCount,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          const SizedBox(width: 24),
          _TeamTabChip(
            label: translateText('Invited'),
            count: invitedCount,
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _TeamTabChip extends StatelessWidget {
  const _TeamTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Flat text tab with a bottom underline on the selected tab, matching
    // the web dashboard — not a rounded pill/chip button.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _teamGold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? _teamGold : _teamMuted,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? _teamGold : _teamMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

/// The "Invited" tab body — pending salon invitations as cards, matching
/// the owner web app's Team → Invited tab layout.
class _InvitedTab extends StatelessWidget {
  const _InvitedTab({
    required this.pendingInvitations,
    required this.isLoading,
    required this.cancellingInvitationIds,
    required this.onCancelInvitation,
  });

  final List<Map<String, dynamic>> pendingInvitations;
  final bool isLoading;
  final Set<int> cancellingInvitationIds;
  final void Function(Map<String, dynamic>) onCancelInvitation;

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (pendingInvitations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              color: _invitationSectionGold,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              translateText('No pending invitations'),
              style: const TextStyle(
                color: _invitationSectionText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: pendingInvitations.map((invitation) {
        final invitationId = _asInt(invitation['invitationId']);
        final isCancelling = invitationId != null &&
            cancellingInvitationIds.contains(invitationId);
        return _InvitationCard(
          invitation: invitation,
          isCancelling: isCancelling,
          onCancel: () => onCancelInvitation(invitation),
        );
      }).toList(),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.isCancelling,
    required this.onCancel,
  });

  final Map<String, dynamic> invitation;
  final bool isCancelling;
  final VoidCallback onCancel;

  String get _firstName => (invitation['firstName'] ?? '').toString().trim();
  String get _lastName => (invitation['lastName'] ?? '').toString().trim();

  String get _fullName {
    final name = '$_firstName $_lastName'.trim();
    return name.isEmpty ? translateText('Invited member') : name;
  }

  String get _initials {
    final first = _firstName.isNotEmpty ? _firstName[0] : '';
    final last = _lastName.isNotEmpty ? _lastName[0] : '';
    final initials = '$first$last'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _sentAgoLabel() {
    final sentAt = _parseDate(invitation['sentAt']);
    if (sentAt == null) return '';
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) {
      return translateText('Sent just now');
    }
    if (diff.inHours < 1) {
      return translateText('Sent {n}m ago', params: {'n': '${diff.inMinutes}'});
    }
    if (diff.inDays < 1) {
      return translateText('Sent {n}h ago', params: {'n': '${diff.inHours}'});
    }
    return translateText('Sent {n}d ago', params: {'n': '${diff.inDays}'});
  }

  String _expiresLabel() {
    final expiresAt = _parseDate(invitation['expiresAt']);
    if (expiresAt == null) return '';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      return translateText('Expired');
    }
    if (diff.inDays >= 1) {
      return translateText('Expires in {n}d', params: {'n': '${diff.inDays}'});
    }
    if (diff.inHours >= 1) {
      return translateText('Expires in {n}h', params: {'n': '${diff.inHours}'});
    }
    return translateText('Expires in {n}m', params: {'n': '${diff.inMinutes}'});
  }

  @override
  Widget build(BuildContext context) {
    final email = (invitation['invitedEmail'] ?? '').toString().trim();
    final phone = (invitation['invitedPhone'] ?? '').toString().trim();
    final sentLabel = _sentAgoLabel();
    final expiresLabel = _expiresLabel();
    final isExpired = (invitation['teamDisplayStatus'] ?? '').toString() ==
        'INVITATION_EXPIRED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _invitationSectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _invitationSectionGoldLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: _invitationSectionGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName,
                      style: const TextStyle(
                        color: _invitationSectionText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      translateText(isExpired ? 'Expired' : 'Pending'),
                      style: TextStyle(
                        color:
                            isExpired ? AppColors.red : _invitationSectionGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              isCancelling
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: _invitationSectionMuted,
                      tooltip: translateText('Cancel invitation'),
                      visualDensity: VisualDensity.compact,
                    ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 12),
            _iconTextRow(Icons.mail_outline_rounded, email),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _iconTextRow(Icons.phone_outlined, phone),
          ],
          if (sentLabel.isNotEmpty || expiresLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _invitationSectionBorder),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sentLabel,
                  style: const TextStyle(
                    color: _invitationSectionMuted,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  expiresLabel,
                  style: const TextStyle(
                    color: _invitationSectionMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconTextRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _invitationSectionMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _invitationSectionText,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoTeamMembersState extends StatelessWidget {
  const _NoTeamMembersState({
    this.onAddTeamMember,
    this.message,
  });

  final VoidCallback? onAddTeamMember;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final messageText = message ?? translateText('No team members yet');

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final compact = availableHeight < 620;
        final veryCompact = availableHeight < 500;
        final imageHeight = (availableHeight *
                (veryCompact
                    ? 0.16
                    : compact
                        ? 0.20
                        : 0.24))
            .clamp(76.0, 170.0);
        final quoteFontSize = veryCompact
            ? 13.0
            : compact
                ? 14.0
                : 18.0;
        final quoteLineHeight = veryCompact
            ? 1.22
            : compact
                ? 1.28
                : 1.45;
        final iconSize = veryCompact
            ? 38.0
            : compact
                ? 44.0
                : 56.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
              0,
              veryCompact
                  ? 6
                  : compact
                      ? 10
                      : 18,
              0,
              veryCompact ? 6 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/add team logo.png',
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: imageHeight,
                    width: double.infinity,
                    color: const Color(0xFFF5EFE8),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _teamGold,
                      size: 42,
                    ),
                  ),
                ),
              ),
              SizedBox(
                  height: veryCompact
                      ? 8
                      : compact
                          ? 12
                          : 22),
              Text(
                '”',
                style: TextStyle(
                  color: const Color(0xFFD0A244),
                  fontSize: veryCompact
                      ? 22
                      : compact
                          ? 26
                          : 34,
                  height: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(
                  height: veryCompact
                      ? 0
                      : compact
                          ? 2
                          : 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  translateText(
                    veryCompact
                        ? '"Great things in business are done by a team."'
                        : '"Great things in business are\nnever done by one person.\nThey’re done by a team of\npeople."',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6E6863),
                    fontSize: quoteFontSize,
                    height: quoteLineHeight,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: veryCompact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                  height: veryCompact
                      ? 6
                      : compact
                          ? 8
                          : 14),
              Container(
                width: 58,
                height: 1,
                color: const Color(0xFFD0A244),
              ),
              SizedBox(
                  height: veryCompact
                      ? 8
                      : compact
                          ? 12
                          : 24),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _teamBorder),
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: _teamMuted,
                  size: veryCompact
                      ? 20
                      : compact
                          ? 22
                          : 28,
                ),
              ),
              SizedBox(
                  height: veryCompact
                      ? 8
                      : compact
                          ? 10
                          : 18),
              Text(
                messageText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _teamInk,
                  fontSize: veryCompact
                      ? 16
                      : compact
                          ? 18
                          : 22,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!veryCompact) ...[
                SizedBox(height: compact ? 5 : 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    translateText(
                      'Start building your world-class salon team. Add stylists, therapists, and coordinators to manage their schedules and performance.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _teamMuted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: compact ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (onAddTeamMember != null) ...[
                SizedBox(
                    height: veryCompact
                        ? 12
                        : compact
                            ? 16
                            : 24),
                SizedBox(
                  width: double.infinity,
                  height: veryCompact ? 44 : 50,
                  child: ElevatedButton.icon(
                    onPressed: onAddTeamMember,
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: Text(
                      translateText('Invite Team Member'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0A244),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
