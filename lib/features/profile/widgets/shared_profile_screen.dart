import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/colors.dart';

const String _profileFontFamily = 'Manrope';
const List<String> _profileFontFallback = ['Inter', 'sans-serif'];

TextStyle _profileTextStyle({
  required double size,
  required FontWeight weight,
  required Color color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _profileFontFamily,
    fontFamilyFallback: _profileFontFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class ProfileMenuItemData {
  const ProfileMenuItemData({
    required this.icon,
    required this.label,
    this.onTap,
    this.showLeftAccent = false,
    this.children = const <ProfileSubMenuItemData>[],
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showLeftAccent;
  final List<ProfileSubMenuItemData> children;
}

class ProfileSubMenuItemData {
  const ProfileSubMenuItemData({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

class SharedProfileScreen extends StatelessWidget {
  const SharedProfileScreen({
    super.key,
    required this.userName,
    required this.phoneNumber,
    required this.currentLanguageCode,
    required this.onLanguageChanged,
    required this.menuItems,
    required this.onLogout,
    required this.onDeleteAccount,
    this.onRefresh,
    this.roleLabel,
    this.topSections = const <Widget>[],
  });

  final String userName;
  final String phoneNumber;
  final String currentLanguageCode;
  final ValueChanged<String> onLanguageChanged;
  final List<ProfileMenuItemData> menuItems;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final Future<void> Function()? onRefresh;
  final String? roleLabel;
  final List<Widget> topSections;

  @override
  Widget build(BuildContext context) {
    final listView = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _ProfileHero(
          userName: userName,
          phoneNumber: phoneNumber,
          roleLabel: roleLabel,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            children: [
              _LanguageCard(
                currentLanguageCode: currentLanguageCode,
                onLanguageChanged: onLanguageChanged,
              ),
              for (final section in topSections) ...[
                const SizedBox(height: 18),
                section,
              ],
              const SizedBox(height: 18),
              for (final item in menuItems) ...[
                _ProfileMenuCard(item: item),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.logout_rounded,
                label: context.t('Logout'),
                onPressed: onLogout,
                backgroundColor: const Color(0xFF231E1A),
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: context.t('Delete Account'),
                onPressed: onDeleteAccount,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE34B3F),
                borderColor: const Color(0xFFE34B3F),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          context.t('Profile'),
          style: _profileTextStyle(
            size: 18,
            weight: FontWeight.w700,
            color: const Color(0xFFB45309),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFF1EBE6),
          ),
        ),
      ),
      body: onRefresh == null
          ? listView
          : RefreshIndicator(
              color: AppColors.starColor,
              onRefresh: onRefresh!,
              child: listView,
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.userName,
    required this.phoneNumber,
    this.roleLabel,
  });

  final String userName;
  final String phoneNumber;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final displayName =
        userName.trim().isEmpty ? context.t('Profile') : userName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          _ProfileAvatar(name: displayName),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: _profileTextStyle(
              size: 24,
              weight: FontWeight.w700,
              color: const Color(0xFF1C1917),
            ),
          ),
          if (phoneNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              phoneNumber,
              style: _profileTextStyle(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF78716C),
              ),
            ),
          ],
          if (roleLabel != null && roleLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3F3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                roleLabel!,
                style: _profileTextStyle(
                  size: 12,
                  weight: FontWeight.w600,
                  color: const Color(0xFF78716C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(name);

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC19A6B),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF334155), Color(0xFF0F172A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: _profileTextStyle(
                  size: 32,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 8,
            child: IgnorePointer(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFC19A6B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFromName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'P';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.currentLanguageCode,
    required this.onLanguageChanged,
  });

  final String currentLanguageCode;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 14,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Text(
                context.t('Choose Language').toUpperCase(),
                style: _profileTextStyle(
                  size: 12,
                  weight: FontWeight.w700,
                  color: const Color(0xFF78716C),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LanguageOptionButton(
                    label: context.t('English'),
                    isSelected: currentLanguageCode == 'en',
                    onTap: () => onLanguageChanged('en'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LanguageOptionButton(
                    label: 'हिंदी',
                    isSelected: currentLanguageCode == 'hi',
                    onTap: () => onLanguageChanged('hi'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOptionButton extends StatelessWidget {
  const _LanguageOptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _profileTextStyle(
              size: 14,
              weight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFFB45309)
                  : const Color(0xFF78716C),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatefulWidget {
  const _ProfileMenuCard({required this.item});

  final ProfileMenuItemData item;

  @override
  State<_ProfileMenuCard> createState() => _ProfileMenuCardState();
}

class _ProfileMenuCardState extends State<_ProfileMenuCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasChildren = item.children.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasChildren
            ? () => setState(() => _isExpanded = !_isExpanded)
            : item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: item.showLeftAccent
                ? const Border(
                    left: BorderSide(
                      color: Color(0xFFC19A6B),
                      width: 4,
                    ),
                  )
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: const Color(0xFF78716C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        style: _profileTextStyle(
                          size: 16,
                          weight: FontWeight.w600,
                          color: const Color(0xFF1C1917),
                        ),
                      ),
                    ),
                    Icon(
                      hasChildren
                          ? (_isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded)
                          : Icons.chevron_right_rounded,
                      size: hasChildren ? 20 : 16,
                      color: const Color(0xFF78716C),
                    ),
                  ],
                ),
                if (hasChildren && _isExpanded) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 46),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.children
                          .map(
                            (child) => _ProfileSubMenuItem(item: child),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSubMenuItem extends StatelessWidget {
  const _ProfileSubMenuItem({required this.item});

  final ProfileSubMenuItemData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Text(
          item.label,
          style: _profileTextStyle(
            size: 14,
            weight: FontWeight.w500,
            color: const Color(0xFF5F574F),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          borderColor == null ? label : label.toUpperCase(),
          style: _profileTextStyle(
            size: borderColor == null ? 18 : 14,
            weight: FontWeight.w700,
            color: foregroundColor,
            letterSpacing: borderColor == null ? 0 : 0.6,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!, width: 2),
          ),
        ),
      ),
    );
  }
}
