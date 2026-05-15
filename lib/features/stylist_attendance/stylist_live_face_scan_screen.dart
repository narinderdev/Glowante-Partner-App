import 'dart:io';

import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_detection_validator.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class StylistLiveFaceScanRequest {
  const StylistLiveFaceScanRequest.enrollment({
    required this.pose,
  })  : poses = null,
        action = null,
        userKey = null,
        branchId = null;

  const StylistLiveFaceScanRequest.enrollmentSequence({
    required this.poses,
  })  : pose = null,
        action = null,
        userKey = null,
        branchId = null;

  const StylistLiveFaceScanRequest.attendance({
    required this.action,
    required this.userKey,
    required this.branchId,
  })  : pose = null,
        poses = null;

  final StylistAttendancePose? pose;
  final List<StylistAttendancePose>? poses;
  final StylistAttendanceAction? action;
  final String? userKey;
  final int? branchId;

  bool get isEnrollment => pose != null;
  bool get isEnrollmentSequence => poses != null;
}

class StylistLiveFaceScanResult {
  const StylistLiveFaceScanResult({
    this.capturedFile,
    this.capturedFilesByPose = const <String, File>{},
  }) : assert(
          capturedFile != null || capturedFilesByPose.length > 0,
          'A captured file or captured pose files are required.',
        );

  final File? capturedFile;
  final Map<String, File> capturedFilesByPose;
}

class StylistLiveFaceScanScreen extends StatefulWidget {
  const StylistLiveFaceScanScreen({
    super.key,
    required this.request,
    required this.service,
  });

  final StylistLiveFaceScanRequest request;
  final StylistFaceAttendanceService service;

  @override
  State<StylistLiveFaceScanScreen> createState() =>
      _StylistLiveFaceScanScreenState();
}

class _StylistLiveFaceScanScreenState extends State<StylistLiveFaceScanScreen> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isCompleted = false;
  bool _isFinalizingSequence = false;
  bool _shouldKeepCapturedFiles = false;
  String _statusMessage = '';
  int _sequencePoseIndex = 0;
  final Map<String, File> _sequenceCapturedFiles = <String, File>{};
  DateTime? _lastProcessedAt;

  List<StylistAttendancePose> get _sequencePoses =>
      widget.request.poses ?? const <StylistAttendancePose>[];

  StylistAttendancePose? get _activeSequencePose =>
      _sequencePoseIndex < _sequencePoses.length
          ? _sequencePoses[_sequencePoseIndex]
          : null;

  bool get _isPreviewingSequence =>
      widget.request.isEnrollmentSequence &&
      _sequenceCapturedFiles.length == _sequencePoses.length &&
      !_isFinalizingSequence;

  @override
  void initState() {
    super.initState();
    _statusMessage = _initialStatusMessage();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopImageStream();
    _controller?.dispose();
    if (!_shouldKeepCapturedFiles) {
      _cleanupCapturedFiles();
    }
    super.dispose();
  }

  String _initialStatusMessage() {
    if (widget.request.isEnrollment) {
      return translateText(widget.request.pose!.description);
    }
    if (widget.request.isEnrollmentSequence) {
      final pose = _activeSequencePose;
      return pose == null
          ? translateText('Align your face inside the frame for auto scan.')
          : translateText(pose.description);
    }
    return translateText('Align your face inside the frame for auto scan.');
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
      await _startImageStream();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _statusMessage = _friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _startImageStream() async {
    final controller = _controller;
    if (controller == null || controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((CameraImage image) {
      _processFrame(image);
    });
  }

  Future<void> _stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }
    await controller.stopImageStream();
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    if (_isProcessing ||
        _isCompleted ||
        _isPreviewingSequence ||
        controller == null ||
        !mounted) {
      return;
    }

    final now = DateTime.now();
    if (_lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) <
            const Duration(milliseconds: 1200)) {
      return;
    }
    _lastProcessedAt = now;

    _isProcessing = true;
    try {
      final capturedFiles = await _saveFrameCandidateFiles(
        image,
        sensorOrientation: controller.description.sensorOrientation,
      );
      StylistFaceValidationResult? bestFailure;
      File? capturedFile;
      StylistFaceValidationResult? validation;
      var selectedIndex = -1;

      for (var index = 0; index < capturedFiles.length; index++) {
        final candidateFile = capturedFiles[index];
        final candidateValidation = widget.request.isEnrollment
            ? await widget.service.validateEnrollmentCapture(
                imageFile: candidateFile,
                pose: widget.request.pose!,
              )
            : widget.request.isEnrollmentSequence
                ? await widget.service.validateEnrollmentCapture(
                    imageFile: candidateFile,
                    pose: _activeSequencePose!,
                  )
                : await widget.service.validateAttendanceCaptureForUser(
                    userKey: widget.request.userKey!,
                    branchId: widget.request.branchId!,
                    imageFile: candidateFile,
                  );

        debugPrint(
          '[StylistAttendance] stream_candidate_validation | index=$index valid=${candidateValidation.isValid} faceCount=${candidateValidation.faceCount} rotX=${candidateValidation.rotX} rotY=${candidateValidation.rotY} rotZ=${candidateValidation.rotZ} message=${candidateValidation.message}',
        );

        if (candidateValidation.isValid) {
          capturedFile = candidateFile;
          validation = candidateValidation;
          selectedIndex = index;
          break;
        }

        if (_preferFailure(candidateValidation, over: bestFailure)) {
          bestFailure = candidateValidation;
        }
      }

      if (capturedFile == null || validation == null) {
        debugPrint(
          '[StylistAttendance] stream_candidate_validation_failed | bestMessage=${bestFailure?.message}',
        );
        for (final file in capturedFiles) {
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _statusMessage = bestFailure?.message ??
              translateText('No face detected. Please try again.');
        });
        return;
      }

      for (var index = 0; index < capturedFiles.length; index++) {
        if (index == selectedIndex) {
          continue;
        }
        final extraFile = capturedFiles[index];
        if (await extraFile.exists()) {
          await extraFile.delete();
        }
      }
      debugPrint(
        '[StylistAttendance] stream_candidate_selected | index=$selectedIndex',
      );

      if (!mounted) {
        return;
      }

      if (validation.isValid) {
        if (widget.request.isEnrollmentSequence) {
          await _handleSequenceCapture(capturedFile);
          return;
        }
        await _stopImageStream();
        _isCompleted = true;
        setState(() {
          _statusMessage = translateText('Face detected successfully');
        });
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(
          StylistLiveFaceScanResult(capturedFile: capturedFile),
        );
        return;
      }

      if (await capturedFile.exists()) {
        await capturedFile.delete();
      }
      setState(() {
        _statusMessage = validation!.message;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = _friendlyErrorMessage(error);
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _handleSequenceCapture(File capturedFile) async {
    final pose = _activeSequencePose;
    if (pose == null) {
      if (await capturedFile.exists()) {
        await capturedFile.delete();
      }
      return;
    }

    final previousFile = _sequenceCapturedFiles[pose.id];
    if (previousFile != null && await previousFile.exists()) {
      await previousFile.delete();
    }
    _sequenceCapturedFiles[pose.id] = capturedFile;

    final nextIndex = _sequencePoseIndex + 1;
    if (nextIndex >= _sequencePoses.length) {
      await _stopImageStream();
      setState(() {
        _sequencePoseIndex = nextIndex;
        _statusMessage = translateText(
          'Review your captured images. Retake if needed or store them.',
        );
      });
      return;
    }

    final nextPose = _sequencePoses[nextIndex];
    setState(() {
      _sequencePoseIndex = nextIndex;
      _statusMessage = translateText(nextPose.description);
    });
  }

  Future<void> _retakeSequence() async {
    await _stopImageStream();
    await _cleanupCapturedFiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _sequenceCapturedFiles.clear();
      _sequencePoseIndex = 0;
      _statusMessage = translateText(_sequencePoses.first.description);
      _lastProcessedAt = null;
    });
    await _startImageStream();
  }

  Future<void> _storeSequence() async {
    if (_sequenceCapturedFiles.length != _sequencePoses.length) {
      return;
    }
    await _stopImageStream();
    if (!mounted) {
      return;
    }
    setState(() {
      _isFinalizingSequence = true;
      _statusMessage = translateText('Storing captured images...');
    });
    _shouldKeepCapturedFiles = true;
    Navigator.of(context).pop(
      StylistLiveFaceScanResult(
        capturedFilesByPose: Map<String, File>.from(_sequenceCapturedFiles),
      ),
    );
  }

  Future<void> _cleanupCapturedFiles() async {
    for (final file in _sequenceCapturedFiles.values) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<File>> _saveFrameCandidateFiles(
    CameraImage image, {
    required int sensorOrientation,
  }) async {
    final converted = _convertCameraImage(image);
    if (converted == null) {
      throw StateError('Unable to capture image from camera stream.');
    }
    final candidates = Platform.isIOS
        ? <img.Image>[
            img.copyRotate(converted, angle: 90),
            img.copyRotate(converted, angle: 270),
            converted,
            img.copyRotate(converted, angle: 180),
          ]
        : <img.Image>[_applyRotation(converted, sensorOrientation)];
    final tempDir = await getTemporaryDirectory();
    final files = <File>[];
    for (var index = 0; index < candidates.length; index++) {
      final bytes = img.encodeJpg(candidates[index], quality: 90);
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}stylist_attendance_face_${DateTime.now().microsecondsSinceEpoch}_$index.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      files.add(file);
    }
    return files;
  }

  img.Image? _convertCameraImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBgra8888(image);
    }
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYuv420(image);
    }
    return null;
  }

  img.Image _convertBgra8888(CameraImage image) {
    final output = img.Image(width: image.width, height: image.height);
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;
    for (var y = 0; y < image.height; y++) {
      final rowOffset = y * bytesPerRow;
      for (var x = 0; x < image.width; x++) {
        final index = rowOffset + (x * 4);
        final b = bytes[index];
        final g = bytes[index + 1];
        final r = bytes[index + 2];
        output.setPixelRgb(x, y, r, g, b);
      }
    }
    return output;
  }

  img.Image _convertYuv420(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final yRow = yPlane.bytesPerRow * y;
      final uvRow = uvRowStride * (y >> 1);
      for (var x = 0; x < width; x++) {
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;
        final yp = yPlane.bytes[yRow + x];
        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        final r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
        final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
            .round()
            .clamp(0, 255);
        final b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

        output.setPixelRgb(x, y, r, g, b);
      }
    }
    return output;
  }

  img.Image _applyRotation(img.Image source, int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return img.copyRotate(source, angle: 90);
      case 180:
        return img.copyRotate(source, angle: 180);
      case 270:
        return img.copyRotate(source, angle: 270);
      default:
        return source;
    }
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    if (raw.startsWith(badStatePrefix)) {
      return raw.substring(badStatePrefix.length).trim();
    }
    return raw;
  }

  bool _preferFailure(
    StylistFaceValidationResult candidate, {
    required StylistFaceValidationResult? over,
  }) {
    if (over == null) {
      return true;
    }
    if (candidate.faceCount > over.faceCount) {
      return true;
    }
    if (candidate.faceCount == over.faceCount && candidate.faceCount > 0) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.request.isEnrollment || widget.request.isEnrollmentSequence
            ? translateText('Face Setup')
            : translateText(widget.request.action!.label);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(title),
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _controller == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : _isPreviewingSequence
                  ? _EnrollmentSequencePreview(
                      poses: _sequencePoses,
                      capturedFilesByPose: _sequenceCapturedFiles,
                      onRetake: _retakeSequence,
                      onStore: _storeSequence,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        Container(
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.center_focus_strong,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _statusMessage,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.request.isEnrollmentSequence) ...[
                                  const SizedBox(height: 14),
                                  _SequenceProgressStrip(
                                    poses: _sequencePoses,
                                    capturedFilesByPose: _sequenceCapturedFiles,
                                    activePoseId: _activeSequencePose?.id,
                                  ),
                                ],
                                const Spacer(),
                                Center(
                                  child: Container(
                                    width: 240,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(140),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: _isProcessing
                                            ? const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              )
                                            : const Icon(
                                                Icons.auto_mode,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          context.t(
                                            widget.request.isEnrollmentSequence
                                                ? 'Auto capture is running. Follow the pose guidance in sequence.'
                                                : 'Auto detection is running. No shutter tap is needed.',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _SequenceProgressStrip extends StatelessWidget {
  const _SequenceProgressStrip({
    required this.poses,
    required this.capturedFilesByPose,
    required this.activePoseId,
  });

  final List<StylistAttendancePose> poses;
  final Map<String, File> capturedFilesByPose;
  final String? activePoseId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: poses.map((pose) {
          final isDone = capturedFilesByPose.containsKey(pose.id);
          final isActive = activePoseId == pose.id;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF166534)
                  : isActive
                      ? const Color(0xFFB45309)
                      : Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: isActive ? 0.7 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.face_6_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  pose.label.tr(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EnrollmentSequencePreview extends StatelessWidget {
  const _EnrollmentSequencePreview({
    required this.poses,
    required this.capturedFilesByPose,
    required this.onRetake,
    required this.onStore,
  });

  final List<StylistAttendancePose> poses;
  final Map<String, File> capturedFilesByPose;
  final Future<void> Function() onRetake;
  final Future<void> Function() onStore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Review Captured Images'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'If all images look fine, store them. Otherwise retake and capture the full sequence again.',
              ),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                itemCount: poses.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final pose = poses[index];
                  final file = capturedFilesByPose[pose.id];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: file == null
                                ? Container(
                                    color: Colors.white10,
                                    child: const Center(
                                      child: Icon(
                                        Icons.face_outlined,
                                        color: Colors.white70,
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          pose.label.tr(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pose.description.tr(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(context.t('Retake')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      context.t('Store Images'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
