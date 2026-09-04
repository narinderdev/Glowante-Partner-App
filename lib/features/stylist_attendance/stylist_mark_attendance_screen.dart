import 'dart:io';

import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_history_screen.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_live_face_scan_screen.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_stored_enrollment_images_screen.dart';
import 'package:bloc_onboarding/services/stylist_branch_selection.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../widgets/app_loader.dart';
import '../profile/widgets/profile_subpage_app_bar.dart';

class StylistMarkAttendanceScreen extends StatefulWidget {
  const StylistMarkAttendanceScreen({super.key});

  @override
  State<StylistMarkAttendanceScreen> createState() =>
      _StylistMarkAttendanceScreenState();
}

class _StylistMarkAttendanceScreenState
    extends State<StylistMarkAttendanceScreen> {
  final StylistFaceAttendanceService _attendanceService =
      StylistFaceAttendanceService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _activeAttendanceActionId;
  int? _userId;
  String _userKey = '';
  String _displayName = '';
  StylistBranchSelection _branchSelection = const StylistBranchSelection();
  StylistAttendanceEnrollment? _enrollment;
  List<StylistAttendanceRecord> _records = const <StylistAttendanceRecord>[];

  @override
  void initState() {
    super.initState();
    _loadAttendanceState();
  }

  @override
  void dispose() {
    _attendanceService.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceState({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final branchSelection = await StylistBranchSelectionStore.load();
      final userId = _resolveUserId(prefs);
      final userKey = _resolveUserKey(prefs);
      final displayName = _resolveDisplayName(prefs);

      StylistAttendanceEnrollment? enrollment;
      List<StylistAttendanceRecord> records = const <StylistAttendanceRecord>[];
      if (branchSelection.branchId != null) {
        enrollment = await _attendanceService.loadEnrollment(
          userKey: userKey,
          branchId: branchSelection.branchId!,
        );
        records = await _attendanceService.loadRecords(
          userKey: userKey,
          branchId: branchSelection.branchId!,
        );

        if (userId != null) {
          records = await _mergeInServerRecordsToday(
            branchId: branchSelection.branchId!,
            userId: userId,
            userKey: userKey,
            localRecords: records,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _userId = userId;
        _userKey = userKey;
        _displayName = displayName;
        _branchSelection = branchSelection;
        _enrollment = enrollment;
        _records = records;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showToast(_friendlyErrorMessage(error));
    }
  }

  // Local storage (loadRecords above) can go stale — "Reset Face Setup"
  // explicitly wipes it, and so does a reinstall or a different device —
  // even though the server still has today's real check-in/out. This
  // fetches today's server truth and synthesizes matching
  // StylistAttendanceRecord entries for whichever of check-in/check-out
  // the LOCAL list doesn't already have for today, so every part of this
  // screen (status pills, Latest Attendance, Recent Attendance) shows the
  // real time regardless of local state. Best-effort: any failure (e.g.
  // offline) just returns the local list unchanged.
  Future<List<StylistAttendanceRecord>> _mergeInServerRecordsToday({
    required int branchId,
    required int userId,
    required String userKey,
    required List<StylistAttendanceRecord> localRecords,
  }) async {
    try {
      final now = DateTime.now();
      final response = await ApiService().getTeamAttendanceHistory(
        branchId: branchId,
        userId: userId,
        month: now.month,
        year: now.year,
      );
      if (response['success'] != true) return localRecords;
      final data = response['data'];
      final rawRecords = data is Map ? data['records'] : null;
      if (rawRecords is! List) return localRecords;

      final localHasCheckInToday = localRecords.any(
        (r) =>
            r.attendanceType == StylistAttendanceAction.checkIn.id &&
            _isTodayRecord(r),
      );
      final localHasCheckOutToday = localRecords.any(
        (r) =>
            r.attendanceType == StylistAttendanceAction.checkOut.id &&
            _isTodayRecord(r),
      );

      String? checkInIso;
      String? checkOutIso;
      for (final raw in rawRecords) {
        if (raw is! Map) continue;
        final checkedInAtIso = (raw['checkedInAt'] ?? '').toString();
        final checkedOutAtIso = (raw['checkedOutAt'] ?? '').toString();
        final checkedInAt = DateTime.tryParse(checkedInAtIso)?.toLocal();
        final checkedOutAt = DateTime.tryParse(checkedOutAtIso)?.toLocal();
        if (checkInIso == null &&
            checkedInAt != null &&
            _isSameLocalDay(checkedInAt, now)) {
          checkInIso = checkedInAtIso;
        }
        if (checkOutIso == null &&
            checkedOutAt != null &&
            _isSameLocalDay(checkedOutAt, now)) {
          checkOutIso = checkedOutAtIso;
        }
      }

      final merged = List<StylistAttendanceRecord>.from(localRecords);
      if (!localHasCheckInToday && checkInIso != null) {
        merged.add(StylistAttendanceRecord(
          id: 'server-checkin-${now.year}${now.month}${now.day}',
          branchId: branchId,
          userKey: userKey,
          scanImagePath: '',
          markedAtIso: checkInIso,
          status: 'success',
          attendanceType: StylistAttendanceAction.checkIn.id,
        ));
      }
      if (!localHasCheckOutToday && checkOutIso != null) {
        merged.add(StylistAttendanceRecord(
          id: 'server-checkout-${now.year}${now.month}${now.day}',
          branchId: branchId,
          userKey: userKey,
          scanImagePath: '',
          markedAtIso: checkOutIso,
          status: 'success',
          attendanceType: StylistAttendanceAction.checkOut.id,
        ));
      }
      merged.sort((a, b) {
        final aTime = a.markedAt;
        final bTime = b.markedAt;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return merged;
    } catch (_) {
      return localRecords;
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _resolveUserKey(SharedPreferences prefs) {
    final rawUserId = prefs.get('user_id');
    final rawPhone = prefs.get('phone_number');
    final userId = rawUserId?.toString().trim() ?? '';
    final phone = rawPhone?.toString().trim() ?? '';
    if (userId.isNotEmpty) {
      return userId;
    }
    if (phone.isNotEmpty) {
      return phone;
    }
    return 'stylist_local_user';
  }

  int? _resolveUserId(SharedPreferences prefs) {
    final rawUserId = prefs.get('user_id');
    if (rawUserId is int) {
      return rawUserId;
    }
    return int.tryParse(rawUserId?.toString() ?? '');
  }

  String _resolveDisplayName(SharedPreferences prefs) {
    final firstName =
        prefs.getString('firstName') ?? prefs.getString('first_name') ?? '';
    final lastName =
        prefs.getString('lastName') ?? prefs.getString('last_name') ?? '';
    final displayName = '$firstName $lastName'.trim();
    return displayName.isEmpty ? translateText('Stylist') : displayName;
  }

  // _records is now already merged with today's server truth (see
  // _mergeInServerRecordsToday in _loadAttendanceState), so these can
  // stay simple local-list checks.
  bool get _hasAnyAttendanceToday => _records.any(_isTodayRecord);

  bool get _hasCheckedInToday => _records.any(
        (record) =>
            record.attendanceType == StylistAttendanceAction.checkIn.id &&
            _isTodayRecord(record),
      );

  bool get _hasCheckedOutToday => _records.any(
        (record) =>
            record.attendanceType == StylistAttendanceAction.checkOut.id &&
            _isTodayRecord(record),
      );

  StylistAttendanceRecord? _todayRecord(String actionId) {
    for (final record in _records) {
      if (record.attendanceType == actionId && _isTodayRecord(record)) {
        return record;
      }
    }
    return null;
  }

  String _formatRecordTime(StylistAttendanceRecord? record) {
    final markedAt = record?.markedAt;
    if (markedAt == null) return '';
    return DateFormat('hh:mm a').format(markedAt);
  }

  bool _isTodayRecord(StylistAttendanceRecord record) {
    final markedAt = record.markedAt;
    if (markedAt == null) {
      return false;
    }
    final now = DateTime.now();
    return markedAt.year == now.year &&
        markedAt.month == now.month &&
        markedAt.day == now.day;
  }

  Future<void> _startEnrollmentSequence() async {
    final branchId = _branchSelection.branchId;
    if (branchId == null) {
      _showToast(translateText('Select a branch to continue'));
      return;
    }

    final result = await Navigator.push<StylistLiveFaceScanResult>(
      context,
      MaterialPageRoute(
        builder: (_) => StylistLiveFaceScanScreen(
          request: const StylistLiveFaceScanRequest.enrollmentSequence(
            poses: kStylistAttendanceRequiredPoses,
          ),
          service: _attendanceService,
        ),
      ),
    );
    if (result == null) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      StylistAttendanceEnrollment? enrollment = _enrollment;
      for (final pose in kStylistAttendanceRequiredPoses) {
        final file = result.capturedFilesByPose[pose.id];
        if (file == null) {
          throw StateError(
            translateText(
              'Please capture all 5 required face images before storing.',
            ),
          );
        }
        enrollment = await _attendanceService.saveEnrollmentPose(
          userKey: _userKey,
          branchId: branchId,
          pose: pose,
          capturedFile: file,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _enrollment = enrollment;
      });
      _showToast(translateText('Face setup completed successfully'));
    } catch (error) {
      _showToast(_friendlyErrorMessage(error));
    } finally {
      for (final file in result.capturedFilesByPose.values) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _startAttendanceAction(StylistAttendanceAction action) async {
    final branchId = _branchSelection.branchId;
    if (branchId == null) {
      _showToast(translateText('Select a branch to continue'));
      return;
    }
    final userId = _userId;
    if (userId == null) {
      _showToast(
        translateText('Unable to resolve your account. Please sign in again.'),
      );
      return;
    }
    if (_enrollment?.isComplete != true) {
      _showToast(translateText('Complete face setup first'));
      return;
    }
    if (action == StylistAttendanceAction.checkIn && _hasCheckedInToday) {
      _showToast(translateText('Check-in is already marked for today.'));
      return;
    }
    if (action == StylistAttendanceAction.checkOut && !_hasCheckedInToday) {
      _showToast(translateText('Check-in must be marked before check-out.'));
      return;
    }
    if (action == StylistAttendanceAction.checkOut && _hasCheckedOutToday) {
      _showToast(translateText('Check-out is already marked for today.'));
      return;
    }
    if (_isBusy || _activeAttendanceActionId != null) {
      return;
    }

    File? capturedFile;
    setState(() {
      _isBusy = true;
      _activeAttendanceActionId = action.id;
    });
    try {
      final result = await Navigator.push<StylistLiveFaceScanResult>(
        context,
        MaterialPageRoute(
          builder: (_) => StylistLiveFaceScanScreen(
            request: StylistLiveFaceScanRequest.attendance(
              action: action,
              userKey: _userKey,
              branchId: branchId,
            ),
            service: _attendanceService,
          ),
        ),
      );
      if (result == null) {
        return;
      }
      capturedFile = result.capturedFile;
      if (capturedFile == null) {
        _showToast(translateText('Unable to capture attendance image.'));
        return;
      }

      final record = await _attendanceService.markAttendanceFromCapture(
        userKey: _userKey,
        userId: userId,
        branchId: branchId,
        capturedFile: capturedFile,
        action: action,
        existingRecords: _records,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = <StylistAttendanceRecord>[record, ..._records];
      });
      _showToast(
        action == StylistAttendanceAction.checkIn
            ? translateText('Check-in marked successfully')
            : translateText('Check-out marked successfully'),
      );
    } catch (error) {
      _showToast(_friendlyErrorMessage(error));
    } finally {
      if (capturedFile != null && await capturedFile.exists()) {
        await capturedFile.delete();
      }
      if (mounted) {
        setState(() {
          _isBusy = false;
          _activeAttendanceActionId = null;
        });
      }
    }
  }

  Future<void> _resetEnrollment() async {
    final branchId = _branchSelection.branchId;
    if (branchId == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.t('Reset Face Setup'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.starColor,
            ),
          ),
          content: Text(
            context.t(
              'This will remove local face setup images and attendance scans on this device.',
            ),
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(context.t('Reset')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await _attendanceService.resetEnrollment(
        userKey: _userKey,
        branchId: branchId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _enrollment = null;
        _records = const <StylistAttendanceRecord>[];
      });
      _showToast(translateText('Face setup reset successfully'));
    } catch (error) {
      _showToast(_friendlyErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openStoredImages() async {
    final enrollment = _enrollment;
    if (enrollment == null || enrollment.imagePaths.isEmpty) {
      _showToast(translateText('No stored images found.'));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StylistStoredEnrollmentImagesScreen(
          enrollment: enrollment,
        ),
      ),
    );
  }

  Future<void> _openAttendanceHistory() async {
    final branchId = _branchSelection.branchId;
    final userId = _userId;
    if (branchId == null) {
      _showToast(translateText('Select a branch to continue'));
      return;
    }
    if (userId == null) {
      _showToast(
        translateText('Unable to resolve your account. Please sign in again.'),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StylistAttendanceHistoryScreen(
          service: _attendanceService,
          branchId: branchId,
          userId: userId,
          displayName: _displayName,
          branchName: _branchSelection.label.trim(),
        ),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    Fluttertoast.showToast(msg: message);
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
    final branchName = _branchSelection.label.trim();
    final todayCheckIn = _todayRecord(StylistAttendanceAction.checkIn.id);
    final todayCheckOut = _todayRecord(StylistAttendanceAction.checkOut.id);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title: context.t('Mark Attendance'),
        actions: [
          IconButton(
            tooltip: context.t('Attendance History'),
            onPressed: _openAttendanceHistory,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: (_isLoading && _branchSelection.branchId == null)
          ? AppLoader.page()
          : _branchSelection.branchId == null
              ? RefreshIndicator(
                  onRefresh: () =>
                      RefreshFeedback.playAndDetach(_loadAttendanceState),
                  color: AppColors.starColor,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _AttendanceEmptyState(
                        title: context.t('Select a branch to continue'),
                        message: context.t(
                          'Attendance uses the stylist branch selected in bookings or home.',
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () =>
                          RefreshFeedback.playAndDetach(_loadAttendanceState),
                      color: AppColors.starColor,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          _AttendanceHeroCard(
                            displayName: _displayName,
                            branchName: branchName,
                            isEnrolled: _enrollment?.isComplete == true,
                            hasAttendanceToday: _hasAnyAttendanceToday,
                            hasCheckedInToday: _hasCheckedInToday,
                            hasCheckedOutToday: _hasCheckedOutToday,
                            checkInTimeText: _formatRecordTime(todayCheckIn),
                            checkOutTimeText: _formatRecordTime(todayCheckOut),
                          ),
                          const SizedBox(height: 16),
                          if (_enrollment?.isComplete == true)
                            _AttendanceReadySection(
                              isBusy: _isBusy,
                              enrollment: _enrollment,
                              records: _records,
                              hasCheckedInToday: _hasCheckedInToday,
                              hasCheckedOutToday: _hasCheckedOutToday,
                              activeActionId: _activeAttendanceActionId,
                              onCheckIn: () => _startAttendanceAction(
                                StylistAttendanceAction.checkIn,
                              ),
                              onCheckOut: () => _startAttendanceAction(
                                StylistAttendanceAction.checkOut,
                              ),
                              onReset: _resetEnrollment,
                              onViewStoredImages: _openStoredImages,
                            )
                          else
                            _AttendanceEnrollmentSection(
                              isBusy: _isBusy,
                              enrollment: _enrollment,
                              onStartCapture: _startEnrollmentSequence,
                            ),
                          if (_enrollment?.isComplete != true &&
                              _records.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _AttendanceRecordsSection(records: _records),
                          ],
                        ],
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: AbsorbPointer(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.08),
                            child: AppLoader.page(),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _AttendanceHeroCard extends StatelessWidget {
  const _AttendanceHeroCard({
    required this.displayName,
    required this.branchName,
    required this.isEnrolled,
    required this.hasAttendanceToday,
    required this.hasCheckedInToday,
    required this.hasCheckedOutToday,
    required this.checkInTimeText,
    required this.checkOutTimeText,
  });

  final String displayName;
  final String branchName;
  final bool isEnrolled;
  final bool hasAttendanceToday;
  final bool hasCheckedInToday;
  final bool hasCheckedOutToday;
  final String checkInTimeText;
  final String checkOutTimeText;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'S'
        : displayName.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1917),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CompactStatusPill(
                  label: isEnrolled
                      ? context.t('Face Setup Ready')
                      : context.t('Face Setup Pending'),
                  color: isEnrolled
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFB45309),
                  background: isEnrolled
                      ? const Color(0xFFE6FFFB)
                      : const Color(0xFFFFF3E8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStatusPill(
                  label: hasAttendanceToday
                      ? context.t('Marked Today')
                      : context.t('Not Marked Yet'),
                  color: hasAttendanceToday
                      ? const Color(0xFF166534)
                      : const Color(0xFF475569),
                  background: hasAttendanceToday
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TodayTimeTile(
                  label: context.t('Check In'),
                  timeText: checkInTimeText,
                  done: hasCheckedInToday,
                  color: const Color(0xFF1D4ED8),
                  background: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TodayTimeTile(
                  label: context.t('Check Out'),
                  timeText: checkOutTimeText,
                  done: hasCheckedOutToday,
                  color: const Color(0xFF7C3AED),
                  background: const Color(0xFFF5F3FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TodayTimeTile extends StatelessWidget {
  const _TodayTimeTile({
    required this.label,
    required this.timeText,
    required this.done,
    required this.color,
    required this.background,
  });

  final String label;
  final String timeText;
  final bool done;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done && timeText.isNotEmpty ? timeText : context.t('Pending'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: done ? const Color(0xFF1C1917) : const Color(0xFF78716C),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEnrollmentSection extends StatelessWidget {
  const _AttendanceEnrollmentSection({
    required this.isBusy,
    required this.enrollment,
    required this.onStartCapture,
  });

  final bool isBusy;
  final StylistAttendanceEnrollment? enrollment;
  final VoidCallback onStartCapture;

  @override
  Widget build(BuildContext context) {
    final completedCount = enrollment?.completedCount ?? 0;
    final hasStoredImages =
        enrollment != null && enrollment!.imagePaths.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.face_retouching_natural_outlined,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t('Face Setup'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              'Capture 5 face angles in one guided flow to prepare local attendance matching on this device.',
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF57534E),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _ProgressBanner(
            title: context.t('Progress'),
            value:
                '$completedCount / ${kStylistAttendanceRequiredPoses.length}',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : onStartCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                context.t(
                  hasStoredImages ? 'Retake All Images' : 'Capture Your Images',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceReadySection extends StatelessWidget {
  const _AttendanceReadySection({
    required this.isBusy,
    required this.enrollment,
    required this.records,
    required this.hasCheckedInToday,
    required this.hasCheckedOutToday,
    required this.activeActionId,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onReset,
    required this.onViewStoredImages,
  });

  final bool isBusy;
  final StylistAttendanceEnrollment? enrollment;
  final List<StylistAttendanceRecord> records;
  final bool hasCheckedInToday;
  final bool hasCheckedOutToday;
  final String? activeActionId;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onReset;
  final VoidCallback onViewStoredImages;

  @override
  Widget build(BuildContext context) {
    final isCheckInLoading =
        isBusy && activeActionId == StylistAttendanceAction.checkIn.id;
    final isCheckOutLoading =
        isBusy && activeActionId == StylistAttendanceAction.checkOut.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isBusy || hasCheckedInToday ? null : onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFE7E5E4),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCheckInLoading) ...[
                        AppLoader.inline(
                          size: 18,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.login_rounded),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isCheckInLoading
                                ? context.t('Checking In...')
                                : context.t('Check In'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isBusy || !hasCheckedInToday || hasCheckedOutToday
                      ? null
                      : onCheckOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    disabledBackgroundColor: const Color(0xFFE7E5E4),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCheckOutLoading) ...[
                        AppLoader.inline(
                          size: 18,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.logout_rounded),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isCheckOutLoading
                                ? context.t('Checking Out...')
                                : context.t('Check Out'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onReset,
                  icon: const Icon(Icons.refresh_outlined),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(context.t('Reset Setup')),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6D5A8D),
                    side: const BorderSide(color: Color(0xFFD8CFE5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isBusy || enrollment == null ? null : onViewStoredImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(context.t('Stored Images')),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6D5A8D),
                    side: const BorderSide(color: Color(0xFFD8CFE5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AttendanceRecordsSection(records: records),
        ],
      ),
    );
  }
}

class _AttendanceRecordsSection extends StatelessWidget {
  const _AttendanceRecordsSection({required this.records});

  final List<StylistAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final latestRecord = records.isNotEmpty ? records.first : null;
    final groupedRecords = <String, List<StylistAttendanceRecord>>{};
    for (final record in records) {
      final markedAt = record.markedAt;
      if (markedAt == null) {
        continue;
      }
      final key = DateFormat('yyyy-MM-dd').format(markedAt);
      groupedRecords
          .putIfAbsent(key, () => <StylistAttendanceRecord>[])
          .add(record);
    }
    final sortedGroups = groupedRecords.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressBanner(
          title: context.t('Latest Attendance'),
          value: latestRecord == null || latestRecord.markedAt == null
              ? context.t('Not marked yet')
              : '${translateText(latestRecord.action.label)} • '
                  '${DateFormat('dd MMM, hh:mm a').format(latestRecord.markedAt!)}',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('Recent Attendance'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
            if (records.isNotEmpty)
              Text(
                records.length.toString(),
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          _AttendanceEmptyState(
            title: context.t('No attendance marked yet'),
            message: context.t(
              'Once auto face scan succeeds, local attendance entries will appear here.',
            ),
          )
        else
          ...sortedGroups.take(10).map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AttendanceDayCard(records: entry.value),
                ),
              ),
      ],
    );
  }
}

class _AttendanceDayCard extends StatelessWidget {
  const _AttendanceDayCard({required this.records});

  final List<StylistAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final datedRecords = records
        .where((record) => record.markedAt != null)
        .toList()
      ..sort((a, b) => a.markedAt!.compareTo(b.markedAt!));
    if (datedRecords.isEmpty) {
      return const SizedBox.shrink();
    }
    final day = datedRecords.first.markedAt!;
    final checkIn = datedRecords.cast<StylistAttendanceRecord?>().firstWhere(
          (record) =>
              record?.attendanceType == StylistAttendanceAction.checkIn.id,
          orElse: () => null,
        );
    final checkOut = datedRecords.cast<StylistAttendanceRecord?>().firstWhere(
          (record) =>
              record?.attendanceType == StylistAttendanceAction.checkOut.id,
          orElse: () => null,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, dd MMM yyyy').format(day),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 10),
          _AttendanceActionRow(
            action: StylistAttendanceAction.checkIn,
            record: checkIn,
          ),
          const SizedBox(height: 8),
          _AttendanceActionRow(
            action: StylistAttendanceAction.checkOut,
            record: checkOut,
          ),
        ],
      ),
    );
  }
}

class _AttendanceActionRow extends StatelessWidget {
  const _AttendanceActionRow({
    required this.action,
    required this.record,
  });

  final StylistAttendanceAction action;
  final StylistAttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final time = record?.markedAt == null
        ? context.t('Not marked yet')
        : DateFormat('hh:mm a').format(record!.markedAt!);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: action == StylistAttendanceAction.checkIn
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            action == StylistAttendanceAction.checkIn
                ? Icons.login_rounded
                : Icons.logout_rounded,
            size: 18,
            color: action == StylistAttendanceAction.checkIn
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            action.label.tr(context),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1917),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: record == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF57534E),
          ),
        ),
      ],
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEmptyState extends StatelessWidget {
  const _AttendanceEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF57534E),
            ),
          ),
        ],
      ),
    );
  }
}
