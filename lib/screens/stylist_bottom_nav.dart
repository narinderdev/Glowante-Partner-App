import 'dart:async';

import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
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
  late int _currentIndex;
  StreamSubscription<BookingNotificationPayload>? _navPushSub;

  @override
  void initState() {
    super.initState();
    final screenCount = _buildScreens().length;
    _currentIndex = widget.tabIndex.clamp(0, screenCount - 1);
    debugPrint(
      '[HomeReach] Stylist home shell initialized with tabIndex=$_currentIndex',
    );

    final pendingNotification =
        PushNotificationService.instance.pendingNavigationEvent;
    if (pendingNotification != null && pendingNotification.wasTapped) {
      _currentIndex = 0;
    }

    _navPushSub =
        PushNotificationService.instance.bookingNotifications.listen((payload) {
      if (!payload.wasTapped || !mounted || _currentIndex == 0) {
        return;
      }
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
        _currentIndex = widget.tabIndex.clamp(0, _buildScreens().length - 1);
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
    _navPushSub?.cancel();
    super.dispose();
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
        onSelect: (index) {
          setState(() {
            _currentIndex = index;
          });
          debugPrint(
            '[HomeReach] Stylist home shell active tab=$_currentIndex',
          );
        },
      ),
    );
  }
}
