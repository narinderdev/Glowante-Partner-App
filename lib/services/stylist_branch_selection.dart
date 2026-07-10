import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StylistBranchSelection {
  const StylistBranchSelection({
    this.salonId,
    this.branchId,
    this.salonName = '',
    this.branchName = '',
  });

  final int? salonId;
  final int? branchId;
  final String salonName;
  final String branchName;

  String get label {
    if (salonName.isNotEmpty &&
        branchName.isNotEmpty &&
        salonName != branchName) {
      return '$salonName • $branchName';
    }
    if (salonName.isNotEmpty) return salonName;
    if (branchName.isNotEmpty) return branchName;
    return '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StylistBranchSelection &&
        other.salonId == salonId &&
        other.branchId == branchId &&
        other.salonName == salonName &&
        other.branchName == branchName;
  }

  @override
  int get hashCode => Object.hash(salonId, branchId, salonName, branchName);
}

class StylistBranchSelectionStore {
  StylistBranchSelectionStore._();

  static final ValueNotifier<StylistBranchSelection> selectionNotifier =
      ValueNotifier(const StylistBranchSelection());

  static const String _selectedSalonIdKey = 'selected_salon_id';
  static const String _selectedBranchIdKey = 'selected_branch_id';
  static const String _selectedSalonNameKey = 'stylist_selected_salon_name';
  static const String _selectedBranchNameKey = 'stylist_selected_branch_name';

  static Future<void> save({
    required int salonId,
    required int branchId,
    required String salonName,
    required String branchName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final selection = StylistBranchSelection(
      salonId: salonId,
      branchId: branchId,
      salonName: salonName,
      branchName: branchName,
    );
    await prefs.setInt(_selectedSalonIdKey, salonId);
    await prefs.setInt(_selectedBranchIdKey, branchId);
    await prefs.setString(_selectedSalonNameKey, salonName);
    await prefs.setString(_selectedBranchNameKey, branchName);
    if (selectionNotifier.value != selection) {
      selectionNotifier.value = selection;
    }
  }

  static Future<bool> saveFromSalonCreateResponse(
    Map<String, dynamic>? response,
  ) async {
    if (response == null || response.isEmpty) return false;

    final root = _mapFrom(response['data']) ?? response;
    final salon =
        _mapFrom(root['salon']) ?? _mapFrom(root['createdSalon']) ?? root;
    final branch = _firstBranchFrom(salon) ??
        _mapFrom(root['branch']) ??
        _mapFrom(root['createdBranch']);
    final salonId = _readDynamicInt(
      salon['id'] ?? salon['salonId'] ?? root['salonId'],
    );
    final branchId = _readDynamicInt(
      branch?['id'] ??
          branch?['branchId'] ??
          root['branchId'] ??
          root['defaultBranchId'],
    );

    if (salonId == null || branchId == null) return false;

    final salonName = _readDynamicString(
      salon['name'] ?? salon['salonName'] ?? root['salonName'],
    );
    final branchName = _readDynamicString(
      branch?['name'] ?? branch?['branchName'] ?? root['branchName'],
    );

    await save(
      salonId: salonId,
      branchId: branchId,
      salonName: salonName.isEmpty ? 'Salon' : salonName,
      branchName: branchName.isEmpty
          ? (salonName.isEmpty ? 'Branch' : salonName)
          : branchName,
    );
    return true;
  }

  static Future<bool> saveFromBranchCreateResponse({
    required int salonId,
    required Map<String, dynamic>? response,
    String fallbackSalonName = '',
    String fallbackBranchName = '',
  }) async {
    if (response == null || response.isEmpty) return false;

    final root = _mapFrom(response['data']) ?? response;
    final branch =
        _mapFrom(root['branch']) ?? _mapFrom(root['createdBranch']) ?? root;
    final salon = _mapFrom(root['salon']);
    final branchId = _readDynamicInt(
      branch['id'] ?? branch['branchId'] ?? root['branchId'],
    );
    if (branchId == null) return false;

    final existing = await load();
    final existingSalonName =
        existing.salonId == salonId ? existing.salonName : '';
    final salonName = _firstNonEmpty([
      salon?['name'],
      salon?['salonName'],
      root['salonName'],
      fallbackSalonName,
      existingSalonName,
      'Salon',
    ]);
    final branchName = _firstNonEmpty([
      branch['name'],
      branch['branchName'],
      root['branchName'],
      fallbackBranchName,
      salonName,
      'Branch',
    ]);

    await save(
      salonId: salonId,
      branchId: branchId,
      salonName: salonName,
      branchName: branchName,
    );
    return true;
  }

  static Future<StylistBranchSelection> load({
    bool updateNotifier = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final selection = StylistBranchSelection(
      salonId: _readInt(prefs, _selectedSalonIdKey),
      branchId: _readInt(prefs, _selectedBranchIdKey),
      salonName: _readString(prefs, _selectedSalonNameKey),
      branchName: _readString(prefs, _selectedBranchNameKey),
    );
    if (updateNotifier && selectionNotifier.value != selection) {
      selectionNotifier.value = selection;
    }
    return selection;
  }

  static int? _readInt(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static String _readString(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic>? _firstBranchFrom(Map<String, dynamic>? salon) {
    final branches = salon?['branches'];
    if (branches is! List || branches.isEmpty) return null;
    for (final branch in branches) {
      final mapped = _mapFrom(branch);
      if (mapped != null) return mapped;
    }
    return null;
  }

  static int? _readDynamicInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value?.toString() ?? '');
  }

  static String _readDynamicString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _readDynamicString(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
