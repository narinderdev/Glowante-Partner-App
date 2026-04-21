import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/push_notification_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'stylist_bookings_screen.dart';
// import 'stylist_inventory_screen.dart';
import 'stylist_profile_screen.dart';
// import 'stylist_services_screen.dart';

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
  // int _servicesRefreshSignal = 0;
  // int _inventoryRefreshSignal = 0;
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
      if (!payload.wasTapped || !mounted || _currentIndex == 0) return;
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
      // StylistServicesScreen(refreshSignal: _servicesRefreshSignal),
      // StylistInventoryScreen(refreshSignal: _inventoryRefreshSignal),
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
      _Destination(
        iconPath: 'assets/images/bookings.png',
        activeIconPath: 'assets/images/bookings1.png',
        label: context.t('Bookings'),
      ),
      // _Destination(
      //   iconPath: 'assets/images/service.png',
      //   activeIconPath: 'assets/images/service1.png',
      //   label: context.t('Services'),
      // ),
      // _Destination(
      //   icon: Icons.inventory_2_outlined,
      //   activeIcon: Icons.inventory_2_rounded,
      //   label: context.t('Inventory'),
      // ),
      _Destination(
        iconPath: 'assets/images/user.png',
        activeIconPath: 'assets/images/user1.png',
        label: context.t('Profile'),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          child: _StylistFloatingNavBar(
            destinations: destinations,
            currentIndex: _currentIndex,
            onSelect: (index) {
              setState(() {
                // if (index == 1) {
                //   _servicesRefreshSignal++;
                // }
                // if (index == 2) {
                //   _inventoryRefreshSignal++;
                // }
                _currentIndex = index;
              });
              debugPrint(
                '[HomeReach] Stylist home shell active tab=$_currentIndex',
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StylistFloatingNavBar extends StatelessWidget {
  const _StylistFloatingNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: primary.withOpacity(0.15),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < destinations.length; i++)
            _StylistNavButton(
              destination: destinations[i],
              isActive: currentIndex == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _StylistNavButton extends StatelessWidget {
  const _StylistNavButton({
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  final _Destination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destination.iconPath != null &&
                  destination.activeIconPath != null)
                Image.asset(
                  isActive
                      ? destination.activeIconPath!
                      : destination.iconPath!,
                  width: 24,
                  height: 24,
                )
              else
                Icon(
                  isActive
                      ? (destination.activeIcon ?? destination.icon)
                      : (destination.icon ?? destination.activeIcon),
                  size: 24,
                  color: isActive
                      ? AppColors.starColor
                      : AppColors.darkGrey.withOpacity(0.6),
                ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.starColor
                      : AppColors.darkGrey.withOpacity(0.6),
                ),
                child: Text(destination.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  _Destination({
    this.iconPath,
    this.activeIconPath,
    this.icon,
    this.activeIcon,
    required this.label,
  });

  final String? iconPath;
  final String? activeIconPath;
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
}
