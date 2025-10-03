import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import '../services/network_listener.dart';
import '../services/push_notification_service.dart';

import 'Bookings.dart';
import 'category_screen.dart';
import 'profile_screen.dart';
import 'salons_screen.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key, this.tabIndex = 0});

  final int tabIndex;

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  late int _currentIndex;
  late final List<_Destination> _destinations;
  late final List<Widget> _screens;
  StreamSubscription<BookingNotificationPayload>? _navPushSub;


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.tabIndex.clamp(0, 3); // 4 tabs: 0..3
    _destinations = [
  _Destination(
    iconPath: 'assets/images/bookings.png',
    activeIconPath: 'assets/images/bookings1.png',
    label: 'Bookings',
  ),
  _Destination(
    iconPath: 'assets/images/salon.png',
    activeIconPath: 'assets/images/salon1.png',
    label: 'Salons',
  ),
  _Destination(
    iconPath: 'assets/images/service.png',
    activeIconPath: 'assets/images/service1.png',
    label: 'Catalog',
  ),
  _Destination(
    iconPath: 'assets/images/user.png',
    activeIconPath: 'assets/images/user1.png',
    label: 'Profile',
  ),
];

    _screens = [
      const BookingsScreen(),
      SalonsScreen(),
      CategoryScreen(),
      ProfileScreen(),
    ];

    final pendingNotification = PushNotificationService.instance.pendingNavigationEvent;
    if (pendingNotification != null && pendingNotification.wasTapped) {
      _currentIndex = 0;
    }

    _navPushSub = PushNotificationService.instance.bookingNotifications.listen((payload) {
      if (!payload.wasTapped || !mounted) return;
      if (_currentIndex == 0) return;
      setState(() => _currentIndex = 0);
    });
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      setState(() {
        _currentIndex =
            widget.tabIndex.clamp(0, _destinations.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _navPushSub?.cancel();
    super.dispose();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: IndexedStack(
  //       index: _currentIndex,
  //       children: _screens,
  //     ),
  //     bottomNavigationBar: SafeArea(
  //       top: false,
  //       child: Padding(
  //         padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
  //         child: _FloatingNavBar(
  //           destinations: _destinations,
  //           currentIndex: _currentIndex,
  //           onSelect: (index) {
  //             if (_currentIndex == index) return;
  //             setState(() => _currentIndex = index);
  //           },
  //         ),
  //       ),
  //     ),
  //   );
  // }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: StreamBuilder<bool>(
      stream: NetworkManager.networkStatusStream,
      initialData: true,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;

        return Stack(
          children: [
            // 👇 your main screens
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),

            // 🔴 No internet overlay (only over body)
            if (!isConnected)
              Container(
                color: Colors.black.withOpacity(0.6),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.wifi_off,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No Internet Connection",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Please check your network settings.",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),

    // 👇 Bottom navigation stays outside the overlay
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
        child: _FloatingNavBar(
          destinations: _destinations,
          currentIndex: _currentIndex,
          onSelect: (index) {
            if (_currentIndex == index) return;
            setState(() => _currentIndex = index);
          },
        ),
      ),
    ),
  );
}

}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;

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
            _NavButton(
              destination: destinations[i],
              isActive: currentIndex == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
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
    Image.asset(
      isActive ? destination.activeIconPath : destination.iconPath,
      width: 24,
      height: 24,
    ),
    const SizedBox(height: 4),
   Opacity(
  opacity: isActive ? 1.0 : 0.0, 
  child: Text(
    destination.label,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isActive ? AppColors.starColor : Colors.transparent, // <-- visible when active
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

class _Destination {
   _Destination({
    required this.iconPath,
    required this.activeIconPath,
    required this.label,
  });

  final String iconPath;
  final String activeIconPath;
  final String label;
}
