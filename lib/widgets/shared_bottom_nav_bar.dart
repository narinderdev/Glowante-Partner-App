import 'dart:ui';

import 'package:flutter/material.dart';

const String _navFontFamily = 'Manrope';
const List<String> _navFontFallback = ['Inter', 'sans-serif'];

class SharedBottomNavDestination {
  const SharedBottomNavDestination({
    required this.label,
    this.iconPath,
    this.activeIconPath,
    this.icon,
    this.activeIcon,
  });

  final String label;
  final String? iconPath;
  final String? activeIconPath;
  final IconData? icon;
  final IconData? activeIcon;
}

class SharedBottomNavBar extends StatelessWidget {
  const SharedBottomNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<SharedBottomNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 64 + bottomInset,
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, bottomInset > 0 ? bottomInset : 10),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            border: const Border(
              top: BorderSide(
                color: Color(0xFFF5F3F3),
                width: 1,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _SharedBottomNavButton(
                          destination: destinations[i],
                          isActive: currentIndex == i,
                          onTap: () => onSelect(i),
                        ),
                      ),
                      if (i != destinations.length - 1)
                        Container(
                          width: 1,
                          height: 28,
                          color: const Color(0xFFF0EBE7),
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

class _SharedBottomNavButton extends StatelessWidget {
  const _SharedBottomNavButton({
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  final SharedBottomNavDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFFA8A29E);
    const activeColor = Color(0xFFB45309);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  const SizedBox(height: 1),
                  Text(
                    destination.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _navFontFamily,
                      fontFamilyFallback: _navFontFallback,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isActive ? activeColor : inactiveColor,
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
