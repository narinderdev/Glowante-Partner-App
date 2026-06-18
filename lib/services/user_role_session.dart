import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserRoleSession {
  UserRoleSession._();

  static final UserRoleSession instance = UserRoleSession._();

  static const int ownerRoleId = 2;
  static const int receptionistRoleId = 4;
  static const int stylistRoleId = 5;
  static const int staffRoleId = 6;

  static const String ownerRoleCode = 'salon_owner';
  static const String receptionistRoleCode = 'salon_receptionist';
  static const String stylistRoleCode = 'salon_stylist';
  static const String staffRoleCode = 'salon_staff';

  static const String _roleIdsKey = 'user_role_ids';
  static const String _roleCodesKey = 'user_role_codes';
  static const String _roleLabelsKey = 'user_role_labels';
  static const String _primaryRoleIdKey = 'primary_role_id';
  static const String _primaryRoleCodeKey = 'primary_role_code';
  static const String _stylistSalonsJsonKey = 'stylist_user_salons_json';
  static const String _stylistUserBranchesJsonKey =
      'stylist_user_branches_json';
  static const String branchPermissionsJsonKey = 'user_branch_permissions_json';

  static bool usesStylistShellForUser(Map<String, dynamic>? user) {
    final roles = user?['roles'];
    if (roles is! List) return false;

    final ids = <int>{};
    final codes = <String>{};

    for (final role in roles) {
      if (role is! Map) continue;
      final map = Map<String, dynamic>.from(role);
      final id = _asInt(map['id']);
      final code = map['code']?.toString().trim().toLowerCase();
      if (id != null) {
        ids.add(id);
      }
      if (code != null && code.isNotEmpty) {
        codes.add(code);
      }
    }

    if (ids.contains(ownerRoleId) || codes.contains(ownerRoleCode)) {
      return false;
    }

    return ids.contains(stylistRoleId) ||
        ids.contains(staffRoleId) ||
        ids.contains(receptionistRoleId) ||
        codes.contains(stylistRoleCode) ||
        codes.contains(staffRoleCode) ||
        codes.contains(receptionistRoleCode);
  }

  Future<void> persistUserRoles(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    final roles = user?['roles'];

    if (roles is! List) {
      await prefs.remove(_roleIdsKey);
      await prefs.remove(_roleCodesKey);
      await prefs.remove(_roleLabelsKey);
      await prefs.remove(_primaryRoleIdKey);
      await prefs.remove(_primaryRoleCodeKey);
      return;
    }

    final roleIds = <String>[];
    final roleCodes = <String>[];
    final roleLabels = <String>[];

    for (final role in roles) {
      if (role is! Map) continue;
      final map = Map<String, dynamic>.from(role);
      final id = _asInt(map['id']);
      final code = map['code']?.toString().trim();
      final label = map['label']?.toString().trim();

      if (id != null) {
        roleIds.add(id.toString());
      }
      if (code != null && code.isNotEmpty) {
        roleCodes.add(code);
      }
      if (label != null && label.isNotEmpty) {
        roleLabels.add(label);
      }
    }

    final primaryRoleId = _resolvePrimaryRoleId(roleIds);
    final primaryRoleCode = _resolvePrimaryRoleCode(roleCodes, primaryRoleId);

    await prefs.setStringList(_roleIdsKey, roleIds);
    await prefs.setStringList(_roleCodesKey, roleCodes);
    await prefs.setStringList(_roleLabelsKey, roleLabels);

    if (primaryRoleId != null) {
      await prefs.setInt(_primaryRoleIdKey, primaryRoleId);
    } else {
      await prefs.remove(_primaryRoleIdKey);
    }

    if (primaryRoleCode != null && primaryRoleCode.isNotEmpty) {
      await prefs.setString(_primaryRoleCodeKey, primaryRoleCode);
    } else {
      await prefs.remove(_primaryRoleCodeKey);
    }
  }

  Future<void> persistUserSalons(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    final salons = user?['salons'];
    if (salons is! List) {
      await prefs.remove(_stylistSalonsJsonKey);
      return;
    }
    await prefs.setString(_stylistSalonsJsonKey, jsonEncode(salons));
  }

  Future<void> persistUserBranches(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    final userBranches = user?['userBranches'];
    if (userBranches is! List) {
      await prefs.remove(_stylistUserBranchesJsonKey);
      return;
    }
    await prefs.setString(
        _stylistUserBranchesJsonKey, jsonEncode(userBranches));
  }

  Future<void> persistUserPermissions(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsByBranch = <String, Set<String>>{};

    void addPermissions(dynamic branchIdValue, dynamic rawPermissions) {
      final branchId = _asInt(branchIdValue);
      if (branchId == null || rawPermissions is! List) return;
      final bucket =
          permissionsByBranch.putIfAbsent('$branchId', () => <String>{});
      for (final permission in rawPermissions) {
        final code = permission?.toString().trim();
        if (code != null && code.isNotEmpty) bucket.add(code);
      }
    }

    final salons = user?['salons'];
    if (salons is List) {
      for (final salonEntry in salons) {
        if (salonEntry is! Map) continue;
        final salon = Map<String, dynamic>.from(salonEntry);
        final branches = salon['branches'];
        if (branches is! List) continue;
        for (final branchEntry in branches) {
          if (branchEntry is! Map) continue;
          final branch = Map<String, dynamic>.from(branchEntry);
          final role = branch['role'];
          final roleMap = role is Map ? Map<String, dynamic>.from(role) : null;
          addPermissions(branch['id'] ?? branch['branchId'],
              roleMap?['permissions'] ?? branch['permissions']);
        }
      }
    }

    final userBranches = user?['userBranches'];
    if (userBranches is List) {
      for (final branchEntry in userBranches) {
        if (branchEntry is! Map) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final role = branch['role'];
        final roleMap = role is Map ? Map<String, dynamic>.from(role) : null;
        addPermissions(branch['id'] ?? branch['branchId'],
            roleMap?['permissions'] ?? branch['permissions']);
      }
    }

    if (permissionsByBranch.isEmpty) {
      await prefs.remove(branchPermissionsJsonKey);
      return;
    }

    await prefs.setString(
      branchPermissionsJsonKey,
      jsonEncode(
        permissionsByBranch.map(
          (branchId, permissions) => MapEntry(branchId, permissions.toList()),
        ),
      ),
    );
  }

  Future<bool> hasPersistedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(branchPermissionsJsonKey);
  }

  Future<Set<String>> loadPermissions({int? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(branchPermissionsJsonKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String>{};

      if (branchId != null) {
        return _permissionsFromList(decoded['$branchId']);
      }

      final allPermissions = <String>{};
      for (final value in decoded.values) {
        allPermissions.addAll(_permissionsFromList(value));
      }
      return allPermissions;
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> hasPermission(String permission, {int? branchId}) async {
    final permissions = await loadPermissions(branchId: branchId);
    return permissions.contains(permission);
  }

  Future<bool> hasAnyPermission(
    Iterable<String> permissionCodes, {
    int? branchId,
  }) async {
    final permissions = await loadPermissions(branchId: branchId);
    return permissionCodes.any(permissions.contains);
  }

  Future<List<Map<String, dynamic>>> loadUserSalons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stylistSalonsJsonKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> loadUserBranches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stylistUserBranchesJsonKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<bool> usesStylistShell() async {
    final prefs = await SharedPreferences.getInstance();
    final roleIds = prefs.getStringList(_roleIdsKey) ?? const <String>[];
    final roleCodes = prefs.getStringList(_roleCodesKey) ?? const <String>[];
    final primaryRoleId = prefs.getInt(_primaryRoleIdKey);
    final primaryRoleCode =
        prefs.getString(_primaryRoleCodeKey)?.trim().toLowerCase();

    if (primaryRoleId != null) {
      return primaryRoleId == stylistRoleId ||
          primaryRoleId == staffRoleId ||
          primaryRoleId == receptionistRoleId;
    }
    if (primaryRoleCode != null && primaryRoleCode.isNotEmpty) {
      return primaryRoleCode == stylistRoleCode ||
          primaryRoleCode == staffRoleCode ||
          primaryRoleCode == receptionistRoleCode;
    }

    return roleIds.contains('$stylistRoleId') ||
        roleIds.contains('$staffRoleId') ||
        roleIds.contains('$receptionistRoleId') ||
        roleCodes
            .map((code) => code.trim().toLowerCase())
            .contains(stylistRoleCode) ||
        roleCodes
            .map((code) => code.trim().toLowerCase())
            .contains(staffRoleCode) ||
        roleCodes
            .map((code) => code.trim().toLowerCase())
            .contains(receptionistRoleCode);
  }

  Future<void> persistPrimaryRole({
    required int? roleId,
    required String? roleCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (roleId != null) {
      await prefs.setInt(_primaryRoleIdKey, roleId);
    } else {
      await prefs.remove(_primaryRoleIdKey);
    }

    final normalizedCode = roleCode?.trim().toLowerCase();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      await prefs.setString(_primaryRoleCodeKey, normalizedCode);
    } else {
      await prefs.remove(_primaryRoleCodeKey);
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Set<String> _permissionsFromList(dynamic raw) {
    if (raw is! List) return <String>{};
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  static int? _resolvePrimaryRoleId(List<String> roleIds) {
    if (roleIds.contains('$ownerRoleId')) return ownerRoleId;
    if (roleIds.contains('$stylistRoleId')) return stylistRoleId;
    if (roleIds.contains('$staffRoleId')) return staffRoleId;
    if (roleIds.contains('$receptionistRoleId')) return receptionistRoleId;
    return roleIds.isEmpty ? null : int.tryParse(roleIds.first);
  }

  static String? _resolvePrimaryRoleCode(
    List<String> roleCodes,
    int? primaryRoleId,
  ) {
    if (primaryRoleId == stylistRoleId) return stylistRoleCode;
    if (primaryRoleId == staffRoleId) return staffRoleCode;
    if (primaryRoleId == receptionistRoleId) return receptionistRoleCode;
    if (primaryRoleId == ownerRoleId) return ownerRoleCode;
    return roleCodes.isEmpty ? null : roleCodes.first.trim().toLowerCase();
  }
}
