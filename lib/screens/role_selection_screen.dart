import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/salon/add_salon_cubit.dart';
import '../repositories/salon_repository.dart';
import '../services/user_role_session.dart';
import '../utils/localization_helper.dart';
import 'UpdateProfileScreen.dart';
import 'add_salon_screen.dart';
import 'bottom_nav.dart';
import 'stylist_bottom_nav.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({
    super.key,
    required this.token,
    required this.user,
    required this.profileComplete,
  });

  final String token;
  final Map<String, dynamic> user;
  final bool profileComplete;

  static int selectableRoleCount(Map<String, dynamic> user) {
    return _visibleRoles(user['roles']).length;
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

  @override
  Widget build(BuildContext context) {
    final roles = _visibleRoles(user['roles']);
    final firstName = (user['firstName'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFAF8),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          translateText('Choose Role'),
          style: const TextStyle(
            color: Color(0xFF8B6500),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty
                    ? translateText('Continue as')
                    : '${translateText('Welcome')}, $firstName',
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1B18),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                translateText(
                  'Select how you want to use Glowante for this session.',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF6C625A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return _RoleCard(
                      role: role,
                      onTap: () => _continueWithRole(
                        context,
                        token: token,
                        user: user,
                        profileComplete: profileComplete,
                        role: role,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<_SelectableRole> _visibleRoles(dynamic rawRoles) {
    if (rawRoles is! List) return const <_SelectableRole>[];

    final roles = rawRoles
        .whereType<Map>()
        .map((role) => _SelectableRole.fromMap(Map<String, dynamic>.from(role)))
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
      if (role.id == UserRoleSession.ownerRoleId ||
          role.code == UserRoleSession.ownerRoleCode) {
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

    final salons = user['salons'];
    final hasSalon = salons is List && salons.isNotEmpty;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => hasSalon
            ? const BottomNav(tabIndex: 2)
            : BlocProvider(
                create: (context) =>
                    AddSalonCubit(context.read<SalonRepository>()),
                child: AddSalonScreen(
                  id: user['id']?.toString(),
                  phoneNumber: user['phoneNumber']?.toString(),
                  fullPhoneNumber: user['fullPhoneNumber']?.toString(),
                  firstName: user['firstName']?.toString(),
                  lastName: user['lastName']?.toString(),
                  email: user['email']?.toString(),
                  isProceedFrom: 'onboarding',
                ),
              ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.onTap,
  });

  final _SelectableRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isStaff = role.destination == _RoleDestination.staff;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6DCD2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF4E8D1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isStaff ? Icons.content_cut_rounded : Icons.storefront_rounded,
                color: const Color(0xFF8B6500),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translateText(role.label),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF201B17),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translateText(
                      isStaff
                          ? 'View assigned bookings and profile.'
                          : 'Manage salons, bookings, catalog, and profile.',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF6C625A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF8B6500),
            ),
          ],
        ),
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

  int get priorityWeight {
    if (code == UserRoleSession.ownerRoleCode ||
        id == UserRoleSession.ownerRoleId) {
      return 0;
    }
    if (code == UserRoleSession.stylistRoleCode ||
        id == UserRoleSession.stylistRoleId ||
        code == UserRoleSession.staffRoleCode ||
        id == UserRoleSession.staffRoleId ||
        code == UserRoleSession.receptionistRoleCode ||
        id == UserRoleSession.receptionistRoleId) {
      return 1;
    }
    return 2;
  }

  factory _SelectableRole.fromMap(Map<String, dynamic> map) {
    final id =
        map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}');
    final code = (map['code'] ?? '').toString().trim().toLowerCase();
    final label = (map['label'] ?? '').toString().trim();

    final isStaff = id == UserRoleSession.stylistRoleId ||
        id == UserRoleSession.staffRoleId ||
        id == UserRoleSession.receptionistRoleId ||
        code == UserRoleSession.stylistRoleCode ||
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
