// lib/screens/category_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for TextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import '../Viewmodels/AddCategory.dart';
import 'AddServices.dart';
import 'notifications.dart';
import '../services/language_listener.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';
import '../utils/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _catalogGold = Color(0xFF8B6500);
const Color _catalogGoldLight = Color(0xFFD0A244);
const Color _catalogInk = Color(0xFF2D2926);
const Color _catalogMuted = Color(0xFF756A61);
const Color _catalogBorder = Color(0xFFE8DED6);
const Color _catalogSurface = Color(0xFFFBF9F8);

/// Shared function signature for opening the subcategory sheet
typedef SubcategoryOp = Future<void> Function({
  Map<String, dynamic>? subCategory,
  required int categoryId,
});

int? _serviceInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _uniqueCatalogServices(
  Iterable<Map<String, dynamic>> services, {
  Set<int>? seenIds,
}) {
  final ids = seenIds ?? <int>{};
  final unique = <Map<String, dynamic>>[];

  for (final service in services) {
    final serviceId = _serviceInt(service['id']);
    if (serviceId != null && !ids.add(serviceId)) continue;
    unique.add(service);
  }

  return unique;
}

bool _isCatalogItemActive(Map<String, dynamic> item) {
  final isActive = item['isActive'] ?? item['active'];
  if (isActive is bool && !isActive) return false;
  if (isActive is num && isActive == 0) return false;
  if (isActive is String) {
    final normalized = isActive.trim().toLowerCase();
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'inactive' ||
        normalized == 'deleted') {
      return false;
    }
  }

  final status = item['status'] ?? item['state'];
  if (status is String) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'inactive' ||
        normalized == 'deleted' ||
        normalized == 'archived' ||
        normalized == 'disabled') {
      return false;
    }
  }

  return true;
}

double? _serviceDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _commissionMaxValueLabel(dynamic value) {
  final amount = minorAmountToRupees(value);
  if (amount == null) return '';
  final fixed = amount.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _catalogBranchAddressSummary(dynamic rawAddress) {
  if (rawAddress is! Map) return '';
  final address = Map<String, dynamic>.from(rawAddress);
  final parts = <String>[];

  void push(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null' || parts.contains(text)) {
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

String _catalogBranchLabel(Map<String, dynamic>? selection) {
  if (selection == null) return translateText('Select Branch');
  final branchName = selection['branchName']?.toString().trim() ?? '';
  if (branchName.isNotEmpty) return branchName;
  final salonName = selection['salonName']?.toString().trim() ?? '';
  if (salonName.isNotEmpty) return salonName;
  return translateText('Select Branch');
}

String _catalogSortLabel(Map<String, dynamic> item) {
  for (final key in const [
    'displayName',
    'name',
    'serviceName',
    'title',
    'label',
    'code',
  ]) {
    final value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value.toLowerCase();
  }
  return '';
}

IconData _catalogIconForCategory(Map<String, dynamic> category) {
  final name = (category['displayName'] ?? category['name'] ?? '')
      .toString()
      .toLowerCase();
  if (name.contains('hair') || name.contains('cut') || name.contains('salon')) {
    return Icons.content_cut_rounded;
  }
  if (name.contains('men') ||
      name.contains('beard') ||
      name.contains('groom')) {
    return Icons.face_retouching_natural_rounded;
  }
  if (name.contains('spa') ||
      name.contains('massage') ||
      name.contains('therapy')) {
    return Icons.spa_rounded;
  }
  if (name.contains('nail') ||
      name.contains('manicure') ||
      name.contains('pedicure')) {
    return Icons.back_hand_rounded;
  }
  if (name.contains('make') ||
      name.contains('beauty') ||
      name.contains('facial')) {
    return Icons.brush_rounded;
  }
  return Icons.room_service_rounded;
}

int _compareCatalogItems(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final labelCompare = _catalogSortLabel(first).compareTo(
    _catalogSortLabel(second),
  );
  if (labelCompare != 0) return labelCompare;
  final firstId = _serviceInt(first['id']) ?? 0;
  final secondId = _serviceInt(second['id']) ?? 0;
  return firstId.compareTo(secondId);
}

List<Map<String, dynamic>> _sortedCatalogItems(
  Iterable<Map<String, dynamic>> items,
) {
  return items.toList()..sort(_compareCatalogItems);
}

String _serviceCommissionValueLabel(Map<String, dynamic> service) {
  if (service['commissionEnabled'] != true) {
    return translateText('No commission');
  }

  final type = (service['commissionType'] ?? '').toString().toLowerCase();
  if (type == 'fixed') {
    final amount = _serviceInt(service['commissionFixedAmountMinor']);
    return amount != null
        ? formatMinorAmount(amount, trimZeroDecimals: true)
        : translateText('Fixed');
  }

  if (type == 'percentage') {
    final percent = _serviceDouble(service['commissionPercentage']);
    final maxAmount = _serviceInt(service['commissionMaxAmountMinor']);
    final percentLabel = percent == null
        ? translateText('Percentage')
        : '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}%';
    return maxAmount != null
        ? '$percentLabel • max ${_commissionMaxValueLabel(maxAmount)}'
        : percentLabel;
  }

  return translateText('Enabled');
}

String _serviceCommissionTagLabel(Map<String, dynamic> service) {
  final valueLabel = _serviceCommissionValueLabel(service);
  if (valueLabel == translateText('No commission')) {
    return translateText('Comm off');
  }
  if (valueLabel == translateText('Enabled')) {
    return translateText('Comm');
  }
  return '${translateText('Comm')} $valueLabel';
}

String _servicePassiveWaitLabel(Map<String, dynamic> service) {
  if (service['passiveWaitEnabled'] != true) return '';
  final waitMinutes = _serviceInt(service['passiveWaitMinutes']);
  if (waitMinutes == null || waitMinutes <= 0) return '';
  return '${translateText('Wait')}: $waitMinutes min';
}

int _serviceCountForCategory(Map<String, dynamic> category) {
  final seenIds = <int>{};
  int count = 0;
  final services = category['services'];
  if (services is List) {
    count += _uniqueCatalogServices(
      services
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where(_isCatalogItemActive),
      seenIds: seenIds,
    ).length;
  }

  final subCategories = category['subCategories'];
  if (subCategories is List) {
    for (final subCategory in subCategories) {
      if (subCategory is! Map) continue;
      final subServices = subCategory['services'];
      if (subServices is List) {
        count += _uniqueCatalogServices(
          subServices
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .where(_isCatalogItemActive),
          seenIds: seenIds,
        ).length;
      }
    }
  }

  return count;
}

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
  State<CategoryScreen> createState() => CategoryScreenState();
}

class CategoryScreenState extends State<CategoryScreen> {
  final Map<int, bool> _expandedCategories = {};
  final Map<int, bool> _expandedSubcategories = {};
  final Map<int, GlobalKey> _filterChipKeys = {};
  final Map<int, GlobalKey> _categoryItemKeys = {};
  final Map<int, GlobalKey> _subcategoryItemKeys = {};
  Map<String, dynamic>? _selectedSalon;
  final ScrollController _catalogScrollController = ScrollController();
  final GlobalKey _branchSelectorKey = GlobalKey();
  final FocusNode _catalogSearchFocusNode = FocusNode();
  final TextEditingController _catalogSearchController =
      TextEditingController();
  String _catalogQuery = '';
  int? _selectedFilterCategoryId;
  double? _pendingScrollOffset;
  bool _syncingBookingsSelection = false;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> _enrichSalonSelection(
    Map<String, dynamic> selection,
    List<Map<String, dynamic>> salons,
  ) {
    final selectedSalonId = _asInt(selection['salonId']);
    final selectedBranchId = _asInt(selection['branchId']);

    for (final salon in salons) {
      final salonId = _asInt(salon['id']);
      if (selectedSalonId != null && salonId != selectedSalonId) continue;
      final branches = salon['branches'];
      if (branches is! List) continue;

      for (final rawBranch in branches) {
        if (rawBranch is! Map) continue;
        final branch = Map<String, dynamic>.from(rawBranch);
        final branchId = _asInt(branch['id']);
        if (selectedBranchId != null && branchId != selectedBranchId) continue;

        return {
          ...selection,
          'salonId': salonId ?? selectedSalonId,
          'salonName': salon['name'] ?? selection['salonName'],
          'branchId': branchId ?? selectedBranchId,
          'branchName': branch['name'] ?? selection['branchName'],
          'addressSummary': _catalogBranchAddressSummary(branch['address']),
        };
      }
    }

    return selection;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salonCubit = context.read<SalonListCubit>();

      if (salonCubit.state.salons.isEmpty) {
        salonCubit.loadSalons();
      } else if (salonCubit.state.selectedSalon != null) {
        final salons = salonCubit.state.salons
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final Map<String, dynamic> selectedSalon = _enrichSalonSelection(
          Map<String, dynamic>.from(salonCubit.state.selectedSalon!),
          salons,
        );
        final int? branchId = _asInt(selectedSalon['branchId']) ??
            _asInt(selectedSalon['salonId']);
        setState(() {
          _selectedSalon = selectedSalon;
        });
        if (branchId != null) {
          final categoryCubit = context.read<CategoryCubit>();
          categoryCubit.resetCategories();
          categoryCubit.loadCategories(branchId);
        }
      }
    });
  }

  void _rememberScrollPosition() {
    if (_catalogScrollController.hasClients) {
      _pendingScrollOffset = _catalogScrollController.offset;
    }
  }

  Future<void> refreshFromCurrentSelection() async {
    final branchId = _asInt(_selectedSalon?['branchId']) ??
        _asInt(_selectedSalon?['salonId']);
    final categoryCubit = context.read<CategoryCubit>();

    if (branchId != null) {
      categoryCubit.resetCategories();
      await categoryCubit.loadCategories(branchId);
      return;
    }

    final salons = context
        .read<SalonListCubit>()
        .state
        .salons
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await _syncFromBookingsSelection(salons);
  }

  void _scheduleSyncFromBookings(List<Map<String, dynamic>> salons) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromBookingsSelection(salons);
    });
  }

  Future<void> _syncFromBookingsSelection(
    List<Map<String, dynamic>> salons,
  ) async {
    if (!mounted || _syncingBookingsSelection || salons.isEmpty) return;
    _syncingBookingsSelection = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedBranchId = prefs.getInt('selected_branch_id');
      if (storedBranchId == null) return;

      Map<String, dynamic>? matchedSalon;
      Map<String, dynamic>? matchedBranch;

      for (final rawSalon in salons) {
        final salon = Map<String, dynamic>.from(rawSalon);
        final branches = salon['branches'];
        if (branches is! List) continue;
        for (final entry in branches) {
          if (entry is! Map) continue;
          final branch = Map<String, dynamic>.from(entry);
          if (_asInt(branch['id']) == storedBranchId) {
            matchedSalon = salon;
            matchedBranch = branch;
            break;
          }
        }
        if (matchedBranch != null) break;
      }

      if (matchedSalon == null || matchedBranch == null) return;

      final matchedSalonId = _asInt(matchedSalon['id']);
      if (matchedSalonId == null) return;

      final nextSelection = {
        'salonId': matchedSalonId,
        'salonName': matchedSalon['name'],
        'branchId': storedBranchId,
        'branchName': matchedBranch['name'],
        'addressSummary':
            _catalogBranchAddressSummary(matchedBranch['address']),
      };
      final isSameBranch =
          _asInt(_selectedSalon?['branchId']) == storedBranchId;

      if (!mounted) return;
      final categoryCubit = context.read<CategoryCubit>();
      if (!isSameBranch) {
        setState(() {
          _selectedSalon = nextSelection;
          _expandedCategories.clear();
          _expandedSubcategories.clear();
        });
        context.read<SalonListCubit>().setSelectedSalon(nextSelection);
        categoryCubit.resetCategories();
        categoryCubit.loadCategories(storedBranchId);
      } else if (categoryCubit.state.status == CategoryStatus.initial) {
        categoryCubit.loadCategories(storedBranchId);
      }
    } finally {
      _syncingBookingsSelection = false;
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
    _catalogSearchFocusNode.dispose();
    _catalogSearchController.dispose();
    super.dispose();
  }

  void _dismissCatalogKeyboard() {
    _catalogSearchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

// ---------- ADD / EDIT CATEGORY ----------
  Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
    _dismissCatalogKeyboard();
    if (_selectedSalon == null) {
      _toast('Select a salon first.');
      return;
    }

    final int? branchId = _asInt(_selectedSalon?['branchId']) ??
        _asInt(_selectedSalon?['salonId']);
    if (branchId == null) {
      _toast('Missing branch information.');
      return;
    }

    final createdCategoryName = await showDialog<String>(
      context: context,
      builder: (sheetContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: const RoundedRectangleBorder(),
        backgroundColor: Colors.white,
        child: _EditCategorySheet(
          category: category,
          branchId: branchId,
          existingCategories: context.read<CategoryCubit>().state.categories,
        ),
      ),
    );

    _dismissCatalogKeyboard();
    if (!mounted || category != null || createdCategoryName == null) return;
    _selectFilterCategoryByName(createdCategoryName);
  }

  void _selectFilterCategoryByName(String categoryName) {
    final normalizedName = categoryName.trim().toLowerCase();
    if (normalizedName.isEmpty) return;

    final categories = context.read<CategoryCubit>().state.categories;
    Map<String, dynamic>? match;
    for (final rawCategory in categories.reversed) {
      if (rawCategory is! Map) continue;
      final category = Map<String, dynamic>.from(rawCategory);
      final label = (category['displayName'] ?? category['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (label == normalizedName) {
        match = category;
        break;
      }
    }

    final categoryId = _asInt(match?['id']);
    if (categoryId == null) return;
    setState(() {
      _selectedFilterCategoryId = categoryId;
      _expandedCategories[categoryId] = true;
    });
    _ensureFilterChipVisible(categoryId);
  }

  void _ensureFilterChipVisible(int categoryId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chipContext = _filterChipKeys[categoryId]?.currentContext;
      if (chipContext == null) return;
      Scrollable.ensureVisible(
        chipContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  void _focusAddedServiceTarget(Object? result) {
    if (result is! Map || result['updated'] != true) return;

    final categoryId = _asInt(result['categoryId']);
    final subCategoryId = _asInt(result['subCategoryId']);
    if (categoryId == null) return;

    _pendingScrollOffset = null;
    _catalogSearchController.clear();
    setState(() {
      _catalogQuery = '';
      _expandedCategories
        ..clear()
        ..[categoryId] = true;
      _expandedSubcategories.clear();
      if (subCategoryId != null) {
        _expandedSubcategories[subCategoryId] = true;
      }
      _selectedFilterCategoryId = categoryId;
    });

    _ensureFilterChipVisible(categoryId);
    _ensureCatalogTargetVisible(
      subCategoryId == null
          ? _categoryItemKeys[categoryId]
          : _subcategoryItemKeys[subCategoryId] ??
              _categoryItemKeys[categoryId],
    );
  }

  void _ensureCatalogTargetVisible(GlobalKey? key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = key?.currentContext;
        if (targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      });
    });
  }

  // ---------- ADD / EDIT SUBCATEGORY ----------
  Future<void> _openSubcategorySheet({
    Map<String, dynamic>? subCategory,
    required int categoryId,
  }) async {
    _dismissCatalogKeyboard();
    if (_selectedSalon == null) return;

    final branchId = _selectedSalon!['branchId'] as int;

    await showDialog<void>(
      context: context,
      builder: (sheetContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: const RoundedRectangleBorder(),
        backgroundColor: Colors.white,
        child: _EditSubcategorySheet(
          subCategory: subCategory,
          branchId: branchId, // sheet will call the cubit & show loader
          categoryId: categoryId, // needed for add
        ),
      ),
    );
    _dismissCatalogKeyboard();
  }

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
    final deletedCategoryId = category['id'] as int;
    final categoryCubit = context.read<CategoryCubit>();
    debugPrint('🗑️ DELETE CATEGORY START categoryId=$deletedCategoryId');
    if (mounted) {
      ScaffoldMessenger.of(context);
    }

    try {
      final deleted = await categoryCubit.deleteCategory(
        branchId,
        deletedCategoryId,
      );

      if (!deleted) {
        final deleteState = categoryCubit.state;
        debugPrint('❌ DELETE CATEGORY FAILED: ${deleteState.message}');
        return;
      }

      debugPrint('✅ DELETE CATEGORY DONE');

      if (!mounted) return;

      setState(() {
        if (_selectedFilterCategoryId == deletedCategoryId) {
          _selectedFilterCategoryId = null;
        }

        _expandedCategories.remove(deletedCategoryId);
        _categoryItemKeys.remove(deletedCategoryId);
      });
      await _refreshData();
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

  String? validateCommissionMax({
    required int priceMinor,
    required bool commissionEnabled,
    required String commissionType,
    required double commissionPercentage,
    required int? commissionMaxAmountMinor,
  }) {
    if (!commissionEnabled) return null;
    if (commissionType.toLowerCase() != 'percentage') return null;
    if (commissionMaxAmountMinor == null) return null;

    final allowedMax = (priceMinor * commissionPercentage / 100).floor();

    if (commissionMaxAmountMinor > allowedMax) {
      return 'Max commission cannot exceed ${formatMinorAmount(allowedMax)} for the selected price and percentage.';
    }

    return null;
  }

  // ---------- EDIT SERVICE ----------
  Future<void> _showUpdateServiceSheet(Map<String, dynamic> service) async {
    if (_selectedSalon == null) return;
    _rememberScrollPosition();
    final branchId = _selectedSalon?['branchId'] as int? ??
        _selectedSalon!['salonId'] as int;
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddServices(
          branchId: branchId,
          categories: context.read<CategoryCubit>().state.categories,
          serviceToEdit: service,
        ),
      ),
    );

    if (!mounted) return;
    final updated =
        result == true || (result is Map && result['updated'] == true);
    if (updated) {
      await context.read<CategoryCubit>().loadCategories(branchId);
      if (result is Map) {
        _focusAddedServiceTarget(result);
      } else {
        _restoreScrollPosition();
      }
    }
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

    final updated =
        result == true || (result is Map && result['updated'] == true);
    if (updated) {
      // Refresh categories/services after adding a service
      await _refreshData();
      _focusAddedServiceTarget(result);
    }
  }

  Future<void> _showPredefinedServicesModal() async {
    if (_selectedSalon == null) return;
    final branchId = _asInt(_selectedSalon?['branchId']) ??
        _asInt(_selectedSalon?['salonId']);
    if (branchId == null) return;

    try {
      final branchServicesResponse =
          await ApiService().getBranchService(branchId: branchId);
      final response = await ApiService().getServiceCatalog();
      final items = _sortedCatalogItems(
        (response['data'] as List? ?? const []).whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ),
      );
      if (!mounted) return;

      final catalogCodeMap = <String, String>{
        for (final item in items)
          if ((item['code'] ?? '').toString().trim().isNotEmpty)
            (item['code'] ?? '').toString().trim().toUpperCase():
                (item['code'] ?? '').toString().trim(),
      };
      final catalogCodes = catalogCodeMap.keys.toSet();
      final branchTopLevelCodes =
          _collectBranchTopCategories(branchServicesResponse['data'])
              .map((category) =>
                  (category['code'] ?? '').toString().trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toSet();
      final initiallySelectedTopLevelCodes = branchTopLevelCodes
          .where((code) => catalogCodes.contains(code))
          .toSet();
      final currentlyImportedCatalogCategories = _collectBranchTopCategories(
        branchServicesResponse['data'],
      ).where((category) {
        final code = (category['code'] ?? '').toString().trim().toUpperCase();
        return code.isNotEmpty && catalogCodes.contains(code);
      }).toList();
      final Set<String> selectedCodes = <String>{
        ...initiallySelectedTopLevelCodes,
      };
      debugPrint('🟡 catalogCodes: $catalogCodes');
      debugPrint(
          '🟡 initiallySelectedTopLevelCodes: $initiallySelectedTopLevelCodes');
      debugPrint(
        '🟡 currentlyImportedCatalogCategories: ${currentlyImportedCatalogCategories.map((category) => '${category['code']}#${category['id']}').toList()}',
      );
      debugPrint('🟡 selectedCodes initial: $selectedCodes');
      bool isImporting = false;
      final imported = await showGeneralDialog<List<String>>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 260),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
        pageBuilder: (sheetContext, animation, secondaryAnimation) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.88,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 24,
                            offset: Offset(-8, 0),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  translateText('Add predefined services'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: isImporting
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded),
                                color: _catalogGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final actualCode =
                                    (item['code'] ?? '').toString().trim();
                                final code = actualCode.toUpperCase();
                                final label = _catalogItemLabel(item);
                                final imageUrl = _catalogItemImageUrl(item);
                                return InkWell(
                                  onTap: code.isEmpty || isImporting
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            if (selectedCodes.contains(code)) {
                                              selectedCodes.remove(code);
                                            } else {
                                              selectedCodes.add(code);
                                            }
                                          });
                                        },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F1EA),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: imageUrl == null
                                              ? const Icon(
                                                  Icons.content_cut_outlined,
                                                  color: _catalogGold,
                                                  size: 20,
                                                )
                                              : Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.content_cut_outlined,
                                                    color: _catalogGold,
                                                    size: 20,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            label.isEmpty
                                                ? translateText(
                                                    'Unnamed service')
                                                : label,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Checkbox(
                                          value: selectedCodes.contains(code),
                                          activeColor: _catalogGold,
                                          onChanged: code.isEmpty || isImporting
                                              ? null
                                              : (checked) {
                                                  setSheetState(() {
                                                    if (checked == true) {
                                                      selectedCodes.add(code);
                                                    } else {
                                                      selectedCodes
                                                          .remove(code);
                                                    }
                                                  });
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isImporting
                                  ? null
                                  : () async {
                                      setSheetState(() => isImporting = true);
                                      try {
                                        final apiService = ApiService();
                                        final selectedActualCodes =
                                            selectedCodes
                                                .map((code) =>
                                                    catalogCodeMap[code] ??
                                                    code)
                                                .toList();
                                        final removedActualCodes = <String>{};
                                        for (final category
                                            in currentlyImportedCatalogCategories) {
                                          final code = (category['code'] ?? '')
                                              .toString()
                                              .trim()
                                              .toUpperCase();
                                          if (code.isEmpty ||
                                              selectedCodes.contains(code)) {
                                            continue;
                                          }
                                          for (final removedCode
                                              in _collectCatalogCodes(
                                                  category)) {
                                            removedActualCodes.add(
                                              catalogCodeMap[removedCode] ??
                                                  removedCode,
                                            );
                                          }
                                        }
                                        final removedCodesList =
                                            removedActualCodes.toList();

                                        debugPrint(
                                            '🟢 selectedCodes before import: $selectedCodes');
                                        debugPrint(
                                            '🟢 sending serviceCodes: $selectedActualCodes');
                                        debugPrint(
                                          '🟠 removing imported catalog codes: $removedCodesList',
                                        );

                                        final importResponse = await apiService
                                            .importPredefinedServices(
                                          branchId: branchId,
                                          serviceCodes: selectedActualCodes,
                                          unselectedCodes: removedCodesList,
                                        );
                                        debugPrint(
                                          '✅ importPredefinedServices response: $importResponse',
                                        );

                                        if (!sheetContext.mounted) return;
                                        Navigator.pop(
                                          sheetContext,
                                          selectedActualCodes,
                                        );
                                      } catch (error) {
                                        if (!mounted) return;
                                        _toast(error.toString());
                                        if (sheetContext.mounted) {
                                          setSheetState(
                                              () => isImporting = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _catalogGold,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isImporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(translateText('Submit')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (imported == null) return;
      if (!mounted) return;
      setState(() {
        _selectedFilterCategoryId = null;
      });
      _toast(translateText('Predefined services imported successfully'));
      await _refreshData();
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString());
    }
  }

  List<Map<String, dynamic>> _collectBranchTopCategories(dynamic value) {
    final data = value is Map ? value['categories'] : value;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(_isCatalogItemActive)
        .toList();
  }

  List<String> _collectCatalogCodes(Map<String, dynamic> item) {
    final codes = <String>[];

    final code = (item['code'] ?? '').toString().trim().toUpperCase();
    if (code.isNotEmpty) {
      codes.add(code);
    }

    final subCategories = item['subCategories'];
    if (subCategories is List) {
      for (final subCategory in subCategories) {
        if (subCategory is! Map) continue;
        codes.addAll(_collectCatalogCodes(
          Map<String, dynamic>.from(subCategory),
        ));
      }
    }

    final services = item['services'];
    if (services is List) {
      for (final service in services) {
        if (service is! Map) continue;
        final serviceCode =
            (service['code'] ?? '').toString().trim().toUpperCase();
        if (serviceCode.isNotEmpty) {
          codes.add(serviceCode);
        }
      }
    }

    return codes;
  }

  String _catalogItemLabel(Map<String, dynamic> item) {
    for (final key in const ['displayName', 'name', 'serviceName', 'title']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String? _catalogItemImageUrl(Map<String, dynamic> item) {
    for (final key in const [
      'image_url',
      'imageUrl',
      'image',
      'iconUrl',
      'photoUrl',
      'thumbnailUrl',
    ]) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
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
        _selectedSalon = {
          'salonId': salonId,
          'salonName': salon['name'],
          'branchId': branchId,
          'branchName': branch['name'],
          'addressSummary': _catalogBranchAddressSummary(branch['address']),
        };
        _expandedCategories.clear();
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
      _selectedSalon = {
        'salonId': fallbackSalonId,
        'salonName': fallbackSalon['name'],
        'branchName': fallbackSalon['name'],
        'addressSummary':
            _catalogBranchAddressSummary(fallbackSalon['address']),
      };
      _expandedCategories.clear();
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
    final salons = salonState.salons
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final branchSelections = _catalogBranchSelections(salons);
    // final showHeaderBranchSelector =
    //     _selectedSalon != null && branchSelections.length > 1;
    final showHeaderBranchSelector =
        _selectedSalon != null && branchSelections.length > 1;

    final showServiceCatalogTitle = !showHeaderBranchSelector;

    _scheduleSyncFromBookings(salons);

    return Scaffold(
      backgroundColor: _catalogSurface,
      // appBar: buildProfileSubpageAppBar(
      //   title: '',
      //   automaticallyImplyLeading: false,
      //   toolbarHeight: showHeaderBranchSelector ? 84 : kToolbarHeight,
      //   titleWidget: showHeaderBranchSelector
      //       ? _CatalogBranchSelector(
      //           key: _branchSelectorKey,
      //           selectedSalon: _selectedSalon,
      //           showDropdown: true,
      //           onTap: () => _showSalonBranchPicker(salons),
      //         )
      //       : null,
      //   actions: [
      //     IconButton(
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      //         );
      //       },
      //       icon: const Icon(Icons.notifications_none_rounded),
      //       color: _catalogGold,
      //     ),
      //     IconButton(
      //       tooltip: translateText('Add predefined services'),
      //       onPressed:
      //           _selectedSalon == null ? null : _showPredefinedServicesModal,
      //       icon: const Icon(Icons.playlist_add_check_rounded),
      //       color: _catalogGold,
      //     ),
      //   ],
      // ),
      appBar: buildProfileSubpageAppBar(
        title: showServiceCatalogTitle ? translateText('Service Catalog') : '',
        automaticallyImplyLeading: false,
        toolbarHeight: showHeaderBranchSelector ? 58 : kToolbarHeight,
        titleWidget: showHeaderBranchSelector
            ? _CatalogBranchSelector(
                key: _branchSelectorKey,
                selectedSalon: _selectedSalon,
                showDropdown: true,
                compact: true,
                onTap: () => _showSalonBranchPicker(salons),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
            color: _catalogGold,
          ),
          IconButton(
            tooltip: translateText('Add predefined services'),
            onPressed:
                _selectedSalon == null ? null : _showPredefinedServicesModal,
            icon: const Icon(Icons.playlist_add_check_rounded),
            color: _catalogGold,
          ),
        ],
      ),
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
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: _catalogSurface,
                      child: _buildCatalogueContent(catState, salons),
                    ),
                  ),
                ],
              ),
              if (catState.isSubmitting ||
                  (catState.isLoading && _selectedSalon != null))
                _buildLoaderOverlay(),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedSalon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: 'catalogueFab',
                onPressed: () => _showAddCategorySheet(),
                backgroundColor: _catalogGold,
                foregroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCatalogueContent(
    CategoryState catState,
    List<Map<String, dynamic>> salons,
  ) {
    final visibleCategories = _visibleCategories(catState.categories);
    final isInitialLoading = catState.isLoading && catState.categories.isEmpty;

    return RefreshIndicator(
      color: _catalogGold,
      displacement: 32,
      onRefresh: _refreshData,
      child: ListView(
        controller: _catalogScrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 104),
        children: [
          _buildCatalogIntroActions(catState),
          const SizedBox(height: 14),
          _buildQuickSearchField(),
          if (catState.categories.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildCategoryFilterChips(catState.categories),
            const SizedBox(height: 26),
          ] else
            const SizedBox(height: 22),
          if (_selectedSalon == null) ...[
            _EmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: translateText('Choose a salon'),
              subtitle: translateText('Please select a salon first.'),
            ),
          ] else ...[
            if (isInitialLoading)
              const SizedBox(height: 260)
            else if (catState.status == CategoryStatus.failure &&
                catState.categories.isEmpty)
              _ErrorCard(
                message: catState.message ?? 'Failed to load categories',
                onRetry: _refreshData,
              )
            else if (catState.categories.isEmpty) ...[
              _EmptyState(
                icon: Icons.category_outlined,
                title: translateText('No categories yet'),
                subtitle: translateText(
                  'Tap "New Category" to create your first one.',
                ),
              ),
            ] else ...[
              if (visibleCategories.isNotEmpty)
                _CategoryList(
                  categories: visibleCategories,
                  allCategories: catState.categories,
                  onAddSubcategory: _openSubcategorySheet,
                  onEditSubcategory: _openSubcategorySheet,
                  // onAddServices: _openAddService,
                  onEditCategory: _showAddCategorySheet,
                  onDeleteCategory: _confirmDeleteCategory,
                  onDeleteSubcategory: _confirmDeleteSubCategory,
                  onEditService: _showUpdateServiceSheet,
                  onDeleteService: _confirmDeleteService,
                  categoryExpanded: _expandedCategories,
                  categoryKeys: _categoryItemKeys,
                  selectedFilterCategoryId: _selectedFilterCategoryId,
                  expanded: _expandedSubcategories,
                  subcategoryKeys: _subcategoryItemKeys,
                  toggleCategoryExpanded: (id) => setState(() {
                    _expandedCategories[id] =
                        !(_expandedCategories[id] ?? false);
                  }),
                  toggleExpanded: (id) => setState(() {
                    _expandedSubcategories[id] =
                        !(_expandedSubcategories[id] ?? false);
                  }),
                ),
              if (visibleCategories.isEmpty)
                _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: translateText('No services found'),
                  subtitle: translateText('Try another search or category.'),
                ),
            ],
          ],
          SizedBox(height: 40),
        ],
      ),
    );
  }

  List<dynamic> _visibleCategories(List<dynamic> categories) {
    final query = _catalogQuery.trim().toLowerCase();

    final visibleCategories = categories.where((rawCategory) {
      final category = Map<String, dynamic>.from(rawCategory as Map);
      final categoryId = _asInt(category['id']);
      if (_selectedFilterCategoryId != null &&
          categoryId != _selectedFilterCategoryId) {
        return false;
      }

      if (query.isEmpty) return true;

      bool matchesText(dynamic value) {
        return (value ?? '').toString().toLowerCase().contains(query);
      }

      if (matchesText(category['displayName']) ||
          matchesText(category['name'])) {
        return true;
      }

      final subCategories = category['subCategories'];
      if (subCategories is List) {
        for (final subCategory in subCategories) {
          if (subCategory is! Map) continue;
          if (matchesText(subCategory['displayName']) ||
              matchesText(subCategory['name'])) {
            return true;
          }
          final services = subCategory['services'];
          if (services is List && _servicesContainQuery(services, query)) {
            return true;
          }
        }
      }

      final services = category['services'];
      return services is List && _servicesContainQuery(services, query);
    }).toList()
      ..sort((first, second) {
        if (first is! Map || second is! Map) return 0;
        return _compareCatalogItems(
          Map<String, dynamic>.from(first),
          Map<String, dynamic>.from(second),
        );
      });

    return visibleCategories;
  }

  bool _servicesContainQuery(List<dynamic> services, String query) {
    for (final service in services) {
      if (service is! Map) continue;
      final values = [
        service['displayName'],
        service['name'],
        service['description'],
      ];
      if (values.any(
          (value) => (value ?? '').toString().toLowerCase().contains(query))) {
        return true;
      }
    }
    return false;
  }

  Widget _buildCatalogIntroActions(CategoryState catState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translateText('MASTER CATALOG'),
                style: const TextStyle(
                  color: _catalogMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                translateText('Manage Services'),
                style: const TextStyle(
                  color: _catalogInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // SizedBox(
        //   height: 30,
        //   child: ElevatedButton.icon(
        //     onPressed: _selectedSalon == null
        //         ? null
        //         : () => _openAddService(
        //               const <String, dynamic>{},
        //               catState.categories,
        //             ),
        //     icon: const Icon(Icons.add_circle_outline_rounded, size: 13),
        //     label: Text(
        //       translateText('Add Service'),
        //       maxLines: 1,
        //       overflow: TextOverflow.ellipsis,
        //       style: const TextStyle(
        //         fontSize: 9,
        //         fontWeight: FontWeight.w800,
        //       ),
        //     ),
        //     style: ElevatedButton.styleFrom(
        //       minimumSize: Size.zero,
        //       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //       backgroundColor: _catalogGold,
        //       foregroundColor: Colors.white,
        //       elevation: 0,
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(8),
        //       ),
        //       padding: const EdgeInsets.symmetric(horizontal: 12),
        //     ),
        //   ),
        // ),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _selectedSalon == null
                ? null
                : () => _openAddService(
                      const <String, dynamic>{},
                      catState.categories,
                    ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: Text(
              translateText('Add Service'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: _catalogGold,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSearchField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9CBBB)),
      ),
      child: TextField(
        controller: _catalogSearchController,
        focusNode: _catalogSearchFocusNode,
        autofocus: false,
        cursorColor: _catalogGold,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        // maxLength: 60,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [
          LengthLimitingTextInputFormatter(60),
        ],
        onChanged: (value) => setState(() => _catalogQuery = value),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _catalogGold,
            size: 24,
          ),
          suffixIcon: _catalogQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: _catalogMuted),
                  onPressed: () {
                    _catalogSearchController.clear();
                    setState(() => _catalogQuery = '');
                  },
                ),
          hintText: translateText('Find services, stylists, or treatments...'),
          hintStyle: const TextStyle(
            color: Color(0xFF34302C),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 19),
        ),
      ),
    );
  }

  // Widget _buildCategoryFilterChips(List<dynamic> categories) {
  //   final categoryItems = _sortedCatalogItems(
  //     categories.whereType<Map>().map(
  //           (entry) => Map<String, dynamic>.from(entry),
  //         ),
  //   );
  //   if (categoryItems.isEmpty) return const SizedBox.shrink();

  //   return SizedBox(
  //     height: 34,
  //     child: SingleChildScrollView(
  //       scrollDirection: Axis.horizontal,
  //       child: Container(
  //         padding: const EdgeInsets.all(3),
  //         decoration: BoxDecoration(
  //           color: const Color(0xFFEDEBE9),
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         child: Row(
  //           children: List.generate(categoryItems.length + 1, (index) {
  //             final bool isAll = index == 0;
  //             final category = isAll ? null : categoryItems[index - 1];
  //             final int? categoryId = isAll ? null : _asInt(category?['id']);
  //             final bool selected = isAll
  //                 ? _selectedFilterCategoryId == null
  //                 : _selectedFilterCategoryId == categoryId;
  //             final label = isAll
  //                 ? translateText('All Services')
  //                 : (category?['displayName'] ??
  //                         category?['name'] ??
  //                         'Category')
  //                     .toString();

  //             return Padding(
  //               padding: EdgeInsets.only(
  //                 left: index == 0 ? 0 : 2,
  //                 right: index == categoryItems.length ? 0 : 2,
  //               ),
  //               child: Material(
  //                 key: !isAll && categoryId != null
  //                     ? _filterChipKeys.putIfAbsent(
  //                         categoryId,
  //                         () => GlobalKey(),
  //                       )
  //                     : null,
  //                 color: Colors.transparent,
  //                 child: InkWell(
  //                   borderRadius: BorderRadius.circular(6),
  //                   onTap: () {
  //                     setState(() => _selectedFilterCategoryId = categoryId);
  //                     if (categoryId != null) {
  //                       _ensureFilterChipVisible(categoryId);
  //                     }
  //                   },
  //                   splashColor: Colors.transparent,
  //                   highlightColor: Colors.transparent,
  //                   child: AnimatedContainer(
  //                     duration: const Duration(milliseconds: 180),
  //                     constraints: const BoxConstraints(minWidth: 92),
  //                     padding: const EdgeInsets.symmetric(horizontal: 14),
  //                     alignment: Alignment.center,
  //                     decoration: BoxDecoration(
  //                       color: selected ? _catalogGold : Colors.transparent,
  //                       borderRadius: BorderRadius.circular(6),
  //                       border: selected
  //                           ? Border.all(color: _catalogGold, width: 1)
  //                           : null,
  //                       boxShadow: selected
  //                           ? const [
  //                               BoxShadow(
  //                                 color: Color(0x248B6500),
  //                                 blurRadius: 8,
  //                                 offset: Offset(0, 3),
  //                               ),
  //                             ]
  //                           : const [],
  //                     ),
  //                     child: Text(
  //                       label,
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: const TextStyle(
  //                         fontFamily: 'Manrope',
  //                         fontFamilyFallback: ['Inter', 'sans-serif'],
  //                         fontSize: 11,
  //                         fontWeight: FontWeight.w800,
  //                         letterSpacing: 0.2,
  //                       ).copyWith(
  //                         color: selected ? Colors.white : _catalogMuted,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             );
  //           }),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildCategoryFilterChips(List<dynamic> categories) {
    final categoryItems = _sortedCatalogItems(
      categories.whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
    );

    if (categoryItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(categoryItems.length + 1, (index) {
            final bool isAll = index == 0;
            final category = isAll ? null : categoryItems[index - 1];
            final int? categoryId = isAll ? null : _asInt(category?['id']);

            final bool selected = isAll
                ? _selectedFilterCategoryId == null
                : _selectedFilterCategoryId == categoryId;

            final label = isAll
                ? translateText('All Services')
                : (category?['displayName'] ?? category?['name'] ?? 'Category')
                    .toString();

            return Padding(
              padding: EdgeInsets.only(
                right: index == categoryItems.length ? 0 : 10,
              ),
              child: Material(
                key: !isAll && categoryId != null
                    ? _filterChipKeys.putIfAbsent(
                        categoryId,
                        () => GlobalKey(),
                      )
                    : null,
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => _selectedFilterCategoryId = categoryId);
                    if (categoryId != null) {
                      _ensureFilterChipVisible(categoryId);
                    }
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 32,
                    constraints: const BoxConstraints(minWidth: 84),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _catalogGold : const Color(0xFFE9E0DE),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x248B6500),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : const [],
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: const ['Inter', 'sans-serif'],
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : _catalogMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showSalonBranchPicker(List<Map<String, dynamic>> salons) async {
    _dismissCatalogKeyboard();

    final selections = _catalogBranchSelections(salons);
    if (selections.length <= 1) return;

    final selectorContext = _branchSelectorKey.currentContext;
    final selectorBox = selectorContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (selectorBox == null || overlayBox == null) return;

    final selectorOffset = selectorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final selectorRect = selectorOffset & selectorBox.size;
    final menuWidth = overlayBox.size.width - 32;

    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      position: RelativeRect.fromLTRB(
        16,
        selectorRect.bottom + 8,
        16,
        0,
      ),
      constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _catalogBorder),
      ),
      items: selections.map((item) {
        final bool isSelected =
            _asInt(item['branchId']) == _asInt(_selectedSalon?['branchId']) &&
                _asInt(item['salonId']) == _asInt(_selectedSalon?['salonId']);
        return PopupMenuItem<Map<String, dynamic>>(
          value: item,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _CatalogBranchDropdownItem(
            item: item,
            isSelected: isSelected,
          ),
        );
      }).toList(),
    );

    if (!mounted || selected == null) return;
    _dismissCatalogKeyboard();
    await _selectSalonBranch(selected);
  }

  List<Map<String, dynamic>> _catalogBranchSelections(
    List<Map<String, dynamic>> salons,
  ) {
    final selections = <Map<String, dynamic>>[];
    for (final salon in salons) {
      final salonId = _asInt(salon['id']);
      if (salonId == null) continue;
      final branches = salon['branches'];
      if (branches is List && branches.isNotEmpty) {
        for (final rawBranch in branches) {
          if (rawBranch is! Map) continue;
          final branch = Map<String, dynamic>.from(rawBranch);
          final branchId = _asInt(branch['id']);
          if (branchId == null) continue;
          selections.add({
            'salonId': salonId,
            'salonName': salon['name'],
            'branchId': branchId,
            'branchName': branch['name'] ?? salon['name'],
            'addressSummary': _catalogBranchAddressSummary(branch['address']),
          });
        }
      } else {
        selections.add({
          'salonId': salonId,
          'salonName': salon['name'],
          'branchName': salon['name'],
          'addressSummary': _catalogBranchAddressSummary(salon['address']),
        });
      }
    }

    return selections;
  }

  Future<void> _selectSalonBranch(Map<String, dynamic> selection) async {
    _dismissCatalogKeyboard();

    final branchId =
        _asInt(selection['branchId']) ?? _asInt(selection['salonId']);
    if (branchId == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (_asInt(selection['branchId']) != null) {
      await prefs.setInt('selected_branch_id', branchId);
    }

    if (!mounted) return;
    setState(() {
      _selectedSalon = selection;
      _expandedCategories.clear();
      _expandedSubcategories.clear();
      _selectedFilterCategoryId = null;
    });

    context.read<SalonListCubit>().setSelectedSalon(selection);
    final categoryCubit = context.read<CategoryCubit>();
    categoryCubit.resetCategories();
    categoryCubit.loadCategories(branchId);
  }

  // Future<void> _refreshData() async {
  //   if (_selectedSalon != null) {
  //     final int? loadId = _asInt(_selectedSalon?['branchId']) ??
  //         _asInt(_selectedSalon?['salonId']);
  //     if (loadId != null) {
  //       await context
  //           .read<CategoryCubit>()
  //           .loadCategories(loadId, silent: true);
  //     } else {
  //       await context.read<SalonListCubit>().loadSalons();
  //     }
  //   } else {
  //     await context.read<SalonListCubit>().loadSalons();
  //   }
  // }
  Future<void> _refreshData() async {
    if (_selectedSalon != null) {
      final int? loadId = _asInt(_selectedSalon?['branchId']) ??
          _asInt(_selectedSalon?['salonId']);

      if (loadId != null) {
        final categoryCubit = context.read<CategoryCubit>();

        // Clear local catalog first so deleted items cannot remain from cache/state.
        categoryCubit.resetCategories();

        // Fetch fresh active catalog from backend.
        await categoryCubit.loadCategories(loadId, silent: true);
      } else {
        await context.read<SalonListCubit>().loadSalons();
      }
    } else {
      await context.read<SalonListCubit>().loadSalons();
    }
  }

  // ---------- OVERLAY ----------
  Widget _buildLoaderOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          IgnorePointer(
            child: Container(
              color: Colors.white.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.starColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------
  void _toast(String msg) {
    if (!mounted) return;
    final toast = FToast()..init(context);
    final screenWidth = MediaQuery.of(context).size.width;

    toast.showToast(
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth - 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4B4B4B),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogBranchSelector extends StatelessWidget {
  const _CatalogBranchSelector({
    super.key,
    required this.selectedSalon,
    required this.showDropdown,
    required this.onTap,
    this.compact = false,
  });

  final Map<String, dynamic>? selectedSalon;
  final bool showDropdown;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final branchLabel = _catalogBranchLabel(selectedSalon);
    final addressSummary =
        (selectedSalon?['addressSummary'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 32 : 70),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 5 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 8 : 10),
            border: Border.all(color: const Color(0xFFD9CBBB)),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 24 : 42,
                height: compact ? 24 : 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8D1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: _catalogGold,
                  size: compact ? 16 : 24,
                ),
              ),
              SizedBox(width: compact ? 8 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      branchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _catalogInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!compact && addressSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        addressSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _catalogMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showDropdown)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _catalogMuted,
                ),
            ],
          ),
        ),
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

class _CatalogBranchDropdownItem extends StatelessWidget {
  const _CatalogBranchDropdownItem({
    required this.item,
    required this.isSelected,
  });

  final Map<String, dynamic> item;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final addressSummary = (item['addressSummary'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _catalogGold.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSelected ? _catalogGold : _catalogBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _catalogGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: _catalogGold,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _catalogBranchLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _catalogInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (addressSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    addressSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _catalogMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isSelected ? _catalogGold : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _catalogGold : _catalogBorder,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  )
                : null,
          ),
        ],
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
    required this.allCategories,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    // required this.onAddServices,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onDeleteSubcategory,
    required this.onEditService,
    required this.onDeleteService,
    required this.categoryExpanded,
    required this.categoryKeys,
    required this.selectedFilterCategoryId,
    required this.expanded,
    required this.subcategoryKeys,
    required this.toggleCategoryExpanded,
    required this.toggleExpanded,
  });

  final List<dynamic> categories;
  final List<dynamic> allCategories;

  final SubcategoryOp onAddSubcategory;
  final SubcategoryOp onEditSubcategory;

  // final void Function(Map<String, dynamic> category, List<dynamic> categories)
  //     onAddServices;

  final Future<void> Function({Map<String, dynamic>? category}) onEditCategory;

  final Future<void> Function(Map<String, dynamic> category) onDeleteCategory;

  final Future<void> Function(Map<String, dynamic>) onDeleteSubcategory;
  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int serviceId) onDeleteService;

  final Map<int, bool> categoryExpanded;
  final Map<int, GlobalKey> categoryKeys;
  final int? selectedFilterCategoryId;
  final Map<int, bool> expanded;
  final Map<int, GlobalKey> subcategoryKeys;
  final void Function(int id) toggleCategoryExpanded;
  final void Function(int id) toggleExpanded;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final sortedCategories = _sortedCatalogItems(
      categories
          .whereType<Map>()
          .map(
            (entry) => Map<String, dynamic>.from(entry),
          )
          .where(_isCatalogItemActive),
    );

    return ListView.separated(
      itemCount: sortedCategories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => SizedBox(height: 18),
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final List<Map<String, dynamic>> rawSubCategories = _sortedCatalogItems(
          (category['subCategories'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (e) => Map<String, dynamic>.from(e),
              )
              .where(_isCatalogItemActive),
        );
        final subServiceIds = <int>{};
        final List<Map<String, dynamic>> subCategories =
            rawSubCategories.map((subCategory) {
          final services = _uniqueCatalogServices(
            _sortedCatalogItems(
              (subCategory['services'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .where(_isCatalogItemActive),
            ),
            seenIds: subServiceIds,
          );
          return {
            ...subCategory,
            'services': services,
          };
        }).toList();
        final List<Map<String, dynamic>> categoryServices =
            _uniqueCatalogServices(
          _sortedCatalogItems(
            (category['services'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (e) => Map<String, dynamic>.from(e),
                )
                .where(_isCatalogItemActive),
          ).where((service) {
            final serviceId = _serviceInt(service['id']);
            return serviceId == null || !subServiceIds.contains(serviceId);
          }),
        );
        final int categoryId = _serviceInt(category['id']) ?? index;
        final bool isCategoryExpanded = categoryExpanded[categoryId] ?? false;
        final bool isSelectedFilter = selectedFilterCategoryId == categoryId;
        final serviceCount = _serviceCountForCategory(category);

        final categoryKey =
            categoryKeys.putIfAbsent(categoryId, () => GlobalKey());

        return Container(
          key: categoryKey,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelectedFilter ? _catalogGold : _catalogBorder,
              width: isSelectedFilter ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: isSelectedFilter
                      ? const Color(0xFFFFF8E8)
                      : const Color(0xFFFBFAF8),
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(14),
                    bottom: Radius.circular(isCategoryExpanded ? 0 : 14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => toggleCategoryExpanded(categoryId),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _catalogGoldLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _catalogIconForCategory(category),
                                color: _catalogGold,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category['displayName'] as String? ??
                                        'Category',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _catalogGold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$serviceCount ${translateText('SERVICES AVAILABLE')}',
                                    style: const TextStyle(
                                      color: _catalogMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _IconButton(
                      icon: Icons.edit_outlined,
                      color: _catalogGold,
                      tooltip: 'Edit category',
                      onTap: () => onEditCategory(category: category),
                    ),
                    const SizedBox(width: 6),
                    _IconButton(
                      icon: Icons.delete_outline_rounded,
                      color: _catalogGold,
                      tooltip: 'Delete category',
                      onTap: () => onDeleteCategory(category),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => toggleCategoryExpanded(categoryId),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _catalogBorder),
                        ),
                        child: Icon(
                          isCategoryExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _catalogGold,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCategoryExpanded && categoryServices.isNotEmpty)
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
              if (isCategoryExpanded && categoryServices.isNotEmpty)
                const SizedBox(height: 10),
              if (isCategoryExpanded && subCategories.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _NoDataPill(message: 'No subcategories added yet'),
                )
              else if (isCategoryExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(
                    children: subCategories.map((sub) {
                      final int subId = sub['id'] as int;
                      return _SubcategoryTile(
                        key: subcategoryKeys.putIfAbsent(
                          subId,
                          () => GlobalKey(),
                        ),
                        categoryId: categoryId,
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
              if (isCategoryExpanded) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              onAddSubcategory(categoryId: categoryId),
                          icon: const Icon(
                            Icons.folder_open_rounded,
                            size: 16,
                          ),
                          label: Text(
                            translateText('Add Subcategory'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: _catalogGold,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    super.key,
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
    final List<Map<String, dynamic>> services = _sortedCatalogItems(
      (subCategory['services'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .where(_isCatalogItemActive),
    );
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('sub-${subCategory['id']}-$isExpanded'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (value) {
            if (value != isExpanded) {
              toggle();
            }
          },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder_open_outlined,
                    color: _catalogGold,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subCategory['displayName'] as String? ?? 'Subcategory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _catalogInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 25),
                  child: Text(
                    '${services.length} ${translateText(services.length == 1 ? 'SERVICE' : 'SERVICES')}',
                    style: const TextStyle(
                      color: _catalogGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
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
                  icon: Icons.edit_outlined,
                  color: _catalogGold,
                  tooltip: 'Edit subcategory',
                  onTap: () => onEditSubcategory(
                    subCategory: subCategory,
                    categoryId: categoryId,
                  ),
                ),
                SizedBox(width: 4),
                _IconButton(
                  icon: Icons.delete_outline_rounded,
                  color: _catalogGold,
                  tooltip: 'Delete subcategory',
                  onTap: () => onDeleteSubcategory(subCategory),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _catalogGold,
                  size: 20,
                ),
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
    final int? price = _serviceInt(service['priceMinor']);
    final int? duration = _serviceInt(service['durationMin']);
    final String description = (service['description'] ?? '').toString().trim();
    final String commissionTagLabel = _serviceCommissionTagLabel(service);
    final bool showCommissionTag = service['commissionEnabled'] == true;
    final String waitLabel = _servicePassiveWaitLabel(service);

    final String priceLabel = price != null
        ? formatMinorAmount(price, trimZeroDecimals: true)
        : translateText('No price');
    final String durationLabel =
        duration != null ? '$duration min' : translateText('No duration');
    final String serviceMeta = [
      durationLabel,
      if (waitLabel.isNotEmpty) waitLabel,
      if (description.isNotEmpty) description,
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _catalogBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _catalogInk,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        serviceMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _catalogMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlainIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit service',
                        onTap: () => onEditService(service),
                      ),
                      const SizedBox(width: 8),
                      _PlainIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete service',
                        onTap: () => onDeleteService(service['id'] as int),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    priceLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _catalogGold,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showCommissionTag) ...[
                    const SizedBox(height: 8),
                    Text(
                      commissionTagLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _catalogGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            color: _catalogInk,
            size: 16,
          ),
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
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _catalogBorder),
        ),
        child: Icon(icon, color: _darken(color, .2), size: 17),
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

class _BottomSheetScaffold extends StatelessWidget {
  const _BottomSheetScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _catalogInk,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: _catalogMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF4B4038),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

InputDecoration _dialogInputDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF7F4F3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _catalogBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _catalogBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _catalogGoldLight, width: 1.2),
    ),
  );
}

ButtonStyle _dialogPrimaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: _catalogGold,
    foregroundColor: Colors.white,
    elevation: 8,
    shadowColor: const Color(0x338B6500),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: inputFormatters,
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
  const _EditCategorySheet({
    this.category,
    required this.branchId,
    required this.existingCategories,
  });
  final Map<String, dynamic>? category;
  final int branchId;
  final List<dynamic> existingCategories;

  @override
  State<_EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<_EditCategorySheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;

  bool isSaving = false;
  String? errorText;

  bool get isEdit => widget.category != null;

  String _categoryNameKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  bool _hasDuplicateCategoryName(String value) {
    final candidateKey = _categoryNameKey(value);
    if (candidateKey.isEmpty) return false;

    final currentCategoryId = widget.category?['id'];
    for (final rawCategory in widget.existingCategories) {
      if (rawCategory is! Map) continue;
      final category = Map<String, dynamic>.from(rawCategory);
      if (currentCategoryId != null && category['id'] == currentCategoryId) {
        continue;
      }

      final label =
          (category['displayName'] ?? category['name'] ?? '').toString().trim();
      if (_categoryNameKey(label) == candidateKey) {
        return true;
      }
    }

    return false;
  }

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
    if (_hasDuplicateCategoryName(t)) {
      return translateText('Category already exists');
    }
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final t = nameController.text.trim();
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
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop(isEdit ? null : t);
    } catch (_) {
      if (!mounted) return;
      setState(() => errorText = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogHeader(
                title: isEdit
                    ? translateText('Edit Category')
                    : translateText('Add Category'),
                subtitle: translateText('Keep your catalog organized.'),
              ),
              const SizedBox(height: 20),
              _DialogLabel(translateText('Category Name')),
              const SizedBox(height: 7),
              TextField(
                controller: nameController,
                cursorColor: _catalogGold,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [
                  const FirstLetterUpperFormatter(),
                  LengthLimitingTextInputFormatter(30),
                ],
                onSubmitted: (_) {
                  if (!isSaving) _submit();
                },
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: _dialogInputDecoration(
                  hint: translateText('Enter category name'),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
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
                  style: _dialogPrimaryButtonStyle(),
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
    FocusManager.instance.primaryFocus?.unfocus();
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
      FocusManager.instance.primaryFocus?.unfocus();
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogHeader(
                title: isEdit
                    ? translateText('Edit Subcategory')
                    : translateText('Add Subcategory'),
                subtitle: translateText('Group related services clearly.'),
              ),
              const SizedBox(height: 20),
              _DialogLabel(translateText('Subcategory Name')),
              const SizedBox(height: 7),
              TextField(
                controller: controller,
                cursorColor: _catalogGold,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [
                  const FirstLetterUpperFormatter(),
                  LengthLimitingTextInputFormatter(30),
                ],
                onSubmitted: (_) {
                  if (!isSaving) _submit();
                },
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: _dialogInputDecoration(
                  hint: translateText('Enter subcategory name'),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
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
                  style: _dialogPrimaryButtonStyle(),
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
  String? commissionMaxError;
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
      text: minorAmountToRupees(s['priceMinor'] ?? s['defaultPriceMinor'])
              ?.toStringAsFixed(0) ??
          '',
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
    } else {
      final priceVal = int.tryParse(priceTxt);
      if (priceVal == null) {
        pErr = 'Enter a valid number';
      } else if (priceVal <= 0) {
        pErr = 'Price must be greater than 0';
      } else if (priceTxt.length > 6) {
        pErr = 'Price cannot exceed 6 digits';
      }
    }

    if (durationTxt.isEmpty) {
      dErr = 'Duration is required';
    } else {
      final durationVal = int.tryParse(durationTxt);
      if (durationVal == null) {
        dErr = 'Enter a valid number';
      } else if (durationVal <= 0) {
        dErr = 'Duration must be greater than 0';
      } else if (durationTxt.length > 4) {
        dErr = 'Duration cannot exceed 4 digits';
      }
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
            maxLength: 50,
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
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
            maxLength: 50,
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
          ),
          SizedBox(height: 12),

          // Duration
          _LabeledField(
            label: translateText('Duration (minutes)'),
            controller: durationController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
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
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
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

          const SizedBox(height: 6),

          // ✅ Submit button (unchanged)
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
                      if (!_validate()) return;
                      FocusScope.of(context).unfocus();
                      setState(() => isSaving = true);
                      try {
                        final payload = {
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'defaultDurationMin':
                              int.tryParse(durationController.text.trim()),
                          'defaultPriceMinor': rupeesToMinorAmount(
                            int.parse(priceController.text.trim()),
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
