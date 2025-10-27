// lib/screens/category_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for TextInputFormatter
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import '../Viewmodels/AddCategory.dart';
import 'AddServices.dart';
import '../services/language_listener.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

/// Shared function signature for opening the subcategory sheet
typedef SubcategoryOp = Future<void> Function({
  Map<String, dynamic>? subCategory,
  required int categoryId,
});

/// Ensures the first alphabetic character the user types is uppercase
class FirstLetterUpperFormatter extends TextInputFormatter {
  const FirstLetterUpperFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldV,
    TextEditingValue newV,
  ) {
    final t = newV.text;
    final i = RegExp(r'[A-Za-z]').firstMatch(t)?.start;
    if (i == null) return newV; // no letters yet
    if (t[i] == t[i].toUpperCase()) return newV; // already upper
    final fixed = t.replaceRange(i, i + 1, t[i].toUpperCase());
    return TextEditingValue(text: fixed, selection: newV.selection);
  }
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final Map<int, bool> _expandedSubcategories = {};
  int? _selectedSalonId;
  Map<String, dynamic>? _selectedSalon;
  final ScrollController _catalogScrollController = ScrollController();
  double? _pendingScrollOffset;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salonCubit = context.read<SalonListCubit>();

      if (salonCubit.state.salons.isEmpty) {
        salonCubit.loadSalons();
      } else if (salonCubit.state.selectedSalon != null) {
        final Map<String, dynamic> selectedSalon =
            Map<String, dynamic>.from(salonCubit.state.selectedSalon!);
        final int? branchId = _asInt(selectedSalon['branchId']);
        final int? salonId = _asInt(selectedSalon['salonId']);
        setState(() {
          _selectedSalon = selectedSalon;
          _selectedSalonId = branchId ?? salonId;
        });
      }
    });
  }

  void _rememberScrollPosition() {
    if (_catalogScrollController.hasClients) {
      _pendingScrollOffset = _catalogScrollController.offset;
    }
  }

  void _restoreScrollPosition() {
    if (_pendingScrollOffset == null) return;
    final targetOffset = _pendingScrollOffset!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_catalogScrollController.hasClients) return;
      final position = _catalogScrollController.position;
      final clamped = targetOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _catalogScrollController.jumpTo((clamped as num).toDouble());
    });
    _pendingScrollOffset = null;
  }

  @override
  void dispose() {
    _catalogScrollController.dispose();
    super.dispose();
  }

  // ---------- SALON HANDLING ----------
  // void _onSalonSelected(int? value, List<Map<String, dynamic>> salons) {
  //   if (value == null) return;

  //   Map<String, dynamic>? selected;
  //   for (final salon in salons) {
  //     final dynamic rawId = salon['id'];
  //     final int? salonId =
  //         rawId is int ? rawId : int.tryParse(rawId.toString());
  //     if (salonId == value) {
  //       selected = Map<String, dynamic>.from(salon as Map);
  //       break;
  //     }
  //   }

  //   if (selected == null) return;

  //   final int salonId = value;
  //   setState(() {
  //     _selectedSalonId = salonId;
  //     _selectedSalon = {
  //       'salonId': salonId,
  //       'salonName': selected?['name'],
  //     };
  //     _expandedSubcategories.clear();
  //   });

  //   context.read<SalonListCubit>().setSelectedSalon(_selectedSalon!);
  //   final categoryCubit = context.read<CategoryCubit>();
  //   categoryCubit.resetCategories();
  //   categoryCubit.loadCategories(salonId);
  // }
void _onSalonSelected(int? value, List<Map<String, dynamic>> salons) {
  if (value == null) return;

  Map<String, dynamic>? selectedSalon;
  Map<String, dynamic>? selectedBranch;

  for (final salon in salons) {
    for (final branch in salon['branches'] ?? []) {
      if (branch['id'] == value) {
        selectedSalon = salon;
        selectedBranch = branch;
        break;
      }
    }
    if (selectedBranch != null) break;
  }

  if (selectedBranch == null) return;

  final Map<String, dynamic> branch = Map<String, dynamic>.from(selectedBranch);
  final Map<String, dynamic> salon = Map<String, dynamic>.from(selectedSalon!);
  final int? branchIdFromMap = _asInt(branch['id']);
  final int? salonId = _asInt(salon['id']);
  final int? effectiveBranchId = branchIdFromMap ?? value;
  if (effectiveBranchId == null || salonId == null) return;

  setState(() {
    _selectedSalonId = effectiveBranchId;
    _selectedSalon = {
      'salonId': salonId,
      'salonName': salon['name'],
      'branchId': effectiveBranchId,
      'branchName': branch['name'],
    };
  });

  context.read<SalonListCubit>().setSelectedSalon(_selectedSalon!);
  final categoryCubit = context.read<CategoryCubit>();
  categoryCubit.resetCategories();
  categoryCubit.loadCategories(effectiveBranchId);
}

// ---------- ADD / EDIT CATEGORY ----------
  Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
    if (_selectedSalon == null) {
      _toast('Select a salon first.');
      return;
    }

    final int? branchId =
        _asInt(_selectedSalon?['branchId']) ?? _asInt(_selectedSalon?['salonId']);
    if (branchId == null) {
      _toast('Missing branch information.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditCategorySheet(
        category: category,
        branchId: branchId,
      ),
    );
  }

  // ---------- ADD / EDIT SUBCATEGORY ----------
  Future<void> _openSubcategorySheet({
    Map<String, dynamic>? subCategory,
    required int categoryId,
  }) async {
    if (_selectedSalon == null) return;

    final branchId = _selectedSalon!['branchId'] as int;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditSubcategorySheet(
        subCategory: subCategory,
        branchId: branchId, // sheet will call the cubit & show loader
        categoryId: categoryId, // needed for add
      ),
    );
  }

  // ---------- CONFIRM DELETE CATEGORY ----------
  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    if (_selectedSalon == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: translateText('Delete Category'),
        message:
            translateText('Are you sure you want to delete this category?'),
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    _rememberScrollPosition();
   final branchId = _selectedSalon!['branchId'] as int;
    try {
      await context.read<CategoryCubit>().deleteCategory(
            branchId,
            category['id'] as int,
          );
    } finally {
      _restoreScrollPosition();
    }
  }

  // ---------- CONFIRM DELETE SUBCATEGORY ----------
  Future<void> _confirmDeleteSubCategory(
    Map<String, dynamic> subCategory,
  ) async {
    if (_selectedSalon == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: translateText('Delete Subcategory'),
        message:
            translateText('Are you sure you want to delete this subcategory?'),
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    _rememberScrollPosition();
  final branchId = _selectedSalon!['branchId'] as int;
    try {
      await context.read<CategoryCubit>().deleteSubCategory(
            branchId,
            subCategory['id'] as int,
          );
    } finally {
      _restoreScrollPosition();
    }
  }

  // ---------- EDIT SERVICE ----------
  Future<void> _showUpdateServiceSheet(Map<String, dynamic> service) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditServiceSheet(service: service),
    );

    if (!mounted || result == null) return;

 final branchId = _selectedSalon?['branchId'] as int? ?? _selectedSalon!['salonId'] as int;
context.read<CategoryCubit>().updateService(
  branchId,
  result['serviceId'] as int,
  result['payload'] as Map<String, dynamic>,
);
  }

  // ---------- CONFIRM DELETE SERVICE ----------
  Future<void> _confirmDeleteService(int serviceId) async {
    if (_selectedSalon == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: translateText('Delete Service'),
        message: translateText('Are you sure you want to delete this service?'),
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    _rememberScrollPosition();
    final salonId = _selectedSalon!['branchId'] as int;
    try {
      await context.read<CategoryCubit>().deleteService(salonId, serviceId);
    } finally {
      _restoreScrollPosition();
    }
  }

  // ---------- OPEN ADD SERVICE SCREEN ----------
  Future<void> _openAddService(
    Map<String, dynamic> category,
    List<dynamic> categories,
  ) async {
    if (_selectedSalon == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddServices(
          branchId: _selectedSalon!['branchId'] as int,
          selectedCategory: category,
          categories: categories,
        ),
      ),
    );

    if (result == true) {
      // Refresh categories/services after adding a service
      await _refreshData();
    }
  }

  void _autoPickFirstSalon(SalonListState state) {
    if (_selectedSalon != null) return;
    if (state.salons.isEmpty) return;

    Map<String, dynamic>? firstSalonWithBranch;
    Map<String, dynamic>? firstBranch;

    for (final rawSalon in state.salons) {
      final salon = Map<String, dynamic>.from(rawSalon);
      final branches = salon['branches'];
      if (branches is List && branches.isNotEmpty) {
        final branch = branches.first;
        if (branch is Map) {
          firstSalonWithBranch = salon;
          firstBranch = Map<String, dynamic>.from(branch);
          break;
        }
      }
      firstSalonWithBranch ??= salon; // fallback if no salon has branches
    }

    if (firstBranch != null && firstSalonWithBranch != null) {
      final Map<String, dynamic> branch = firstBranch;
      final Map<String, dynamic> salon = firstSalonWithBranch;
      final int? branchId = _asInt(branch['id']);
      final int? salonId = _asInt(salon['id']);
      if (branchId == null || salonId == null) return;

      setState(() {
        _selectedSalonId = branchId;
        _selectedSalon = {
          'salonId': salonId,
          'salonName': salon['name'],
          'branchId': branchId,
          'branchName': branch['name'],
        };
        _expandedSubcategories.clear();
      });

      context.read<SalonListCubit>().setSelectedSalon(_selectedSalon!);
      final categoryCubit = context.read<CategoryCubit>();
      categoryCubit.resetCategories();
      categoryCubit.loadCategories(branchId);
      return;
    }

    final Map<String, dynamic> fallbackSalon =
        Map<String, dynamic>.from(state.salons.first);
    final int? fallbackSalonId = _asInt(fallbackSalon['id']);
    if (fallbackSalonId == null) return;

    setState(() {
      _selectedSalonId = fallbackSalonId;
      _selectedSalon = {
        'salonId': fallbackSalonId,
        'salonName': fallbackSalon['name'],
      };
      _expandedSubcategories.clear();
    });

    context.read<SalonListCubit>().setSelectedSalon(_selectedSalon!);
    final categoryCubit = context.read<CategoryCubit>();
    categoryCubit.resetCategories();
    categoryCubit.loadCategories(fallbackSalonId);
  }

// ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    final salonState = context.watch<SalonListCubit>().state;
    final CategoryState catState = context.watch<CategoryCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.starColor,
      body: MultiBlocListener(
        listeners: [
          BlocListener<CategoryCubit, CategoryState>(
            listenWhen: (previous, current) =>
                previous.message != current.message,
            listener: (context, state) {
              if (state.message != null) {
                _toast(state.message!);
                context.read<CategoryCubit>().clearMessage();
              }
            },
          ),
          BlocListener<SalonListCubit, SalonListState>(
            listenWhen: (prev, curr) =>
                prev.salons != curr.salons ||
                prev.selectedSalon != curr.selectedSalon,
            listener: (context, salonState) {
              _autoPickFirstSalon(salonState);
            },
          ),
        ],
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _HeaderSection(
                    salonState: salonState,
                    selectedSalonId: _selectedSalonId,
                    selectedSalon: _selectedSalon,
                    onSalonSelected: _onSalonSelected,
                    onRefresh: _handleManualRefresh,
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: _buildCatalogueContent(catState),
                    ),
                  ),
                ],
              ),
              if (catState.isSubmitting) _buildLoaderOverlay(),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedSalon == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'catalogueFab',
              onPressed: () => _showAddCategorySheet(),
              icon: Icon(Icons.add_rounded, size: 18,),
              label: Text(translateText('New Category'),style: const TextStyle(
            fontSize: 13, // 🔹 smaller font
            fontWeight: FontWeight.w600,
          ),),
              backgroundColor: AppColors.starColor,
              foregroundColor: AppColors.white,
              extendedPadding: const EdgeInsets.symmetric(
          horizontal: 10, // 🔹 reduces width
          vertical: 0,    // 🔹 reduces height
        ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCatalogueContent(CategoryState catState) {
    return RefreshIndicator(
      color: AppColors.starColor,
      displacement: 32,
      onRefresh: _refreshData,
      child: ListView(
        controller: _catalogScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 140),
        children: [
          if (_selectedSalon == null) ...[
            _EmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: translateText('Choose a salon'),
              subtitle: translateText(
                  'Pick a salon above to start managing its catalogue.'),
            ),
          ] else ...[
            if (catState.isLoading && catState.categories.isEmpty)
              const _LoaderCard()
            else if (catState.status == CategoryStatus.failure &&
                catState.categories.isEmpty)
              _ErrorCard(
                message: catState.message ?? 'Failed to load categories',
                onRetry: _refreshData,
              )
            else ...[
              if (catState.isLoading)
                _InlineProgress(
                    message: translateText('Refreshing catalogue...')),
              _CategoryList(
                categories: catState.categories,
                onAddSubcategory: _openSubcategorySheet,
                onEditSubcategory: _openSubcategorySheet,
                onAddServices: _openAddService,
                onEditCategory: _showAddCategorySheet,
                onDeleteCategory: _confirmDeleteCategory,
                onDeleteSubcategory: _confirmDeleteSubCategory,
                onEditService: _showUpdateServiceSheet,
                onDeleteService: _confirmDeleteService,
                expanded: _expandedSubcategories,
                toggleExpanded: (id) => setState(() {
                  _expandedSubcategories[id] =
                      !(_expandedSubcategories[id] ?? false);
                }),
              ),
            ],
          ],
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _handleManualRefresh() async {
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (_selectedSalon != null) {
      final int? loadId =
          _asInt(_selectedSalon?['branchId']) ?? _asInt(_selectedSalon?['salonId']);
      if (loadId != null) {
        context.read<CategoryCubit>().loadCategories(loadId);
      } else {
        context.read<SalonListCubit>().loadSalons();
      }
    } else {
      context.read<SalonListCubit>().loadSalons();
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // ---------- OVERLAY ----------
  Widget _buildLoaderOverlay() {
    return const Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: Colors.black45),
          Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.salonState,
    required this.selectedSalonId,
    required this.selectedSalon,
    required this.onSalonSelected,
    required this.onRefresh,
  });

  final SalonListState salonState;
  final int? selectedSalonId;
  final Map<String, dynamic>? selectedSalon;
  final void Function(int?, List<Map<String, dynamic>>) onSalonSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final List<Map<String, dynamic>> salons = salonState.salons
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // final List<DropdownMenuItem<int>> salonItems = <DropdownMenuItem<int>>[];
    // for (final salon in salons) {
    //   final dynamic rawId = salon['id'];
    //   final int? salonId =
    //       rawId is int ? rawId : int.tryParse(rawId.toString());
    //   if (salonId == null) continue;
    //   final String salonTitle =
    //       salon['name']?.toString().trim().isNotEmpty == true
    //           ? salon['name'].toString()
    //           : 'Salon';
    //   salonItems.add(
    //     DropdownMenuItem<int>(
    //       value: salonId,
    //       child: Row(
    //         children: [
    //           Container(
    //             padding: const EdgeInsets.all(8),
    //             decoration: BoxDecoration(
    //               color: Colors.grey.shade200,
    //               borderRadius: BorderRadius.circular(8),
    //             ),
    //             child: Icon(
    //               Icons.storefront,
    //               color: AppColors.starColor,
    //               size: 18,
    //             ),
    //           ),
    //           const SizedBox(width: 12),
    //           Expanded(
    //             child: Text(
    //               salonTitle,
    //               style: textTheme.bodyMedium?.copyWith(
    //                 fontWeight: FontWeight.w600,
    //                 color: Colors.black,
    //               ),
    //               overflow: TextOverflow.ellipsis,
    //             ),
    //           ),
    //         ],
    //       ),
    //     ),
    //   );
    // }
final List<DropdownMenuItem<int>> salonItems = <DropdownMenuItem<int>>[];

for (final salon in salons) {
  final String salonName = salon['name'] ?? 'Salon';
  final List branches = salon['branches'] ?? [];

  for (final branch in branches) {
    final int? branchId = branch['id'];
    if (branchId == null) continue;

    final String branchName = branch['name'] ?? 'Branch';
    final String city = branch['address']?['city'] ?? '';

    salonItems.add(
      DropdownMenuItem<int>(
        value: branchId,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront,
                color: AppColors.starColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "$branchName${city.isNotEmpty ? ' ($city)' : ''}",
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

    final bool hasSelection = salonItems.any(
      (item) => item.value == selectedSalonId,
    );
    final int? dropdownValue = hasSelection ? selectedSalonId : null;

    final String? selectedName = selectedSalon?['salonName'] as String?;

    final headerGradient = LinearGradient(
      colors: [AppColors.starColor, AppColors.getStartedButton],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      decoration: BoxDecoration(
        gradient: headerGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText('Catalog'),
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // const SizedBox(height: 4),
                    Text(
                      selectedName ??
                          translateText('Select a salon to get started'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      translateText('Choose Salon'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (salonState.isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                // const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade100,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: dropdownValue,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.starColor,
                      ),
                      dropdownColor: Colors.white,
                      items: salonItems,
                      onChanged: salonItems.isEmpty
                          ? null
                          : (value) => onSalonSelected(value, salons),
                      hint: Text(
                        salonItems.isEmpty
                            ? translateText('No salons available')
                            : translateText('Choose salon'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(height: 20),
          // OutlinedButton.icon(
          //   onPressed: salonState.isLoading ? null : onRefresh,
          //   style: OutlinedButton.styleFrom(
          //     foregroundColor: Colors.white,
          //     side: const BorderSide(color: Colors.white54),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //   ),
          //   icon: const Icon(Icons.refresh_rounded),
          //   label: Text(translateText('Refresh salons')),
          // ),
        ],
      ),
    );
  }
}

class _NoDataPill extends StatelessWidget {
  const _NoDataPill({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _InlineProgress extends StatelessWidget {
  const _InlineProgress({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    const tint = Colors.black;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            ),
            SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(color: tint, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final double lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

/* =======================  UI BUILDING BLOCKS  ======================= */

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    required this.onAddServices,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onDeleteSubcategory,
    required this.onEditService,
    required this.onDeleteService,
    required this.expanded,
    required this.toggleExpanded,
  });

  final List<dynamic> categories;

  final SubcategoryOp onAddSubcategory;
  final SubcategoryOp onEditSubcategory;

  final void Function(Map<String, dynamic> category, List<dynamic> categories)
      onAddServices;

  final Future<void> Function({Map<String, dynamic>? category}) onEditCategory;

  final Future<void> Function(Map<String, dynamic> category) onDeleteCategory;

  final Future<void> Function(Map<String, dynamic>) onDeleteSubcategory;
  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int serviceId) onDeleteService;

  final Map<int, bool> expanded;
  final void Function(int id) toggleExpanded;

  static const List<Color> _tones = [
    Color(0xFF111111),
    Color(0xFF1F1F1F),
    Color(0xFF2D2D2D),
    Color(0xFF3B3B3B),
  ];

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories yet',
        subtitle: 'Tap "New Category" to create your first one.',
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => SizedBox(height: 18),
      itemBuilder: (context, index) {
        final category = Map<String, dynamic>.from(categories[index] as Map);
        final List<Map<String, dynamic>> subCategories =
            (category['subCategories'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                const [];
        final List<Map<String, dynamic>> categoryServices =
            (category['services'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                const [];
        final Color tone = _tones[index % _tones.length];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  color: Colors.grey.shade100,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.folder_special_rounded,
                          color: AppColors.starColor),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        category['displayName'] as String? ?? 'Category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.starColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _IconButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.starColor,
                      tooltip: 'Edit category',
                      onTap: () => onEditCategory(category: category),
                    ),
                    SizedBox(width: 6),
                    _IconButton(
                      icon: Icons.delete_rounded,
                      color: AppColors.starColor,
                      tooltip: 'Delete category',
                      onTap: () => onDeleteCategory(category),
                    ),
                  ],
                ),
              ),
              if (categoryServices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translateText('Services'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...categoryServices.map((service) => _ServiceCard(
                            service: service,
                            onEditService: onEditService,
                            onDeleteService: onDeleteService,
                          )),
                    ],
                  ),
                ),
              if (categoryServices.isNotEmpty) const SizedBox(height: 10),
              if (subCategories.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _NoDataPill(message: 'No subcategories added yet'),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: subCategories.map((sub) {
                      final int subId = sub['id'] as int;
                      return _SubcategoryTile(
                        categoryId: category['id'] as int,
                        subCategory: sub,
                        isExpanded: expanded[subId] ?? false,
                        toggle: () => toggleExpanded(subId),
                        onEditSubcategory: onEditSubcategory,
                        onDeleteSubcategory: onDeleteSubcategory,
                        onEditService: onEditService,
                        onDeleteService: onDeleteService,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            onAddSubcategory(categoryId: category['id'] as int),
                        icon: Icon(
                          Icons.add_rounded,
                          color: AppColors.starColor,
                        ),
                        label: Text(
                          translateText('Add subcategory'),
                          style: TextStyle(
                            color: AppColors.starColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.starColor),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onAddServices(category, categories),
                        icon: Icon(Icons.design_services_rounded),
                        label: Text(translateText('Add services')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.categoryId,
    required this.subCategory,
    required this.isExpanded,
    required this.toggle,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
    required this.onEditService,
    required this.onDeleteService,
  });

  final int categoryId;
  final Map<String, dynamic> subCategory;
  final bool isExpanded;
  final VoidCallback toggle;

  final SubcategoryOp onEditSubcategory;
  final Future<void> Function(Map<String, dynamic>) onDeleteSubcategory;

  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int) onDeleteService;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> services =
        (subCategory['services'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
    final theme = Theme.of(context);

    final Color borderColor =
        isExpanded ? Colors.grey.shade400 : Colors.grey.shade300;
    final Color fillColor =
        isExpanded ? Colors.grey.shade200 : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        color: fillColor,
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(subCategory['id']),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16,),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (value) {
            if (value != isExpanded) {
              toggle();
            }
          },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subCategory['displayName'] as String? ?? 'Subcategory',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getStartedButton,
                  fontSize: 14,
                ),
              ),
              if (services.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  '${services.length} ${services.length == 1 ? 'service' : 'services'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
          trailing: SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.starColor,
                  tooltip: 'Edit subcategory',
                  onTap: () => onEditSubcategory(
                    subCategory: subCategory,
                    categoryId: categoryId,
                  ),
                ),
                SizedBox(width: 4),
                _IconButton(
                  icon: Icons.delete_rounded,
                  color: AppColors.starColor,
                  tooltip: 'Delete subcategory',
                  onTap: () => onDeleteSubcategory(subCategory),
                ),
                SizedBox(width: 4),
              ],
            ),
          ),
          children: [
            if (services.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: _NoDataPill(
                    message: translateText('No services added yet')),
              )
            else
              Column(
                children: services
                    .map((service) => _ServiceCard(
                          service: service,
                          onEditService: onEditService,
                          onDeleteService: onDeleteService,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onEditService,
    required this.onDeleteService,
  });

  final Map<String, dynamic> service;
  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int) onDeleteService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = service['displayName']?.toString() ??
        service['name']?.toString() ??
        translateText('Unnamed service');
    final int? price = service['priceMinor'] as int?;
    final int? duration = service['durationMin'] as int?;
    final String description = (service['description'] ?? '').toString().trim();

    final String priceLabel =
        price != null ? 'Rs ' + price.toString() : translateText('No price');
    final String durationLabel = duration != null
        ? duration.toString() + ' min'
        : translateText('No duration');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.design_services_rounded,
              color: AppColors.starColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$priceLabel - $durationLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.edit_outlined,
            color: AppColors.starColor,
            tooltip: 'Edit service',
            onTap: () => onEditService(service),
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.delete_outline_rounded,
            color: AppColors.starColor,
            tooltip: 'Delete service',
            onTap: () => onDeleteService(service['id'] as int),
          ),
        ],
      ),
    );
  }
}

/* =======================  SMALL WIDGETS  ======================= */

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _darken(color, .2), size: 18),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.black),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: onBg,
            ),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBg.withValues(alpha: 0.8),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.black),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
            SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
              ),
              child: Text(translateText('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoaderCard extends StatelessWidget {
  const _LoaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: Colors.black)),
      ),
    );
  }
}

class _BottomSheetScaffold extends StatelessWidget {
  const _BottomSheetScaffold({
    required this.title,
    required this.child,
    this.initial = 0.55,
    this.min = 0.35,
    this.max = 0.9,
  });

  final String title;
  final Widget child;

  // New: customizable sizes (with safe defaults)
  final double initial;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initial,
      minChildSize: min,
      maxChildSize: max,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 14),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: '',
        border: OutlineInputBorder(),
      ).copyWith(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translateText('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: Text(translateText('Delete')),
        ),
      ],
    );
  }
}

/* =======================  SHEET WIDGETS  ======================= */
/* Category: inline error + loader + API here */
class _EditCategorySheet extends StatefulWidget {
  const _EditCategorySheet({this.category, required this.branchId});
  final Map<String, dynamic>? category;
  final int branchId;

  @override
  State<_EditCategorySheet> createState() => _EditCategorySheetState();
}


class _EditCategorySheetState extends State<_EditCategorySheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;

  bool isSaving = false;
  String? errorText;

  bool get isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.category?['displayName'] as String? ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.category?['description'] as String? ?? '',
    );
    // _validate(nameController.text);
    // nameController.addListener(() => _validate(nameController.text));
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String? _validateName(String v) {
    final t = v.trim();
    if (t.isEmpty) {
      return translateText('Name is required');
    }
    final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
    if (first != null && first != first.toUpperCase()) {
      return 'Name must start with a capital letter';
    }
    return null;
  }

  Future<void> _submit() async {
    final t = nameController.text.trim();

    // ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ 1. Validate input
    final validationError = _validateName(t);
    if (validationError != null) {
      setState(() => errorText = validationError);
      return;
    }

    setState(() => isSaving = true);

    try {
      // ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ 2. Prepare request using updated model
      final req = AddCategoryRequest(
        displayName: t,
        description: descriptionController.text.trim(),
        isActive: true,
        sortOrder: 100, // you can make this dynamic if needed
      );

      // ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ 3. Use correct Cubit function
      final cubit = context.read<CategoryCubit>();

     if (isEdit) {
  final categoryId = widget.category!['id'] as int;
  await cubit.updateCategory(widget.branchId, categoryId, req);
} else {
  await cubit.addCategory(widget.branchId, req);
}


      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => errorText = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BottomSheetScaffold(
        title: isEdit
            ? translateText('Edit Category')
            : translateText('Add Category'),
        initial: 0.55,
        min: 0.35,
        max: 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [FirstLetterUpperFormatter()],
              onChanged: (_) {
                if (errorText != null) setState(() => errorText = null);
              },
              decoration: InputDecoration(
                labelText: translateText('Category Name'),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            // Optional description input ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â´ keep if you need it in UI
            // TextField(
            //   controller: descriptionController,
            //   maxLines: 2,
            //   textCapitalization: TextCapitalization.sentences,
            //   decoration: InputDecoration(
            //     labelText: translateText('Description (optional)'),
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            if (errorText != null) ...[
              SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.check_rounded),
                onPressed: isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  isEdit
                      ? translateText('Update Category')
                      : translateText('Add Category'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Subcategory: inline error + loader + API here */
class _EditSubcategorySheet extends StatefulWidget {
  const _EditSubcategorySheet({
    this.subCategory,
       required this.branchId,
    required this.categoryId,
  });
  final Map<String, dynamic>? subCategory;
   final int branchId;
  final int categoryId;

  @override
  State<_EditSubcategorySheet> createState() => _EditSubcategorySheetState();
}

class _EditSubcategorySheetState extends State<_EditSubcategorySheet> {
  late final TextEditingController controller;
  bool isSaving = false;
  String? errorText;

  bool get isEdit => widget.subCategory != null;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.subCategory?['displayName'] as String? ?? '',
    );
    // _validate(controller.text);
    // controller.addListener(() => _validate(controller.text));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String? _validateName(String v) {
    final t = v.trim();
    if (t.isEmpty) {
      return translateText('Name is required');
    }
    final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
    if (first != null && first != first.toUpperCase()) {
      return 'Name must start with a capital letter';
    }
    return null;
  }

  Future<void> _submit() async {
    final t = controller.text.trim();

    final validationError = _validateName(t);
    if (validationError != null) {
      setState(() => errorText = validationError);
      return;
    }

    setState(() => isSaving = true);
    try {
      final cubit = context.read<CategoryCubit>();

      if (isEdit) {
        final subCategoryId = widget.subCategory!['id'] as int;
        await cubit.updateSubCategory(widget.branchId, subCategoryId, t);
      } else {
       await cubit.addSubCategory(widget.branchId, widget.categoryId, t);

      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => errorText = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BottomSheetScaffold(
        title: isEdit
            ? translateText('Edit Subcategory')
            : translateText('Add Subcategory'),
        initial: 0.55,
        min: 0.35,
        max: 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.none,
              inputFormatters: const [FirstLetterUpperFormatter()],
              onChanged: (_) {
                if (errorText != null) setState(() => errorText = null);
              },
              decoration: InputDecoration(
                labelText: translateText('Subcategory Name'),
                border: OutlineInputBorder(),
              ),
            ),
            if (errorText != null) ...[
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.check_rounded),
                onPressed: isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  isEdit
                      ? translateText('Update Subcategory')
                      : translateText('Add Subcategory'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Service editor: inline error (no toast). Parent still performs API. */
// class _EditServiceSheet extends StatefulWidget {
//   const _EditServiceSheet({required this.service});
//   final Map<String, dynamic> service;

//   @override
//   State<_EditServiceSheet> createState() => _EditServiceSheetState();
// }

// class _EditServiceSheetState extends State<_EditServiceSheet> {
//   late final TextEditingController nameController;
//   late final TextEditingController descriptionController;
//   late final TextEditingController durationController;
//   late final TextEditingController priceController;
//   late final ValueNotifier<bool> isActive;

//   String? errorText;
//   bool isSaving = false; // visual spinner while we pop with payload

//   @override
//   void initState() {
//     super.initState();
//     final s = widget.service;
//     nameController = TextEditingController(
//       text: s['displayName'] ?? s['name'] ?? '',
//     );
//     descriptionController = TextEditingController(text: s['description'] ?? '');
//     durationController = TextEditingController(
//       text: (s['durationMin'] ?? s['defaultDurationMin'])?.toString() ?? '',
//     );
//     priceController = TextEditingController(
//       text: (s['priceMinor'] ?? s['defaultPriceMinor'])?.toString() ?? '',
//     );
//     isActive = ValueNotifier<bool>(s['isActive'] ?? true);
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     descriptionController.dispose();
//     durationController.dispose();
//     priceController.dispose();
//     isActive.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _BottomSheetScaffold(
//       title: 'Edit Service',
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _LabeledField(
//             label: 'Service Name',
//             controller: nameController,
//             textCapitalization: TextCapitalization.words,
//           ),
//           SizedBox(height: 12),
//           _LabeledField(
//             label: 'Description',
//             controller: descriptionController,
//             maxLines: 1,
//             textCapitalization: TextCapitalization.sentences,
//           ),
//           SizedBox(height: 12),
//           _LabeledField(
//             label: 'Duration (minutes)',
//             controller: durationController,
//             keyboardType: TextInputType.number,
//           ),
//           SizedBox(height: 12),
//           _LabeledField(
//             label: 'Price (minor units)',
//             controller: priceController,
//             keyboardType: TextInputType.number,
//           ),
//           SizedBox(height: 8),
//           ValueListenableBuilder<bool>(
//             valueListenable: isActive,
//             builder: (context, value, _) {
//               return SwitchListTile(
//                 value: value,
//                 onChanged: (nv) => isActive.value = nv,
//                 title: const Text('Active'),
//                 contentPadding: EdgeInsets.zero,
//               );
//             },
//           ),
//           if (errorText != null) ...[
//             SizedBox(height: 2),
//             Align(
//               alignment: Alignment.centerLeft,
//               child: Text(
//                 errorText!,
//                 style: const TextStyle(color: Colors.black,),
//               ),
//             ),
//           ],
//           SizedBox(height: 6),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               icon: isSaving
//                   ? SizedBox(
//                       width: 18, height: 18,
//                       child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                     )
//                   : Icon(Icons.save_rounded),
//               onPressed: isSaving
//                   ? null
//                   : () async {
//                       final name = nameController.text.trim();
//                       if (name.isEmpty) {
//                         setState(() => errorText = translateText('Name is required'));
//                         return;
//                       }
//                       if (!RegExp(r'^[A-Z]').hasMatch(name)) {
//                         setState(() => errorText = 'Name must start with an uppercase letter');
//                         return;
//                       }
//
//                       FocusScope.of(context).unfocus();

//                       setState(() => isSaving = true);
//                       try {
//                         final payload = {
//                           'name': name,
//                           'description': descriptionController.text.trim(),
//                           'defaultDurationMin': int.tryParse(
//                             durationController.text.trim(),
//                           ),
//                           'defaultPriceMinor': int.tryParse(
//                             priceController.text.trim(),
//                           ),
//                           'isActive': isActive.value,
//                         }..removeWhere((k, v) => v == null);

//                         Navigator.of(context).pop(<String, dynamic>{
//                           'serviceId': widget.service['id'] as int,
//                           'payload': payload,
//                         });
//                       } finally {
//                         if (mounted) setState(() => isSaving = false);
//                       }
//                     },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.black,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               label: const Text('Update Service'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
/* Service editor: field-level errors for name/price/duration */
class _EditServiceSheet extends StatefulWidget {
  const _EditServiceSheet({required this.service});
  final Map<String, dynamic> service;

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController durationController;
  late final TextEditingController priceController;
  late final ValueNotifier<bool> isActive;

  // Field-specific errors (shown under each field)
  String? nameError;
  String? priceError;
  String? durationError;

  bool isSaving = false; // spinner in the button while popping payload

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    nameController = TextEditingController(
      text: s['displayName'] ?? s['name'] ?? '',
    );
    descriptionController = TextEditingController(text: s['description'] ?? '');
    durationController = TextEditingController(
      text: (s['durationMin'] ?? s['defaultDurationMin'])?.toString() ?? '',
    );
    priceController = TextEditingController(
      text: (s['priceMinor'] ?? s['defaultPriceMinor'])?.toString() ?? '',
    );
    isActive = ValueNotifier<bool>(s['isActive'] ?? true);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    priceController.dispose();
    isActive.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nErr, pErr, dErr;

    final name = nameController.text.trim();
    final priceTxt = priceController.text.trim();
    final durationTxt = durationController.text.trim();

    if (name.isEmpty) {
      nErr = translateText('Name is required');
    }

    if (priceTxt.isEmpty) {
      pErr = 'Price is required';
    } else if (int.tryParse(priceTxt) == null) {
      pErr = 'Enter a valid number';
    }

    if (durationTxt.isEmpty) {
      dErr = 'Duration is required';
    } else if (int.tryParse(durationTxt) == null) {
      dErr = 'Enter a valid number';
    }

    setState(() {
      nameError = nErr;
      priceError = pErr;
      durationError = dErr;
    });

    return nErr == null && pErr == null && dErr == null;
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetScaffold(
      title: translateText('Edit Service'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name
          _LabeledField(
            label: translateText('Service Name'),
            controller: nameController,
            textCapitalization: TextCapitalization.words,
          ),
          if (nameError != null) ...[
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                nameError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          SizedBox(height: 12),

          // Description (optional)
          _LabeledField(
            label: translateText('Description'),
            controller: descriptionController,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 12),

          // Duration
          _LabeledField(
            label: translateText('Duration (minutes)'),
            controller: durationController,
            keyboardType: TextInputType.number,
          ),
          if (durationError != null) ...[
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                durationError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          SizedBox(height: 12),

          // Price
          _LabeledField(
            label: translateText('Price (in ₹)'),
            controller: priceController,
            keyboardType: TextInputType.number,
          ),
          if (priceError != null) ...[
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                priceError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          SizedBox(height: 8),

          // Active switch
//           ValueListenableBuilder<bool>(
//             valueListenable: isActive,
//             builder: (context, value, _) {
//               return SwitchListTile(
//   value: value,
//   onChanged: (nv) => isActive.value = nv,
//   title: const Text('Active'),
//   thumbColor: MaterialStateProperty.resolveWith((states) =>
//     states.contains(MaterialState.selected) ? AppColors.starColor : null),
//   trackColor: MaterialStateProperty.resolveWith((states) =>
//     states.contains(MaterialState.selected) ? AppColors.starColor.withOpacity(0.35) : null),
//   contentPadding: EdgeInsets.zero,
// );
//             },
//           ),

          SizedBox(height: 6),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.save_rounded),
              onPressed: isSaving
                  ? null
                  : () async {
                      // validate only on click
                      if (!_validate()) return;

                      FocusScope.of(context).unfocus();
                      setState(() => isSaving = true);
                      try {
                        final payload = {
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'defaultDurationMin': int.tryParse(
                            durationController.text.trim(),
                          ),
                          'defaultPriceMinor': int.tryParse(
                            priceController.text.trim(),
                          ),
                          'isActive': isActive.value,
                        }..removeWhere((k, v) => v == null);

                        Navigator.of(context).pop(<String, dynamic>{
                          'serviceId': widget.service['id'] as int,
                          'payload': payload,
                        });
                      } finally {
                        if (mounted) setState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(translateText('Update Service')),
            ),
          ),
        ],
      ),
    );
  }
}
