import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../utils/api_service.dart';
import 'stylist_attendance_local_store.dart';
import 'stylist_attendance_models.dart';
import 'stylist_face_detection_validator.dart';
import 'stylist_shared_face_recognition.dart';

class StylistFaceAttendanceService {
  StylistFaceAttendanceService({
    StylistAttendanceLocalStore? store,
    StylistFaceDetectionValidator? validator,
    StylistSharedFaceRecognition? sharedRecognition,
    ApiService? apiService,
  })  : _store = store ?? const StylistAttendanceLocalStore(),
        _validator = validator ?? StylistFaceDetectionValidator(),
        _sharedRecognition =
            sharedRecognition ?? StylistSharedFaceRecognition(),
        _apiService = apiService ?? ApiService();

  final StylistAttendanceLocalStore _store;
  final StylistFaceDetectionValidator _validator;
  final StylistSharedFaceRecognition _sharedRecognition;
  final ApiService _apiService;

  Future<StylistAttendanceEnrollment?> loadEnrollment({
    required String userKey,
    required int branchId,
  }) {
    return _store.loadEnrollment(userKey: userKey, branchId: branchId);
  }

  Future<List<StylistAttendanceRecord>> loadRecords({
    required String userKey,
    required int branchId,
  }) {
    return _store.loadRecords(userKey: userKey, branchId: branchId);
  }

  Future<StylistAttendanceEnrollment> saveEnrollmentPose({
    required String userKey,
    required int branchId,
    required StylistAttendancePose pose,
    required File capturedFile,
  }) async {
    debugPrint(
      '[StylistAttendance] save_enrollment_pose_start | branchId=$branchId userKey=$userKey pose=${pose.id}',
    );
    final validation = await _validator.validateEnrollmentImage(
      imageFile: capturedFile,
      pose: pose,
    );
    if (!validation.isValid) {
      throw StateError(validation.message);
    }

    final imagePath = await _store.persistImage(
      source: capturedFile,
      userKey: userKey,
      branchId: branchId,
      bucket: 'enrollment',
      fileName: '${pose.id}.jpg',
    );

    final current = await _store.loadEnrollment(
          userKey: userKey,
          branchId: branchId,
        ) ??
        StylistAttendanceEnrollment(
          userKey: userKey,
          branchId: branchId,
          imagePaths: <String, String>{},
          updatedAtIso: DateTime.now().toIso8601String(),
        );

    final nextPaths = Map<String, String>.from(current.imagePaths)
      ..[pose.id] = imagePath;
    final nowIso = DateTime.now().toIso8601String();
    final enrollment = current.copyWith(
      imagePaths: nextPaths,
      updatedAtIso: nowIso,
      completedAtIso: nextPaths.length == kStylistAttendanceRequiredPoses.length
          ? nowIso
          : current.completedAtIso,
    );
    await _store.saveEnrollment(enrollment);
    debugPrint(
      '[StylistAttendance] save_enrollment_pose_success | branchId=$branchId userKey=$userKey pose=${pose.id} count=${enrollment.completedCount}',
    );
    return enrollment;
  }

  Future<StylistAttendanceRecord> markAttendanceFromCapture({
    required String userKey,
    required int userId,
    required int branchId,
    required File capturedFile,
    required StylistAttendanceAction action,
    required List<StylistAttendanceRecord> existingRecords,
  }) async {
    debugPrint(
      '[StylistAttendance] mark_attendance_from_capture_start | branchId=$branchId userKey=$userKey action=${action.id}',
    );
    final validation = await _validator.validateAttendanceScan(
      imageFile: capturedFile,
    );
    if (!validation.isValid) {
      throw StateError(validation.message);
    }
    final enrollment = await _store.loadEnrollment(
      userKey: userKey,
      branchId: branchId,
    );
    final frontPath = enrollment?.imagePaths['front'];
    if (frontPath == null || frontPath.isEmpty) {
      throw StateError(
          'Front face setup is missing. Please complete setup again.');
    }
    final frontFile = File(frontPath);
    if (!await frontFile.exists()) {
      throw StateError(
          'Front face setup is missing. Please complete setup again.');
    }
    final identityValidation = await _validateIdentity(
      enrollmentFrontImageFile: frontFile,
      attendanceImageFile: capturedFile,
    );
    if (!identityValidation.isValid) {
      throw StateError(identityValidation.message);
    }

    final now = DateTime.now();
    if (_hasActionForDay(existingRecords, action.id, now)) {
      throw StateError(
        action == StylistAttendanceAction.checkIn
            ? 'Check-in is already marked for today.'
            : 'Check-out is already marked for today.',
      );
    }
    if (action == StylistAttendanceAction.checkOut &&
        !_hasActionForDay(
            existingRecords, StylistAttendanceAction.checkIn.id, now)) {
      throw StateError('Check-in must be marked before check-out.');
    }

    final remoteResponse = await _apiService.markTeamAttendance(
      branchId: branchId,
      userId: userId,
      action: action.apiValue,
    );
    if (remoteResponse['success'] == false) {
      throw StateError(_resolveRemoteAttendanceError(remoteResponse));
    }
    final remoteData = _extractRemoteAttendanceData(remoteResponse);

    final imagePath = await _store.persistImage(
      source: capturedFile,
      userKey: userKey,
      branchId: branchId,
      bucket: 'scans',
      fileName: '${action.id}_${now.millisecondsSinceEpoch}.jpg',
    );

    final record = StylistAttendanceRecord(
      id: _resolveRemoteRecordId(remoteData, action, now),
      branchId: branchId,
      userKey: userKey,
      scanImagePath: imagePath,
      markedAtIso: _resolveRemoteMarkedAtIso(remoteData, action, now),
      status: _resolveRemoteStatus(remoteData),
      attendanceType: action.id,
    );
    final nextRecords = <StylistAttendanceRecord>[record, ...existingRecords];
    await _store.saveRecords(
      userKey: userKey,
      branchId: branchId,
      records: nextRecords,
    );
    debugPrint(
      '[StylistAttendance] mark_attendance_from_capture_success | branchId=$branchId userKey=$userKey action=${action.id} recordId=${record.id}',
    );
    return record;
  }

  Future<void> resetEnrollment({
    required String userKey,
    required int branchId,
  }) async {
    debugPrint(
      '[StylistAttendance] reset_enrollment | branchId=$branchId userKey=$userKey',
    );
    await _store.clearEnrollment(userKey: userKey, branchId: branchId);
    await _store.clearRecords(userKey: userKey, branchId: branchId);
    await _store.clearStoredFiles(userKey: userKey, branchId: branchId);
  }

  bool hasActionForToday(
    List<StylistAttendanceRecord> records,
    StylistAttendanceAction action,
  ) {
    return _hasActionForDay(records, action.id, DateTime.now());
  }

  bool _hasActionForDay(
    List<StylistAttendanceRecord> records,
    String actionId,
    DateTime day,
  ) {
    return records.any((record) {
      if (record.attendanceType != actionId) {
        return false;
      }
      final markedAt = record.markedAt;
      return markedAt != null && _sameDate(markedAt, day);
    });
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<StylistAttendanceHistoryEntry>> loadAttendanceHistory({
    required int branchId,
    required int userId,
    required int month,
    required int year,
  }) async {
    final response = await _apiService.getTeamAttendanceHistory(
      branchId: branchId,
      userId: userId,
      month: month,
      year: year,
    );
    if (response['success'] == false) {
      throw StateError(_resolveRemoteAttendanceError(response));
    }

    final rawData = _extractRemoteHistoryList(response['data']);
    if (rawData == null) {
      return const <StylistAttendanceHistoryEntry>[];
    }

    final history = rawData
        .whereType<Map>()
        .map(
          (item) => StylistAttendanceHistoryEntry.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();

    history.sort((first, second) {
      final firstTime = first.checkedInAt ?? first.checkedOutAt;
      final secondTime = second.checkedInAt ?? second.checkedOutAt;
      if (firstTime == null && secondTime == null) {
        return second.id.compareTo(first.id);
      }
      if (firstTime == null) {
        return 1;
      }
      if (secondTime == null) {
        return -1;
      }
      return secondTime.compareTo(firstTime);
    });

    return history;
  }

  List<dynamic>? _extractRemoteHistoryList(Object? rawData) {
    if (rawData is List) {
      return rawData;
    }
    if (rawData is Map<String, dynamic>) {
      for (final key in <String>[
        'attendance',
        'history',
        'records',
        'items',
        'data',
      ]) {
        final value = rawData[key];
        if (value is List) {
          return value;
        }
      }
    }
    if (rawData is Map) {
      return _extractRemoteHistoryList(
        rawData.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  Map<String, dynamic> _extractRemoteAttendanceData(
    Map<String, dynamic> response,
  ) {
    final rawData = response['data'];
    if (rawData is Map<String, dynamic>) {
      final rawAttendance = rawData['attendance'];
      if (rawAttendance is Map<String, dynamic>) {
        return rawAttendance;
      }
      if (rawAttendance is Map) {
        return rawAttendance.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return rawData;
    }
    if (rawData is Map) {
      return rawData.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return const <String, dynamic>{};
  }

  String _resolveRemoteAttendanceError(Map<String, dynamic> response) {
    final message = response['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Unable to mark attendance right now. Please try again.';
  }

  String _resolveRemoteRecordId(
    Map<String, dynamic> remoteData,
    StylistAttendanceAction action,
    DateTime fallback,
  ) {
    for (final key in <String>[
      'attendanceId',
      'recordId',
      'id',
      'checkInId',
      'checkOutId',
    ]) {
      final value = remoteData[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return 'attendance_${action.id}_${fallback.millisecondsSinceEpoch}';
  }

  String _resolveRemoteMarkedAtIso(
    Map<String, dynamic> remoteData,
    StylistAttendanceAction action,
    DateTime fallback,
  ) {
    final candidateKeys = <String>[
      if (action == StylistAttendanceAction.checkIn) ...<String>[
        'checkInAt',
        'checkedInAt',
      ] else ...<String>[
        'checkOutAt',
        'checkedOutAt',
      ],
      'markedAt',
      'attendanceAt',
      'createdAt',
      'updatedAt',
      'timestamp',
      'time',
    ];
    for (final key in candidateKeys) {
      final rawValue = remoteData[key]?.toString().trim();
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }
      final parsed = DateTime.tryParse(rawValue);
      if (parsed != null) {
        return parsed.toIso8601String();
      }
    }
    return fallback.toIso8601String();
  }

  String _resolveRemoteStatus(Map<String, dynamic> remoteData) {
    final status = remoteData['status']?.toString().trim();
    if (status != null && status.isNotEmpty) {
      return status;
    }
    return 'Marked';
  }

  Future<StylistFaceValidationResult> validateEnrollmentCapture({
    required File imageFile,
    required StylistAttendancePose pose,
  }) {
    return _validator.validateEnrollmentImage(imageFile: imageFile, pose: pose);
  }

  Future<StylistFaceValidationResult> validateAttendanceCapture({
    required File imageFile,
  }) {
    return _validator.validateAttendanceScan(imageFile: imageFile);
  }

  Future<StylistFaceValidationResult> validateAttendanceCaptureForUser({
    required String userKey,
    required int branchId,
    required File imageFile,
  }) async {
    final validation = await _validator.validateAttendanceScan(
      imageFile: imageFile,
    );
    if (!validation.isValid) {
      return validation;
    }
    final enrollment = await _store.loadEnrollment(
      userKey: userKey,
      branchId: branchId,
    );
    final frontPath = enrollment?.imagePaths['front'];
    if (frontPath == null || frontPath.isEmpty) {
      return StylistFaceValidationResult(
        isValid: false,
        message: 'Front face setup is missing. Please complete setup again.',
      );
    }
    final frontFile = File(frontPath);
    if (!await frontFile.exists()) {
      return StylistFaceValidationResult(
        isValid: false,
        message: 'Front face setup is missing. Please complete setup again.',
      );
    }
    return _validateIdentity(
      enrollmentFrontImageFile: frontFile,
      attendanceImageFile: imageFile,
    );
  }

  Future<StylistFaceValidationResult> _validateIdentity({
    required File enrollmentFrontImageFile,
    required File attendanceImageFile,
  }) async {
    final sharedResult = await _sharedRecognition.compareFaces(
      enrollmentPath: enrollmentFrontImageFile.path,
      attendancePath: attendanceImageFile.path,
    );
    if (sharedResult.isAvailable) {
      debugPrint(
        '[StylistAttendance] shared_identity_compare_result | similarity=${sharedResult.similarity} distance=${sharedResult.distance} spoofScore=${sharedResult.spoofScore} match=${sharedResult.isMatch}',
      );
      return StylistFaceValidationResult(
        isValid: sharedResult.isMatch,
        message: sharedResult.message ??
            (sharedResult.isMatch
                ? 'Face detected successfully'
                : 'Face does not match the enrolled user. Please use the enrolled face.'),
      );
    }

    debugPrint(
      '[StylistAttendance] shared_identity_compare_unavailable | falling_back_to_geometry message=${sharedResult.message}',
    );
    return _validator.validateAttendanceIdentity(
      enrollmentFrontImageFile: enrollmentFrontImageFile,
      attendanceImageFile: attendanceImageFile,
    );
  }

  Future<void> dispose() {
    return Future.wait<void>([
      _validator.dispose(),
      _sharedRecognition.dispose(),
    ]);
  }
}
