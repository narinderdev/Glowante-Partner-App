import 'dart:async';

import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import 'stylist_bookings_screen.dart';
import 'stylist_profile_screen.dart';

class StylistBottomNav extends StatefulWidget {
  const StylistBottomNav({
    super.key,
    this.tabIndex = 0,
  });

  final int tabIndex;

  @override
  State<StylistBottomNav> createState() => _StylistBottomNavState();
}

class _StylistBottomNavState extends State<StylistBottomNav> {
  static const List<List<String>> _tabPermissionRequirements = [
    <String>['bookings.view'],
    <String>[],
  ];

  late int _currentIndex;
  late final VoidCallback _branchSelectionListener;
  StreamSubscription<BookingNotificationPayload>? _navPushSub;
  Set<String> _permissions = const <String>{};
  bool _hasPermissionPayload = false;

  @override
  void initState() {
    super.initState();
    final screenCount = _buildScreens().length;
    _currentIndex = widget.tabIndex.clamp(0, screenCount - 1);
    debugPrint(
      '[HomeReach] Stylist home shell initialized with tabIndex=$_currentIndex',
    );
    _branchSelectionListener = () {
      if (mounted) unawaited(_loadPermissions());
    };
    StylistBranchSelectionStore.selectionNotifier
        .addListener(_branchSelectionListener);
    unawaited(_loadPermissions());

    final pendingNotification =
        PushNotificationService.instance.pendingNavigationEvent;
    if (pendingNotification != null &&
        pendingNotification.wasTapped &&
        _isTabAllowed(0)) {
      _currentIndex = 0;
    }

    _navPushSub =
        PushNotificationService.instance.bookingNotifications.listen((payload) {
      if (!payload.wasTapped || !mounted || _currentIndex == 0) {
        return;
      }
      if (!_isTabAllowed(0)) return;
      setState(() {
        _currentIndex = 0;
      });
    });
  }

  @override
  void didUpdateWidget(covariant StylistBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      setState(() {
        final nextIndex = widget.tabIndex.clamp(0, _buildScreens().length - 1);
        _currentIndex = _isTabAllowed(nextIndex) ? nextIndex : 1;
      });
    }
  }

  List<Widget> _buildScreens() {
    return [
      const StylistBookingsScreen(),
      const StylistProfileScreen(),
    ];
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

  void _handleTabSelect(int index) {
    if (!_isTabAllowed(index)) return;
    setState(() {
      _currentIndex = index;
    });
    debugPrint(
      '[HomeReach] Stylist home shell active tab=$_currentIndex',
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    if (!_isTabAllowed(_currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isTabAllowed(_currentIndex)) return;
        setState(() => _currentIndex = 1);
      });
    }

    final destinations = [
      SharedBottomNavDestination(
        iconPath: 'assets/images/bookings.png',
        activeIconPath: 'assets/images/bookings1.png',
        label: context.t('Bookings'),
        enabled: _isTabAllowed(0),
      ),
      SharedBottomNavDestination(
        iconPath: 'assets/images/user.png',
        activeIconPath: 'assets/images/user1.png',
        label: context.t('Profile'),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: SharedBottomNavBar(
        destinations: destinations,
        currentIndex: _currentIndex,
        onSelect: _handleTabSelect,
      ),
    );
  }
}
