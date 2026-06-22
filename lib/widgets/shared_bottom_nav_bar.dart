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
    this.enabled = true,
    this.onDisabledTap,
  });

  final String label;
  final String? iconPath;
  final String? activeIconPath;
  final IconData? icon;
  final IconData? activeIcon;
  final bool enabled;
  final VoidCallback? onDisabledTap;
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

    return Container(
      height: 64 + bottomInset,
      padding:
          EdgeInsets.fromLTRB(18, 8, 18, bottomInset > 0 ? bottomInset : 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8DED6), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < destinations.length; i++)
            Expanded(
              child: _SharedBottomNavButton(
                destination: destinations[i],
                isActive: currentIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
        ],
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
    const inactiveColor = Color(0xFF776E67);
    const activeColor = Color(0xFF8B6500);
    const disabledColor = Color(0xFFBDB5AE);
    final enabled = destination.enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : destination.onDisabledTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: const BoxDecoration(color: Colors.transparent),
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
                      width: 20,
                      height: 20,
                    )
                  else
                    Icon(
                      isActive
                          ? (destination.activeIcon ?? destination.icon)
                          : (destination.icon ?? destination.activeIcon),
                      size: 21,
                      color: !enabled
                          ? disabledColor
                          : isActive
                              ? activeColor
                              : inactiveColor,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _navFontFamily,
                      fontFamilyFallback: _navFontFallback,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: !enabled
                          ? disabledColor
                          : isActive
                              ? activeColor
                              : inactiveColor,
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
