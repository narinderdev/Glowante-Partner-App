import 'dart:async';

import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
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

  Future<void> _handleTabSelect(int index, {bool animate = true}) async {
    if (_shouldLockToSalonsTab() && index != 2) {
      return;
    }
    _setCurrentIndex(index, animate: animate);
  }

  bool _shouldLockToSalonsTab() {
    final salonState = context.read<SalonListCubit>().state;
    return salonState.status == SalonListStatus.success &&
        salonState.salons.isEmpty;
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
    final salonState = context.watch<SalonListCubit>().state;
    final lockToSalonsTab = salonState.status == SalonListStatus.success &&
        salonState.salons.isEmpty;

    if (lockToSalonsTab && _currentIndex != 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_shouldLockToSalonsTab() || _currentIndex == 2) {
          return;
        }
        _setCurrentIndex(2, animate: false);
      });
    }

    final destinations = [
      SharedBottomNavDestination(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: context.t('Home'),
        enabled: !lockToSalonsTab,
      ),
      SharedBottomNavDestination(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_outlined,
        label: context.t('Bookings'),
        enabled: !lockToSalonsTab,
      ),
      SharedBottomNavDestination(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_outlined,
        label: context.t('Salons'),
        enabled: true,
      ),
      SharedBottomNavDestination(
        icon: Icons.content_cut_rounded,
        activeIcon: Icons.content_cut_rounded,
        label: context.t('Catalog'),
        enabled: !lockToSalonsTab,
      ),
      SharedBottomNavDestination(
        icon: Icons.more_horiz_rounded,
        activeIcon: Icons.more_horiz_rounded,
        label: context.t('More'),
        enabled: !lockToSalonsTab,
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
