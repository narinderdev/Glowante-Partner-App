import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import '../utils/api_service.dart';
import '../utils/team_member_completeness.dart';
import 'Addteam.dart';
import 'TeamMemberDetails.dart';
import 'AssignUser.dart';
import 'assign_user_flow_constants.dart';
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

String _teamBranchLabel(Map<String, dynamic>? branch) {
  if (branch == null) return translateText('Select Branch');
  final branchName = branch['branchName']?.toString().trim() ?? '';
  if (branchName.isNotEmpty) return branchName;
  final salonName = branch['salonName']?.toString().trim() ?? '';
  if (salonName.isNotEmpty) return salonName;
  return translateText('Select Branch');
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
  bool _isOpeningViewMember = false;
  bool _isLoadingTeamMembers = false;

  @override
  void initState() {
    super.initState();
    _teamSearchController.addListener(_onTeamSearchChanged);
    _branchSelectionListener = () {
      if (!mounted || _suppressBranchSelectionRefresh) return;
      setState(() {
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
        if (mounted &&
            out.isNotEmpty &&
            (selectedBranchId == null ||
                (preferredBranchId != null &&
                    selectedBranchId != preferredBranchId))) {
          final branchToSelect = preferredBranchId == null
              ? out.first
              : out.firstWhere(
                  (item) => _asInt(item['branchId']) == preferredBranchId,
                  orElse: () => out.first,
                );
          _pickBranch(branchToSelect);
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
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    void push(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty ||
          text.toLowerCase() == 'null' ||
          parts.contains(text)) {
        return;
      }
      parts.add(text);
    }

    push(address['line1']);
    push(address['line2']);
    push(address['village']);
    push(address['district']);
    push(address['city']);
    push(address['state']);
    push(address['postalCode']);
    push(address['country']);
    return parts.join(', ');
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

  Future<void> _refreshTeamMembers() async {
    if (selectedBranchId == null || !mounted) return;
    final future = _getTeamMembersByBranch(selectedBranchId!);
    setState(() => _startTeamMembersFuture(future));
    await future;
  }

  // Pull-to-refresh reloads everything on screen — the salon/branch list
  // and the current branch's team members — not just the member list.
  Future<void> _refreshAll() async {
    if (!mounted) return;
    final branchFuture = _getBranchOptions();
    setState(() => branchOptionsFuture = branchFuture);
    await branchFuture;
    await _refreshTeamMembers();
  }

  void _reloadTeamMembersForFilters({bool showOverlay = true}) {
    final branchId = selectedBranchId;
    if (branchId == null || !mounted) return;
    setState(
      () => _startTeamMembersFuture(
        _getTeamMembersByBranch(branchId),
        showOverlay: showOverlay,
      ),
    );
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
              'Service #$serviceId')
          .toString()
          .trim();
      options.add(
        _TeamServiceFilterOption(
          id: serviceId,
          name: name.isEmpty ? 'Service #$serviceId' : name,
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

  Widget _buildTeamFiltersBar() {
    return _TeamFiltersBar(
      searchController: _teamSearchController,
      hasActiveFilters: _hasActiveTeamFilters,
      onOpenFilters: _showTeamFiltersSheet,
    );
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
                (makeActive
                    ? 'Failed to activate team member'
                    : 'Failed to deactivate team member'));
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
                'Failed to delete team member');
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
    }

    if (selectedBranchId != null) {
      final branchId = selectedBranchId!;
      _startTeamMembersFuture(_getTeamMembersByBranch(branchId));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || selectedBranchId != branchId) return;
        unawaited(_loadTeamServiceOptions(branchId));
      });
    } else {
      teamMembersFuture = null;
      _isLoadingTeamMembers = false;
    }
  }

  bool _memberHasAssignments(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    return rawAssignments is List && rawAssignments.isNotEmpty;
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
      final refresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTeamScreen(
            branchId: selectedBranch!['branchId'],
            salonId: selectedBranch!['salonId'],
            salonName: selectedBranch!['salonName'],
          ),
        ),
      );
      if (!mounted) return;
      if (refresh == true) {
        setState(() => _startTeamMembersFuture(
            _getTeamMembersByBranch(selectedBranchId!)));
        Fluttertoast.showToast(
            msg: translateText("Team member added successfully"));
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

  Future<void> _openEditMember(Map<String, dynamic> member) async {
    if (selectedBranch == null) return;
    FocusScope.of(context).unfocus();
    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTeamScreen(
          branchId: selectedBranch!['branchId'],
          salonId: selectedBranch!['salonId'],
          salonName: selectedBranch!['salonName'],
          isEdit: true,
          initialMember: Map<String, dynamic>.from(member),
        ),
      ),
    );
    if (refresh == true) {
      await _refreshTeamMembers();
    }
  }

  Future<void> _openAssignMember(Map<String, dynamic> member) async {
    if (!_teamIsActiveEntity(member)) {
      Fluttertoast.showToast(
        msg: translateText(
          'Inactive team members cannot be assigned to another branch.',
        ),
      );
      return;
    }

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
    if (assigned == true) {
      await _refreshTeamMembers();
    }
  }

  Future<void> _openViewMember(Map<String, dynamic> member) async {
    if (_isOpeningViewMember) return;

    final userId = _teamAsInt(member['id']) ?? 0;
    if (userId == 0) return;

    final branchId = selectedBranchId ??
        _teamAsInt(_teamFirstAssignmentBranchId(member['userBranches']));
    if (branchId == null) return;

    if (mounted) {
      setState(() => _isOpeningViewMember = true);
    }

    final ratingSummary =
        _professionalRatings[userId] ?? _TeamRatingSummary.empty;
    Map<String, dynamic> detailMember = Map<String, dynamic>.from(member);

    try {
      final response = await ApiService.getTeamMemberDetails(branchId, userId);
      if (response['success'] == true && response['data'] is Map) {
        detailMember = Map<String, dynamic>.from(
            response['data'] as Map<dynamic, dynamic>);
      }
    } catch (error) {
      debugPrint('Failed to load team member details: $error');
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
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningViewMember = false);
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

  List<OwnerBranchHeaderSelectorOption<int>> _teamBranchOptions(
    List<Map<String, dynamic>> branches,
  ) {
    return branches
        .map((branch) {
          final branchId = _asInt(branch['branchId']);
          if (branchId == null) return null;
          return OwnerBranchHeaderSelectorOption<int>(
            value: branchId,
            label: _teamBranchLabel(branch),
            subtitle: (branch['addressSummary'] ?? '').toString(),
          );
        })
        .whereType<OwnerBranchHeaderSelectorOption<int>>()
        .toList();
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _TeamMembersLoadingView();
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                  final branches = snapshot.data!;

                  return RefreshIndicator(
                    color: AppColors.starColor,
                    onRefresh: () => RefreshFeedback.playAndRun(_refreshAll),
                    child: FutureBuilder<List<dynamic>>(
                      future: teamMembersFuture,
                      builder: (context, teamSnapshot) {
                        final children = <Widget>[
                          if (branches.length > 1) ...[
                            OwnerBranchHeaderSelector<int>(
                              label: _teamBranchLabel(selectedBranch),
                              options: _teamBranchOptions(branches),
                              selectedValue: selectedBranchId,
                              placeholder: translateText('Select Branch'),
                              isInteractive: true,
                              onSelected: (branchId) {
                                final branch = branches.firstWhere(
                                  (item) =>
                                      _asInt(item['branchId']) == branchId,
                                  orElse: () => branches.first,
                                );
                                setState(() => _pickBranch(branch));
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildTeamFiltersBar(),
                          const SizedBox(height: 16),
                        ];

                        final isWaiting = teamSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            teamSnapshot.connectionState ==
                                ConnectionState.none;
                        final members = (teamSnapshot.data ?? const [])
                            .whereType<Map>()
                            .map((item) => Map<String, dynamic>.from(item))
                            .toList();

                        if (isWaiting && members.isEmpty) {
                          // Still fetching and nothing to show yet — never
                          // fall through to the empty-state illustration
                          // just because data hasn't arrived.
                          children.add(
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.72,
                              child: const _TeamMembersLoadingView(),
                            ),
                          );
                        } else if (teamSnapshot.hasError && members.isEmpty) {
                          children.add(
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.45,
                              child: Center(
                                child: Text("Error: ${teamSnapshot.error}"),
                              ),
                            ),
                          );
                        } else if (members.isEmpty) {
                          children.add(
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.72,
                              child: _NoTeamMembersState(
                                onAddTeamMember: selectedBranch == null
                                    ? null
                                    : _openAddMember,
                                message: _hasActiveTeamFilters
                                    ? translateText(
                                        'No team members match the selected filters',
                                      )
                                    : null,
                              ),
                            ),
                          );
                        } else {
                          children.add(
                            _TeamMembersGrid(
                              members: members,
                              selectedBranch: selectedBranch,
                              salons: _salons,
                              statusUpdatingIds: _statusUpdatingIds,
                              deletingMemberIds: _deletingMemberIds,
                              isViewOpening: _isOpeningViewMember,
                              professionalRatings: _professionalRatings,
                              onEditMember: _openEditMember,
                              onDeleteMember: _deleteMember,
                              onToggleMemberActive: _toggleMemberActive,
                              onViewMember: _openViewMember,
                              onAssignMember: _openAssignMember,
                              assignButtonBuilder: _buildAssignButtonChild,
                              memberNameBuilder: _memberDisplayName,
                              memberRoleBuilder: _memberRoleLabel,
                            ),
                          );
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
      floatingActionButton: _hasTeamMembers
          ? FloatingActionButton.extended(
              heroTag: 'salon_teams_add_member_fab',
              onPressed: _openAddMember,
              label: Text(translateText("Add Member")),
              icon: const Icon(Icons.add),
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _TeamMembersLoadingView extends StatelessWidget {
  const _TeamMembersLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.starColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            translateText('Loading team members...'),
            style: const TextStyle(
              color: Color(0xFF6E6259),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.starColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMembersGrid extends StatelessWidget {
  const _TeamMembersGrid({
    required this.members,
    required this.selectedBranch,
    required this.salons,
    required this.statusUpdatingIds,
    required this.deletingMemberIds,
    required this.isViewOpening,
    required this.professionalRatings,
    required this.onEditMember,
    required this.onDeleteMember,
    required this.onToggleMemberActive,
    required this.onViewMember,
    required this.onAssignMember,
    required this.assignButtonBuilder,
    required this.memberNameBuilder,
    required this.memberRoleBuilder,
  });

  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? selectedBranch;
  final List<Map<String, dynamic>> salons;
  final Set<int> statusUpdatingIds;
  final Set<int> deletingMemberIds;
  final bool isViewOpening;
  final Map<int, _TeamRatingSummary> professionalRatings;
  final Future<void> Function(Map<String, dynamic> member) onEditMember;
  final Future<void> Function(int userId) onDeleteMember;
  final Future<void> Function(int userId, bool makeActive) onToggleMemberActive;
  final Future<void> Function(Map<String, dynamic> member) onViewMember;
  final Future<void> Function(Map<String, dynamic> member) onAssignMember;
  final Widget Function(Map<String, dynamic> member) assignButtonBuilder;
  final String Function(Map<String, dynamic> member) memberNameBuilder;
  final String Function(Map<String, dynamic> member) memberRoleBuilder;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1024
        ? 3
        : screenWidth >= 700
            ? 2
            : 1;
    final cardHeight = screenWidth >= 700 ? 342.0 : 328.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TeamListHeader(
          count: members.length,
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final userId = _teamAsInt(member['id']) ?? 0;
            final isActive = _teamIsActiveEntity(member);
            final isStatusUpdating = statusUpdatingIds.contains(userId);
            final isDeleting = deletingMemberIds.contains(userId);
            final ratingSummary =
                professionalRatings[userId] ?? _TeamRatingSummary.empty;

            return _TeamMemberCard(
              member: member,
              name: memberNameBuilder(member),
              role: memberRoleBuilder(member),
              ratingSummary: ratingSummary,
              isActive: isActive,
              isDeleting: isDeleting,
              isStatusUpdating: isStatusUpdating,
              isViewOpening: isViewOpening,
              isDeleteBlocked: false,
              isDeactivateBlocked: false,
              canAssign: selectedBranch != null && salons.isNotEmpty,
              assignButtonChild: assignButtonBuilder(member),
              onEdit: () => onEditMember(member),
              onDelete: () => onDeleteMember(userId),
              onToggleActive: () => onToggleMemberActive(userId, !isActive),
              onView: () {
                unawaited(onViewMember(member));
              },
              onAssign: () => onAssignMember(member),
            );
          },
        ),
      ],
    );
  }
}

class _TeamFiltersBar extends StatelessWidget {
  const _TeamFiltersBar({
    required this.searchController,
    required this.hasActiveFilters,
    required this.onOpenFilters,
  });

  final TextEditingController searchController;
  final bool hasActiveFilters;
  final VoidCallback onOpenFilters;

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
        const SizedBox(width: 10),
        _TeamFilterButton(
          hasActiveFilters: hasActiveFilters,
          onPressed: onOpenFilters,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _teamGold.withValues(alpha: 0.98),
                          const Color(0xFFB88A19),
                          const Color(0xFFDFC77A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F8B6500),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translateText('Filter team members'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                translateText(
                                  'Filters update the list automatically when you apply them.',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _TeamHeaderPill(
                                    label:
                                        '${translateText('Applied')}: $activeFilterCount',
                                  ),
                                  if (_selectedServiceIds.isNotEmpty)
                                    _TeamHeaderPill(
                                      label:
                                          '${translateText('Services')}: ${_selectedServiceIds.length}',
                                    ),
                                  if (_dateFilter != null)
                                    _TeamHeaderPill(
                                      label: DateFormat('MMM d').format(
                                        _dateFilter!,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                            shape: const CircleBorder(),
                          ),
                        ),
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
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ...visibleServices.map(
                                          (service) => _FilterChoiceChip(
                                            label: service.name,
                                            selected: _selectedServiceIds
                                                .contains(service.id),
                                            onSelected: () =>
                                                _toggleService(service.id),
                                          ),
                                        ),
                                        if (_selectedServiceIds.isNotEmpty)
                                          TextButton.icon(
                                            onPressed: _clearServices,
                                            icon: const Icon(
                                              Icons.cleaning_services_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              translateText('Clear services'),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _teamMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
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
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_rounded, size: 19),
                          label: Text(
                            activeFilterCount > 0
                                ? '${translateText('Show results')} ($activeFilterCount)'
                                : translateText('Show results'),
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

class _TeamListHeader extends StatelessWidget {
  const _TeamListHeader({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teamBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 21,
            backgroundColor: _teamGoldLight,
            child: Icon(Icons.groups_2_outlined, color: _teamGold, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Team members'),
                  style: const TextStyle(
                    color: _teamInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  translateText('Total team members'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _teamGoldLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _teamBorder),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _teamGold,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    required this.name,
    required this.role,
    required this.ratingSummary,
    required this.isActive,
    required this.isDeleting,
    required this.isStatusUpdating,
    required this.isViewOpening,
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
  final bool isDeleting;
  final bool isStatusUpdating;
  final bool isViewOpening;
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

  int get _teamExperienceValue {
    final branches = member['userBranches'];

    if (branches is List && branches.isNotEmpty && branches.first is Map) {
      final exp = branches.first['experience'];
      return int.tryParse(exp?.toString() ?? '') ?? 0;
    }

    return int.tryParse(member['experience']?.toString() ?? '') ?? 0;
  }

  List<String> get _setupMissingFields =>
      computeTeamMemberMissingFields(member);

  bool get _needsSetupCompletion => _setupMissingFields.isNotEmpty;

  String get _setupCompletionHint {
    final missing = _setupMissingFields;
    if (missing.isEmpty) return '';
    return '${translateText('Complete setup')} • ${missing.join(', ')}';
  }

  String get _assignedBranchesLabel {
    final rawAssignments = member['userBranches'];
    if (rawAssignments is! List || rawAssignments.isEmpty) {
      return '';
    }

    final labels = <String>[];
    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final branchName = branch is Map
          ? (branch['name'] ?? branch['branchName'] ?? '')
          : assignment['branchName'];
      final text = _cleanText(branchName);
      if (text.isNotEmpty && !labels.contains(text)) {
        labels.add(text);
      }
    }

    return labels.join(', ');
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
    final experienceUnit = _teamExperienceValue <= 1
        ? translateText('year')
        : translateText('years');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teamBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TeamAvatar(
                imageUrl: imageUrl,
                initials: _initials,
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
                        color: _teamInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teamMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_needsSetupCompletion) ...[
                      const SizedBox(height: 8),
                      Tooltip(
                        message: _setupCompletionHint,
                        child: InkWell(
                          onTap: _isBusy ? null : onEdit,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D5),
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: const Color(0xFFE5C36A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: _teamGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  translateText('Setup incomplete'),
                                  style: const TextStyle(
                                    color: _teamGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
              _TeamStatusPill(isActive: isActive),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TeamInfoChip(
                  icon: Icons.workspace_premium_outlined,
                  label: '$_teamExperienceValue $experienceUnit',
                  value: translateText('Experience'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TeamInfoChip(
                  icon: Icons.star_rounded,
                  label: ratingSummary.average.toStringAsFixed(1),
                  value: translateText('Rating'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TeamIconButton(
                icon: Icons.edit_outlined,
                tooltip: translateText('Edit'),
                onPressed: _isBusy ? null : onEdit,
              ),
              const SizedBox(width: 8),
              _TeamIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: translateText('Delete'),
                color: Colors.red,
                isBlocked: false,
                isLoading: isDeleting,
                onPressed: _isBusy ? null : onDelete,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isBusy ? null : onToggleActive,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.starColor,
                    ),
                    foregroundColor: AppColors.starColor,
                    minimumSize: const Size.fromHeight(42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: isStatusUpdating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.starColor,
                          ),
                        )
                      : Text(
                          translateText(isActive ? 'Deactivate' : 'Activate')),
                ),
              ),
            ],
          ),
          if (_assignedBranchesLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${translateText('Assigned branches')}: ',
                    style: const TextStyle(
                      color: _teamInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: _assignedBranchesLabel,
                    style: const TextStyle(
                      color: _teamMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy ? null : onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(translateText('View')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isBusy || !canAssign ? null : onAssign,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.starColor),
                    foregroundColor: AppColors.starColor,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: assignButtonChild,
                ),
              ),
            ],
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
  });

  final String imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          height: 56,
          width: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials),
        ),
      );
    }
    return _InitialsAvatar(initials: initials);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _teamGoldLight,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _teamGold,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamStatusPill extends StatelessWidget {
  const _TeamStatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF18864B) : _teamMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        translateText(isActive ? 'Active' : 'Inactive').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _teamSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teamBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.starColor, size: 18),
          const SizedBox(width: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 10,
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
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: actionColor,
                    strokeWidth: 2,
                  ),
                )
              : Icon(icon, size: 20),
        ),
      ),
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
                  veryCompact
                      ? '"Great things in business are done by a team."'
                      : '"Great things in business are\nnever done by one person.\nThey’re done by a team of\npeople."',
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
                      translateText('Add Team Member'),
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
