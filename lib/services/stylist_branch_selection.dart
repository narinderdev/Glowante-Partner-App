import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/address_formatter.dart';

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

class OwnerBranchOption {
  const OwnerBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get label {
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (salonName.trim().isNotEmpty) return salonName.trim();
    return 'Branch #$branchId';
  }

  String get subtitle {
    if (address.trim().isNotEmpty) return address.trim();
    return branchName.trim();
  }

  String get displayLabel => label;

  StylistBranchSelection get selection => StylistBranchSelection(
        salonId: salonId,
        branchId: branchId,
        salonName: salonName,
        branchName: branchName,
      );

  Future<void> saveSelection() {
    return StylistBranchSelectionStore.save(
      salonId: salonId,
      branchId: branchId,
      salonName: salonName,
      branchName: branchName,
    );
  }

  static List<OwnerBranchOption> listFromSalonList(List<dynamic> rawSalons) {
    final options = <OwnerBranchOption>[];
    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) continue;
      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _readInt(salon['id'] ?? salon['salonId']);
      if (salonId == null) continue;
      final salonName = _readString(salon['name'] ?? salon['salonName']);
      final branches = (salon['branches'] as List?) ?? const <dynamic>[];
      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _readInt(branch['id'] ?? branch['branchId']);
        if (branchId == null) continue;
        options.add(
          OwnerBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _readString(branch['name'] ?? branch['branchName']),
            address: formatAddressSummary(branch['address']),
          ),
        );
      }
    }
    return options;
  }

  static OwnerBranchOption? findByBranchId(
    List<OwnerBranchOption> options,
    int? branchId,
  ) {
    if (branchId == null) return null;
    for (final option in options) {
      if (option.branchId == branchId) return option;
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OwnerBranchOption &&
        other.salonId == salonId &&
        other.branchId == branchId &&
        other.salonName == salonName &&
        other.branchName == branchName &&
        other.address == address;
  }

  @override
  int get hashCode => Object.hash(
        salonId,
        branchId,
        salonName,
        branchName,
        address,
      );
}

class StylistBranchSelectionStore {
  StylistBranchSelectionStore._();

  static final ValueNotifier<StylistBranchSelection> selectionNotifier =
      ValueNotifier(const StylistBranchSelection());
  static final ValueNotifier<int> salonCatalogRevision = ValueNotifier(0);

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

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedSalonIdKey);
    await prefs.remove(_selectedBranchIdKey);
    await prefs.remove(_selectedSalonNameKey);
    await prefs.remove(_selectedBranchNameKey);
    const selection = StylistBranchSelection();
    if (selectionNotifier.value != selection) {
      selectionNotifier.value = selection;
    }
  }

  static Future<bool> clearIfMatches({
    int? salonId,
    int? branchId,
  }) async {
    final selection = await load();
    final matchesSalon = salonId != null && selection.salonId == salonId;
    final matchesBranch = branchId != null && selection.branchId == branchId;
    if (!matchesSalon && !matchesBranch) return false;
    await clear();
    return true;
  }

  static void notifySalonCatalogChanged() {
    salonCatalogRevision.value = salonCatalogRevision.value + 1;
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
