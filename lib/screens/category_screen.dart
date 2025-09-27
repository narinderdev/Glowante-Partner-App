// lib/screens/category_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for TextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import '../Viewmodels/AddCategory.dart';
import 'AddServices.dart';
import '../utils/colors.dart';
/// Shared function signature for opening the subcategory sheet
typedef SubcategoryOp =
    Future<void> Function({
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
  int? _selectedBranchId;
  Map<String, dynamic>? _selectedBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salonCubit = context.read<SalonListCubit>();

      if (salonCubit.state.salons.isEmpty) {
        salonCubit.loadSalons();
      } else if (salonCubit.state.selectedBranch != null) {
        setState(() {
          _selectedBranch = salonCubit.state.selectedBranch;
          _selectedBranchId = _selectedBranch!['branchId'];
        });
      }
    });
  }

  // ---------- BRANCH HANDLING ----------
  void _onBranchSelected(int? value, List<Map<String, dynamic>> salons) {
    if (value == null) return;

    for (final salon in salons) {
      final branches =
          (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final Map<String, dynamic> match = branches.firstWhere(
        (branch) => branch['id'] == value,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        setState(() {
          _selectedBranchId = value;
          _selectedBranch = {
            'salonId': salon['id'],
            'salonName': salon['name'],
            'branchId': match['id'],
            'branchName': match['name'],
          };
          _expandedSubcategories.clear();
        });
        context.read<SalonListCubit>().setSelectedBranch(_selectedBranch!);
        final categoryCubit = context.read<CategoryCubit>();
        categoryCubit.resetCategories();
        categoryCubit.loadCategories(salon['id'] as int);
        break;
      }
    }
  }

  // ---------- ADD / EDIT CATEGORY ----------
  Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
    if (_selectedBranch == null) {
      _toast('Select a salon first.');
      return;
    }

    final salonId = _selectedBranch!['salonId'] as int;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditCategorySheet(
        category: category,
        salonId: salonId, // sheet will call the cubit & show loader
      ),
    );
  }

  // ---------- ADD / EDIT SUBCATEGORY ----------
  Future<void> _openSubcategorySheet({
    Map<String, dynamic>? subCategory,
    required int categoryId,
  }) async {
    if (_selectedBranch == null) return;

    final salonId = _selectedBranch!['salonId'] as int;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditSubcategorySheet(
        subCategory: subCategory,
        salonId: salonId, // sheet will call the cubit & show loader
        categoryId: categoryId, // needed for add
      ),
    );
  }

  // ---------- CONFIRM DELETE CATEGORY ----------
  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ConfirmDialog(
        title: 'Delete Category',
        message: 'Are you sure you want to delete this category?',
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteCategory(
      salonId,
      category['id'] as int,
    );
  }

  // ---------- CONFIRM DELETE SUBCATEGORY ----------
  Future<void> _confirmDeleteSubCategory(
    Map<String, dynamic> subCategory,
  ) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ConfirmDialog(
        title: 'Delete Subcategory',
        message: 'Are you sure you want to delete this subcategory?',
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteSubCategory(
      salonId,
      subCategory['id'] as int,
    );
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

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().updateService(
      salonId,
      result['serviceId'] as int,
      result['payload'] as Map<String, dynamic>,
    );
  }

  // ---------- CONFIRM DELETE SERVICE ----------
  Future<void> _confirmDeleteService(int serviceId) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ConfirmDialog(
        title: 'Delete Service',
        message: 'Are you sure you want to delete this service?',
        confirmColor: Colors.black,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteService(salonId, serviceId);
  }

  // ---------- OPEN ADD SERVICE SCREEN ----------
  void _openAddService(
    Map<String, dynamic> category,
    List<dynamic> categories,
  ) {
    if (_selectedBranch == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddServices(
          salonId: _selectedBranch!['salonId'] as int,
          selectedCategory: category,
          categories: categories,
        ),
      ),
    );
  }

  void _autoPickFirstBranch(SalonListState state) {
    if (_selectedBranch != null) return; // don't override user choice
    if (state.salons.isEmpty) return;

    for (final salon in state.salons) {
      final branches =
          (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      if (branches.isNotEmpty) {
        final first = branches.first;
        setState(() {
          _selectedBranchId = first['id'] as int;
          _selectedBranch = {
            'salonId': salon['id'],
            'salonName': salon['name'],
            'branchId': first['id'],
            'branchName': first['name'],
          };
          _expandedSubcategories.clear();
        });
        // reflect selection in SalonListCubit and load categories
        context.read<SalonListCubit>().setSelectedBranch(_selectedBranch!);
        final categoryCubit = context.read<CategoryCubit>();
        categoryCubit.resetCategories();
        categoryCubit.loadCategories(salon['id'] as int);
        break;
      }
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final salonState = context.watch<SalonListCubit>().state;
    final CategoryState catState = context.watch<CategoryCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.white,
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
                prev.selectedBranch != curr.selectedBranch,
            listener: (context, salonState) {
              _autoPickFirstBranch(salonState);
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
                    selectedBranchId: _selectedBranchId,
                    selectedBranch: _selectedBranch,
                    onBranchSelected: _onBranchSelected,
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
      floatingActionButton: _selectedBranch == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'catalogueFab',
              onPressed: () => _showAddCategorySheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Category'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCatalogueContent(CategoryState catState) {
    return RefreshIndicator(
      color: Colors.black,
      displacement: 32,
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
        children: [
          if (_selectedBranch == null) ...[
            const _EmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'Choose a salon',
              subtitle: 'Pick a salon above to start managing its catalogue.',
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
                const _InlineProgress(message: 'Refreshing catalogue...'),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _handleManualRefresh() async {
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (_selectedBranch != null) {
      final salonId = _selectedBranch!['salonId'] as int;
      context.read<CategoryCubit>().loadCategories(salonId);
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
    required this.selectedBranchId,
    required this.selectedBranch,
    required this.onBranchSelected,
    required this.onRefresh,
  });

  final SalonListState salonState;
  final int? selectedBranchId;
  final Map<String, dynamic>? selectedBranch;
  final void Function(int?, List<Map<String, dynamic>>) onBranchSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final String? branchName = selectedBranch?['branchName'] as String?;
    final String? salonName = selectedBranch?['salonName'] as String?;

    final List<Map<String, dynamic>> salons = salonState.salons
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final List<DropdownMenuItem<int>> branchItems = salons.expand((salon) {
      final String salonTitle = salon['name']?.toString() ?? 'Salon';
      final List<Map<String, dynamic>> branches =
          (salon['branches'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [];
      return branches.map((branch) {
        final String branchTitle = branch['name']?.toString() ?? 'Branch';
        return DropdownMenuItem<int>(
          value: branch['id'] as int,
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
                  color: Colors.black87,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchTitle,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      salonTitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    }).toList();

    final bool hasSelection = branchItems.any(
      (item) => item.value == selectedBranchId,
    );
    final int? dropdownValue = hasSelection ? selectedBranchId : null;

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                      'Catalog',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      branchName != null
                          ? '${branchName ?? ''} / ${salonName ?? 'Salon'}'
                          : 'Select a salon to get started',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: salonState.isLoading ? null : () => onRefresh(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Salon and Branch',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    if (salonState.isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black,
                      ),
                      dropdownColor: Colors.white,
                      items: branchItems,
                      onChanged: branchItems.isEmpty
                          ? null
                          : (value) => onBranchSelected(value, salons),
                      hint: Text(
                        branchItems.isEmpty
                            ? 'No branches available'
                            : 'Choose branch',
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
          const SizedBox(width: 8),
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
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            ),
            const SizedBox(width: 12),
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
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final category = Map<String, dynamic>.from(categories[index] as Map);
        final List<Map<String, dynamic>> subCategories =
            (category['subCategories'] as List?)
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.folder_special_rounded, color: tone),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        category['name'] as String? ?? 'Category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _IconButton(
                      icon: Icons.edit_rounded,
                      color: Colors.black87,
                      tooltip: 'Edit category',
                      onTap: () => onEditCategory(category: category),
                    ),
                    const SizedBox(width: 6),
                    _IconButton(
                      icon: Icons.delete_rounded,
                      color: Colors.black87,
                      tooltip: 'Delete category',
                      onTap: () => onDeleteCategory(category),
                    ),
                  ],
                ),
              ),
              if (subCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'Add subcategory',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black54),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onAddServices(category, categories),
                        icon: const Icon(Icons.design_services_rounded),
                        label: const Text('Add services'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
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
              const SizedBox(height: 20),
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

    final Color borderColor = isExpanded
        ? Colors.grey.shade400
        : Colors.grey.shade300;
    final Color fillColor = isExpanded
        ? Colors.grey.shade200
        : Colors.grey.shade100;

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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                subCategory['name'] as String? ?? 'Subcategory',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                  color: Colors.black87,
                  tooltip: 'Edit subcategory',
                  onTap: () => onEditSubcategory(
                    subCategory: subCategory,
                    categoryId: categoryId,
                  ),
                ),
                const SizedBox(width: 4),
                _IconButton(
                  icon: Icons.delete_rounded,
                  color: Colors.black87,
                  tooltip: 'Delete subcategory',
                  onTap: () => onDeleteSubcategory(subCategory),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          children: [
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _NoDataPill(message: 'No services added yet'),
              )
            else
              Column(
                children: services.map((service) {
                  final String name =
                      service['displayName']?.toString() ?? 'Unnamed service';
                  final int? price = service['priceMinor'] as int?;
                  final int? duration = service['durationMin'] as int?;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.design_services_rounded,
                            color: Colors.black87,
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
                                '${price != null ? 'Rs ' + price.toString() : 'No price'} - ${duration != null ? duration.toString() + ' min' : 'No duration'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _IconButton(
                          icon: Icons.edit_outlined,
                          color: Colors.black87,
                          tooltip: 'Edit service',
                          onTap: () => onEditService(service),
                        ),
                        const SizedBox(width: 4),
                        _IconButton(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.black87,
                          tooltip: 'Delete service',
                          onTap: () => onDeleteService(service['id'] as int),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
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
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: onBg,
            ),
          ),
          const SizedBox(height: 6),
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
            const Icon(Icons.error_outline_rounded, color: Colors.black),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
              ),
              child: const Text('Retry'),
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
      child: const Padding(
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
                const SizedBox(height: 14),
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
      decoration:
          const InputDecoration(
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/* =======================  SHEET WIDGETS  ======================= */
/* Category: inline error + loader + API here */
class _EditCategorySheet extends StatefulWidget {
  const _EditCategorySheet({this.category, required this.salonId});
  final Map<String, dynamic>? category;
  final int salonId;

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
      text: widget.category?['name'] as String? ?? '',
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

  void _validate(String v) {
    final t = v.trim();
    String? err;
    if (t.isEmpty) {
      err = 'Name is required';
    } else {
      final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
      if (first != null && first != first.toUpperCase()) {
        err = 'Name must start with a capital letter';
      }
    }
    if (err != errorText) setState(() => errorText = err);
  }

  Future<void> _submit() async {
    final t = nameController.text.trim();

    // validate only when pressing the button
    if (t.isEmpty) {
      setState(() => errorText = 'Name is required');
      return;
    }
    final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
    if (first != null && first != first.toUpperCase()) {
      setState(() => errorText = 'Name must start with a capital letter');
      return;
    }
    setState(() => errorText = null);

    setState(() => isSaving = true);
    try {
      final req = AddCategoryRequest(
        name: t,
        description: descriptionController.text.trim(),
      );

      final cubit = context.read<CategoryCubit>();
      if (isEdit) {
        final categoryId = widget.category!['id'] as int;
        await cubit.updateCategory(widget.salonId, categoryId, req);
      } else {
        await cubit.addCategory(widget.salonId, req);
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
    return _BottomSheetScaffold(
      title: isEdit ? 'Edit Category' : 'Add Category',
      initial: 0.30, // was 0.55
      min: 0.10, // was 0.35
      max: 0.30, // was 0.90
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [FirstLetterUpperFormatter()],
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Optional description input ΓÇô keep if you need it in UI
          // TextField(
          //   controller: descriptionController,
          //   maxLines: 2,
          //   textCapitalization: TextCapitalization.sentences,
          //   decoration: const InputDecoration(
          //     labelText: 'Description (optional)',
          //     border: OutlineInputBorder(),
          //   ),
          // ),
          if (errorText != null) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(isEdit ? 'Update Category' : 'Add Category'),
            ),
          ),
        ],
      ),
    );
  }
}

/* Subcategory: inline error + loader + API here */
class _EditSubcategorySheet extends StatefulWidget {
  const _EditSubcategorySheet({
    this.subCategory,
    required this.salonId,
    required this.categoryId,
  });
  final Map<String, dynamic>? subCategory;
  final int salonId;
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
      text: widget.subCategory?['name'] as String? ?? '',
    );
    // _validate(controller.text);
    // controller.addListener(() => _validate(controller.text));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _validate(String v) {
    final t = v.trim();
    String? err;
    if (t.isEmpty) {
      err = 'Name is required';
    } else {
      final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
      if (first != null && first != first.toUpperCase()) {
        err = 'Name must start with a capital letter';
      }
    }
    if (err != errorText) setState(() => errorText = err);
  }

  Future<void> _submit() async {
    final t = controller.text.trim();

    // validate only when pressing the button
    if (t.isEmpty) {
      setState(() => errorText = 'Name is required');
      return;
    }
    final first = RegExp(r'[A-Za-z]').firstMatch(t)?.group(0);
    if (first != null && first != first.toUpperCase()) {
      setState(() => errorText = 'Name must start with a capital letter');
      return;
    }
    setState(() => errorText = null);

    setState(() => isSaving = true);
    try {
      final cubit = context.read<CategoryCubit>();

      if (isEdit) {
        final subCategoryId = widget.subCategory!['id'] as int;
        await cubit.updateSubCategory(widget.salonId, subCategoryId, t);
      } else {
        await cubit.addSubCategory(widget.salonId, widget.categoryId, t);
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
    return _BottomSheetScaffold(
      title: isEdit ? 'Edit Subcategory' : 'Add Subcategory',
      initial: 0.30, // was 0.55
      min: 0.10, // was 0.35
      max: 0.30, // was 0.90
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [FirstLetterUpperFormatter()],
            decoration: const InputDecoration(
              labelText: 'Subcategory Name',
              border: OutlineInputBorder(),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(isEdit ? 'Update Subcategory' : 'Add Subcategory'),
            ),
          ),
        ],
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
//           const SizedBox(height: 12),
//           _LabeledField(
//             label: 'Description',
//             controller: descriptionController,
//             maxLines: 1,
//             textCapitalization: TextCapitalization.sentences,
//           ),
//           const SizedBox(height: 12),
//           _LabeledField(
//             label: 'Duration (minutes)',
//             controller: durationController,
//             keyboardType: TextInputType.number,
//           ),
//           const SizedBox(height: 12),
//           _LabeledField(
//             label: 'Price (minor units)',
//             controller: priceController,
//             keyboardType: TextInputType.number,
//           ),
//           const SizedBox(height: 8),
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
//             const SizedBox(height: 2),
//             Align(
//               alignment: Alignment.centerLeft,
//               child: Text(
//                 errorText!,
//                 style: const TextStyle(color: Colors.black,),
//               ),
//             ),
//           ],
//           const SizedBox(height: 6),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               icon: isSaving
//                   ? const SizedBox(
//                       width: 18, height: 18,
//                       child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                     )
//                   : const Icon(Icons.save_rounded),
//               onPressed: isSaving
//                   ? null
//                   : () async {
//                       final name = nameController.text.trim();
//                       if (name.isEmpty) {
//                         setState(() => errorText = 'Name is required');
//                         return;
//                       }
//                       if (!RegExp(r'^[A-Z]').hasMatch(name)) {
//                         setState(() => errorText = 'Name must start with an uppercase letter');
//                         return;
//                       }
//                       setState(() => errorText = null);

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
      nErr = 'Name is required';
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
      title: 'Edit Service',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name
          _LabeledField(
            label: 'Service Name',
            controller: nameController,
            textCapitalization: TextCapitalization.words,
          ),
          if (nameError != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                nameError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Description (optional)
          _LabeledField(
            label: 'Description',
            controller: descriptionController,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // Duration
          _LabeledField(
            label: 'Duration (minutes)',
            controller: durationController,
            keyboardType: TextInputType.number,
          ),
          if (durationError != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                durationError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Price
          _LabeledField(
            label: 'Price (in Γé╣)',
            controller: priceController,
            keyboardType: TextInputType.number,
          ),
          if (priceError != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                priceError!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Active switch
          ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: (nv) => isActive.value = nv,
                title: const Text('Active'),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),

          const SizedBox(height: 6),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
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
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: const Text('Update Service'),
            ),
          ),
        ],
      ),
    );
  }
}
