import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/api_service.dart';
import 'Addteam.dart';
import 'TeamMemberDetails.dart';
import 'AssignUser.dart';
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

  int? selectedBranchId;
  Map<String, dynamic>?
      selectedBranch; // {branchId, branchName, salonId, salonName}
  Future<List<dynamic>>? teamMembersFuture;
  List<dynamic> _teamMembersCache = [];
  List<Map<String, dynamic>> _salons = const [];
  Map<int, _TeamRatingSummary> _professionalRatings = const {};
  bool _hasTeamMembers = false;
  bool _autoPicked = false;
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

  @override
  void initState() {
    super.initState();
    _teamSearchController.addListener(_onTeamSearchChanged);
    branchOptionsFuture = _getBranchOptions(); // single list for the dropdown
  }

  @override
  void dispose() {
    _teamSearchDebounce?.cancel();
    _teamSearchController.dispose();
    super.dispose();
  }

  /// Flattens salons->branches to branch options:
  /// [{branchId, branchName, salonId, salonName}]
  Future<List<Map<String, dynamic>>> _getBranchOptions() async {
    try {
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
        serviceIds: _selectedTeamServiceIds.toList(growable: false),
        date: _teamDateFilter,
        search: _teamSearchController.text.trim(),
      );

      final members = response['success'] == true && response['data'] is List
          ? List<dynamic>.from(response['data'] as List)
          : <dynamic>[];
      final ratings = await _loadProfessionalRatings(branchId);

      _teamMembersCache = members;
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

  Future<void> _refreshTeamMembers() async {
    if (selectedBranchId == null || !mounted) return;
    final future = _getTeamMembersByBranch(selectedBranchId!);
    setState(() {
      teamMembersFuture = future;
    });
    await future;
  }

  void _reloadTeamMembersForFilters() {
    final branchId = selectedBranchId;
    if (branchId == null || !mounted) return;
    setState(() {
      teamMembersFuture = _getTeamMembersByBranch(branchId);
    });
  }

  void _onTeamSearchChanged() {
    _teamSearchDebounce?.cancel();
    _teamSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      _reloadTeamMembersForFilters,
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

  Future<void> _pickTeamDateFilter() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _teamDateFilter ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null || !mounted) return;
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
      statusFilter: _teamStatusFilter,
      allowOnlineBookingFilter: _allowOnlineBookingFilter,
      dateFilter: _teamDateFilter,
      serviceOptions: _teamServiceOptions,
      selectedServiceIds: _selectedTeamServiceIds,
      isLoadingServices: _isLoadingTeamServices,
      showAllServices: _showAllTeamServices,
      hasActiveFilters: _hasActiveTeamFilters,
      onStatusChanged: _setStatusFilter,
      onOnlineBookingChanged: _setOnlineBookingFilter,
      onPickDate: _pickTeamDateFilter,
      onClearDate: _clearTeamDateFilter,
      onServiceToggled: _toggleTeamServiceFilter,
      onClearServices: _clearTeamServiceFilters,
      onToggleShowAllServices: _toggleShowAllTeamServices,
      onClearAll: _clearTeamFilters,
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
          teamMembersFuture = Future.value(_teamMembersCache);
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

    if (selectedBranchId != null) {
      final branchId = selectedBranchId!;
      teamMembersFuture = _getTeamMembersByBranch(branchId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || selectedBranchId != branchId) return;
        unawaited(_loadTeamServiceOptions(branchId));
      });
    } else {
      teamMembersFuture = null;
    }
  }

  bool _memberHasAssignments(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    return rawAssignments is List && rawAssignments.isNotEmpty;
  }

  String? _salonNameForBranchId(int branchId) {
    for (final salon in _salons) {
      final salonName = (salon['name'] ?? '').toString().trim();
      final branches = salon['branches'] as List? ?? const [];
      for (final branch in branches) {
        if (branch is! Map) continue;
        final rawId = branch['id'];
        final id = rawId is int
            ? rawId
            : rawId is num
                ? rawId.toInt()
                : int.tryParse('${rawId ?? ''}');
        if (id == branchId) {
          return salonName;
        }
      }
    }
    return null;
  }

  String _memberAssignedSalonLabel(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    if (rawAssignments is! List || rawAssignments.isEmpty) {
      return '';
    }

    final salonNames = <String>{};
    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final rawBranchId = branch is Map ? branch['id'] : assignment['branchId'];
      final branchId = rawBranchId is int
          ? rawBranchId
          : rawBranchId is num
              ? rawBranchId.toInt()
              : int.tryParse('${rawBranchId ?? ''}');
      if (branchId == null) continue;
      final salonName = _salonNameForBranchId(branchId);
      if (salonName != null && salonName.isNotEmpty) {
        salonNames.add(salonName);
      }
    }

    if (salonNames.isNotEmpty) {
      return salonNames.join(', ');
    }

    return (selectedBranch?['salonName'] ?? '').toString().trim();
  }

  Widget _buildAssignButtonChild(Map<String, dynamic> member) {
    if (!_memberHasAssignments(member)) {
      return Text(translateText("Assign"));
    }

    final assignedSalonLabel = _memberAssignedSalonLabel(member);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          translateText("Assigned to"),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (assignedSalonLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            assignedSalonLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, height: 1.15),
          ),
        ],
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
        setState(() {
          teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!);
        });
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
    return translateText('Staff');
  }

  Future<void> _openEditMember(Map<String, dynamic> member) async {
    if (selectedBranch == null) return;
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
    if (selectedBranch == null || _salons.isEmpty) return;
    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: branchOptionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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

              // ✅ Auto-pick first branch exactly once
              if (!_autoPicked && branches.isNotEmpty) {
                _autoPicked = true;
                _pickBranch(branches.first);
              }

              return RefreshIndicator(
                color: AppColors.starColor,
                onRefresh: _refreshTeamMembers,
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
                              (item) => _asInt(item['branchId']) == branchId,
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

                    if (teamSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !teamSnapshot.hasData) {
                      children.add(
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.starColor,
                            ),
                          ),
                        ),
                      );
                    } else if (teamSnapshot.hasError) {
                      children.add(
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: Center(
                            child: Text("Error: ${teamSnapshot.error}"),
                          ),
                        ),
                      );
                    } else if (!teamSnapshot.hasData ||
                        teamSnapshot.data!.isEmpty) {
                      children.add(
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.72,
                          child: _NoTeamMembersState(
                            onAddTeamMember:
                                selectedBranch == null ? null : _openAddMember,
                            message: _hasActiveTeamFilters
                                ? translateText(
                                    'No team members match the selected filters',
                                  )
                                : null,
                          ),
                        ),
                      );
                    } else {
                      final members = teamSnapshot.data!
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList();

                      children.add(
                        _TeamMembersGrid(
                          members: members,
                          selectedBranch: selectedBranch,
                          salons: _salons,
                          statusUpdatingIds: _statusUpdatingIds,
                          deletingMemberIds: _deletingMemberIds,
                          professionalRatings: _professionalRatings,
                          onEditMember: _openEditMember,
                          onDeleteMember: _deleteMember,
                          onToggleMemberActive: _toggleMemberActive,
                          onViewMember: (member) {
                            final userId = _asInt(member['id']) ?? 0;
                            final ratingSummary =
                                _professionalRatings[userId] ??
                                    _TeamRatingSummary.empty;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamMemberDetails(
                                  member: member,
                                  salons: _salons,
                                  professionalRating:
                                      ratingSummary.average.toDouble(),
                                  professionalReviewCount: ratingSummary.count,
                                ),
                              ),
                            );
                          },
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

class _TeamMembersGrid extends StatelessWidget {
  const _TeamMembersGrid({
    required this.members,
    required this.selectedBranch,
    required this.salons,
    required this.statusUpdatingIds,
    required this.deletingMemberIds,
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
  final Map<int, _TeamRatingSummary> professionalRatings;
  final Future<void> Function(Map<String, dynamic> member) onEditMember;
  final Future<void> Function(int userId) onDeleteMember;
  final Future<void> Function(int userId, bool makeActive) onToggleMemberActive;
  final void Function(Map<String, dynamic> member) onViewMember;
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
    final cardHeight = screenWidth >= 700 ? 318.0 : 296.0;

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
              isDeleteBlocked: false,
              isDeactivateBlocked: false,
              canAssign: selectedBranch != null && salons.isNotEmpty,
              assignButtonChild: assignButtonBuilder(member),
              onEdit: () => onEditMember(member),
              onDelete: () => onDeleteMember(userId),
              onToggleActive: () => onToggleMemberActive(userId, !isActive),
              onView: () => onViewMember(member),
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
    required this.statusFilter,
    required this.allowOnlineBookingFilter,
    required this.dateFilter,
    required this.serviceOptions,
    required this.selectedServiceIds,
    required this.isLoadingServices,
    required this.showAllServices,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onOnlineBookingChanged,
    required this.onPickDate,
    required this.onClearDate,
    required this.onServiceToggled,
    required this.onClearServices,
    required this.onToggleShowAllServices,
    required this.onClearAll,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final bool? allowOnlineBookingFilter;
  final DateTime? dateFilter;
  final List<_TeamServiceFilterOption> serviceOptions;
  final Set<int> selectedServiceIds;
  final bool isLoadingServices;
  final bool showAllServices;
  final bool hasActiveFilters;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool?> onOnlineBookingChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<int> onServiceToggled;
  final VoidCallback onClearServices;
  final VoidCallback onToggleShowAllServices;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateFilter == null
        ? translateText('Date')
        : DateFormat('yyyy-MM-dd').format(dateFilter!);
    final visibleServices =
        showAllServices ? serviceOptions : serviceOptions.take(3).toList();
    final hiddenServiceCount = serviceOptions.length - visibleServices.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teamBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: translateText('Search by name, phone, or email'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: translateText('Clear search'),
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _teamSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _teamBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _teamBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.starColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChoiceChip(
                  label: translateText('All'),
                  selected: statusFilter == 'all',
                  onSelected: () => onStatusChanged('all'),
                ),
                const SizedBox(width: 8),
                _FilterChoiceChip(
                  label: translateText('Active'),
                  selected: statusFilter == 'active',
                  onSelected: () => onStatusChanged('active'),
                ),
                const SizedBox(width: 8),
                _FilterChoiceChip(
                  label: translateText('Inactive'),
                  selected: statusFilter == 'inactive',
                  onSelected: () => onStatusChanged('inactive'),
                ),
                const SizedBox(width: 8),
                _FilterChoiceChip(
                  label: translateText('Online: All'),
                  selected: allowOnlineBookingFilter == null,
                  onSelected: () => onOnlineBookingChanged(null),
                ),
                const SizedBox(width: 8),
                _FilterChoiceChip(
                  label: translateText('Online: Yes'),
                  selected: allowOnlineBookingFilter == true,
                  onSelected: () => onOnlineBookingChanged(true),
                ),
                const SizedBox(width: 8),
                _FilterChoiceChip(
                  label: translateText('Online: No'),
                  selected: allowOnlineBookingFilter == false,
                  onSelected: () => onOnlineBookingChanged(false),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (dateFilter != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: translateText('Clear date'),
                    onPressed: onClearDate,
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    color: AppColors.starColor,
                  ),
                ],
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onClearAll,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: Text(translateText('Clear filters')),
                    style: TextButton.styleFrom(
                      foregroundColor: _teamMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isLoadingServices) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              color: AppColors.starColor,
              backgroundColor: _teamGoldLight,
              minHeight: 3,
            ),
          ] else if (serviceOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visibleServices.expand(
                    (service) => [
                      _FilterChoiceChip(
                        label: service.name,
                        selected: selectedServiceIds.contains(service.id),
                        onSelected: () => onServiceToggled(service.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  if (serviceOptions.length > 3)
                    TextButton(
                      onPressed: onToggleShowAllServices,
                      child: Text(
                        showAllServices
                            ? translateText('Show less')
                            : '${translateText('Show more')} ($hiddenServiceCount)',
                      ),
                    ),
                  if (selectedServiceIds.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onClearServices,
                      icon: const Icon(
                        Icons.cleaning_services_outlined,
                        size: 18,
                      ),
                      label: Text(translateText('Clear services')),
                      style: TextButton.styleFrom(
                        foregroundColor: _teamMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
    return ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: _teamGoldLight,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? _teamGold : _teamMuted,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected ? AppColors.starColor : _teamBorder,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
  final bool isDeleteBlocked;
  final bool isDeactivateBlocked;
  final bool canAssign;
  final Widget assignButtonChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onView;
  final VoidCallback onAssign;

  bool get _isBusy => isDeleting || isStatusUpdating;
  int get _teamExperienceValue {
    final branches = member['userBranches'];

    if (branches is List && branches.isNotEmpty && branches.first is Map) {
      final exp = branches.first['experience'];
      return int.tryParse(exp?.toString() ?? '') ?? 0;
    }

    return int.tryParse(member['experience']?.toString() ?? '') ?? 0;
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
                      fontSize: 12,
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
