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
    this.subtitle,
    this.onTap,
    this.showLeftAccent = false,
    this.children = const <ProfileSubMenuItemData>[],
  });

  final IconData icon;
  final String label;
  final String? subtitle;
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
    required this.currentThemeMode,
    required this.onThemeChanged,
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
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileSectionLabel(label: context.t('Account Settings')),
              const SizedBox(height: 12),
              _LanguageCard(
                currentLanguageCode: currentLanguageCode,
                onLanguageChanged: onLanguageChanged,
              ),
              const SizedBox(height: 12),
              _ThemeCard(
                currentThemeMode: currentThemeMode,
                onThemeChanged: onThemeChanged,
              ),
              for (final section in topSections) ...[
                const SizedBox(height: 18),
                section,
              ],
              const SizedBox(height: 14),
              for (var index = 0; index < menuItems.length; index++) ...[
                _ProfileMenuCard(item: menuItems[index]),
                if (index != menuItems.length - 1) ...[
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _ProfileSectionLabel(
                label: context.t('Account Actions'),
                color: AppColors.red,
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: Icons.logout_rounded,
                label: context.t('Logout'),
                onPressed: onLogout,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1C1917),
                borderColor: const Color(0xFFD8C7B3),
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: context.t('Delete Account'),
                onPressed: onDeleteAccount,
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  'GLOWANTE - V1.0.4 - © 2024',
                  style: _profileTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFFAAA39D),
                      letterSpacing: 2.4),
                ),
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
        toolbarHeight: kToolbarHeight,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
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
            const SizedBox(height: 6),
            Text(
              roleLabel!,
              style: _profileTextStyle(
                size: 16,
                weight: FontWeight.w500,
                color: const Color(0xFF6F665E),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProfileBadge(label: 'Premium Plan', filled: false),
                SizedBox(width: 12),
                _ProfileBadge(label: 'Verified Manager', filled: true),
              ],
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

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFD0A244) : const Color(0xFFF7F4F1),
        borderRadius: BorderRadius.circular(10),
        border: filled ? null : Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: _profileTextStyle(
          size: 11,
          weight: FontWeight.w700,
          color: filled ? const Color(0xFF4A3400) : const Color(0xFF5F574F),
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel({
    required this.label,
    this.color = const Color(0xFF8A8179),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: _profileTextStyle(
          size: 12,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 4,
        ),
      ),
    );
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
    return _ProfileSettingsTile(
      icon: Icons.language_rounded,
      title: context.t('Language Selection'),
      subtitle: currentLanguageCode == 'hi' ? 'हिंदी' : 'English / Hindi',
      onTap: () => _showLanguagePicker(context),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LanguageSheetOption(
                  label: context.t('English'),
                  selected: currentLanguageCode == 'en',
                  onTap: () {
                    Navigator.pop(context);
                    onLanguageChanged('en');
                  },
                ),
                const SizedBox(height: 10),
                _LanguageSheetOption(
                  label: 'हिंदी',
                  selected: currentLanguageCode == 'hi',
                  onTap: () {
                    Navigator.pop(context);
                    onLanguageChanged('hi');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageSheetOption extends StatelessWidget {
  const _LanguageSheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? const Color(0xFFF6EFE3) : const Color(0xFFFBF9F8),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: AppColors.starColor,
      ),
      title: Text(
        label,
        style: _profileTextStyle(
          size: 16,
          weight: FontWeight.w700,
          color: const Color(0xFF1C1917),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return _ProfileSettingsTile(
      icon: currentThemeMode == ThemeMode.dark
          ? Icons.dark_mode_rounded
          : Icons.light_mode_rounded,
      title: context.t('Theme'),
      subtitle: currentThemeMode == ThemeMode.dark ? 'Dark' : 'Light',
      onTap: () => _showThemePicker(context),
    );
  }

  void _showThemePicker(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.t('Theme'),
            style: _profileTextStyle(
              size: 18,
              weight: FontWeight.w700,
              color: const Color(0xFF1C1917),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeSheetOption(
                label: context.t('Light'),
                selected: currentThemeMode == ThemeMode.light,
                onTap: () {
                  Navigator.pop(dialogContext);
                  onThemeChanged(ThemeMode.light);
                },
              ),
              const SizedBox(height: 10),
              _ThemeSheetOption(
                label: context.t('Dark'),
                selected: currentThemeMode == ThemeMode.dark,
                onTap: () {
                  Navigator.pop(dialogContext);
                  onThemeChanged(ThemeMode.dark);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeSheetOption extends StatelessWidget {
  const _ThemeSheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? const Color(0xFFF6EFE3) : const Color(0xFFFBF9F8),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: AppColors.starColor,
      ),
      title: Text(
        label,
        style: _profileTextStyle(
          size: 16,
          weight: FontWeight.w700,
          color: const Color(0xFF1C1917),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ProfileSettingsTile extends StatelessWidget {
  const _ProfileSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0E9E2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.starColor, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _profileTextStyle(
                        size: 16,
                        weight: FontWeight.w600,
                        color: const Color(0xFF1C1917),
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: _profileTextStyle(
                          size: 14,
                          weight: FontWeight.w500,
                          color: const Color(0xFF5F574F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFB8B0A8),
                size: 28,
              ),
            ],
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

    if (hasChildren) {
      return _ProfileExpandableMenuCard(
        item: item,
        isExpanded: _isExpanded,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
      );
    }

    return _ProfileSettingsTile(
      icon: item.icon,
      title: item.label,
      subtitle: item.subtitle ?? '',
      onTap: item.onTap,
    );
  }
}

class _ProfileExpandableMenuCard extends StatelessWidget {
  const _ProfileExpandableMenuCard({
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  final ProfileMenuItemData item;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasChildren = item.children.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                          ? (isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded)
                          : Icons.chevron_right_rounded,
                      size: hasChildren ? 20 : 16,
                      color: const Color(0xFF78716C),
                    ),
                  ],
                ),
                if (hasChildren && isExpanded) ...[
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
          label,
          style: _profileTextStyle(
            size: 16,
            weight: FontWeight.w700,
            color: foregroundColor,
            letterSpacing: 0,
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
