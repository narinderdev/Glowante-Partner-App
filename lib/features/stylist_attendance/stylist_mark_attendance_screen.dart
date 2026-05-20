import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_history_screen.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_live_face_scan_screen.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_stored_enrollment_images_screen.dart';
import 'package:bloc_onboarding/services/stylist_branch_selection.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _showSnackBar(_friendlyErrorMessage(error));
    }
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
      _showSnackBar(translateText('Select a branch to continue'));
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
      _showSnackBar(translateText('Face setup completed successfully'));
    } catch (error) {
      _showSnackBar(_friendlyErrorMessage(error));
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
      _showSnackBar(translateText('Select a branch to continue'));
      return;
    }
    final userId = _userId;
    if (userId == null) {
      _showSnackBar(
        translateText('Unable to resolve your account. Please sign in again.'),
      );
      return;
    }
    if (_enrollment?.isComplete != true) {
      _showSnackBar(translateText('Complete face setup first'));
      return;
    }
    if (action == StylistAttendanceAction.checkIn && _hasCheckedInToday) {
      _showSnackBar(translateText('Check-in is already marked for today.'));
      return;
    }
    if (action == StylistAttendanceAction.checkOut && !_hasCheckedInToday) {
      _showSnackBar(translateText('Check-in must be marked before check-out.'));
      return;
    }
    if (action == StylistAttendanceAction.checkOut && _hasCheckedOutToday) {
      _showSnackBar(translateText('Check-out is already marked for today.'));
      return;
    }

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
    final capturedFile = result.capturedFile;
    if (capturedFile == null) {
      _showSnackBar(translateText('Unable to capture attendance image.'));
      return;
    }

    setState(() {
      _isBusy = true;
      _activeAttendanceActionId = action.id;
    });
    try {
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
      _showSnackBar(
        action == StylistAttendanceAction.checkIn
            ? translateText('Check-in marked successfully')
            : translateText('Check-out marked successfully'),
      );
    } catch (error) {
      _showSnackBar(_friendlyErrorMessage(error));
    } finally {
      if (await capturedFile.exists()) {
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
          title: Text(context.t('Reset Face Setup')),
          content: Text(
            context.t(
              'This will remove local face setup images and attendance scans on this device.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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
      _showSnackBar(translateText('Face setup reset successfully'));
    } catch (error) {
      _showSnackBar(_friendlyErrorMessage(error));
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
      _showSnackBar(translateText('No stored images found.'));
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
      _showSnackBar(translateText('Select a branch to continue'));
      return;
    }
    if (userId == null) {
      _showSnackBar(
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('Mark Attendance'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.t('Attendance History'),
            onPressed: _openAttendanceHistory,
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _branchSelection.branchId == null
              ? _AttendanceEmptyState(
                  title: context.t('Select a branch to continue'),
                  message: context.t(
                    'Attendance uses the stylist branch selected in bookings or home.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAttendanceState,
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
                    ],
                  ),
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
  });

  final String displayName;
  final String branchName;
  final bool isEnrolled;
  final bool hasAttendanceToday;
  final bool hasCheckedInToday;
  final bool hasCheckedOutToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1E7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            branchName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(
                icon: isEnrolled
                    ? Icons.verified_user_outlined
                    : Icons.face_6_outlined,
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
              _StatusChip(
                icon: hasAttendanceToday
                    ? Icons.check_circle_outline
                    : Icons.timer_outlined,
                label: hasAttendanceToday
                    ? context.t('Attendance Marked Today')
                    : context.t('Attendance Not Marked Yet'),
                color: hasAttendanceToday
                    ? const Color(0xFF166534)
                    : const Color(0xFF475569),
                background: hasAttendanceToday
                    ? const Color(0xFFECFDF3)
                    : const Color(0xFFF1F5F9),
              ),
              _StatusChip(
                icon: hasCheckedInToday
                    ? Icons.login_rounded
                    : Icons.login_outlined,
                label: hasCheckedInToday
                    ? context.t('Check-in Done')
                    : context.t('Check-in Pending'),
                color: hasCheckedInToday
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF64748B),
                background: hasCheckedInToday
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
              ),
              _StatusChip(
                icon: hasCheckedOutToday
                    ? Icons.logout_rounded
                    : Icons.logout_outlined,
                label: hasCheckedOutToday
                    ? context.t('Check-out Done')
                    : context.t('Check-out Pending'),
                color: hasCheckedOutToday
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF64748B),
                background: hasCheckedOutToday
                    ? const Color(0xFFF5F3FF)
                    : const Color(0xFFF8FAFC),
              ),
            ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Face Setup'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(
            'Capture 5 face angles in one guided flow to prepare local attendance matching on this device.',
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF57534E),
          ),
        ),
        const SizedBox(height: 14),
        _ProgressBanner(
          title: context.t('Progress'),
          value: '$completedCount / ${kStylistAttendanceRequiredPoses.length}',
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy ? null : onStartCapture,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              context.t(
                hasStoredImages ? 'Retake All Images' : 'Capture Your Images',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
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
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy || hasCheckedInToday ? null : onCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isCheckInLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(Icons.login_rounded),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isCheckInLoading
                          ? context.t('Checking In...')
                          : context.t('Check In'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isCheckOutLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(Icons.logout_rounded),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isCheckOutLoading
                          ? context.t('Checking Out...')
                          : context.t('Check Out'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                label: Text(context.t('Reset Face Setup')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    isBusy || enrollment == null ? null : onViewStoredImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(context.t('Your Stored Images')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProgressBanner(
          title: context.t('Latest Attendance'),
          value: latestRecord == null
              ? context.t('Not marked yet')
              : '${translateText(latestRecord.action.label)} • '
                  '${DateFormat('dd MMM yyyy, hh:mm a').format(latestRecord.markedAt!)}',
        ),
        const SizedBox(height: 16),
        Text(
          context.t('Recent Attendance'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
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
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(16),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
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
        borderRadius: BorderRadius.circular(18),
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
