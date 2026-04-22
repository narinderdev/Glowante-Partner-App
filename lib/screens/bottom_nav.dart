import 'dart:async';

import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import 'Bookings.dart';
import 'category_screen.dart';
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
  StreamSubscription<BookingNotificationPayload>? _navPushSub;

  @override
  void initState() {
    super.initState();
    _salonsScreenKey = GlobalKey<SalonsScreenState>();
    _screens = [
      const BookingsScreen(),
      SalonsScreen(key: _salonsScreenKey),
      const CategoryScreen(),
      const ProfileScreen(),
    ];
    _currentIndex = widget.tabIndex.clamp(0, _screens.length - 1);
    debugPrint(
      '[HomeReach] Owner home shell initialized with tabIndex=$_currentIndex',
    );

    final pendingNotification =
        PushNotificationService.instance.pendingNavigationEvent;
    if (pendingNotification != null && pendingNotification.wasTapped) {
      _setCurrentIndex(0, animate: false);
    }

    _navPushSub =
        PushNotificationService.instance.bookingNotifications.listen((payload) {
      if (!payload.wasTapped || !mounted) {
        return;
      }
      if (_currentIndex == 0) {
        return;
      }
      _setCurrentIndex(0);
    });
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      _setCurrentIndex(widget.tabIndex.clamp(0, _screens.length - 1));
    }
  }

  @override
  void dispose() {
    _navPushSub?.cancel();
    super.dispose();
  }

  void _setCurrentIndex(int index, {bool animate = true}) {
    if (_currentIndex == index && animate) {
      if (index == 1) {
        _salonsScreenKey.currentState?.collapseQuickActions();
      }
      return;
    }

    if (_currentIndex == 1) {
      _salonsScreenKey.currentState?.collapseQuickActions();
    }

    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    } else {
      _currentIndex = index;
    }
    debugPrint('[HomeReach] Owner home shell active tab=$_currentIndex');
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final destinations = [
      SharedBottomNavDestination(
        iconPath: 'assets/images/bookings.png',
        activeIconPath: 'assets/images/bookings1.png',
        label: context.t('Bookings'),
      ),
      SharedBottomNavDestination(
        iconPath: 'assets/images/salon.png',
        activeIconPath: 'assets/images/salon1.png',
        label: context.t('Salons'),
      ),
      SharedBottomNavDestination(
        iconPath: 'assets/images/service.png',
        activeIconPath: 'assets/images/service1.png',
        label: context.t('Catalog'),
      ),
      SharedBottomNavDestination(
        iconPath: 'assets/images/user.png',
        activeIconPath: 'assets/images/user1.png',
        label: context.t('Profile'),
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
        onSelect: (index) => _setCurrentIndex(index),
      ),
    );
  }
}
