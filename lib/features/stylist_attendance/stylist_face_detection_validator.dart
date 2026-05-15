import 'dart:io';
import 'dart:math';

import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'stylist_attendance_models.dart';

class StylistFaceValidationResult {
  const StylistFaceValidationResult({
    required this.isValid,
    required this.message,
    this.faceCount = 0,
    this.rotX,
    this.rotY,
    this.rotZ,
  });

  final bool isValid;
  final String message;
  final int faceCount;
  final double? rotX;
  final double? rotY;
  final double? rotZ;
}

class _FaceSignature {
  const _FaceSignature(this.values);

  final List<double> values;
}

class StylistFaceDetectionValidator {
  StylistFaceDetectionValidator()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableContours: true,
            enableLandmarks: true,
            enableClassification: false,
            minFaceSize: 0.15,
          ),
        );

  final FaceDetector _detector;

  Future<StylistFaceValidationResult> validateEnrollmentImage({
    required File imageFile,
    required StylistAttendancePose pose,
  }) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(imageFile.path),
    );
    if (faces.isEmpty) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText('No face detected. Please try again.'),
      );
    }
    if (faces.length > 1) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Multiple faces detected. Only one face should be visible.',
        ),
        faceCount: faces.length,
      );
    }

    final face = faces.first;
    final rotX = face.headEulerAngleX;
    final rotY = face.headEulerAngleY;
    final rotZ = face.headEulerAngleZ;
    debugPrint(
      '[StylistAttendance] validate_enrollment_face | pose=${pose.id} rotX=$rotX rotY=$rotY rotZ=$rotZ',
    );

    if (!_matchesPose(pose.id, rotX: rotX, rotY: rotY, rotZ: rotZ)) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Face angle does not match {pose}. Please follow the pose guide.',
          params: <String, String>{'pose': translateText(pose.label)},
        ),
        faceCount: 1,
        rotX: rotX,
        rotY: rotY,
        rotZ: rotZ,
      );
    }

    return StylistFaceValidationResult(
      isValid: true,
      message: translateText('Face detected successfully'),
      faceCount: 1,
      rotX: rotX,
      rotY: rotY,
      rotZ: rotZ,
    );
  }

  Future<StylistFaceValidationResult> validateAttendanceScan({
    required File imageFile,
  }) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(imageFile.path),
    );
    if (faces.isEmpty) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText('No face detected. Please try again.'),
      );
    }
    if (faces.length > 1) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Multiple faces detected. Only one face should be visible.',
        ),
        faceCount: faces.length,
      );
    }

    final face = faces.first;
    final rotX = face.headEulerAngleX;
    final rotY = face.headEulerAngleY;
    final rotZ = face.headEulerAngleZ;
    final isFrontLike = (rotY?.abs() ?? 0) <= 20 &&
        (rotX?.abs() ?? 0) <= 20 &&
        (rotZ?.abs() ?? 0) <= 18;
    if (!isFrontLike) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Capture a clearer front-facing scan to mark attendance.',
        ),
        faceCount: 1,
        rotX: rotX,
        rotY: rotY,
        rotZ: rotZ,
      );
    }

    return StylistFaceValidationResult(
      isValid: true,
      message: translateText('Face detected successfully'),
      faceCount: 1,
      rotX: rotX,
      rotY: rotY,
      rotZ: rotZ,
    );
  }

  Future<StylistFaceValidationResult> validateAttendanceIdentity({
    required File enrollmentFrontImageFile,
    required File attendanceImageFile,
  }) async {
    final enrollmentFaces = await _detector.processImage(
      InputImage.fromFilePath(enrollmentFrontImageFile.path),
    );
    final attendanceFaces = await _detector.processImage(
      InputImage.fromFilePath(attendanceImageFile.path),
    );
    if (enrollmentFaces.length != 1 || attendanceFaces.length != 1) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Face verification failed. Please retry with the enrolled person.',
        ),
      );
    }

    final enrollmentSignature = _extractSignature(enrollmentFaces.first);
    final attendanceSignature = _extractSignature(attendanceFaces.first);
    if (enrollmentSignature == null || attendanceSignature == null) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Face verification failed. Please retry with the enrolled person.',
        ),
      );
    }

    final distance = _signatureDistance(
      enrollmentSignature.values,
      attendanceSignature.values,
    );
    debugPrint(
      '[StylistAttendance] validate_attendance_identity | distance=$distance',
    );
    if (distance > 0.085) {
      return StylistFaceValidationResult(
        isValid: false,
        message: translateText(
          'Face does not match the enrolled user. Please use the enrolled face.',
        ),
      );
    }

    return StylistFaceValidationResult(
      isValid: true,
      message: translateText('Face detected successfully'),
    );
  }

  bool _matchesPose(
    String poseId, {
    double? rotX,
    double? rotY,
    double? rotZ,
  }) {
    final x = rotX ?? 0;
    final y = rotY ?? 0;
    final z = rotZ ?? 0;
    switch (poseId) {
      case 'front':
        return y.abs() <= 18 && x.abs() <= 18 && z.abs() <= 15;
      case 'left':
        return y <= -12 && z.abs() <= 20 && x.abs() <= 22;
      case 'right':
        return y >= 12 && z.abs() <= 20 && x.abs() <= 22;
      case 'up':
        return x >= 8 && y.abs() <= 18;
      case 'down':
        return x <= -8 && y.abs() <= 18;
      default:
        return true;
    }
  }

  _FaceSignature? _extractSignature(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    final points = [
      leftEye,
      rightEye,
      nose,
      leftMouth,
      rightMouth,
      bottomMouth,
      leftCheek,
      rightCheek,
    ];
    if (points.any((point) => point == null)) {
      return null;
    }

    final box = face.boundingBox;
    final width = box.width <= 0 ? 1.0 : box.width;
    final height = box.height <= 0 ? 1.0 : box.height;
    final centerX = box.left + width / 2;
    final centerY = box.top + height / 2;

    double normalizedX(Point<int> point) => (point.x - centerX) / width;
    double normalizedY(Point<int> point) => (point.y - centerY) / height;
    double distance(Point<int> a, Point<int> b) {
      final dx = (a.x - b.x).toDouble();
      final dy = (a.y - b.y).toDouble();
      return sqrt(dx * dx + dy * dy);
    }

    final eyeDistance = distance(leftEye!, rightEye!);
    if (eyeDistance == 0) {
      return null;
    }

    final values = <double>[
      normalizedX(leftEye),
      normalizedY(leftEye),
      normalizedX(rightEye),
      normalizedY(rightEye),
      normalizedX(nose!),
      normalizedY(nose),
      normalizedX(leftMouth!),
      normalizedY(leftMouth),
      normalizedX(rightMouth!),
      normalizedY(rightMouth),
      normalizedX(bottomMouth!),
      normalizedY(bottomMouth),
      distance(leftEye, nose) / eyeDistance,
      distance(rightEye, nose) / eyeDistance,
      distance(leftMouth, rightMouth) / eyeDistance,
      distance(nose, bottomMouth) / eyeDistance,
      distance(leftCheek!, rightCheek!) / eyeDistance,
      ((face.headEulerAngleX ?? 0) / 45).clamp(-1.0, 1.0),
      ((face.headEulerAngleY ?? 0) / 45).clamp(-1.0, 1.0),
      ((face.headEulerAngleZ ?? 0) / 45).clamp(-1.0, 1.0),
    ];
    values.addAll(
      _sampleContour(
        face.contours[FaceContourType.leftEye]?.points,
        width,
        height,
        centerX,
        centerY,
      ),
    );
    values.addAll(
      _sampleContour(
        face.contours[FaceContourType.rightEye]?.points,
        width,
        height,
        centerX,
        centerY,
      ),
    );
    values.addAll(
      _sampleContour(
        face.contours[FaceContourType.noseBridge]?.points,
        width,
        height,
        centerX,
        centerY,
      ),
    );
    return _FaceSignature(values);
  }

  List<double> _sampleContour(
    List<Point<int>>? points,
    double width,
    double height,
    double centerX,
    double centerY,
  ) {
    if (points == null || points.isEmpty) {
      return const <double>[];
    }
    final sampleIndexes = <int>{
      0,
      points.length ~/ 4,
      points.length ~/ 2,
      (points.length * 3) ~/ 4,
      points.length - 1,
    }.toList()
      ..sort();
    final values = <double>[];
    for (final index in sampleIndexes) {
      final point = points[index];
      values.add((point.x - centerX) / width);
      values.add((point.y - centerY) / height);
    }
    return values;
  }

  double _signatureDistance(List<double> a, List<double> b) {
    if (a.length != b.length) {
      return double.infinity;
    }
    var sum = 0.0;
    for (var index = 0; index < a.length; index++) {
      final delta = a[index] - b[index];
      sum += delta * delta;
    }
    return sqrt(sum / a.length);
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}
