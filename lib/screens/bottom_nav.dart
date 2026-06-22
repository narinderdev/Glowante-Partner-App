import 'dart:async';

import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
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
  late int _currentIndex;
  late final List<Widget> _screens;
  late final GlobalKey<SalonsScreenState> _salonsScreenKey;
  late final GlobalKey<CategoryScreenState> _categoryScreenKey;
  StreamSubscription<BookingNotificationPayload>? _navPushSub;
  bool _permissionsLoaded = false;
  bool _hasPermissionPayload = false;
  Set<String> _branchPermissions = const <String>{};

  static const List<List<String>> _tabPermissions = <List<String>>[
    <String>['dashboard.view'],
    <String>['bookings.view'],
    <String>['salons.view'],
    <String>['catalog.view'],
    <String>[
      'team.view',
      'deals.view',
      'packages.view',
      'gallery.view',
    ],
  ];

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
    _loadPermissions();
    debugPrint(
      '[HomeReach] Owner home shell initialized with tabIndex=$_currentIndex',
    );

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
    _navPushSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final selection = await StylistBranchSelectionStore.load();
    final branchId = selection.branchId ?? await _firstPersistedBranchId();
    final hasPermissionPayload =
        await UserRoleSession.instance.hasPersistedPermissions();
    final branchPermissions = await UserRoleSession.instance.loadPermissions(
      branchId: branchId,
    );

    if (!mounted) return;

    setState(() {
      _permissionsLoaded = true;
      _hasPermissionPayload = hasPermissionPayload;
      _branchPermissions = branchPermissions;
    });

    if (!_canAccessTab(_currentIndex)) {
      final fallback = _firstAllowedTabIndex();
      if (fallback != _currentIndex) {
        _setCurrentIndex(fallback, animate: false);
      }
    }
  }

  Future<int?> _firstPersistedBranchId() async {
    final salons = await UserRoleSession.instance.loadUserSalons();
    for (final salon in salons) {
      final branches = salon['branches'];
      if (branches is! List) continue;
      for (final branch in branches) {
        if (branch is! Map) continue;
        final id = _intValue(branch['id'] ?? branch['branchId']);
        if (id != null) return id;
      }
    }

    final userBranches = await UserRoleSession.instance.loadUserBranches();
    for (final userBranch in userBranches) {
      final branch = userBranch['branch'];
      final branchMap = branch is Map ? Map<String, dynamic>.from(branch) : {};
      final id = _intValue(
        userBranch['branchId'] ??
            branchMap['id'] ??
            branchMap['branchId'] ??
            userBranch['id'],
      );
      if (id != null) return id;
    }

    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  bool _canAccessPermissions(List<String> permissions) {
    if (permissions.isEmpty) return true;
    if (!_permissionsLoaded || !_hasPermissionPayload) return true;
    return permissions.any(_branchPermissions.contains);
  }

  bool _canAccessTab(int index) {
    if (index < 0 || index >= _tabPermissions.length) return false;
    return _canAccessPermissions(_tabPermissions[index]);
  }

  int _firstAllowedTabIndex() {
    for (var index = 0; index < _tabPermissions.length; index++) {
      if (_canAccessTab(index)) return index;
    }
    return 0;
  }

  Future<void> _handleTabSelect(int index, {bool animate = true}) async {
    await _loadPermissions();
    if (!_canAccessTab(index)) {
      _showPermissionDenied();
      return;
    }
    _setCurrentIndex(index, animate: animate);
  }

  void _showPermissionDenied() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('You do not have permission to access this section.'),
        ),
      ),
    );
  }

  void _setCurrentIndex(int index, {bool animate = true}) {
    if (_currentIndex == index && animate) {
      if (index == 2) {
        _salonsScreenKey.currentState?.collapseQuickActions();
      } else if (index == 3) {
        _categoryScreenKey.currentState?.refreshFromCurrentSelection();
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
        _categoryScreenKey.currentState?.refreshFromCurrentSelection();
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

    final destinations = [
      SharedBottomNavDestination(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: context.t('Home'),
        enabled: _canAccessTab(0),
        onDisabledTap: _showPermissionDenied,
      ),
      SharedBottomNavDestination(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_outlined,
        label: context.t('Bookings'),
        enabled: _canAccessTab(1),
        onDisabledTap: _showPermissionDenied,
      ),
      SharedBottomNavDestination(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_outlined,
        label: context.t('Salons'),
        enabled: _canAccessTab(2),
        onDisabledTap: _showPermissionDenied,
      ),
      SharedBottomNavDestination(
        icon: Icons.content_cut_rounded,
        activeIcon: Icons.content_cut_rounded,
        label: context.t('Catalog'),
        enabled: _canAccessTab(3),
        onDisabledTap: _showPermissionDenied,
      ),
      SharedBottomNavDestination(
        icon: Icons.more_horiz_rounded,
        activeIcon: Icons.more_horiz_rounded,
        label: context.t('More'),
        enabled: _canAccessTab(4),
        onDisabledTap: _showPermissionDenied,
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
