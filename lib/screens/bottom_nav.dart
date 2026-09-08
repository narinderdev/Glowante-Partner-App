import 'dart:async';

import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import 'Bookings.dart';
import 'category_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_more_screen.dart';
import 'profile_screen.dart';
import 'salons_screen.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    this.tabIndex = 0,
  });

  final int tabIndex;

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  static const List<List<String>> _tabPermissionRequirements = [
    <String>[],
    <String>['bookings.view'],
    <String>['salons.view'],
    <String>['catalog.view'],
    <String>[],
  ];

  late int _currentIndex;
  late final List<Widget> _screens;
  late final GlobalKey<SalonsScreenState> _salonsScreenKey;
  late final GlobalKey<CategoryScreenState> _categoryScreenKey;
  late final VoidCallback _branchSelectionListener;
  StreamSubscription<BookingNotificationPayload>? _navPushSub;
  Set<String> _permissions = const <String>{};
  bool _hasPermissionPayload = false;

  @override
  void initState() {
    super.initState();
    _salonsScreenKey = GlobalKey<SalonsScreenState>();
    _categoryScreenKey = GlobalKey<CategoryScreenState>();
    _screens = [
      OwnerDashboardScreen(onOpenMoreTab: _openProfileMenu),
      const BookingsScreen(),
      SalonsScreen(key: _salonsScreenKey),
      CategoryScreen(key: _categoryScreenKey),
      const OwnerMoreScreen(),
    ];
    _currentIndex = widget.tabIndex.clamp(0, _screens.length - 1);
    debugPrint(
        '[HomeReach] Owner home shell initialized with tabIndex=$_currentIndex');
    _branchSelectionListener = () {
      if (mounted) unawaited(_loadPermissions());
    };
    StylistBranchSelectionStore.selectionNotifier
        .addListener(_branchSelectionListener);
    unawaited(_loadPermissions());

    if (_currentIndex == 3) {
      // Landed directly on Catalog (e.g. straight after adding a salon),
      // not via a later tab tap — still counts as the tab being visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _categoryScreenKey.currentState
            ?.refreshFromCurrentSelection(tabBecameActive: true);
      });
    }

    final pendingNotification =
        PushNotificationService.instance.pendingNavigationEvent;
    if (pendingNotification != null && pendingNotification.wasTapped) {
      _handleTabSelect(1, animate: false);
    }

    _navPushSub =
        PushNotificationService.instance.bookingNotifications.listen((payload) {
      if (!payload.wasTapped || !mounted) {
        return;
      }
      if (_currentIndex == 1) {
        return;
      }
      _handleTabSelect(1);
    });
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      _handleTabSelect(widget.tabIndex.clamp(0, _screens.length - 1));
    }
  }

  @override
  void dispose() {
    StylistBranchSelectionStore.selectionNotifier
        .removeListener(_branchSelectionListener);
    _navPushSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final hasPermissionPayload =
        await UserRoleSession.instance.hasPersistedPermissions();
    final selection = await StylistBranchSelectionStore.load();
    final permissions = hasPermissionPayload
        ? await UserRoleSession.instance.loadPermissions(
            branchId: selection.branchId,
          )
        : <String>{};
    if (!mounted) return;
    setState(() {
      _hasPermissionPayload = hasPermissionPayload;
      _permissions = permissions;
    });
  }

  bool _isTabAllowed(int index) {
    if (index < 0 || index >= _tabPermissionRequirements.length) return false;
    final requiredPermissions = _tabPermissionRequirements[index];
    if (requiredPermissions.isEmpty || !_hasPermissionPayload) return true;
    return requiredPermissions.any(_permissions.contains);
  }

  Future<void> _handleTabSelect(int index, {bool animate = true}) async {
    if (_shouldRestrictToDashboardAndSalons() && index != 0 && index != 2) {
      return;
    }
    if (!_isTabAllowed(index)) return;
    _setCurrentIndex(index, animate: animate);
  }

  bool _shouldRestrictToDashboardAndSalons() {
    final salonState = context.read<SalonListCubit>().state;
    return salonState.status == SalonListStatus.success &&
        salonState.salons.isEmpty;
  }

  void _setCurrentIndex(int index, {bool animate = true}) {
    if (_currentIndex == index && animate) {
      if (index == 2) {
        _salonsScreenKey.currentState?.collapseQuickActions();
      } else if (index == 3) {
        _categoryScreenKey.currentState
            ?.refreshFromCurrentSelection(tabBecameActive: true);
      }
      return;
    }

    if (_currentIndex == 2) {
      _salonsScreenKey.currentState?.collapseQuickActions();
    }

    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    } else {
      _currentIndex = index;
    }
    if (index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _categoryScreenKey.currentState
            ?.refreshFromCurrentSelection(tabBecameActive: true);
      });
    }
    debugPrint('[HomeReach] Owner home shell active tab=$_currentIndex');
  }

  void _openProfileMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    final salonState = context.watch<SalonListCubit>().state;
    final restrictToDashboardAndSalons =
        salonState.status == SalonListStatus.success &&
            salonState.salons.isEmpty;

    if (restrictToDashboardAndSalons &&
        _currentIndex != 0 &&
        _currentIndex != 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_shouldRestrictToDashboardAndSalons() ||
            _currentIndex == 0 ||
            _currentIndex == 2) {
          return;
        }
        _setCurrentIndex(0, animate: false);
      });
    }
    if (!_isTabAllowed(_currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isTabAllowed(_currentIndex)) return;
        _setCurrentIndex(0, animate: false);
      });
    }

    final destinations = [
      SharedBottomNavDestination(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: context.t('Home'),
        enabled: true,
      ),
      SharedBottomNavDestination(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_outlined,
        label: context.t('Bookings'),
        enabled: !restrictToDashboardAndSalons && _isTabAllowed(1),
      ),
      SharedBottomNavDestination(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_outlined,
        label: context.t('Salons'),
        enabled: _isTabAllowed(2),
      ),
      SharedBottomNavDestination(
        icon: Icons.content_cut_rounded,
        activeIcon: Icons.content_cut_rounded,
        label: context.t('Catalog'),
        enabled: !restrictToDashboardAndSalons && _isTabAllowed(3),
      ),
      SharedBottomNavDestination(
        icon: Icons.more_horiz_rounded,
        activeIcon: Icons.more_horiz_rounded,
        label: context.t('More'),
        enabled: !restrictToDashboardAndSalons,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SharedBottomNavBar(
        destinations: destinations,
        currentIndex: _currentIndex,
        onSelect: (index) => _handleTabSelect(index),
      ),
    );
  }
}
