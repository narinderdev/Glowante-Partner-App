import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stylist_attendance_models.dart';

class StylistAttendanceLocalStore {
  const StylistAttendanceLocalStore();

  Future<StylistAttendanceEnrollment?> loadEnrollment({
    required String userKey,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enrollmentKey(userKey, branchId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return StylistAttendanceEnrollment.fromJson(decoded);
  }

  Future<void> saveEnrollment(StylistAttendanceEnrollment enrollment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _enrollmentKey(enrollment.userKey, enrollment.branchId),
      jsonEncode(enrollment.toJson()),
    );
  }

  Future<void> clearEnrollment({
    required String userKey,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enrollmentKey(userKey, branchId));
  }

  Future<void> clearRecords({
    required String userKey,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey(userKey, branchId));
  }

  Future<List<StylistAttendanceRecord>> loadRecords({
    required String userKey,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey(userKey, branchId));
    if (raw == null || raw.isEmpty) {
      return const <StylistAttendanceRecord>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <StylistAttendanceRecord>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => StylistAttendanceRecord.fromJson(
            item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList();
  }

  Future<void> saveRecords({
    required String userKey,
    required int branchId,
    required List<StylistAttendanceRecord> records,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordsKey(userKey, branchId),
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  Future<String> persistImage({
    required File source,
    required String userKey,
    required int branchId,
    required String bucket,
    required String fileName,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final safeUserKey = userKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final separator = Platform.pathSeparator;
    final dir = Directory(
      '${root.path}$separator'
      'stylist_attendance$separator'
      '$safeUserKey$separator'
      'branch_$branchId$separator'
      '$bucket',
    );
    await dir.create(recursive: true);
    final target = File('${dir.path}$separator$fileName');
    if (await target.exists()) {
      await target.delete();
    }
    await source.copy(target.path);
    return target.path;
  }

  Future<void> clearStoredFiles({
    required String userKey,
    required int branchId,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final safeUserKey = userKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final separator = Platform.pathSeparator;
    final dir = Directory(
      '${root.path}$separator'
      'stylist_attendance$separator'
      '$safeUserKey$separator'
      'branch_$branchId',
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String _enrollmentKey(String userKey, int branchId) =>
      'stylist_attendance_enrollment::$userKey::$branchId';

  String _recordsKey(String userKey, int branchId) =>
      'stylist_attendance_records::$userKey::$branchId';
}
