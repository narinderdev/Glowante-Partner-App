import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class StylistSharedFaceRecognitionResult {
  const StylistSharedFaceRecognitionResult({
    required this.isAvailable,
    required this.isMatch,
    this.similarity,
    this.distance,
    this.spoofScore,
    this.message,
  });

  final bool isAvailable;
  final bool isMatch;
  final double? similarity;
  final double? distance;
  final double? spoofScore;
  final String? message;

  factory StylistSharedFaceRecognitionResult.unavailable([String? message]) {
    return StylistSharedFaceRecognitionResult(
      isAvailable: false,
      isMatch: false,
      message: message,
    );
  }
}

class StylistSharedFaceRecognition {
  StylistSharedFaceRecognition({
    FaceDetector? detector,
  }) : _detector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                performanceMode: FaceDetectorMode.accurate,
                enableLandmarks: true,
                enableContours: false,
                enableClassification: false,
                minFaceSize: 0.15,
              ),
            );

  final FaceDetector _detector;
  Interpreter? _faceNetInterpreter;
  Interpreter? _mobileNetInterpreter;
  bool _loaded = false;

  Future<StylistSharedFaceRecognitionResult> compareFaces({
    required String enrollmentPath,
    required String attendancePath,
  }) async {
    final loaded = await _ensureLoaded();
    if (!loaded) {
      return StylistSharedFaceRecognitionResult.unavailable(
        'Shared FaceNet model is not available.',
      );
    }

    final enrollmentBitmap = await _decodeImage(enrollmentPath);
    final attendanceBitmap = await _decodeImage(attendancePath);
    if (enrollmentBitmap == null || attendanceBitmap == null) {
      return const StylistSharedFaceRecognitionResult(
        isAvailable: true,
        isMatch: false,
        message: 'Unable to read face image for verification.',
      );
    }

    final enrollmentFace = await _detectSingleFace(enrollmentPath);
    final attendanceFace = await _detectSingleFace(attendancePath);
    if (enrollmentFace == null || attendanceFace == null) {
      return const StylistSharedFaceRecognitionResult(
        isAvailable: true,
        isMatch: false,
        message:
            'Face verification failed. Please retry with the enrolled person.',
      );
    }

    final alignedEnrollment =
        _prepareAlignedFace(enrollmentBitmap, enrollmentFace);
    final alignedAttendance =
        _prepareAlignedFace(attendanceBitmap, attendanceFace);
    if (alignedEnrollment == null || alignedAttendance == null) {
      return const StylistSharedFaceRecognitionResult(
        isAvailable: true,
        isMatch: false,
        message:
            'Face verification failed. Please retry with the enrolled person.',
      );
    }

    final enrollmentEmbedding = _extractEmbedding(alignedEnrollment);
    final attendanceEmbedding = _extractEmbedding(alignedAttendance);
    if (enrollmentEmbedding == null || attendanceEmbedding == null) {
      return StylistSharedFaceRecognitionResult.unavailable(
        'Unable to generate face embeddings from the shared model.',
      );
    }

    final similarity = _cosineSimilarity(
      enrollmentEmbedding,
      attendanceEmbedding,
    );
    final distance = _euclideanDistance(
      enrollmentEmbedding,
      attendanceEmbedding,
    );
    final spoofScore = _classifySpoof(alignedAttendance);
    final isMatch = similarity >= _defaultSimilarity;

    debugPrint(
      '[StylistAttendance] shared_identity_compare | similarity=$similarity distance=$distance spoofScore=$spoofScore match=$isMatch',
    );

    return StylistSharedFaceRecognitionResult(
      isAvailable: true,
      isMatch: isMatch,
      similarity: similarity,
      distance: distance,
      spoofScore: spoofScore,
      message: isMatch
          ? 'Face detected successfully'
          : 'Face does not match the enrolled user. Please use the enrolled face.',
    );
  }

  Future<bool> _ensureLoaded() async {
    if (_loaded) {
      return _faceNetInterpreter != null;
    }
    _loaded = true;
    try {
      _faceNetInterpreter = await Interpreter.fromAsset(_faceNetAssetPath);
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] shared_face_net_load_failed | $error\n$stackTrace',
      );
    }
    try {
      _mobileNetInterpreter = await Interpreter.fromAsset(_mobileNetAssetPath);
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] shared_mobile_net_load_failed | $error\n$stackTrace',
      );
    }
    return _faceNetInterpreter != null;
  }

  Future<img.Image?> _decodeImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return img.decodeImage(bytes);
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] shared_decode_image_failed | path=$path error=$error\n$stackTrace',
      );
      return null;
    }
  }

  Future<Face?> _detectSingleFace(String path) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(path),
    );
    if (faces.length != 1) {
      return null;
    }
    return faces.first;
  }

  img.Image? _prepareAlignedFace(
    img.Image source,
    Face face,
  ) {
    final cropRect = _expandAndClampRect(
      face.boundingBox,
      source.width,
      source.height,
    );
    if (cropRect == null) {
      return null;
    }

    final cropped = img.copyCrop(
      source,
      x: cropRect.left,
      y: cropRect.top,
      width: cropRect.width,
      height: cropRect.height,
    );

    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (leftEye == null || rightEye == null) {
      return img.copyResize(
        cropped,
        width: _faceNetImageSize,
        height: _faceNetImageSize,
      );
    }

    final leftEyeX = leftEye.x - cropRect.left;
    final leftEyeY = leftEye.y - cropRect.top;
    final rightEyeX = rightEye.x - cropRect.left;
    final rightEyeY = rightEye.y - cropRect.top;
    final angleRadians = math.atan2(
      rightEyeY - leftEyeY,
      rightEyeX - leftEyeX,
    );
    final rotated = img.copyRotate(
      cropped,
      angle: -angleRadians * 180 / math.pi,
    );

    return img.copyResize(
      rotated,
      width: _faceNetImageSize,
      height: _faceNetImageSize,
    );
  }

  _CropRect? _expandAndClampRect(
    Rect source,
    int maxWidth,
    int maxHeight,
  ) {
    final extraWidth = (source.width * 0.2).round();
    final extraHeight = (source.height * 0.25).round();
    final left = math.max<int>(0, source.left.round() - extraWidth);
    final top = math.max<int>(0, source.top.round() - extraHeight);
    final right = math.min<int>(maxWidth, source.right.round() + extraWidth);
    final bottom =
        math.min<int>(maxHeight, source.bottom.round() + extraHeight);
    if (right <= left || bottom <= top) {
      return null;
    }
    return _CropRect(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }

  Float32List? _extractEmbedding(img.Image faceImage) {
    final interpreter = _faceNetInterpreter;
    if (interpreter == null) {
      return null;
    }
    final input = _imageToTensor(
      faceImage,
      _faceNetImageSize,
    );
    final output = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(_faceNetEmbeddingSize, 0),
    );
    try {
      interpreter.run(input, output);
      return Float32List.fromList(
        output.first.map((value) => value.toDouble()).toList(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] shared_extract_embedding_failed | $error\n$stackTrace',
      );
      return null;
    }
  }

  double? _classifySpoof(img.Image faceImage) {
    final interpreter = _mobileNetInterpreter;
    if (interpreter == null) {
      return null;
    }
    final input = _imageToTensor(
      img.copyResize(
        faceImage,
        width: _mobileNetImageSize,
        height: _mobileNetImageSize,
      ),
      _mobileNetImageSize,
    );
    final outputTensor = interpreter.getOutputTensor(0);
    final shape = outputTensor.shape;
    try {
      if (shape.length == 2) {
        final rows = shape[0].clamp(1, 64);
        final cols = shape[1].clamp(1, 64);
        final output = List<List<double>>.generate(
          rows,
          (_) => List<double>.filled(cols, 0),
        );
        interpreter.run(input, output);
        return output.expand((row) => row).fold<double>(
              0,
              (current, value) => math.max(current, value),
            );
      }

      final flatLength = shape.fold<int>(1, (acc, value) => acc * value);
      final output = List<double>.filled(flatLength, 0);
      interpreter.run(input, output);
      return output.fold<double>(
        0,
        (current, value) => math.max(current, value),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] shared_classify_spoof_failed | $error\n$stackTrace',
      );
      return null;
    }
  }

  List<List<List<List<double>>>> _imageToTensor(
    img.Image source,
    int size,
  ) {
    final resized = source.width == size && source.height == size
        ? source
        : img.copyResize(source, width: size, height: size);
    return <List<List<List<double>>>>[
      List<List<List<double>>>.generate(size, (y) {
        return List<List<double>>.generate(size, (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            (pixel.r - _imageMean) / _imageStd,
            (pixel.g - _imageMean) / _imageStd,
            (pixel.b - _imageMean) / _imageStd,
          ];
        });
      }),
    ];
  }

  double _cosineSimilarity(Float32List first, Float32List second) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var index = 0; index < first.length; index++) {
      final a = first[index];
      final b = second[index];
      dot += a * b;
      normA += a * a;
      normB += b * b;
    }
    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0) {
      return 0;
    }
    return dot / denominator;
  }

  double _euclideanDistance(Float32List first, Float32List second) {
    var sum = 0.0;
    for (var index = 0; index < first.length; index++) {
      final delta = first[index] - second[index];
      sum += delta * delta;
    }
    return math.sqrt(sum);
  }

  Future<void> dispose() async {
    await _detector.close();
    _faceNetInterpreter?.close();
    _mobileNetInterpreter?.close();
  }

  static const String _faceNetAssetPath = 'assets/models/face_net_512.tflite';
  static const String _mobileNetAssetPath = 'assets/models/mobile_net.tflite';
  static const int _faceNetImageSize = 160;
  static const int _faceNetEmbeddingSize = 512;
  static const int _mobileNetImageSize = 224;
  static const double _imageMean = 128.0;
  static const double _imageStd = 128.0;
  static const double _defaultSimilarity = 0.69;
}

class _CropRect {
  const _CropRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}
