import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/api_service.dart';
import 'AssignUserSlots.dart'; // 👈 NEW: Step 3 screen
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../widgets/multi_step_flow_header.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _assignServicesBackground = Color(0xFFFBFAF8);
const Color _assignServicesBorder = Color(0xFFE8DED6);
const Color _assignServicesText = Color(0xFF2B241D);
const Color _assignServicesMuted = Color(0xFF8C7A66);
const Color _assignServicesSurface = Colors.white;
const Color _assignServicesSoftGold = Color(0xFFFFF3D5);

class SelectServicesAssignUser extends StatefulWidget {
  final int salonId;
  final int userId;
  final int branchId;
  final String joinedAt;
  final Map<String, dynamic> member; // ✅ add
  final List<Map<String, dynamic>> salons;
  final Map<int, bool>? initialSelected;

  const SelectServicesAssignUser({
    super.key,
    required this.salonId,
    required this.userId,
    required this.branchId,
    required this.joinedAt,
    required this.member, // ✅ add
    required this.salons,
    this.initialSelected,
  });

  @override
  State<SelectServicesAssignUser> createState() =>
      _SelectServicesAssignUserState();
}

class _SelectServicesAssignUserState extends State<SelectServicesAssignUser> {
  List categories = [];
  final Map<int, bool> selected = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final Map<int, bool> _expandedCategories = {};
  final Map<int, bool> _expandedSubcategories = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      selected.addAll(widget.initialSelected!);
    }
    _fetchServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    try {
      final resp = await ApiService()
          .getBranchService(branchId: widget.branchId); // ✅ branch not salon
      if (resp['success'] == true) {
        setState(() {
          categories = resp['data']?['categories'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<int> get selectedServiceIds =>
      selected.entries.where((e) => e.value).map((e) => e.key).toList();

  bool get allSelected {
    final allIds = _allServiceIds();
    return allIds.isNotEmpty && allIds.every((id) => selected[id] == true);
  }

  void toggleAll(bool? value) {
    for (final id in _allServiceIds()) {
      selected[id] = value == true;
    }
    setState(() {});
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

  List<Map<String, dynamic>> _visibleCategories() {
    final query = _searchQuery.trim().toLowerCase();
    final visibleCategories = <Map<String, dynamic>>[];

    for (final rawCategory in categories) {
      if (rawCategory is! Map) continue;
      final category = Map<String, dynamic>.from(rawCategory);

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
      if (query.isEmpty && !hasVisibleContent) continue;
      if (query.isNotEmpty && !hasVisibleContent) continue;

      visibleCategories.add({
        ...category,
        'services': visibleCategoryServices,
        'subCategories': visibleSubCategories,
      });
    }

    return visibleCategories;
  }

  List<int> _allServiceIds() {
    final ids = <int>[];
    for (final cat in _visibleCategories()) {
      for (final s in (cat['services'] ?? [])) {
        ids.add((s as Map)['id'] as int); // ✅ branch service id
      }
      for (final sub in _visibleSubCategories(cat)) {
        for (final s in ((sub['services'] ?? []) as List)) {
          ids.add((s as Map)['id'] as int); // ✅ branch service id
        }
      }
    }
    return ids;
  }

  List<Map<String, dynamic>> _visibleSubCategories(Map<String, dynamic> cat) {
    final subs = cat['subCategories'] as List? ?? const [];
    return subs
        .whereType<Map>()
        .map((sub) => Map<String, dynamic>.from(sub))
        .where((sub) => ((sub['services'] as List?) ?? const []).isNotEmpty)
        .toList();
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int price = (s['priceMinor'] ?? 0) as int;
    final int duration = (s['durationMin'] ?? 0) as int;
    final bool checked = selected[id] ?? false;

    return InkWell(
      onTap: () => setState(() => selected[id] = !checked),
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
                    "${formatMinorAmount(price)} • $duration ${translateText('mins')}",
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
    final List<Map<String, dynamic>> subs = _visibleSubCategories(cat);

    final allIds = [
      ...services.map((s) => (s as Map)['id'] as int),
      ...subs.expand((sub) => ((sub['services'] ?? []) as List)
          .map((s) => (s as Map)['id'] as int)),
    ];
    final int selCount = allIds.where((id) => selected[id] == true).length;
    final bool searchActive = _searchQuery.trim().isNotEmpty;
    final bool catExpanded = searchActive ||
        (categoryId != null && _expandedCategories[categoryId] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _assignServicesCardDecoration(
        highlighted: selCount > 0,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(
            'assign-cat-${categoryId ?? 0}-${searchActive ? 'search-${_searchQuery.trim().toLowerCase()}' : 'base'}',
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
                  cat['displayName']?.toString() ?? '',
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
            ...subs.map<Widget>((subMap) {
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
                      'assign-sub-${subCategoryId ?? 0}-${searchActive ? 'search-${_searchQuery.trim().toLowerCase()}' : 'base'}',
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
                      subMap['displayName']?.toString() ?? '',
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
                        .map<Widget>(
                          (s) => _buildServiceItem(
                            (s as Map).cast<String, dynamic>(),
                          ),
                        )
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

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _visibleCategories();
    return Scaffold(
      backgroundColor: _assignServicesBackground,
      appBar: buildProfileSubpageAppBar(
        title: translateText("Assign User"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(
            context,
            {
              'completed': false,
              'selectedServiceIds': selectedServiceIds,
            },
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.starColor),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MultiStepFlowHeader(
                        currentStep: 2,
                        useIcons: true,
                        steps: const [
                          FlowStepItem(
                            stepNumber: 1,
                            label: 'Select Branches',
                            icon: Icons.place_outlined,
                          ),
                          FlowStepItem(
                            stepNumber: 2,
                            label: 'Choose Services',
                            icon: Icons.handyman_outlined,
                          ),
                          FlowStepItem(
                            stepNumber: 3,
                            label: 'Schedule',
                            icon: Icons.calendar_today_outlined,
                          ),
                          FlowStepItem(
                            stepNumber: 4,
                            label: 'Complete',
                            icon: Icons.check_circle_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

                if (_allServiceIds().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _SelectionSummaryCard(
                      selectedCount: selectedServiceIds.length,
                      totalCount: _allServiceIds().length,
                      allSelected: allSelected,
                      onSelectAll: () => toggleAll(!allSelected),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // children: [
                  //   Text(
                  //     "User ID: ${widget.userId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 4),
                  //   Text(
                  //     "Joined At: ${widget.joinedAt}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //    SizedBox(height: 4),
                  //   Text(
                  //     "Salon ID: ${widget.salonId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 4),
                  //   Text(
                  //     "Branch ID: ${widget.branchId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 12),
                  // ],
                ),

                // Categories
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
                  onPressed: () => Navigator.pop(
                    context,
                    {
                      'completed': false,
                      'selectedServiceIds': selectedServiceIds,
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.starColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    translateText("Back"),
                    style: const TextStyle(
                      color: AppColors.starColor,
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final ids = selectedServiceIds;
                    if (ids.isEmpty) {
                      Fluttertoast.showToast(
                        msg: translateText('Choose at least one service.'),
                      );
                      return;
                    }

                    // ✅ Add salonId & branchId
                    final payload = {
                      "userId": widget.userId,
                      "joinedAt": widget.joinedAt,
                      "salonId": widget.salonId,
                      "branchId": widget.branchId,
                      "branchServiceIds": ids,
                    };

                    debugPrint("Assign user services payload: $payload");
                    final navigator = Navigator.of(context);

                    // 👉 Navigate to Step 3
                    final assigned = await navigator.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AssignUserSlot(
                          salonId: widget.salonId,
                          branchId: widget.branchId,
                          userId: widget.userId,
                          selectedServiceIds: ids,
                          member: widget.member, // ✅ pass to Step 2
                          salons: widget.salons,
                          joinedAt: widget.joinedAt, // 👈 don’t forget this
                        ),
                      ),
                    );
                    if (!mounted) return;
                    if (assigned == true) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        navigator.pop(true);
                      });
                      return;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    translateText("Next"),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
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
        border: Border.all(color: const Color(0xFFD9CBBB)),
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
                      : 'No services available',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _assignServicesText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                translateText(
                  isSearchActive
                      ? 'Try a different search term.'
                      : 'No services are available for this branch to assign.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _assignServicesMuted,
                  height: 1.35,
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
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: highlighted ? AppColors.starColor : _assignServicesBorder,
      width: highlighted ? 1.2 : 1,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
}
