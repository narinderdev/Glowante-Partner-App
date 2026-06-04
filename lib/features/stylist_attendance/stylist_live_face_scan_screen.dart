import 'dart:async';
import 'dart:io';

import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

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
  Future<void>? _autoCaptureLoop;
  bool _isDisposing = false;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isCompleted = false;
  bool _isAutoCaptureActive = false;
  bool _isFinalizingSequence = false;
  bool _shouldKeepCapturedFiles = false;
  String _statusMessage = '';
  int _sequencePoseIndex = 0;
  final Map<String, File> _sequenceCapturedFiles = <String, File>{};

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
    _isDisposing = true;
    _stopAutoCapture();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_disposeCameraController(controller));
    }
    if (!_shouldKeepCapturedFiles) {
      unawaited(_cleanupCapturedFiles());
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
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await _disposeCameraController(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
      _startAutoCapture();
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

  void _startAutoCapture() {
    if (_isAutoCaptureActive) {
      return;
    }
    _isAutoCaptureActive = true;
    _autoCaptureLoop = _runAutoCaptureLoop();
  }

  void _stopAutoCapture() {
    _isAutoCaptureActive = false;
  }

  Future<void> _runAutoCaptureLoop() async {
    while (mounted && _isAutoCaptureActive && !_isCompleted) {
      if (_isPreviewingSequence || _isFinalizingSequence) {
        break;
      }

      await _captureAndProcessFrame();
      if (!mounted || !_isAutoCaptureActive || _isCompleted) {
        break;
      }

      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }

    _isAutoCaptureActive = false;
    _autoCaptureLoop = null;
  }

  Future<void> _captureAndProcessFrame() async {
    final controller = _controller;
    if (_isProcessing ||
        _isCompleted ||
        _isDisposing ||
        _isPreviewingSequence ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        !mounted) {
      return;
    }

    _isProcessing = true;
    try {
      final capturedFile = await _captureStillImage(controller);
      if (!mounted || _isDisposing) {
        if (await capturedFile.exists()) {
          await capturedFile.delete();
        }
        return;
      }
      final validation = widget.request.isEnrollment
          ? await widget.service.validateEnrollmentCapture(
              imageFile: capturedFile,
              pose: widget.request.pose!,
            )
          : widget.request.isEnrollmentSequence
              ? await widget.service.validateEnrollmentCapture(
                  imageFile: capturedFile,
                  pose: _activeSequencePose!,
                )
              : await widget.service.validateAttendanceCaptureForUser(
                  userKey: widget.request.userKey!,
                  branchId: widget.request.branchId!,
                  imageFile: capturedFile,
                );

      if (!mounted) {
        return;
      }

      if (validation.isValid) {
        if (widget.request.isEnrollmentSequence) {
          await _handleSequenceCapture(capturedFile);
          return;
        }
        _stopAutoCapture();
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
        _statusMessage = validation.message;
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
      _stopAutoCapture();
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
    _stopAutoCapture();
    final captureLoop = _autoCaptureLoop;
    if (captureLoop != null) {
      await captureLoop;
    }
    await _cleanupCapturedFiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _sequenceCapturedFiles.clear();
      _sequencePoseIndex = 0;
      _statusMessage = translateText(_sequencePoses.first.description);
    });
    _startAutoCapture();
  }

  Future<void> _storeSequence() async {
    if (_sequenceCapturedFiles.length != _sequencePoses.length) {
      return;
    }
    _stopAutoCapture();
    final captureLoop = _autoCaptureLoop;
    if (captureLoop != null) {
      await captureLoop;
    }
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
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
      }
    }
  }

  Future<void> _disposeCameraController(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      debugPrint(
        '[StylistAttendance] camera_dispose_ignored | $error\n$stackTrace',
      );
    }
  }

  Future<File> _captureStillImage(CameraController controller) async {
    final rawCapture = await controller.takePicture();
    final capturedFile = File(rawCapture.path);
    final bytes = await capturedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to capture image from camera.');
    }

    final normalized = img.bakeOrientation(decoded);
    await capturedFile.writeAsBytes(
      img.encodeJpg(normalized, quality: 90),
      flush: true,
    );
    return capturedFile;
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    if (raw.startsWith(badStatePrefix)) {
      return raw.substring(badStatePrefix.length).trim();
    }
    return raw;
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
