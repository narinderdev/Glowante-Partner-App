import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';
import 'team_online_availability_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _assignServicesBackground = Color(0xFFFBFAF8);
const Color _assignServicesBorder = Color(0xFFE8DED6);
const Color _assignServicesText = Color(0xFF2B241D);
const Color _assignServicesMuted = Color(0xFF8C7A66);
const Color _assignServicesSurface = Colors.white;
const Color _assignServicesSoftGold = Color(0xFFFFF3D5);

class AddTeamSelectServices extends StatefulWidget {
  final Map<String, dynamic> teamMemberData;

  const AddTeamSelectServices({super.key, required this.teamMemberData});

  @override
  State<AddTeamSelectServices> createState() => _AddTeamSelectServicesState();
}

class _AddTeamSelectServicesState extends State<AddTeamSelectServices> {
  bool _loading = true;
  bool _submitting = false;

  // API response (categories with nested subCategories & services)
  List<Map<String, dynamic>> _categories = [];

  // Track selections by branch service id
  final Map<int, bool> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final Map<int, bool> _expandedCategories = {};
  final Map<int, bool> _expandedSubcategories = {};

  @override
  void initState() {
    super.initState();
    for (final serviceId in _initialSelectedServiceIds()) {
      _selected[serviceId] = true;
    }
    _fetchServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<int> _initialSelectedServiceIds() {
    final ids = <int>{};
    final bool isEditFlow = widget.teamMemberData['isEdit'] == true;

    void addId(dynamic value) {
      if (value is int) {
        ids.add(value);
      } else if (value is num) {
        ids.add(value.toInt());
      } else if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) ids.add(parsed);
      }
    }

    final directIds = widget.teamMemberData['branchServiceIds'];
    if (directIds is List) {
      for (final id in directIds) {
        addId(id);
      }
    }

    if (isEditFlow) {
      final userBranchServices = widget.teamMemberData['userBranchServices'];
      if (userBranchServices is List) {
        for (final item in userBranchServices) {
          if (item is! Map) continue;
          addId(item['branchServiceId']);
          final branchService = item['branchService'];
          if (branchService is Map) {
            addId(branchService['id']);
          }
        }
      }
    }

    return ids.toList();
  }

  Future<void> _fetchServices() async {
    setState(() => _loading = true);
    try {
      final int branchId = (widget.teamMemberData['branchId'] as int?) ?? 0;
      final resp = await ApiService().getBranchService(branchId: branchId);
      if (resp['success'] == true) {
        setState(() {
          _categories = (resp['data']?['categories'] as List? ?? const [])
              .whereType<Map>()
              .map((cat) => Map<String, dynamic>.from(cat))
              .toList();
          if (_selected.isEmpty) {
            for (final serviceId in _allServiceIds()) {
              _selected[serviceId] = true;
            }
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showError(resp['message']?.toString() ?? 'Failed to load services.');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Unable to load services. Please try again.');
    }
  }

  bool _matchesServiceQuery(Map<String, dynamic> item, String query) {
    if (query.isEmpty) return true;
    return [
      item['displayName'],
      item['name'],
      item['serviceName'],
      item['title'],
      item['description'],
      item['code'],
    ].any((value) =>
        (value ?? '').toString().toLowerCase().contains(query.toLowerCase()));
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
  }
// ---------- Helpers: put inside _AddTeamSelectServicesState ----------

  /// Convert "08:00 AM" / "8:00 pm" → "08:00:00".
  String _to24h(String input) {
    final s = input.trim();

    final reg24 = RegExp(r'^(\d{1,2}):([0-5]\d)(?::([0-5]\d))?$');
    final match24 = reg24.firstMatch(s);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1) ?? '');
      final minute = int.tryParse(match24.group(2) ?? '');
      final second = int.tryParse(match24.group(3) ?? '') ?? 0;
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        return s;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
    }

    // match 8:05 am / 08:05 PM / 12:00 am etc.
    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
    final m = reg12.firstMatch(s);
    if (m != null) {
      int h = int.parse(m.group(1)!);
      final int min = int.parse(m.group(2)!);
      final String mer = m.group(3)!.toUpperCase();
      if (h == 12) h = 0;
      if (mer == 'PM') h += 12;
      final hh = h.toString().padLeft(2, '0');
      final mm = min.toString().padLeft(2, '0');
      return '$hh:$mm:00';
    }

    // if we can’t parse, just return as-is (or throw)
    return s;
  }

  /// Map UI display names to API enum codes. Adjust to your backend’s values.
  String _roleToCode(String name) {
    final n = name.toString().trim().toLowerCase();
    const map = {
      'salon worker': 'salon_worker',
      'worker': 'salon_worker',
      'stylist': 'salon_worker',
      'receptionist': 'salon_receptionist',
      'salon receptionist': 'salon_receptionist',
    };
    return map[n] ?? n.replaceAll(' ', '_'); // fallback to snake_case
  }

  String _specToCode(String name) {
    final n = name.toString().trim().toLowerCase();
    const map = {
      'hair cut': 'hair_cut',
      'haircut': 'hair_cut',
      'facial': 'facial',
      'pedicure': 'pedicure',
    };
    return map[n] ?? n.replaceAll(' ', '_');
  }

  /// Remove nulls and keys the API doesn’t need in body (since branch is in URL).
  Map<String, dynamic> _cleanBody(Map<String, dynamic> m) {
    final copy = Map<String, dynamic>.from(m)
      ..remove('useSalonHours')
      ..remove('otp')
      ..remove('profileImage')
      ..remove('branchId'); // branch comes from URL
    copy.removeWhere((k, v) => v == null);
    return copy;
  }

  /// Build exactly what the API expects.
  // Map<String, dynamic> _buildPayloadForApi(
  //   Map<String, dynamic> base,
  //   List<int> branchServiceIds,
  // ) {
  //   // roles & specs normalization
  //   final roles = (base['roles'] as List? ?? const [])
  //       .map((e) => _roleToCode(e.toString()))
  //       .toList();

  //   final specs = (base['specialities'] as List? ??
  //           base['specializations'] as List? ??
  //           const [])
  //       .map((e) => _specToCode(e.toString()))
  //       .toList();

  //   // schedules normalization to HH:mm
  //   final schedules =
  //       (base['schedules'] as List? ?? const []).map<Map<String, dynamic>>((s) {
  //     final sm = (s as Map).cast<String, dynamic>();
  //     return {
  //       'day': (sm['day'] ?? '').toString().toLowerCase(),
  //       'startTime': _to24h((sm['startTime'] ?? sm['start'] ?? '').toString()),
  //       'endTime': _to24h((sm['endTime'] ?? sm['end'] ?? '').toString()),
  //     };
  //   }).toList();

  //   // countryCode default
  //   final countryCode = (base['countryCode'] ?? '+91').toString();

  //   // joiningDate passthrough (string "YYYY-MM-DD" preferred)
  //   final joiningDate = base['joiningDate'];

  //   final result = <String, dynamic>{
  //     'countryCode': countryCode,
  //     'phoneNumber': base['phoneNumber'],
  //     'firstName': base['firstName'],
  //     'lastName': base['lastName'],
  //     'email': base['email'],
  //     'gender': (base['gender'] ?? '').toString().toLowerCase(),
  //     'joiningDate': joiningDate, // ensure it's "yyyy-MM-dd"
  //     'info': base['info'] ?? base['brief'],
  //     'roles': roles,
  //     'specialities': specs,
  //     'schedules': schedules,
  //     'branchServiceIds': branchServiceIds,
  //     'profilePictureUrl': base['profilePictureUrl'],
  //     'allowOnlineBooking': base['allowOnlineBooking'] ?? false,

  //   };

  //   return _cleanBody(result);
  // }

  Map<String, dynamic> _buildPayloadForApi(
    Map<String, dynamic> base,
    List<int> branchServiceIds,
  ) {
    final roles = (base['roles'] as List? ?? const [])
        .map((e) => _roleToCode(e.toString()))
        .toList();

    final specs = (base['specialities'] as List? ??
            base['specializations'] as List? ??
            const [])
        .map((e) => _specToCode(e.toString()))
        .toList();

    final schedules =
        (base['schedules'] as List? ?? const []).map<Map<String, dynamic>>((s) {
      final sm = (s as Map).cast<String, dynamic>();

      return {
        'day': (sm['day'] ?? '').toString().toLowerCase(),
        'startTime': _to24h((sm['startTime'] ?? sm['start'] ?? '').toString()),
        'endTime': _to24h((sm['endTime'] ?? sm['end'] ?? '').toString()),
      };
    }).toList();

    final countryCode = (base['countryCode'] ?? '+91').toString();

    final result = <String, dynamic>{
      'countryCode': countryCode,
      if (base['originalPhoneNumber'] != null)
        'originalPhoneNumber': base['originalPhoneNumber'],
      if (base['originalEmail'] != null) 'originalEmail': base['originalEmail'],
      'phoneNumber': base['phoneNumber'],
      'firstName': base['firstName'],
      'lastName': base['lastName'],
      'email': base['email'],
      'gender': (base['gender'] ?? '').toString().toLowerCase(),
      'joiningDate': base['joiningDate'],
      'info': base['info'] ?? base['brief'],
      'roles': roles,
      'specialities': specs,
      'schedules': schedules,
      'branchServiceIds': branchServiceIds,
      'profilePictureUrl': base['profilePictureUrl'],
      'allowOnlineBooking': base['allowOnlineBooking'] ?? false,
      'experience': int.tryParse(
            base['experience']?.toString() ?? '',
          ) ??
          0,
      if (base['address'] != null) 'address': base['address'],
    };

    debugPrint('FINAL PAYLOAD TO AVAILABILITY SCREEN: $result');

    return _cleanBody(result);
  }

  List<int> _allServiceIds() {
    final ids = <int>[];
    for (final cat in _visibleCategories()) {
      for (final s in (cat['services'] ?? [])) {
        ids.add((s as Map)['id'] as int); // branch service id
      }
      for (final sub in _visibleSubCategories(cat)) {
        for (final s in ((sub['services'] ?? []) as List)) {
          ids.add((s as Map)['id'] as int); // branch service id
        }
      }
    }
    return ids;
  }

  List<Map<String, dynamic>> _visibleCategories() {
    final query = _searchQuery.trim().toLowerCase();
    final visibleCategories = <Map<String, dynamic>>[];

    for (final category in _categories) {
      final visibleCategoryServices = <Map<String, dynamic>>[];
      final rawCategoryServices = category['services'];
      if (rawCategoryServices is List) {
        for (final rawService in rawCategoryServices) {
          if (rawService is! Map) continue;
          final service = Map<String, dynamic>.from(rawService);
          if (_matchesServiceQuery(service, query)) {
            visibleCategoryServices.add(service);
          }
        }
      }

      final visibleSubCategories = <Map<String, dynamic>>[];
      final rawSubCategories = category['subCategories'];
      if (rawSubCategories is List) {
        for (final rawSubCategory in rawSubCategories) {
          if (rawSubCategory is! Map) continue;
          final subCategory = Map<String, dynamic>.from(rawSubCategory);
          final visibleSubServices = <Map<String, dynamic>>[];
          final rawSubServices = subCategory['services'];
          if (rawSubServices is List) {
            for (final rawService in rawSubServices) {
              if (rawService is! Map) continue;
              final service = Map<String, dynamic>.from(rawService);
              if (_matchesServiceQuery(service, query)) {
                visibleSubServices.add(service);
              }
            }
          }

          if (query.isNotEmpty && visibleSubServices.isEmpty) continue;

          if (query.isNotEmpty) {
            visibleSubCategories.add({
              ...subCategory,
              'services': visibleSubServices,
            });
          } else if (visibleSubServices.isNotEmpty) {
            visibleSubCategories.add({
              ...subCategory,
              'services': visibleSubServices,
            });
          }
        }
      }

      final hasVisibleContent =
          visibleCategoryServices.isNotEmpty || visibleSubCategories.isNotEmpty;
      if (!hasVisibleContent) continue;

      visibleCategories.add({
        ...category,
        'services': visibleCategoryServices,
        'subCategories': visibleSubCategories,
      });
    }

    return visibleCategories;
  }

  List<Map<String, dynamic>> _visibleSubCategories(Map<String, dynamic> cat) {
    final subs = cat['subCategories'] as List? ?? const [];
    return subs
        .whereType<Map>()
        .map((sub) => Map<String, dynamic>.from(sub))
        .where((sub) => ((sub['services'] as List?) ?? const []).isNotEmpty)
        .toList();
  }

  List<int> get _selectedServiceIds =>
      _selected.entries.where((e) => e.value).map((e) => e.key).toList();

  void _popWithSelectedServices({required bool completed}) {
    Navigator.pop(
      context,
      {
        'completed': completed,
        'selectedServiceIds': _selectedServiceIds,
      },
    );
  }

  bool get _allSelected {
    final all = _allServiceIds();
    return all.isNotEmpty && all.every((id) => _selected[id] == true);
  }

  bool get _hasAssignableServices => _allServiceIds().isNotEmpty;

  void _toggleAll(bool? value) {
    for (final id in _allServiceIds()) {
      _selected[id] = value == true;
    }
    setState(() {});
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int priceMinor = (s['priceMinor'] ?? 0) as int;
    final int durationMin = (s['durationMin'] ?? 0) as int;
    final bool checked = _selected[id] ?? false;

    return InkWell(
      onTap: () => setState(() => _selected[id] = !checked),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFFFFAF1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? AppColors.starColor : _assignServicesBorder,
          ),
        ),
        child: Row(
          children: [
            _ServiceSelectionMark(selected: checked),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? translateText('Service') : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _assignServicesText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatMinorAmount(priceMinor)} • $durationMin ${translateText('mins')}",
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _assignServicesMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final int? categoryId = cat['id'] as int?;
    final List services = cat['services'] as List? ?? [];
    final visibleSubs = _visibleSubCategories(cat);

    if (services.isEmpty && visibleSubs.isEmpty) {
      return const SizedBox.shrink();
    }

    final allIds = <int>[
      ...services.map((s) => (s as Map)['id'] as int),
      ...visibleSubs.expand((sub) => ((sub['services'] ?? []) as List)
          .map<int>((s) => (s as Map)['id'] as int)),
    ];

    final int selCount = allIds.where((id) => _selected[id] == true).length;
    final bool searchActive = _searchQuery.trim().isNotEmpty;
    final bool catExpanded = searchActive ||
        (categoryId != null && _expandedCategories[categoryId] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _assignServicesCardDecoration(highlighted: selCount > 0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(
            'add-team-cat-${categoryId ?? 0}-${searchActive ? 'search-${_searchQuery.trim().toLowerCase()}' : 'base'}',
          ),
          initiallyExpanded: catExpanded,
          onExpansionChanged: (expanded) {
            if (categoryId == null) return;
            setState(() => _expandedCategories[categoryId] = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.starColor,
          collapsedIconColor: _assignServicesMuted,
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _assignServicesSoftGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  size: 16,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (cat['displayName'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _assignServicesText,
                  ),
                ),
              ),
              _CountPill(selected: selCount, total: allIds.length),
            ],
          ),
          children: [
            ...services.map<Widget>(
              (s) => _buildServiceItem((s as Map).cast<String, dynamic>()),
            ),
            ...visibleSubs.map<Widget>((subMap) {
              final int? subCategoryId = subMap['id'] as int?;
              final bool subExpanded = searchActive ||
                  (subCategoryId != null &&
                      _expandedSubcategories[subCategoryId] == true);
              final List subServices = subMap['services'] as List? ?? [];
              return Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFAF8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _assignServicesBorder),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey(
                      'add-team-sub-${subCategoryId ?? 0}-${searchActive ? 'search-${_searchQuery.trim().toLowerCase()}' : 'base'}',
                    ),
                    initiallyExpanded: subExpanded,
                    onExpansionChanged: (expanded) {
                      if (subCategoryId == null) return;
                      setState(
                        () => _expandedSubcategories[subCategoryId] = expanded,
                      );
                    },
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    iconColor: AppColors.starColor,
                    collapsedIconColor: _assignServicesMuted,
                    title: Text(
                      (subMap['displayName'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _assignServicesText,
                      ),
                    ),
                    children: subServices
                        .map<Widget>((s) => _buildServiceItem(
                            (s as Map).cast<String, dynamic>()))
                        .toList(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Future<void> _submit() async {
  //   if (_selectedServiceIds.isEmpty) {
  //     _showError('Please select at least one service.');
  //     return;
  //   }

  //   setState(() => _submitting = true);
  //   try {
  //     // Merge selected services into payload (as branchServiceIds)
  //     final payload = Map<String, dynamic>.from(widget.teamMemberData);
  //     payload['branchServiceIds'] = _selectedServiceIds;

  //     final int branchId = (payload['branchId'] as int?) ?? 0;

  //     final response = await ApiService().addTeamMember(branchId, payload);

  //     if (!mounted) return;

  //     if (response['success'] == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Team member added successfully')),
  //       );
  //       Navigator.pushAndRemoveUntil(
  //         context,
  //         MaterialPageRoute(builder: (_) => TeamScreen()),
  //         (route) => false,
  //       );
  //     } else {
  //       _showError(response['message']?.toString() ?? 'Failed to add team member');
  //     }
  //   } catch (e) {
  //     _showError('An unexpected error occurred.');
  //   } finally {
  //     if (mounted) setState(() => _submitting = false);
  //   }
  // }

  Future<void> _goToOnlineAvailability() async {
    if (_selectedServiceIds.isEmpty) {
      Fluttertoast.showToast(
        msg: translateText('Choose at least one service.'),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // Build normalized body
      final payload = _buildPayloadForApi(
        widget.teamMemberData,
        _selectedServiceIds, // List<int>
      );

      final int branchId = (widget.teamMemberData['branchId'] as int?) ?? 0;
      debugPrint(
        '[AddTeamSelectServices] Opening online availability '
        'isEdit=${widget.teamMemberData['isEdit'] == true} '
        'branchId=$branchId selectedServices=$_selectedServiceIds',
      );
      final response = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.teamMemberData['isEdit'] == true
              ? TeamOnlineAvailabilityScreen.editMember(
                  branchId: branchId,
                  userId: (widget.teamMemberData['userId'] as int?) ?? 0,
                  payload: payload,
                )
              : TeamOnlineAvailabilityScreen.addMember(
                  branchId: branchId,
                  payload: payload,
                ),
        ),
      );
      if (!mounted) return;
      if (response == true) {
        Navigator.pop(
          context,
          {
            'completed': true,
            'selectedServiceIds': _selectedServiceIds,
          },
        );
      }
    } catch (e) {
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    Fluttertoast.showToast(msg: translateText(msg));
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _visibleCategories();

    return Scaffold(
      backgroundColor: _assignServicesBackground,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Select Services'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _popWithSelectedServices(completed: false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: MultiStepFlowHeader(
                    currentStep: 3,
                    steps: const [
                      FlowStepItem(stepNumber: 1, label: 'Personal Details'),
                      FlowStepItem(stepNumber: 2, label: 'Schedule'),
                      FlowStepItem(stepNumber: 3, label: 'Services'),
                      FlowStepItem(stepNumber: 4, label: 'Online Availability'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translateText('Choose Services'),
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
                          'Select services this team member can perform at the branch.',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: _assignServicesMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSearchBar(),
                    ],
                  ),
                ),
                if (_hasAssignableServices)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _SelectionSummaryCard(
                      selectedCount: _selectedServiceIds.length,
                      totalCount: _allServiceIds().length,
                      allSelected: _allSelected,
                      onSelectAll: () => _toggleAll(!_allSelected),
                    ),
                  ),
                Expanded(
                  child: visibleCategories.isEmpty
                      ? _EmptyServicesState(
                          isSearchActive: _searchQuery.trim().isNotEmpty,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: visibleCategories.length,
                          itemBuilder: (ctx, i) =>
                              _buildCategory(visibleCategories[i]),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => _popWithSelectedServices(completed: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D2926),
                    side: const BorderSide(color: Color(0xFFE2D3BF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(translateText('Previous')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _goToOnlineAvailability,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          translateText('Next'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _assignServicesBorder),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        cursorColor: AppColors.starColor,
        textInputAction: TextInputAction.search,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
        onChanged: _setSearchQuery,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.starColor,
            size: 24,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _assignServicesMuted),
                  onPressed: () {
                    _searchController.clear();
                    _setSearchQuery('');
                  },
                ),
          hintText: translateText('Find services...'),
          hintStyle: const TextStyle(
            color: Color(0xFF34302C),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onSelectAll,
  });

  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _assignServicesCardDecoration(highlighted: selectedCount > 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _assignServicesSoftGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.handyman_outlined,
              size: 18,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Services selected'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _assignServicesText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$selectedCount/$totalCount',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _assignServicesMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.starColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(
              translateText(allSelected ? 'Clear all' : 'Select all'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSelectionMark extends StatelessWidget {
  const _ServiceSelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.starColor : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.starColor : _assignServicesBorder,
          width: 1.3,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.selected, required this.total});

  final int selected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final active = selected > 0;
    final color = active ? AppColors.starColor : _assignServicesMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$selected/$total',
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

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({this.isSearchActive = false});

  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _assignServicesCardDecoration(),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _assignServicesSoftGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translateText(
                  isSearchActive
                      ? 'No matching services found'
                      : 'No services are available for this branch to assign.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                translateText(
                  isSearchActive
                      ? 'Try a different keyword.'
                      : 'Please select a different branch or add branch services.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

BoxDecoration _assignServicesCardDecoration({bool highlighted = false}) {
  return BoxDecoration(
    color: _assignServicesSurface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: highlighted ? AppColors.starColor : _assignServicesBorder,
    ),
    boxShadow: highlighted
        ? [
            BoxShadow(
              color: AppColors.starColor.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
  );
}
