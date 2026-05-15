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
}

class StylistBranchSelectionStore {
  StylistBranchSelectionStore._();

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
    await prefs.setInt(_selectedSalonIdKey, salonId);
    await prefs.setInt(_selectedBranchIdKey, branchId);
    await prefs.setString(_selectedSalonNameKey, salonName);
    await prefs.setString(_selectedBranchNameKey, branchName);
  }

  static Future<StylistBranchSelection> load() async {
    final prefs = await SharedPreferences.getInstance();
    final salonId = _readInt(prefs, _selectedSalonIdKey);
    final branchId = _readInt(prefs, _selectedBranchIdKey);
    return StylistBranchSelection(
      salonId: salonId,
      branchId: branchId,
      salonName: _readString(prefs, _selectedSalonNameKey),
      branchName: _readString(prefs, _selectedBranchNameKey),
    );
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
}
