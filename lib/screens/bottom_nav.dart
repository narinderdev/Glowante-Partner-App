import 'package:flutter/material.dart';

import 'Bookings.dart';
import 'category_screen.dart';
import 'home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.tabIndex.clamp(0, 4);
    _destinations = const [
      _Destination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _Destination(
        icon: Icons.store_outlined,
        selectedIcon: Icons.storefront_rounded,
        label: 'Salons',
      ),
      _Destination(
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        label: 'Categories',
      ),
      _Destination(
        icon: Icons.event_outlined,
        selectedIcon: Icons.event_note_rounded,
        label: 'Bookings',
      ),
      _Destination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];
    _screens = [
      HomeScreen(),
      SalonsScreen(),
      CategoryScreen(),
      BookingsScreen(),
      ProfileScreen(),
    ];
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      setState(() {
        _currentIndex = widget.tabIndex.clamp(0, _destinations.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20), // full-width spread
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

// class _FloatingNavBar extends StatelessWidget {
//   const _FloatingNavBar({
//     required this.destinations,
//     required this.currentIndex,
//     required this.onSelect,
//   });

//   final List<_Destination> destinations;
//   final int currentIndex;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final Color primary = theme.colorScheme.primary;
//     final Color onSurface = theme.colorScheme.onSurface;

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // smaller margin = wider bar
//       height: 72, // keep same height
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(28),
//         boxShadow: [
//           BoxShadow(
//             color: primary.withOpacity(0.25),
//             blurRadius: 30,
//             spreadRadius: 5,
//             offset: const Offset(0, 12),
//           ),
//         ],
//         border: Border.all(
//           color: primary.withOpacity(0.15),
//           width: 1.2,
//         ),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Row(
//         children: [
//           for (int i = 0; i < destinations.length; i++)
//             Expanded(
//               child: _NavButton(
//                 destination: destinations[i],
//                 isActive: currentIndex == i,
//                 primary: primary,
//                 inactiveColor: onSurface.withOpacity(0.55),
//                 onTap: () => onSelect(i),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class _NavButton extends StatelessWidget {
//   const _NavButton({
//     required this.destination,
//     required this.isActive,
//     required this.onTap,
//     required this.primary,
//     required this.inactiveColor,
//   });

//   final _Destination destination;
//   final bool isActive;
//   final VoidCallback onTap;
//   final Color primary;
//   final Color inactiveColor;

//   @override
//   Widget build(BuildContext context) {
//     final Color iconColor = isActive ? Colors.white : inactiveColor;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 6),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(22),
//           onTap: onTap,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 220),
//             curve: Curves.easeOut,
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             decoration: BoxDecoration(
//               color: isActive ? primary : Colors.transparent,
//               borderRadius: BorderRadius.circular(18),
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   isActive ? destination.selectedIcon : destination.icon,
//                   size: 26,
//                   color: iconColor,
//                 ),
//                 const SizedBox(height: 4),
//                 AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 200),
//                   child: isActive
//                       ? Text(
//                           destination.label,
//                           key: ValueKey(destination.label),
//                           style: const TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.white,
//                           ),
//                         )
//                       : const SizedBox.shrink(),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

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
    final Color onSurface = theme.colorScheme.onSurface;

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
        mainAxisAlignment: MainAxisAlignment.spaceAround, // spread evenly
        children: [
          for (int i = 0; i < destinations.length; i++)
            _NavButton(
              destination: destinations[i],
              isActive: currentIndex == i,
              primary: primary,
              inactiveColor: onSurface.withOpacity(0.55),
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
    required this.primary,
    required this.inactiveColor,
  });

  final _Destination destination;
  final bool isActive;
  final VoidCallback onTap;
  final Color primary;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isActive ? Colors.white : inactiveColor;

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
            color: isActive ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // prevents overflow
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? destination.selectedIcon : destination.icon,
                size: 24,
                color: iconColor,
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isActive
                    ? Flexible( // ensures text shrinks if needed
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            destination.label,
                            key: ValueKey(destination.label),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
