import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_role_session.dart';
import '../utils/localization_helper.dart';
import 'UpdateProfileScreen.dart';
import 'bottom_nav.dart';
import 'stylist_bottom_nav.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.token,
    required this.user,
    required this.profileComplete,
  });

  final String token;
  final Map<String, dynamic> user;
  final bool profileComplete;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();

  static int selectableRoleCount(Map<String, dynamic> user) {
    return _visibleRoles(user['roles']).length;
  }

  // How many distinct workspaces (Owner / Stylist) are available to switch
  // between, from the cached roles persisted at login. Used by the Profile
  // tab to decide whether to show "Change Workspace".
  static Future<int> cachedWorkspaceCount() async {
    final roleEntries = await UserRoleSession.instance.loadCachedRoleEntries();
    return _visibleRoles(roleEntries).length;
  }

  // Opens the role picker using cached session data, without re-login.
  static Future<void> openWorkspaceSwitcher(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token') ?? '';
    final roleEntries = await UserRoleSession.instance.loadCachedRoleEntries();
    final user = <String, dynamic>{
      'firstName': prefs.getString('first_name') ?? '',
      'lastName': prefs.getString('last_name') ?? '',
      'phoneNumber': prefs.getString('phone_number') ?? '',
      'roles': roleEntries,
    };

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          token: token,
          user: user,
          profileComplete: true,
        ),
      ),
      (route) => false,
    );
  }

  static Future<void> continueWithSingleRole({
    required BuildContext context,
    required String token,
    required Map<String, dynamic> user,
    required bool profileComplete,
  }) async {
    final roles = _visibleRoles(user['roles']);
    final role = _primaryRole(roles) ??
        const _SelectableRole(
          id: null,
          code: 'app_user',
          label: 'App User',
          destination: _RoleDestination.owner,
        );

    await _continueWithRole(
      context,
      token: token,
      user: user,
      profileComplete: profileComplete,
      role: role,
    );
  }

  static List<_SelectableRole> _visibleRoles(dynamic rawRoles) {
    if (rawRoles is! List) return const <_SelectableRole>[];

    // Backend has returned both role objects ({id, code, label}) and flat
    // role-code strings. Normalize both shapes before choosing workspaces.
    final roles = rawRoles
        .map((role) {
          if (role is Map) return Map<String, dynamic>.from(role);
          if (role is String && role.trim().isNotEmpty) {
            return <String, dynamic>{'code': role.trim()};
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .map(_SelectableRole.fromMap)
        .where((role) => role.label.isNotEmpty)
        .toList();

    final hasSpecificRole = roles.any((role) => role.code != 'app_user');
    if (hasSpecificRole) {
      roles.removeWhere((role) => role.code == 'app_user');
    }

    roles.sort((first, second) {
      final firstWeight = first.priorityWeight;
      final secondWeight = second.priorityWeight;
      if (firstWeight != secondWeight) {
        return firstWeight.compareTo(secondWeight);
      }
      return first.label.toLowerCase().compareTo(second.label.toLowerCase());
    });

    // The screen chooses a workspace (Owner vs Team), not a specific salon.
    final seenDestinations = <_RoleDestination>{};
    roles.retainWhere((role) => seenDestinations.add(role.destination));

    return roles.isEmpty
        ? const [
            _SelectableRole(
              id: null,
              code: 'app_user',
              label: 'App User',
              destination: _RoleDestination.owner,
            ),
          ]
        : roles;
  }

  static _SelectableRole? _primaryRole(List<_SelectableRole> roles) {
    if (roles.isEmpty) return null;
    for (final role in roles) {
      // Match by code only. Role ids are not stable/global across salon-scoped
      // roles, and app_user has been observed colliding with ownerRoleId.
      if (role.code == UserRoleSession.ownerRoleCode) {
        return role;
      }
    }
    return roles.first;
  }

  static Future<void> _continueWithRole(
    BuildContext context, {
    required String token,
    required Map<String, dynamic> user,
    required bool profileComplete,
    required _SelectableRole role,
  }) async {
    await UserRoleSession.instance.persistPrimaryRole(
      roleId: role.id,
      roleCode: role.code,
    );

    if (!context.mounted) return;

    final isStylistShell = role.destination == _RoleDestination.staff;
    if (!profileComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UpdateUserProfileScreen(
            token: token,
            isStylist: isStylistShell,
          ),
        ),
      );
      return;
    }

    if (isStylistShell) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const StylistBottomNav(tabIndex: 0),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const BottomNav(tabIndex: 2),
      ),
    );
  }
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _selectedIndex = 0;
  bool _isContinuing = false;

  @override
  Widget build(BuildContext context) {
    final roles = RoleSelectionScreen._visibleRoles(widget.user['roles']);
    if (_selectedIndex >= roles.length) _selectedIndex = 0;

    final selectedRole = roles[_selectedIndex];
    final firstName = (widget.user['firstName'] ?? '').toString().trim();
    final lastName = (widget.user['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    final phone =
        (widget.user['fullPhoneNumber'] ?? widget.user['phoneNumber'] ?? '')
            .toString()
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      body: SafeArea(
        child: Column(
          children: [
            _WorkspaceHeader(fullName: fullName, phone: phone),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (firstName.isNotEmpty) ...[
                      Text(
                        translateText('Welcome back').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B6500),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      translateText('Choose your workspace'),
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1B18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      translateText(
                        'Switch between the tools you need for this session.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF6C625A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _WorkspacePreview(role: selectedRole),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 18),
                        itemCount: roles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          return _RoleCard(
                            role: role,
                            selected: index == _selectedIndex,
                            onTap: () {
                              setState(() => _selectedIndex = index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _RoleSelectionFooter(
              role: selectedRole,
              isLoading: _isContinuing,
              onContinue: () => _continue(selectedRole),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue(_SelectableRole role) async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);

    await RoleSelectionScreen._continueWithRole(
      context,
      token: widget.token,
      user: widget.user,
      profileComplete: widget.profileComplete,
      role: role,
    );

    if (mounted) {
      setState(() => _isContinuing = false);
    }
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.fullName, required this.phone});

  final String fullName;
  final String phone;

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where(
          (part) => part.isNotEmpty,
        );
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1EBE6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4E8D1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 20,
              color: Color(0xFF8B6500),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Glowante',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8B6500),
            ),
          ),
          const Spacer(),
          if (fullName.isNotEmpty || phone.isNotEmpty) ...[
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (fullName.isNotEmpty)
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1B18),
                      ),
                    ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A9089),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E8D1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8C774)),
              ),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B6500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspacePreview extends StatelessWidget {
  const _WorkspacePreview({required this.role});

  final _SelectableRole role;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Container(
        key: ValueKey(role.code),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1B18),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFAA13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(role.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translateText(role.workspaceTitle).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8C774),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    translateText(role.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    translateText(role.summary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE7DED7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final _SelectableRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1 : 0.985,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFFFFCF9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF8B6500)
                    : const Color(0xFFE6DCD2),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0x1A8B6500)
                      : const Color(0x08000000),
                  blurRadius: selected ? 20 : 12,
                  offset: Offset(0, selected ? 10 : 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF8B6500)
                            : const Color(0xFFF4E8D1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF8B6500)
                              : const Color(0xFFE8C774),
                        ),
                      ),
                      child: Icon(
                        role.icon,
                        color:
                            selected ? Colors.white : const Color(0xFF8B6500),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translateText(role.workspaceTitle),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B6500),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translateText(role.label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF201B17),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      width: 30,
                      height: 30,
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF8B6500)
                            : const Color(0xFFFAF7F3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF8B6500)
                              : const Color(0xFFE6DCD2),
                        ),
                      ),
                      child: Icon(
                        selected
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: selected ? 18 : 16,
                        color:
                            selected ? Colors.white : const Color(0xFFB2A8A0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  translateText(role.description),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C625A),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: role.capabilityChips(selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionFooter extends StatelessWidget {
  const _RoleSelectionFooter({
    required this.role,
    required this.isLoading,
    required this.onContinue,
  });

  final _SelectableRole role;
  final bool isLoading;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1EBE6))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onContinue,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF8B6500),
              disabledBackgroundColor: const Color(0xFFD8D0C8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: ValueKey(role.code),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${translateText('Continue as')} ${translateText(role.label)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF6E1) : const Color(0xFFFAF7F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFFE8C774) : const Color(0xFFE9E1D9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: selected ? const Color(0xFF8B6500) : const Color(0xFF7B7169),
          ),
          const SizedBox(width: 5),
          Text(
            translateText(label),
            style: TextStyle(
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w800,
              color:
                  selected ? const Color(0xFF8B6500) : const Color(0xFF6C625A),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RoleDestination { owner, staff }

class _SelectableRole {
  const _SelectableRole({
    required this.id,
    required this.code,
    required this.label,
    required this.destination,
  });

  final int? id;
  final String code;
  final String label;
  final _RoleDestination destination;

  bool get isStaffWorkspace => destination == _RoleDestination.staff;

  String get workspaceTitle {
    return isStaffWorkspace ? 'Team workspace' : 'Owner workspace';
  }

  String get summary {
    return isStaffWorkspace
        ? 'Bookings, schedule, attendance, profile'
        : 'Salons, branches, catalog, reports';
  }

  String get description {
    return isStaffWorkspace
        ? 'Work with assigned bookings, team schedule, attendance, and profile details.'
        : 'Manage salons, branches, team, services, reports, and business settings.';
  }

  IconData get icon {
    return isStaffWorkspace
        ? Icons.content_cut_rounded
        : Icons.storefront_rounded;
  }

  List<_CapabilityChip> capabilityChips(bool selected) {
    if (isStaffWorkspace) {
      return [
        _CapabilityChip(
          icon: Icons.event_available_rounded,
          label: 'Bookings',
          selected: selected,
        ),
        _CapabilityChip(
          icon: Icons.badge_rounded,
          label: 'Attendance',
          selected: selected,
        ),
        _CapabilityChip(
          icon: Icons.person_rounded,
          label: 'Profile',
          selected: selected,
        ),
      ];
    }

    return [
      _CapabilityChip(
        icon: Icons.store_mall_directory_rounded,
        label: 'Salons',
        selected: selected,
      ),
      _CapabilityChip(
        icon: Icons.groups_rounded,
        label: 'Team',
        selected: selected,
      ),
      _CapabilityChip(
        icon: Icons.insights_rounded,
        label: 'Reports',
        selected: selected,
      ),
    ];
  }

  // Code only, never id. Role ids are not stable/global, so an id check risks
  // colliding with another role's real id.
  int get priorityWeight {
    if (code == UserRoleSession.ownerRoleCode) {
      return 0;
    }
    if (code == UserRoleSession.stylistRoleCode ||
        code == UserRoleSession.staffRoleCode ||
        code == UserRoleSession.receptionistRoleCode) {
      return 1;
    }
    return 2;
  }

  factory _SelectableRole.fromMap(Map<String, dynamic> map) {
    final id =
        map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}');
    final code = (map['code'] ?? '').toString().trim().toLowerCase();
    final label = (map['label'] ?? '').toString().trim();

    final isStaff = code == UserRoleSession.stylistRoleCode ||
        code == UserRoleSession.staffRoleCode ||
        code == UserRoleSession.receptionistRoleCode;

    return _SelectableRole(
      id: id,
      code: code,
      label: label.isEmpty ? code : label,
      destination: isStaff ? _RoleDestination.staff : _RoleDestination.owner,
    );
  }
}
