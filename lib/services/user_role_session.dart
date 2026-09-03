import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../utils/api_service.dart';

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

    final codes = <String>{};

    for (final role in roles) {
      // Two shapes seen from the backend: role objects ({id, code, label})
      // and, more recently, a flat list of role-code strings. Match on
      // `code` only, never `id` — role ids are not stable/global (e.g. a
      // salon-scoped role like salon_stylist gets its own per-salon id),
      // and the generic "app_user" role has been observed with id 2, the
      // same as the hardcoded ownerRoleId constant — matching by id alone
      // would misidentify a plain app_user as the owner.
      if (role is Map) {
        final code =
            Map<String, dynamic>.from(role)['code']?.toString().trim().toLowerCase();
        if (code != null && code.isNotEmpty) codes.add(code);
      } else if (role is String) {
        final code = role.trim().toLowerCase();
        if (code.isNotEmpty) codes.add(code);
      }
    }

    if (codes.contains(ownerRoleCode)) {
      return false;
    }

    return codes.contains(stylistRoleCode) ||
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
      // Two shapes seen from the backend: role objects ({id, code, label})
      // and, more recently, a flat list of role-code strings — the latter
      // has no id/label, just the code.
      if (role is Map) {
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
      } else if (role is String) {
        final code = role.trim();
        if (code.isNotEmpty) roleCodes.add(code);
      }
    }

    // Resolve the primary role from codes alone, not ids — role ids are
    // not stable/global (a salon-scoped role like salon_stylist gets its
    // own per-salon id), and the generic "app_user" role has been
    // observed with id 2, the same as the hardcoded ownerRoleId constant.
    // Deriving primaryRoleCode from primaryRoleId (as this used to) let
    // that collision misidentify a plain app_user as the owner.
    final primaryRoleCode = _resolvePrimaryRoleCode(roleCodes);
    // Derived from the already-resolved code, not independently guessed
    // from hardcoded ids (loadPrimaryRoleLabel below looks up a label by
    // matching this id's position in roleIds/roleLabels — if this were
    // resolved from ids alone it could point at a different role
    // entirely, e.g. app_user's id 2 instead of salon_stylist's).
    final primaryRoleId =
        _resolvePrimaryRoleId(roleIds, roleCodes, primaryRoleCode);

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
        final code = _permissionCode(permission);
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
        final nestedBranch = branch['branch'];
        final nestedBranchMap =
            nestedBranch is Map ? Map<String, dynamic>.from(nestedBranch) : {};
        addPermissions(
          branch['branchId'] ??
              nestedBranchMap['id'] ??
              nestedBranchMap['branchId'] ??
              branch['id'],
          roleMap?['permissions'] ?? branch['permissions'],
        );
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

  Future<String> loadPrimaryRoleLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final roleLabels = prefs.getStringList(_roleLabelsKey) ?? const <String>[];
    final roleIds = prefs.getStringList(_roleIdsKey) ?? const <String>[];
    final roleCodes = prefs.getStringList(_roleCodesKey) ?? const <String>[];
    final primaryRoleId = prefs.getInt(_primaryRoleIdKey);
    final primaryRoleCode =
        prefs.getString(_primaryRoleCodeKey)?.trim().toLowerCase();

    if (roleLabels.isEmpty) {
      return '';
    }

    if (primaryRoleId != null) {
      final primaryIdString = primaryRoleId.toString();
      for (var index = 0; index < roleLabels.length; index++) {
        if (index < roleIds.length && roleIds[index] == primaryIdString) {
          final label = roleLabels[index].trim();
          if (label.isNotEmpty) {
            return label;
          }
        }
      }
    }

    if (primaryRoleCode != null && primaryRoleCode.isNotEmpty) {
      for (var index = 0; index < roleLabels.length; index++) {
        if (index < roleCodes.length &&
            roleCodes[index].trim().toLowerCase() == primaryRoleCode) {
          final label = roleLabels[index].trim();
          if (label.isNotEmpty) {
            return label;
          }
        }
      }
    }

    return roleLabels.first.trim();
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

  /// Fetches this user's current branch assignments (roles, services,
  /// schedule) live, per salon they belong to — via the same
  /// getTeamMemberDetailV2 endpoint the owner-side Team Member Details
  /// screen uses to refresh a member's data — instead of [loadUserBranches]
  /// below, which is only ever as fresh as the last login.
  ///
  /// Returns entries in the flat shape ({branchId, branchName, schedules,
  /// services, ...}); an empty list on any failure (offline, no salons
  /// resolved, etc.) — callers should fall back to [loadUserBranches] then.
  Future<List<Map<String, dynamic>>> fetchFreshUserBranches() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return const [];

    final salons = await loadUserSalons();
    final salonIds = <int>{};
    for (final salon in salons) {
      final id = salon['id'];
      final parsed = id is int ? id : int.tryParse('$id');
      if (parsed != null) salonIds.add(parsed);
    }

    final freshBranches = <Map<String, dynamic>>[];
    await Future.wait(salonIds.map((salonId) async {
      try {
        final response =
            await ApiService().getTeamMemberDetailV2(salonId, userId);
        if (response['success'] != true) return;
        final data = response['data'];
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);

        // branches/userBranches are siblings of `profile` at the top level
        // of `data` — not nested inside it.
        final userBranches = payload['userBranches'];
        final branches = payload['branches'];
        final raw = (userBranches is List && userBranches.isNotEmpty)
            ? userBranches
            : branches;
        if (raw is List) {
          freshBranches.addAll(
            raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
        }
      } catch (_) {
        // Leave this salon's branches out — callers fall back to cached
        // data when the overall result ends up empty.
      }
    }));

    return freshBranches;
  }

  Future<bool> usesStylistShell() async {
    final prefs = await SharedPreferences.getInstance();
    final roleCodes = prefs.getStringList(_roleCodesKey) ?? const <String>[];
    final primaryRoleCode =
        prefs.getString(_primaryRoleCodeKey)?.trim().toLowerCase();

    // Decided from codes only, never from the persisted numeric role ids
    // — those are not stable/global (a salon-scoped role like
    // salon_stylist gets its own per-salon id), and the generic
    // "app_user" role has been observed with id 2, the same as the
    // hardcoded ownerRoleId constant. Trusting primaryRoleId here used to
    // let that collision misidentify a plain app_user as the owner on
    // every app restart (persistUserRoles/_resolvePrimaryRoleCode are
    // already code-only; this just matches that here too).
    if (primaryRoleCode != null && primaryRoleCode.isNotEmpty) {
      if (primaryRoleCode == ownerRoleCode) return false;
      return primaryRoleCode == stylistRoleCode ||
          primaryRoleCode == staffRoleCode ||
          primaryRoleCode == receptionistRoleCode;
    }

    final normalizedCodes =
        roleCodes.map((code) => code.trim().toLowerCase()).toSet();
    if (normalizedCodes.contains(ownerRoleCode)) return false;
    return normalizedCodes.contains(stylistRoleCode) ||
        normalizedCodes.contains(staffRoleCode) ||
        normalizedCodes.contains(receptionistRoleCode);
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

  static String? _permissionCode(dynamic permission) {
    if (permission == null) return null;
    if (permission is String) return permission.trim();
    if (permission is Map) {
      final map = Map<String, dynamic>.from(permission);
      for (final key in const ['key', 'code', 'name']) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return permission.toString().trim();
  }

  static Set<String> _permissionsFromList(dynamic raw) {
    if (raw is! List) return <String>{};
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  // Looks up the id paired (by array position) with whichever role entry's
  // code matches primaryRoleCode — never independently matched against
  // the hardcoded owner/stylist/staff/receptionist id constants, since
  // those aren't stable/global (e.g. salon_stylist observed with id 10,
  // not the hardcoded 5) and can collide with an unrelated role's real id
  // (app_user observed with id 2, same as the hardcoded ownerRoleId).
  static int? _resolvePrimaryRoleId(
    List<String> roleIds,
    List<String> roleCodes,
    String? primaryRoleCode,
  ) {
    if (primaryRoleCode != null) {
      for (var i = 0; i < roleCodes.length && i < roleIds.length; i++) {
        if (roleCodes[i].trim().toLowerCase() == primaryRoleCode) {
          return int.tryParse(roleIds[i]);
        }
      }
      return null;
    }
    return roleIds.isEmpty ? null : int.tryParse(roleIds.first);
  }

  static String? _resolvePrimaryRoleCode(List<String> roleCodes) {
    // Resolved from codes alone, never from a numeric role id — role ids
    // are not stable/global (a salon-scoped role like salon_stylist gets
    // its own per-salon id, e.g. observed as 10 instead of the hardcoded
    // 5), and the generic "app_user" role has been observed with id 2,
    // the same as the hardcoded ownerRoleId constant. Prefer any specific
    // role over the generic "app_user" placeholder, rather than just
    // taking whichever code happened to be listed first.
    final normalized =
        roleCodes.map((code) => code.trim().toLowerCase()).toList();
    if (normalized.contains(ownerRoleCode)) return ownerRoleCode;
    if (normalized.contains(stylistRoleCode)) return stylistRoleCode;
    if (normalized.contains(staffRoleCode)) return staffRoleCode;
    if (normalized.contains(receptionistRoleCode)) return receptionistRoleCode;

    return normalized.isEmpty ? null : normalized.first;
  }
}
