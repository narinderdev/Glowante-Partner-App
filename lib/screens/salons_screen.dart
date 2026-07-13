import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import 'add_branch_screen.dart';
import 'add_salon_screen.dart';
import 'branch_detail_screen.dart';
import 'SalonDeal.dart';
import 'SalonPackage.dart';
import 'SalonTeams.dart';
import 'notifications.dart';
import 'salon_detail_screen.dart';
import '../utils/address_formatter.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:fluttertoast/fluttertoast.dart';

const double _salonHeroImageHeight = 240;

class SalonsScreen extends StatefulWidget {
  const SalonsScreen({
    super.key,
    this.readOnly = false,
  });

  final bool readOnly;

  @override
  SalonsScreenState createState() => SalonsScreenState();
}

class SalonsScreenState extends State<SalonsScreen> {
  bool fabExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchActivityTimer;
  bool _isSearchActivityVisible = false;
  bool _isActionLoading = false;
  final Set<int> _collapsedSalonIds = <int>{};
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _fabPanelKey = GlobalKey();

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final cubit = context.read<SalonListCubit>();
  //     if (cubit.state.salons.isEmpty) {
  //       cubit.loadSalons();
  //     }
  //   });
  // }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<SalonListCubit>();
      cubit.loadSalons(); // Always refresh salons when screen is shown
    });
  }

  @override
  void dispose() {
    _searchActivityTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleSearchChanged(String value) {
    _searchActivityTimer?.cancel();
    final query = value.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      _isSearchActivityVisible = query.isNotEmpty;
      if (fabExpanded) fabExpanded = false;
    });
    if (query.isNotEmpty) {
      _searchActivityTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() => _isSearchActivityVisible = false);
      });
    }
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }
    _searchActivityTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearchActivityVisible = false;
      if (fabExpanded) fabExpanded = false;
    });
  }

  void _collapseFab() {
    if (!fabExpanded) return;
    setState(() => fabExpanded = false);
  }

  void collapseQuickActions() => _collapseFab();

  bool _isPointerInside(GlobalKey key, Offset globalPosition) {
    final context = key.currentContext;
    if (context == null) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return false;
    final local = renderObject.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dx <= renderObject.size.width &&
        local.dy >= 0 &&
        local.dy <= renderObject.size.height;
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> salons) {
    if (_searchQuery.isEmpty) {
      return salons;
    }
    final query = _searchQuery;
    return salons.where((salon) {
      if (_containsSearchQuery([
        salon['name'],
        salon['description'],
        salon['tagline'],
        salon['phone'],
        salon['phoneNumber'],
        _composeSearchLocation(salon['address']),
        _composeSearchLocation(salon),
      ], query)) {
        return true;
      }
      final branches =
          (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final branch in branches) {
        if (_containsSearchQuery([
          branch['name'],
          branch['description'],
          branch['phone'],
          branch['phoneNumber'],
          branch['contactNumber'],
          _composeSearchLocation(branch['address']),
          _composeSearchLocation(branch),
        ], query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  bool _containsSearchQuery(List<dynamic> values, String query) {
    return values.any((value) {
      final text = (value ?? '').toString().trim().toLowerCase();
      return text.isNotEmpty && text.contains(query);
    });
  }

  String _composeSearchLocation(dynamic value) {
    if (value is! Map) return '';
    final parts = <String>[];
    final seenParts = <String>{};
    for (final key in const [
      'line1',
      'addressLine1',
      'buildingName',
      'line2',
      'addressLine2',
      'village',
      'district',
      'city',
      'state',
      'country',
      'postalCode',
      'pincode',
      'zip',
      'latitude',
      'longitude',
      'lat',
      'lng',
    ]) {
      final text = (value[key] ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        for (final part in text.split(',')) {
          final cleanedPart = part.trim();
          final key = cleanedPart.toLowerCase();
          if (cleanedPart.isNotEmpty && seenParts.add(key)) {
            parts.add(cleanedPart);
          }
        }
      }
    }
    return parts.join(' ');
  }

  int _resolveId(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  Future<void> _refreshSalons() async {
    await context.read<SalonListCubit>().loadSalons();
  }

  void _toggleSalonBranches(int salonId) {
    setState(() {
      if (_collapsedSalonIds.contains(salonId)) {
        _collapsedSalonIds.remove(salonId);
      } else {
        _collapsedSalonIds.add(salonId);
      }
    });
  }

  Future<void> _goToAddSalon() async {
    _collapseFab();
    _dismissKeyboard();
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => AddSalonCubit(context.read<SalonRepository>()),
          child: AddSalonScreen(),
        ),
      ),
    );

    if (mounted) {
      _dismissKeyboard();
    }
    if (added == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _goToEditSalon(Map<String, dynamic> salon) async {
    _collapseFab();
    _dismissKeyboard();
    debugPrint('[SalonAction] Edit salon tapped -> salonId=${salon['id']}');
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => AddSalonCubit(context.read<SalonRepository>()),
          child: AddSalonScreen(
            isEdit: true,
            initialSalon: salon,
          ),
        ),
      ),
    );

    if (mounted) {
      _dismissKeyboard();
    }
    if (updated == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _setSalonActive({
    required int salonId,
    required bool active,
  }) async {
    if (_isActionLoading) return;
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(translateText('Deactivate Salon')),
          content: Text(
            translateText(
              'If the main salon is deactivated, all branches will be automatically deactivated. Do you want to continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(translateText('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B6500),
                foregroundColor: Colors.white,
              ),
              child: Text(translateText('Deactivate')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }
    final repo = context.read<SalonRepository>();
    setState(() => _isActionLoading = true);
    try {
      debugPrint(
        '[SalonAction] ${active ? 'Activate' : 'Deactivate'} salon -> salonId=$salonId',
      );
      if (active) {
        await repo.activateSalon(salonId);
      } else {
        await repo.deactivateSalon(salonId);
      }
      if (!mounted) return;
      Fluttertoast.showToast(
          msg: translateText(
        active
            ? 'Salon activated successfully'
            : 'Salon deactivated successfully',
      ));
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteSalon(int salonId) async {
    final repository = context.read<SalonRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(translateText('Delete Salon')),
        content: Text(
          translateText('Are you sure you want to delete this salon?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(translateText('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.starColor),
            child: Text(translateText('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      debugPrint('[SalonAction] Delete salon -> salonId=$salonId');
      await repository.deleteSalon(salonId);
      if (!mounted) return;
      Fluttertoast.showToast(msg: translateText('Salon deleted successfully'));
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _goToAddBranch(int salonId) async {
    _dismissKeyboard();
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) =>
              AddBranchCubit(context.read<SalonRepository>(), salonId: salonId),
          child: AddBranchScreen(salonId: salonId),
        ),
      ),
    );

    if (mounted) {
      _dismissKeyboard();
    }
    if (added == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _goToEditBranch({
    required int salonId,
    required Map<String, dynamic> branch,
  }) async {
    _dismissKeyboard();
    debugPrint(
      '[BranchAction] Edit branch tapped -> salonId=$salonId branchId=${branch['id']}',
    );
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) =>
              AddBranchCubit(context.read<SalonRepository>(), salonId: salonId),
          child: AddBranchScreen(
            salonId: salonId,
            isEdit: true,
            initialBranch: branch,
          ),
        ),
      ),
    );

    if (mounted) {
      _dismissKeyboard();
    }
    if (updated == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _setBranchActive({
    required int branchId,
    required bool active,
  }) async {
    if (_isActionLoading) return;
    final repo = context.read<SalonRepository>();
    setState(() => _isActionLoading = true);
    try {
      debugPrint(
        '[BranchAction] ${active ? 'Activate' : 'Deactivate'} branch -> branchId=$branchId',
      );
      if (active) {
        await repo.activateBranch(branchId);
      } else {
        await repo.deactivateBranch(branchId);
      }
      if (!mounted) return;
      Fluttertoast.showToast(
          msg: translateText(
        active
            ? 'Branch activated successfully'
            : 'Branch deactivated successfully',
      ));
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteBranch(int branchId) async {
    final repository = context.read<SalonRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(translateText('Delete Branch')),
        content: Text(
          translateText('Are you sure you want to delete this branch?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(translateText('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.starColor),
            child: Text(translateText('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      debugPrint('[BranchAction] Delete branch -> branchId=$branchId');
      await repository.deleteBranch(branchId);
      if (!mounted) return;
      Fluttertoast.showToast(msg: translateText('Branch deleted successfully'));
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _showSalonDetailsModal({
    required Map<String, dynamic> salon,
  }) async {
    _collapseFab();
    _dismissKeyboard();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalonDetailScreen(salon: salon),
      ),
    );
  }

  Future<void> _showBranchDetailsModal({
    required int salonId,
    required int branchId,
    required Map<String, dynamic> branch,
  }) async {
    _collapseFab();
    _dismissKeyboard();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchDetailScreen(
          branchId: branchId,
          initialBranch: branch,
        ),
      ),
    );
  }

  // ignore: unused_element
  String _cleanDialogTitle(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: _SalonsAppBar(
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onSearchChanged: _handleSearchChanged,
        onSearchTap: _collapseFab,
        onHeaderTap: _collapseFab,
        toolbarHeight: isIos ? 34 : 52,
        logoHeight: isIos ? 34 : 34,
        logoYOffset: isIos ? -6 : -3,
        onAddSalonTap: widget.readOnly ? null : _goToAddSalon,
        onNotificationTap: () {
          _collapseFab();
          _dismissKeyboard();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (!fabExpanded) return;
          if (_isPointerInside(_fabKey, event.position)) return;
          if (_isPointerInside(_fabPanelKey, event.position)) return;
          _collapseFab();
        },
        child: BlocBuilder<SalonListCubit, SalonListState>(
          builder: (context, state) {
            final salons = _applySearch(state.salons);
            final isInitialLoading = state.isLoading && state.salons.isEmpty;

            return Stack(
              children: [
                _RefreshableSalonsScroll(
                  enabled: !isInitialLoading,
                  onRefresh: _refreshSalons,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      if (state.hasError && state.salons.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                            child: _InlineErrorBanner(
                              message: state.errorMessage ??
                                  'Unable to refresh salons right now.',
                              onRetry: _refreshSalons,
                            ),
                          ),
                        ),
                      if (state.isLoading && state.salons.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
                            child: _InlineLoadingBanner(),
                          ),
                        ),
                      if (state.isLoading && state.salons.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _LoadingSalonsView(),
                        )
                      else if (state.hasError && state.salons.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ErrorView(
                            message:
                                state.errorMessage ?? 'Failed to load salons',
                            onRetry: _refreshSalons,
                          ),
                        )
                      else if (salons.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptySalonsView(
                            hasSearchQuery: _searchQuery.isNotEmpty,
                            onAddSalon: _goToAddSalon,
                            readOnly: widget.readOnly,
                            onClearSearch: _clearSearch,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
                          sliver: SliverList(
                            delegate:
                                SliverChildBuilderDelegate((context, index) {
                              final salon = salons[index];
                              final dynamic rawId = salon['id'];
                              final salonId = _resolveId(rawId, index);
                              final isExpanded =
                                  !_collapsedSalonIds.contains(salonId);
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == salons.length - 1 ? 0 : 16,
                                ),
                                child: _SalonCard(
                                  salon: salon,
                                  salonId: salonId,
                                  isExpanded: isExpanded,
                                  onToggle: () => _toggleSalonBranches(salonId),
                                  onOpenSalon: () => _showSalonDetailsModal(
                                    salon: salon,
                                  ),
                                  onAddBranch: widget.readOnly
                                      ? null
                                      : () => _goToAddBranch(salonId),
                                  onEditSalon: widget.readOnly
                                      ? null
                                      : () => _goToEditSalon(salon),
                                  onToggleSalonActive: widget.readOnly
                                      ? null
                                      : (active) => _setSalonActive(
                                            salonId: salonId,
                                            active: active,
                                          ),
                                  onDeleteSalon: widget.readOnly
                                      ? null
                                      : () => _deleteSalon(salonId),
                                  onEditBranch: widget.readOnly
                                      ? null
                                      : (branch) => _goToEditBranch(
                                            salonId: salonId,
                                            branch: branch,
                                          ),
                                  onToggleBranchActive: widget.readOnly
                                      ? null
                                      : (branchId, active) => _setBranchActive(
                                            branchId: branchId,
                                            active: active,
                                          ),
                                  onDeleteBranch: widget.readOnly
                                      ? null
                                      : (branchId) => _deleteBranch(branchId),
                                  onOpenBranch: (branchId, branch) =>
                                      _showBranchDetailsModal(
                                    salonId: salonId,
                                    branchId: branchId,
                                    branch: branch,
                                  ),
                                ),
                              );
                            }, childCount: salons.length),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isSearchActivityVisible)
                  const Positioned.fill(child: _SearchActivityOverlay()),
                if (_isActionLoading)
                  const Positioned.fill(child: _SalonActionLoadingOverlay()),
              ],
            );
          },
        ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: fabExpanded
                        ? KeyedSubtree(
                            key: const ValueKey('fab-panel'),
                            child: _FabActionPanel(
                              key: _fabPanelKey,
                              onTeam: () {
                                _collapseFab();
                                _dismissKeyboard();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamScreen(),
                                  ),
                                );
                              },
                              onDeals: () {
                                _collapseFab();
                                _dismissKeyboard();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DealScreen(),
                                  ),
                                );
                              },
                              onPackages: () {
                                _collapseFab();
                                _dismissKeyboard();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PackageScreen(),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('fab-empty')),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    key: _fabKey,
                    heroTag: 'salons_quick_actions_fab',
                    backgroundColor: const Color(0xFF8B6500),
                    foregroundColor: Colors.white,
                    icon: Icon(
                      fabExpanded ? Icons.close : Icons.menu_rounded,
                      size: 20,
                    ),
                    label: Text(
                      translateText(fabExpanded ? 'Close' : 'Quick actions'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () {
                      _dismissKeyboard();
                      setState(() => fabExpanded = !fabExpanded);
                    },
                    extendedPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    elevation: 4,
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _SalonsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SalonsAppBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onSearchTap,
    this.onHeaderTap,
    this.toolbarHeight = 52,
    this.logoHeight = 34,
    this.logoYOffset = 0,
    this.onAddSalonTap,
    required this.onNotificationTap,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchTap;
  final VoidCallback? onHeaderTap;
  final double toolbarHeight;
  final double logoHeight;
  final double logoYOffset;
  final VoidCallback? onAddSalonTap;
  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1EBE6)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHeaderTap,
          child: SizedBox(
            height: toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: toolbarHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: Offset(0, logoYOffset),
                        child: Image.asset(
                          'assets/images/finallogo.png',
                          height: logoHeight,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/logo.png',
                            height: logoHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: toolbarHeight,
                    height: toolbarHeight,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: toolbarHeight,
                        height: toolbarHeight,
                      ),
                      onPressed: onNotificationTap,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF8B6500),
                        size: 24,
                      ),
                    ),
                  ),
                  if (onAddSalonTap != null) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: onAddSalonTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(translateText('Add Salon')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshableSalonsScroll extends StatelessWidget {
  const _RefreshableSalonsScroll({
    required this.enabled,
    required this.onRefresh,
    required this.child,
  });

  final bool enabled;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return RefreshIndicator(
      onRefresh: () => RefreshFeedback.playAndRun(onRefresh),
      color: AppColors.starColor,
      displacement: 32,
      child: child,
    );
  }
}

class _LoadingSalonsView extends StatelessWidget {
  const _LoadingSalonsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: Center(
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
              translateText('Loading salons...'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translateText(
                'This can take a little longer on slow internet.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF607D8B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLoadingBanner extends StatelessWidget {
  const _InlineLoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.starColor,
              ),
            ),
            SizedBox(width: 12),
            Text(
              translateText('Syncing latest data...'),
              style: TextStyle(
                color: Color(0xFF546E7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF6D78A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFF8B6500),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              translateText(message),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B4E00),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.starColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              translateText('Retry'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchActivityOverlay extends StatelessWidget {
  const _SearchActivityOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.white.withValues(alpha: 0.58),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                translateText('Searching salons...'),
                style: const TextStyle(
                  color: Color(0xFF546E7A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalonActionLoadingOverlay extends StatelessWidget {
  const _SalonActionLoadingOverlay();

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translateText('Please wait...'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B3A2A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPopupRow extends StatelessWidget {
  const _ActionPopupRow({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFFB8AEA6)
        : destructive
            ? const Color(0xFFB42318)
            : const Color(0xFF4B3A2A);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: !enabled
                ? const Color(0xFFF2F0EE)
                : destructive
                    ? const Color(0xFFFFEFEF)
                    : const Color(0xFFF4E8D1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            translateText(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySalonsView extends StatelessWidget {
  const _EmptySalonsView({
    required this.hasSearchQuery,
    required this.onAddSalon,
    required this.readOnly,
    this.onClearSearch,
  });

  final bool hasSearchQuery;
  final VoidCallback onAddSalon;
  final bool readOnly;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = hasSearchQuery
        ? 'No salons match your search'
        : (readOnly
            ? 'No salons available'
            : 'Create your first salon experience');
    final subtitle = hasSearchQuery
        ? 'Try adjusting filters or check the spelling to discover more results.'
        : (readOnly
            ? 'Your assigned salons will appear here.'
            : 'Add a salon to start managing branches, services, and teams together.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              hasSearchQuery ? Icons.search_off_rounded : Icons.spa,
              color: AppColors.starColor,
              size: 40,
            ),
          ),
          SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF37474F),
                ) ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF37474F),
                ),
          ),
          SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607D8B),
                ) ??
                const TextStyle(color: Color(0xFF607D8B)),
          ),
          if (hasSearchQuery && onClearSearch != null) ...[
            SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: Icon(Icons.refresh, size: 18),
              label: Text(translateText('Reset search')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.starColor,
                side: const BorderSide(color: AppColors.starColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else if (!readOnly) ...[
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAddSalon,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                translateText('Add Salon'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.salonId,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenSalon,
    this.onAddBranch,
    this.onEditSalon,
    this.onToggleSalonActive,
    this.onDeleteSalon,
    this.onEditBranch,
    this.onToggleBranchActive,
    this.onDeleteBranch,
    required this.onOpenBranch,
  });

  final Map<String, dynamic> salon;
  final int salonId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onOpenSalon;
  final VoidCallback? onAddBranch;
  final VoidCallback? onEditSalon;
  final void Function(bool active)? onToggleSalonActive;
  final VoidCallback? onDeleteSalon;
  final void Function(Map<String, dynamic> branch)? onEditBranch;
  final void Function(int branchId, bool active)? onToggleBranchActive;
  final void Function(int branchId)? onDeleteBranch;
  final Future<void> Function(int branchId, Map<String, dynamic> branch)
      onOpenBranch;

  int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _composeAddress(Map<String, dynamic>? data) {
    return formatAddressSummary(data);
  }

  Widget _heroImage(String? imageUrl) {
    final usableImageUrl = _usableSalonImageUrl(imageUrl);
    if (usableImageUrl == null) return _noSalonImageCard();
    return SizedBox(
      height: _salonHeroImageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1EFEC)),
          Positioned.fill(
            child: _AdaptiveSalonNetworkImage(
              imageUrl: usableImageUrl,
              fallback: _noSalonImageCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noSalonImageCard() {
    return SizedBox(
      height: _salonHeroImageHeight,
      width: double.infinity,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFF7F3EF),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF8B6500),
              size: 30,
            ),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(
                color: Color(0xFF756A61),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _usableSalonImageUrl(String? imageUrl) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final lowerUrl = url.toLowerCase();
    final isNetworkUrl =
        lowerUrl.startsWith('http://') || lowerUrl.startsWith('https://');
    if (!isNetworkUrl &&
        (lowerUrl.contains('image_picker') ||
            lowerUrl.startsWith('file://') ||
            lowerUrl.startsWith('/'))) {
      return null;
    }
    return url;
  }

  String _cleanImageUrl(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'url',
        'imageUrl',
        'publicUrl',
        'cdnUrl',
        'src',
      ]) {
        final text = _cleanText(value[key]);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return _cleanText(value);
  }

  List<String> _extractImageUrls(dynamic source) {
    final urls = <String>[];

    void add(dynamic value) {
      final url = _usableSalonImageUrl(_cleanImageUrl(value));
      if (url != null && !urls.contains(url)) {
        urls.add(url);
      }
    }

    if (source is List) {
      for (final entry in source) {
        add(entry);
      }
    } else {
      add(source);
    }

    return urls;
  }

  List<String> _resolveHeroImageUrls({
    required String fallbackImageUrl,
    required Map<String, dynamic> salon,
  }) {
    final urls = <String>[];

    void pushUrl(String? rawUrl) {
      final usable = _usableSalonImageUrl(rawUrl);
      if (usable != null && !urls.contains(usable)) {
        urls.add(usable);
      }
    }

    for (final url in _extractImageUrls(salon['imageUrls'])) {
      pushUrl(url);
    }
    pushUrl(fallbackImageUrl);

    return urls;
  }

  Widget _badge(String label, IconData icon, {bool light = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: light ? Colors.white : const Color(0xFF8B6500),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: light ? const Color(0xFF8B6500) : Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            translateText(label),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: light ? const Color(0xFF8B6500) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF6E6259)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6E6259),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E8D1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7D5B3)),
      ),
      child: Text(
        translateText(label),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF8B6500),
        ),
      ),
    );
  }

  Widget _statusTag(String label, {required bool active}) {
    final textColor =
        active ? const Color(0xFF047857) : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8FFF5) : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFB7F0D0) : const Color(0xFFF5C2C7),
        ),
      ),
      child: Text(
        translateText(label),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _addBranchButton() {
    if (onAddBranch == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        height: 30,
        child: ElevatedButton.icon(
          onPressed: onAddBranch,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text(
            translateText('Add Branch'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF8B6500),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _salonMenuButton(
    BuildContext context,
    bool isActive,
  ) {
    final canEdit = isActive && onEditSalon != null;
    if (onEditSalon == null &&
        onToggleSalonActive == null &&
        onDeleteSalon == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: Color(0xFF8B6500),
        ),
        color: Colors.white,
        elevation: 10,
        offset: const Offset(-8, 34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8DED4)),
        ),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              if (isActive) onEditSalon?.call();
              break;
            case 'toggle':
              onToggleSalonActive?.call(!isActive);
              break;
            case 'delete':
              onDeleteSalon?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          if (onEditSalon != null)
            PopupMenuItem<String>(
              value: 'edit',
              enabled: canEdit,
              child: _ActionPopupRow(
                icon: Icons.edit_outlined,
                label: 'Edit Salon',
                enabled: canEdit,
              ),
            ),
          if (onToggleSalonActive != null)
            PopupMenuItem<String>(
              value: 'toggle',
              child: _ActionPopupRow(
                icon: isActive
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                label: isActive ? 'Deactivate Salon' : 'Activate Salon',
              ),
            ),
          if (onDeleteSalon != null)
            PopupMenuItem<String>(
              value: 'delete',
              child: _ActionPopupRow(
                icon: Icons.delete_outline,
                label: 'Delete Salon',
                destructive: true,
              ),
            ),
        ],
      ),
    );
  }

  int _staffCount(List<Map<String, dynamic>> branches) {
    for (final key in const [
      'staffCount',
      'teamCount',
      'employeeCount',
      'stylistsCount',
    ]) {
      final value = salon[key];
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    int total = 0;
    for (final branch in branches) {
      final team = branch['team'] ?? branch['staff'] ?? branch['stylists'];
      if (team is List) total += team.length;
      final value = branch['staffCount'] ?? branch['teamCount'];
      if (value is int) total += value;
      if (value is String) total += int.tryParse(value) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final branches =
        (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawName = _cleanText(salon['name']);
    final salonName = rawName.isEmpty ? 'Unnamed Salon' : rawName;
    final tagline = _cleanText(salon['tagline']).isNotEmpty
        ? _cleanText(salon['tagline'])
        : _cleanText(salon['description']);
    var imageUrl = _cleanText(salon['imageUrl']);
    if (imageUrl.isEmpty) imageUrl = '';

    String normalizeName(String value) => value.trim().toLowerCase();
    bool isMainBranch(Map<String, dynamic> branch) {
      final rawIsMain = branch['isMain'];
      if (rawIsMain is bool) return rawIsMain;
      return normalizeName(_cleanText(branch['name'])) ==
          normalizeName(salonName);
    }

    Map<String, dynamic>? primaryBranch;
    if (branches.isNotEmpty) {
      try {
        primaryBranch = branches.firstWhere(isMainBranch);
      } catch (_) {
        primaryBranch = branches.first;
      }
    }

    final heroImageUrls = _resolveHeroImageUrls(
      fallbackImageUrl: imageUrl,
      salon: salon,
    );

    String addressLabel = '';
    if (salon['address'] is Map<String, dynamic>) {
      addressLabel = _composeAddress(salon['address'] as Map<String, dynamic>);
    }
    if (addressLabel.isEmpty && primaryBranch != null) {
      final branchAddress = primaryBranch['address'];
      addressLabel = branchAddress is Map<String, dynamic>
          ? _composeAddress(branchAddress)
          : _composeAddress(primaryBranch);
    }

    String extractPhone(Map<String, dynamic>? data) {
      if (data == null) return '';
      for (final key in ['phone', 'phoneNumber', 'contactNumber', 'mobile']) {
        final value = _cleanText(data[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final salonPhone = [
      extractPhone(salon),
      extractPhone(primaryBranch),
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final visibleBranches = branches.where((branch) => !isMainBranch(branch));
    final visibleBranchList = visibleBranches.toList();
    final branchCount = visibleBranchList.length;
    final staffCount = _staffCount(branches);
    final isActive = salon['active'] != false;
    var primaryBranchId = 0;
    if (primaryBranch != null) {
      primaryBranchId = _parseId(primaryBranch['id']);
    }
    if (primaryBranchId == 0) {
      primaryBranchId = _parseId(salon['branchId'] ?? salon['mainBranchId']);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFE8DED4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenSalon,
              child: Stack(
                children: [
                  _AutoSlidingHeroImage(
                    imageUrls: heroImageUrls,
                    fallback: _noSalonImageCard(),
                    imageBuilder: _heroImage,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child:
                        _badge('Main Salon', Icons.workspace_premium_rounded),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SalonRatingBadge(branchId: primaryBranchId),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onOpenSalon,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                salonName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF201B17),
                                ),
                              ),
                            ),
                            if (!isActive) ...[
                              const SizedBox(width: 8),
                              _statusTag('Deactivated', active: false),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _salonMenuButton(
                        context,
                        isActive,
                      ),
                    ],
                  ),
                  _infoLine(Icons.location_on_outlined, addressLabel),
                  _infoLine(Icons.phone_outlined, salonPhone),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _countChip(
                        '$branchCount ${branchCount == 1 ? 'Branch' : 'Branches'}',
                      ),
                      if (staffCount > 0) _countChip('$staffCount Staff'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFAF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFECE4DC)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            translateText('BRANCHES'),
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B5B4D),
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF8B6500),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !isExpanded
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                          child: Column(
                            children: [
                              if (visibleBranchList.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 10, 8, 12),
                                  child: Text(
                                    translateText(
                                      'No branches added yet. Expand your network by adding a new location.',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.45,
                                      color: Color(0xFF8A8178),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                ...visibleBranchList.map((branch) {
                                  final branchId = _parseId(branch['id']);
                                  if (branchId == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return _BranchTile(
                                    branch: branch,
                                    accentColor: AppColors.starColor,
                                    onOpen: () => onOpenBranch(
                                      branchId,
                                      branch,
                                    ),
                                    onEdit: onEditBranch == null
                                        ? null
                                        : () => onEditBranch!(branch),
                                    onToggleActive: onToggleBranchActive == null
                                        ? null
                                        : (active) => onToggleBranchActive!(
                                              branchId,
                                              active,
                                            ),
                                    onDelete: onDeleteBranch == null
                                        ? null
                                        : () => onDeleteBranch!(branchId),
                                    hideViewButton: false,
                                    hideTitle: false,
                                  );
                                }),
                              const SizedBox(height: 6),
                              _addBranchButton(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (tagline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xFF7A7068),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Legacy modal retained for now; Salons tab now navigates to dedicated screens.
// ignore: unused_element
class _SalonDetailsDialog extends StatelessWidget {
  const _SalonDetailsDialog({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.icon,
    required this.actionLabel,
    // ignore: unused_element_parameter
    this.warning,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> details;
  final IconData icon;
  final String actionLabel;
  final String? warning;

  String _cleanText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  bool _isSalonDialog() => subtitle != 'Branch';

  Map<String, dynamic>? _primaryBranch() {
    if (!_isSalonDialog()) return null;
    final branches = _branches();
    if (branches.isEmpty) return null;
    final salonName = _cleanText(
      details['name'] ?? details['salonName'] ?? details['displayName'],
    ).toLowerCase();

    for (final branch in branches) {
      final isMain = branch['isMain'];
      if (isMain == true || _cleanText(isMain).toLowerCase() == 'true') {
        return branch;
      }
      final branchName = _cleanText(
        branch['name'] ?? branch['branchName'] ?? branch['displayName'],
      ).toLowerCase();
      if (salonName.isNotEmpty && branchName == salonName) {
        return branch;
      }
    }
    return branches.first;
  }

  dynamic _firstRawValue(List<String> keys) {
    for (final key in keys) {
      final value = details[key];
      if (_cleanText(value).isNotEmpty || value is List || value is Map) {
        return value;
      }
    }
    final primaryBranch = _primaryBranch();
    if (primaryBranch != null) {
      for (final key in keys) {
        final value = primaryBranch[key];
        if (_cleanText(value).isNotEmpty || value is List || value is Map) {
          return value;
        }
      }
    }
    return null;
  }

  String _firstFieldText(List<String> keys) {
    final values = <dynamic>[];
    for (final key in keys) {
      values.add(details[key]);
    }
    final primaryBranch = _primaryBranch();
    if (primaryBranch != null) {
      for (final key in keys) {
        values.add(primaryBranch[key]);
      }
    }
    return _firstText(values);
  }

  String _composeAddress(dynamic source) {
    if (source is! Map) return '';
    final data = Map<String, dynamic>.from(source);
    final segments = <String>[];
    final seenParts = <String>{};

    void push(dynamic value) {
      final text = _cleanText(value);
      if (text.isEmpty) return;
      for (final part in text.split(',')) {
        final cleanedPart = _cleanText(part);
        final key = cleanedPart.toLowerCase();
        if (cleanedPart.isNotEmpty && seenParts.add(key)) {
          segments.add(cleanedPart);
        }
      }
    }

    push(data['line1'] ?? data['addressLine1'] ?? data['buildingName']);
    push(data['line2'] ?? data['addressLine2']);
    push(data['village']);
    push(data['district']);
    push(data['city']);
    push(data['state']);
    push(data['country']);
    push(data['postalCode'] ?? data['pincode'] ?? data['zip']);
    return segments.join(', ');
  }

  String _addressText() {
    final nestedAddress = _composeAddress(details['address']);
    if (nestedAddress.isNotEmpty) return nestedAddress;
    final primaryBranch = _primaryBranch();
    if (primaryBranch != null) {
      final primaryAddress = _composeAddress(primaryBranch['address']);
      if (primaryAddress.isNotEmpty) return primaryAddress;
      final primaryInlineAddress = _composeAddress(primaryBranch);
      if (primaryInlineAddress.isNotEmpty) return primaryInlineAddress;
    }
    return _composeAddress(details);
  }

  Map<String, dynamic> _addressMap() {
    final address = details['address'];
    if (address is Map) return Map<String, dynamic>.from(address);
    final primaryBranch = _primaryBranch();
    final primaryAddress = primaryBranch?['address'];
    if (primaryAddress is Map) return Map<String, dynamic>.from(primaryAddress);
    if (primaryBranch != null) return primaryBranch;
    return details;
  }

  String _addressField(List<String> keys) {
    final address = _addressMap();
    return _firstText(keys.map((key) => address[key]).toList());
  }

  List<String> _imageUrls() {
    final urls = <String>[];

    void add(dynamic source) {
      dynamic value = source;
      if (value is Map) {
        value = value['url'] ??
            value['imageUrl'] ??
            value['publicUrl'] ??
            value['cdnUrl'] ??
            value['src'];
      }
      final text = _cleanText(value);
      final lower = text.toLowerCase();
      if ((lower.startsWith('http://') || lower.startsWith('https://')) &&
          !urls.contains(text)) {
        urls.add(text);
      }
    }

    void addFromMap(Map<String, dynamic> source) {
      final imageUrls = source['imageUrls'];
      if (imageUrls is List && imageUrls.isNotEmpty) {
        for (final image in imageUrls) {
          add(image);
        }
      }
      add(source['imageUrl']);
      add(source['image']);
    }

    addFromMap(details);
    final primaryBranch = _primaryBranch();
    if (primaryBranch != null) addFromMap(primaryBranch);
    return urls;
  }

  String _imageUrl() {
    final urls = _imageUrls();
    return urls.isEmpty ? '' : urls.first;
  }

  String _statusText() {
    final active = details['active'];
    if (active == false) return 'Deactivated';
    final status = _cleanText(details['status']);
    if (status.isNotEmpty) return status;
    return 'Active';
  }

  bool _isActive() => _statusText().toLowerCase() != 'deactivated';

  List<_DetailRowData> _basicRows() {
    return [
      _DetailRowData(
        icon: Icons.badge_outlined,
        label: subtitle == 'Branch' ? 'Branch Name' : 'Salon Name',
        value: _firstFieldText([
          'name',
          'salonName',
          'branchName',
          'displayName',
          'title',
        ]),
      ),
      _DetailRowData(
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: _firstFieldText([
          'phone',
          'phoneNumber',
          'contactNumber',
          'mobile',
        ]),
      ),
      _DetailRowData(
        icon: Icons.access_time_rounded,
        label: 'Start Time',
        value: _firstFieldText([
          'startTime',
          'openingTime',
          'openTime',
        ]),
      ),
      _DetailRowData(
        icon: Icons.access_time_filled_rounded,
        label: 'End Time',
        value: _firstFieldText([
          'endTime',
          'closingTime',
          'closeTime',
        ]),
      ),
      _DetailRowData(
        icon: Icons.first_page_rounded,
        label: 'First Visible Slot',
        value: _firstFieldText([
          'firstVisibleSlot',
          'first_visible_slot',
        ]),
      ),
      _DetailRowData(
        icon: Icons.last_page_rounded,
        label: 'Last Visible Slot',
        value: _firstFieldText([
          'lastVisibleSlot',
          'last_visible_slot',
        ]),
      ),
      _DetailRowData(
        icon: Icons.photo_library_outlined,
        label: 'Uploaded Photos',
        value: _imageUrls().isEmpty ? '' : _imageUrls().length.toString(),
      ),
      _DetailRowData(
        icon: Icons.category_outlined,
        label: 'Selected Category Codes',
        value: _stringList(_firstRawValue(['selectedCategoryCodes'])),
      ),
      _DetailRowData(
        icon: Icons.content_copy_rounded,
        label: 'Copied From Branch ID',
        value: _firstFieldText(['sourceBranchId']),
      ),
    ].where((row) => row.value.isNotEmpty).toList();
  }

  List<_DetailRowData> _locationRows() {
    return [
      _DetailRowData(
        icon: Icons.home_work_outlined,
        label: 'Complete Address',
        value: _firstText([
          _addressField(['line1', 'addressLine1', 'buildingName']),
          _addressText(),
        ]),
      ),
      _DetailRowData(
        icon: Icons.meeting_room_outlined,
        label: 'House / Flat',
        value: _addressField(['city']),
      ),
      _DetailRowData(
        icon: Icons.add_road_outlined,
        label: 'Street / Area',
        value: _addressField(['postalCode', 'pincode', 'zip']),
      ),
      _DetailRowData(
        icon: Icons.map_outlined,
        label: 'State',
        value: _addressField(['state']),
      ),
      _DetailRowData(
        icon: Icons.public_outlined,
        label: 'Country',
        value: _addressField(['country']),
      ),
      _DetailRowData(
        icon: Icons.my_location_outlined,
        label: 'Latitude',
        value: _firstText([
          _addressField(['latitude', 'lat']),
          details['latitude'],
          details['lat'],
        ]),
      ),
      _DetailRowData(
        icon: Icons.my_location_rounded,
        label: 'Longitude',
        value: _firstText([
          _addressField(['longitude', 'lng', 'lon']),
          details['longitude'],
          details['lng'],
          details['lon'],
        ]),
      ),
    ].where((row) => row.value.isNotEmpty).toList();
  }

  String _stringList(dynamic value) {
    if (value is List) {
      final parts = value
          .map((item) => _cleanText(item))
          .where((item) => item.isNotEmpty)
          .toList();
      return parts.join(', ');
    }
    return _cleanText(value);
  }

  List<String> _scheduleLines() {
    const dayOrder = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final rawSchedule = _firstRawValue(['schedule', 'schedules']);
    final lines = <String>[];

    String formatDay(String day) {
      if (day.isEmpty) return '';
      return '${day[0].toUpperCase()}${day.substring(1).toLowerCase()}';
    }

    String slotText(dynamic slot) {
      if (slot is! Map) return '';
      final start = _firstText([slot['start'], slot['startTime']]);
      final end = _firstText([slot['end'], slot['endTime']]);
      if (start.isEmpty || end.isEmpty) return '';
      return '$start - $end';
    }

    if (rawSchedule is Map) {
      for (final day in dayOrder) {
        final rawSlots = rawSchedule[day] ?? rawSchedule[formatDay(day)];
        if (rawSlots is! List) continue;
        final slots = rawSlots.map(slotText).where((slot) => slot.isNotEmpty);
        if (slots.isNotEmpty) {
          lines.add('${formatDay(day)}: ${slots.join(', ')}');
        }
      }
    } else if (rawSchedule is List) {
      for (final entry in rawSchedule) {
        if (entry is! Map) continue;
        final day = _firstText([entry['day'], entry['weekday'], entry['name']]);
        final rawSlots = entry['slots'];
        final slots = rawSlots is List
            ? rawSlots.map(slotText).where((slot) => slot.isNotEmpty).toList()
            : <String>[slotText(entry)]
                .where((slot) => slot.isNotEmpty)
                .toList();
        if (day.isNotEmpty && slots.isNotEmpty) {
          lines.add('${formatDay(day)}: ${slots.join(', ')}');
        }
      }
    }

    return lines;
  }

  List<String> _serviceLines() {
    final services = <String>[];

    void addLabel(dynamic value) {
      final text = _cleanText(value);
      if (text.isNotEmpty && !services.contains(text)) {
        services.add(text);
      }
    }

    void collect(dynamic source) {
      if (source is List) {
        for (final item in source) {
          collect(item);
        }
        return;
      }
      if (source is! Map) {
        addLabel(source);
        return;
      }

      final map = Map<String, dynamic>.from(source);
      final nestedServices = map['services'] ??
          map['serviceList'] ??
          map['items'] ??
          map['selectedServices'];
      final subCategories = map['subCategories'] ??
          map['subcategories'] ??
          map['children'] ??
          map['subCategory'];

      if (nestedServices != null) collect(nestedServices);
      if (subCategories != null) collect(subCategories);

      if (nestedServices == null && subCategories == null) {
        addLabel(
          map['displayName'] ??
              map['name'] ??
              map['serviceName'] ??
              map['title'] ??
              map['code'],
        );
      }
    }

    void collectFromMap(Map<String, dynamic> source) {
      for (final key in const [
        'services',
        'serviceList',
        'branchServices',
        'salonServices',
        'selectedServices',
        'serviceCodes',
        'selectedServiceCodes',
        'categories',
        'category',
      ]) {
        collect(source[key]);
      }
    }

    collectFromMap(details);
    final primaryBranch = _primaryBranch();
    if (primaryBranch != null) collectFromMap(primaryBranch);
    return services;
  }

  List<Map<String, dynamic>> _branches() {
    final raw = details['branches'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  String _branchTitle(Map<String, dynamic> branch) {
    return _firstText([
      branch['name'],
      branch['branchName'],
      branch['displayName'],
      branch['title'],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final description = _firstText([
      details['description'],
      details['tagline'],
      details['about'],
    ]);
    final rows = _basicRows();
    final locationRows = _locationRows();
    final scheduleLines = _scheduleLines();
    final serviceLines = _serviceLines();
    final imageUrls = _imageUrls();
    final branches = _branches();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final maxWidth = MediaQuery.sizeOf(context).width >= 720
        ? 620.0
        : MediaQuery.sizeOf(context).width - 34;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B6500),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translateText(subtitle),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFE8B6),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (warning != null && warning!.trim().isNotEmpty)
                          _DialogWarning(message: warning!),
                        if (imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _DialogImageFallback(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          const _DialogImageFallback(),
                          const SizedBox(height: 14),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DialogStatusPill(
                              label: _statusText(),
                              active: _isActive(),
                            ),
                            if (branches.isNotEmpty)
                              _DialogStatusPill(
                                label:
                                    '${branches.length} ${branches.length == 1 ? 'Branch' : 'Branches'}',
                                active: true,
                              ),
                          ],
                        ),
                        if (imageUrls.length > 1) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: 'Uploaded Photos',
                            child: SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: imageUrls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const _DialogImageFallback(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _DialogSection(
                            title: 'Description',
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF4B3A2A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (locationRows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: 'Location Filled By User',
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < locationRows.length;
                                    i++) ...[
                                  _DialogInfoRow(
                                    icon: locationRows[i].icon,
                                    label:
                                        '${locationRows[i].label}: ${locationRows[i].value}',
                                  ),
                                  if (i != locationRows.length - 1)
                                    const Divider(
                                      height: 16,
                                      color: Color(0xFFF1EBE6),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (rows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: subtitle == 'Branch'
                                ? 'Branch Form Values'
                                : 'Salon Form Values',
                            child: Column(
                              children: [
                                for (var i = 0; i < rows.length; i++) ...[
                                  _DialogInfoRow(
                                    icon: rows[i].icon,
                                    label: '${rows[i].label}: ${rows[i].value}',
                                  ),
                                  if (i != rows.length - 1)
                                    const Divider(
                                      height: 16,
                                      color: Color(0xFFF1EBE6),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (scheduleLines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: 'Weekly Schedule Filled By User',
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < scheduleLines.length;
                                    i++) ...[
                                  _DialogInfoRow(
                                    icon: Icons.calendar_month_outlined,
                                    label: scheduleLines[i],
                                  ),
                                  if (i != scheduleLines.length - 1)
                                    const Divider(
                                      height: 16,
                                      color: Color(0xFFF1EBE6),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (serviceLines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: 'Services / Categories',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final service in serviceLines)
                                  _DialogChip(label: service),
                              ],
                            ),
                          ),
                        ],
                        if (branches.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DialogSection(
                            title: 'Branches',
                            child: Column(
                              children: [
                                for (var i = 0; i < branches.length; i++) ...[
                                  _DialogBranchSummary(
                                    title: _branchTitle(branches[i]).isEmpty
                                        ? 'Unnamed Branch'
                                        : _branchTitle(branches[i]),
                                    address: _composeAddress(
                                      branches[i]['address'],
                                    ).isNotEmpty
                                        ? _composeAddress(
                                            branches[i]['address'],
                                          )
                                        : _composeAddress(branches[i]),
                                    active: branches[i]['active'] != false,
                                  ),
                                  if (i != branches.length - 1)
                                    const Divider(
                                      height: 16,
                                      color: Color(0xFFF1EBE6),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B6500),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        translateText(actionLabel),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DED4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText(title).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8B6500),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  const _DialogInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8B6500)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            translateText(label),
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF4B3A2A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogStatusPill extends StatelessWidget {
  const _DialogStatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF047857) : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8FFF5) : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFB7F0D0) : const Color(0xFFF5C2C7),
        ),
      ),
      child: Text(
        translateText(label),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _DialogChip extends StatelessWidget {
  const _DialogChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Text(
        translateText(label),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4B3A2A),
        ),
      ),
    );
  }
}

class _DialogImageFallback extends StatelessWidget {
  const _DialogImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DED4)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF8B6500),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            translateText('No image available'),
            style: const TextStyle(
              color: Color(0xFF756A61),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogWarning extends StatelessWidget {
  const _DialogWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF6D78A)),
      ),
      child: Text(
        translateText(message),
        style: const TextStyle(
          color: Color(0xFF6B4E00),
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DialogBranchSummary extends StatelessWidget {
  const _DialogBranchSummary({
    required this.title,
    required this.address,
    required this.active,
  });

  final String title;
  final String address;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF4E8D1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Color(0xFF8B6500),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF201B17),
                      ),
                    ),
                  ),
                  _DialogStatusPill(
                    label: active ? 'Active' : 'Deactivated',
                    active: active,
                  ),
                ],
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFF8A8178),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AdaptiveSalonNetworkImage extends StatefulWidget {
  const _AdaptiveSalonNetworkImage({
    required this.imageUrl,
    required this.fallback,
  });

  final String imageUrl;
  final Widget fallback;

  @override
  State<_AdaptiveSalonNetworkImage> createState() =>
      _AdaptiveSalonNetworkImageState();
}

class _AdaptiveSalonNetworkImageState
    extends State<_AdaptiveSalonNetworkImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveSalonNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeImageListener();
      _hasError = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (_, __) {},
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _hasError = true);
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return widget.fallback;

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}

class _AutoSlidingHeroImage extends StatefulWidget {
  const _AutoSlidingHeroImage({
    required this.imageUrls,
    required this.fallback,
    required this.imageBuilder,
  });

  final List<String> imageUrls;
  final Widget fallback;
  final Widget Function(String imageUrl) imageBuilder;

  @override
  State<_AutoSlidingHeroImage> createState() => _AutoSlidingHeroImageState();
}

class _AutoSlidingHeroImageState extends State<_AutoSlidingHeroImage> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  int _autoScrollDirection = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _AutoSlidingHeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _currentPage = 0;
      _autoScrollDirection = 1;
      _stopAutoScroll();
      _startAutoScroll();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  void _startAutoScroll() {
    if (widget.imageUrls.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients || widget.imageUrls.isEmpty) {
        return;
      }
      final lastIndex = widget.imageUrls.length - 1;
      var nextPage = _currentPage + _autoScrollDirection;

      if (nextPage >= lastIndex) {
        nextPage = lastIndex;
        _autoScrollDirection = -1;
      } else if (nextPage <= 0) {
        nextPage = 0;
        _autoScrollDirection = 1;
      }

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 760),
        curve: Curves.easeInOutCubicEmphasized,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return widget.fallback;
    if (widget.imageUrls.length == 1) {
      return widget.imageBuilder(widget.imageUrls.first);
    }

    return SizedBox(
      height: _salonHeroImageHeight,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.hardEdge,
        padEnds: false,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          if (!mounted) return;
          setState(() {
            _currentPage = index;
            if (index == 0) {
              _autoScrollDirection = 1;
            } else if (index == widget.imageUrls.length - 1) {
              _autoScrollDirection = -1;
            }
          });
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final page = _pageController.hasClients &&
                      _pageController.position.hasPixels
                  ? (_pageController.page ?? _currentPage.toDouble())
                  : _currentPage.toDouble();
              final delta = page - index;
              final distance = delta.abs().clamp(0.0, 1.0);
              final shift = -delta * 32.0;
              final scale = 1.14 - (distance * 0.08);
              final rotateY = -delta * 0.34;
              final opacity = 0.90 + (1.0 - distance) * 0.10;

              return Opacity(
                opacity: opacity,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateY(rotateY),
                    child: Transform.translate(
                      offset: Offset(shift, 0.0),
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox.expand(
                          child: widget.imageBuilder(widget.imageUrls[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SalonRatingBadge extends StatefulWidget {
  const _SalonRatingBadge({required this.branchId});

  final int branchId;

  @override
  State<_SalonRatingBadge> createState() => _SalonRatingBadgeState();
}

class _SalonRatingBadgeState extends State<_SalonRatingBadge> {
  late Future<_SalonRatingSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRating();
  }

  @override
  void didUpdateWidget(covariant _SalonRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _future = _loadRating();
    }
  }

  Future<_SalonRatingSummary> _loadRating() async {
    if (widget.branchId <= 0) {
      return const _SalonRatingSummary(average: 0, count: 0);
    }

    try {
      final data = await ApiService.fetchBranchRatings(widget.branchId);
      final appointments = data['data']?['appointments'];
      if (data['success'] != true || appointments is! List) {
        return const _SalonRatingSummary(average: 0, count: 0);
      }

      final branchRatings = <num>[];
      final fallbackRatings = <num>[];

      for (final appointment in appointments) {
        if (appointment is! Map) continue;

        final branchReview = appointment['branchReview'];
        final branchRating =
            branchReview is Map ? branchReview['rating'] : null;
        if (branchRating is num) {
          branchRatings.add(branchRating);
          continue;
        }

        final clientReview = appointment['clientReview'];
        final clientRating =
            clientReview is Map ? clientReview['rating'] : null;
        if (clientRating is num) {
          fallbackRatings.add(clientRating);
        }

        final professionalReviews = appointment['professionalReviews'];
        if (professionalReviews is List) {
          for (final review in professionalReviews) {
            final rating = review is Map ? review['rating'] : null;
            if (rating is num) fallbackRatings.add(rating);
          }
        }
      }

      final ratings =
          branchRatings.isNotEmpty ? branchRatings : fallbackRatings;
      if (ratings.isEmpty) {
        return const _SalonRatingSummary(average: 0, count: 0);
      }

      final total = ratings.fold<double>(
        0,
        (sum, rating) => sum + rating.toDouble(),
      );
      return _SalonRatingSummary(
        average: total / ratings.length,
        count: ratings.length,
      );
    } catch (_) {
      return const _SalonRatingSummary(average: 0, count: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SalonRatingSummary>(
      future: _future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final label = snapshot.connectionState == ConnectionState.waiting
            ? '—'
            : (summary?.average ?? 0).toStringAsFixed(1);

        return Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 13,
                color: Color(0xFFD0A244),
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B6500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalonRatingSummary {
  const _SalonRatingSummary({
    required this.average,
    required this.count,
  });

  final double average;
  final int count;
}

class _BranchTile extends StatefulWidget {
  const _BranchTile({
    required this.branch,
    required this.accentColor,
    this.onOpen,
    this.onEdit,
    this.onToggleActive,
    this.onDelete,
    this.hideViewButton = false,
    this.hideTitle = false,
  });

  final Map<String, dynamic> branch;
  final Future<void> Function()? onOpen;
  final Color accentColor;
  final VoidCallback? onEdit;
  final void Function(bool active)? onToggleActive;
  final VoidCallback? onDelete;
  final bool hideViewButton;
  final bool hideTitle;

  @override
  State<_BranchTile> createState() => _BranchTileState();
}

class _BranchTileState extends State<_BranchTile> {
  bool isLoading = false;

  String _cleanText(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  String _composeAddress(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return '';
    }

    final segments = <String>[];
    final seenParts = <String>{};

    void push(dynamic value) {
      final text = _cleanText(value);
      if (text.isEmpty) return;
      for (final part in text.split(',')) {
        final cleanedPart = _cleanText(part);
        final key = cleanedPart.toLowerCase();
        if (cleanedPart.isNotEmpty && seenParts.add(key)) {
          segments.add(cleanedPart);
        }
      }
    }

    push(data['line1'] ?? data['addressLine1'] ?? data['buildingName']);
    push(data['line2'] ?? data['addressLine2']);
    push(data['village']);
    push(data['district']);
    push(data['city']);
    push(data['state']);
    push(data['country']);
    push(data['postalCode'] ?? data['pincode'] ?? data['zip']);
    return segments.join(', ');
  }

  void _handleTap() async {
    if (isLoading || widget.onOpen == null) {
      return;
    }
    setState(() => isLoading = true);
    try {
      await widget.onOpen!();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _branchMenuButton(bool isActive) {
    final canEdit = isActive && widget.onEdit != null;

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: Color(0xFF8A8178),
        ),
        color: Colors.white,
        elevation: 10,
        offset: const Offset(-8, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8DED4)),
        ),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              if (isActive) widget.onEdit?.call();
              break;
            case 'toggle':
              widget.onToggleActive?.call(!isActive);
              break;
            case 'delete':
              widget.onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          if (widget.onEdit != null)
            PopupMenuItem<String>(
              value: 'edit',
              enabled: canEdit,
              child: _ActionPopupRow(
                icon: Icons.edit_outlined,
                label: 'Edit Branch',
                enabled: canEdit,
              ),
            ),
          if (widget.onToggleActive != null)
            PopupMenuItem<String>(
              value: 'toggle',
              child: _ActionPopupRow(
                icon: isActive
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                label: isActive ? 'Deactivate Branch' : 'Activate Branch',
              ),
            ),
          if (widget.onDelete != null)
            const PopupMenuItem<String>(
              value: 'delete',
              child: _ActionPopupRow(
                icon: Icons.delete_outline,
                label: 'Delete Branch',
                destructive: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _branchStatusTag(bool isActive) {
    final textColor =
        isActive ? const Color(0xFF047857) : const Color(0xFFB42318);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8FFF5) : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive ? const Color(0xFFB7F0D0) : const Color(0xFFF5C2C7),
        ),
      ),
      child: Text(
        translateText(isActive ? 'Active' : 'Deactivated'),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final accentColor = widget.accentColor;
    final address = branch['address'] as Map<String, dynamic>? ?? {};
    final fullAddress = _composeAddress(address).isNotEmpty
        ? _composeAddress(address)
        : _composeAddress(branch);
    final phone = (branch['phone'] ??
            branch['phoneNumber'] ??
            branch['contactNumber'] ??
            '')
        .toString()
        .trim();
    final isActive = branch['active'] != false;
    final String title = [
      branch['name'],
      branch['branchName'],
      branch['displayName'],
      branch['title'],
    ].map(_cleanText).firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final bool showTitle = !widget.hideTitle && title.isNotEmpty;

    return InkWell(
      onTap: widget.onOpen == null ? null : _handleTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isLoading
                ? accentColor.withValues(alpha: 0.35)
                : const Color(0xFFE8DED4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTitle)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF201B17),
                            ),
                          ),
                        ),
                        if (!isActive) ...[
                          const SizedBox(width: 6),
                          _branchStatusTag(false),
                        ],
                      ],
                    ),
                  if (fullAddress.isNotEmpty) ...[
                    if (showTitle) const SizedBox(height: 4),
                    Text(
                      fullAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: Color(0xFF8A8178),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A8178),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onEdit != null ||
                widget.onToggleActive != null ||
                widget.onDelete != null)
              _branchMenuButton(isActive),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FabActionPanel extends StatelessWidget {
  const _FabActionPanel({
    super.key,
    required this.onTeam,
    required this.onDeals,
    required this.onPackages,
  });

  final VoidCallback onTeam;
  final VoidCallback onDeals;
  final VoidCallback onPackages;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FabActionTile(
                icon: Icons.groups_2_rounded,
                label: translateText('Team members'),
                subtitle: translateText('Manage stylists & staff'),
                onTap: onTeam,
              ),
              const Divider(height: 1, color: Color(0xFFE8DED4)),
              _FabActionTile(
                icon: Icons.local_offer_outlined,
                label: translateText('Deals'),
                subtitle: translateText('Create offers'),
                onTap: onDeals,
              ),
              const Divider(height: 1, color: Color(0xFFE8DED4)),
              _FabActionTile(
                icon: Icons.card_giftcard_outlined,
                label: translateText('Packages'),
                subtitle: translateText('Bundle services'),
                onTap: onPackages,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabActionTile extends StatelessWidget {
  const _FabActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF4E8D1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF8B6500), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF201B17),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A8178),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFB8AEA6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
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
              child: Icon(
                Icons.wifi_tethering_error_rounded,
                color: AppColors.starColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              translateText('Could not load salons'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF37474F),
                  ) ??
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF37474F),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              translateText(message),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF607D8B),
                    height: 1.35,
                  ) ??
                  const TextStyle(
                    color: Color(0xFF607D8B),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                translateText('Retry'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
