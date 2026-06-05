import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/repositories/branch_repository.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import 'add_branch_screen.dart';
import 'add_salon_screen.dart';
import 'branch_screen.dart';
import 'SalonDeal.dart';
import 'SalonPackage.dart';
import 'SalonTeams.dart';
import 'notifications.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText(
              active
                  ? 'Salon activated successfully'
                  : 'Salon deactivated successfully',
            ),
          ),
        ),
      );
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Salon deleted successfully'))),
      );
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText(
              active
                  ? 'Branch activated successfully'
                  : 'Branch deactivated successfully',
            ),
          ),
        ),
      );
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Branch deleted successfully'))),
      );
      await _refreshSalons();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _openBranchDetail({
    required int salonId,
    required int branchId,
  }) async {
    final repository = context.read<BranchRepository>();

    try {
      final response = await repository.fetchBranchDetail(branchId);
      if (response['success'] == true && response['data'] != null) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BranchScreen(
              salonId: salonId,
              branchDetails: response['data'] as Map<String, dynamic>,
            ),
          ),
        );
      } else {
        final message = response['message'] ?? 'Unable to open branch details';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: _SalonsAppBar(
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onSearchChanged: _handleSearchChanged,
        onSearchTap: _collapseFab,
        onHeaderTap: _collapseFab,
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

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refreshSalons,
                  color: (AppColors.starColor),
                  displacement: 32,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
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
                          child: Center(child: CircularProgressIndicator()),
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
                                  onOpenBranch: (branchId) => _openBranchDetail(
                                    salonId: salonId,
                                    branchId: branchId,
                                  ),
                                ),
                              );
                            }, childCount: salons.length),
                          ),
                        ),
                      if (!widget.readOnly && _searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 28),
                            child: _AddMainSalonCard(onTap: _goToAddSalon),
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
    required this.onNotificationTap,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchTap;
  final VoidCallback? onHeaderTap;
  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(52);

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
            height: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/finallogo.png',
                    height: 34,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png',
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onNotificationTap,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF8B6500),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              translateText('Syncing latest data.'),
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
  final VoidCallback? onAddBranch;
  final VoidCallback? onEditSalon;
  final void Function(bool active)? onToggleSalonActive;
  final VoidCallback? onDeleteSalon;
  final void Function(Map<String, dynamic> branch)? onEditBranch;
  final void Function(int branchId, bool active)? onToggleBranchActive;
  final void Function(int branchId)? onDeleteBranch;
  final Future<void> Function(int branchId) onOpenBranch;

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
    if (data == null || data.isEmpty) return '';
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

  Widget _heroImage(String? imageUrl) {
    final usableImageUrl = _usableSalonImageUrl(imageUrl);
    if (usableImageUrl == null) return _localHeroImage();
    return SizedBox(
      height: _salonHeroImageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1EFEC)),
          _AdaptiveSalonNetworkImage(
            imageUrl: usableImageUrl,
            fallback: _localHeroImage(),
          ),
        ],
      ),
    );
  }

  Widget _localHeroImage() {
    return SizedBox(
      height: _salonHeroImageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1EFEC)),
          Image.asset(
            'assets/images/salonImage.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ],
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

  Widget _salonMenuButton(bool isActive) {
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
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEditSalon?.call();
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
              child: Text(translateText('Edit Salon')),
            ),
          if (onToggleSalonActive != null)
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(
                translateText(
                  isActive ? 'Deactivate Salon' : 'Activate Salon',
                ),
              ),
            ),
          if (onDeleteSalon != null)
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(translateText('Delete Salon')),
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
          Padding(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                _AutoSlidingHeroImage(
                  imageUrls: heroImageUrls,
                  fallback: _localHeroImage(),
                  imageBuilder: _heroImage,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _badge('Main Salon', Icons.workspace_premium_rounded),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _SalonRatingBadge(branchId: primaryBranchId),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      _salonMenuButton(isActive),
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
                                    onOpen: null,
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
  double? _aspectRatio;
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
      _aspectRatio = null;
      _hasError = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final height = info.image.height;
        if (!mounted || height == 0) return;
        setState(() {
          _aspectRatio = info.image.width / height;
        });
      },
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

    final aspectRatio = _aspectRatio;
    final fit = aspectRatio == null
        ? BoxFit.cover
        : aspectRatio >= 1.1
            ? BoxFit.cover
            : BoxFit.contain;

    return Image.network(
      widget.imageUrl,
      fit: fit,
      alignment: Alignment.center,
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _AutoSlidingHeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _currentPage = 0;
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
      final nextPage = (_currentPage + 1) % widget.imageUrls.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _currentPage = index);
            },
            itemBuilder: (_, index) =>
                widget.imageBuilder(widget.imageUrls[index]),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.imageUrls.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 14 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: isActive ? 1 : 0.78,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF201B17),
                      ),
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
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Color(0xFF8A8178),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      widget.onEdit?.call();
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
                      child: Text(translateText('Edit Branch')),
                    ),
                  if (widget.onToggleActive != null)
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(
                        translateText(
                          isActive ? 'Deactivate Branch' : 'Activate Branch',
                        ),
                      ),
                    ),
                  if (widget.onDelete != null)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(translateText('Delete Branch')),
                    ),
                ],
              ),
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

class _AddMainSalonCard extends StatelessWidget {
  const _AddMainSalonCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFE8DED4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                color: const Color(0xFFFBF7F0),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B6500),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      translateText('Add New Main Salon'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B6500),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      translateText('Expand your empire today'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8178),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1EBE6),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFFD0A244),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        translateText(
                          '"Scale your vision with precision. Manage every location seamlessly and watch your salon network flourish with each new client."',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFFD0A244),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 44,
                      height: 1,
                      color: const Color(0xFFE3D8C7),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh),
            label: Text(translateText('Retry')),
          ),
        ],
      ),
    );
  }
}
