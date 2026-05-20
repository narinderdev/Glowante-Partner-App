import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StylistAttendanceHistoryScreen extends StatefulWidget {
  const StylistAttendanceHistoryScreen({
    super.key,
    required this.service,
    required this.branchId,
    required this.userId,
    required this.displayName,
    required this.branchName,
  });

  final StylistFaceAttendanceService service;
  final int branchId;
  final int userId;
  final String displayName;
  final String branchName;

  @override
  State<StylistAttendanceHistoryScreen> createState() =>
      _StylistAttendanceHistoryScreenState();
}

class _StylistAttendanceHistoryScreenState
    extends State<StylistAttendanceHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StylistAttendanceHistoryEntry> _history =
      const <StylistAttendanceHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final history = await widget.service.loadAttendanceHistory(
        branchId: widget.branchId,
        userId: widget.userId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _history = history;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    if (raw.startsWith(badStatePrefix)) {
      return raw.substring(badStatePrefix.length).trim();
    }
    return raw.isEmpty
        ? translateText('Unable to load attendance history right now.')
        : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('Attendance History'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadHistory(showLoader: false),
              color: AppColors.starColor,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _HistoryHeroCard(
                    displayName: widget.displayName,
                    branchName: widget.branchName,
                    totalEntries: _history.length,
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _HistoryMessageCard(
                      title: context
                          .t('Unable to load attendance history right now.'),
                      message: _errorMessage!,
                    )
                  else if (_history.isEmpty)
                    _HistoryMessageCard(
                      title: context.t('No attendance history found.'),
                      message: context.t(
                        'Pull down to refresh your attendance history.',
                      ),
                    )
                  else
                    ..._history.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryEntryCard(entry: entry),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HistoryHeroCard extends StatelessWidget {
  const _HistoryHeroCard({
    required this.displayName,
    required this.branchName,
    required this.totalEntries,
  });

  final String displayName;
  final String branchName;
  final int totalEntries;

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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '${context.t('Attendance History')} • $totalEntries',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMessageCard extends StatelessWidget {
  const _HistoryMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 30,
            color: Color(0xFF78716C),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
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

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry});

  final StylistAttendanceHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final referenceDate = entry.checkedInAt ?? entry.checkedOutAt;
    final dateLabel = referenceDate == null
        ? context.t('Not marked yet')
        : DateFormat('EEEE, dd MMM yyyy').format(referenceDate.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: entry.checkedOutAt == null
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.checkedOutAt == null
                      ? context.t('Still checked in')
                      : context.t('Marked'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.checkedOutAt == null
                        ? const Color(0xFFB45309)
                        : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HistoryTimeRow(
            icon: Icons.login_rounded,
            label: context.t('Checked In'),
            value: _formatDateTime(context, entry.checkedInAt),
            accentColor: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(height: 10),
          _HistoryTimeRow(
            icon: Icons.logout_rounded,
            label: context.t('Checked Out'),
            value: entry.checkedOutAt == null
                ? context.t('Still checked in')
                : _formatDateTime(context, entry.checkedOutAt),
            accentColor: const Color(0xFF7C3AED),
            backgroundColor: const Color(0xFFF5F3FF),
          ),
          if (entry.updatedByUserId != null) ...[
            const SizedBox(height: 12),
            Text(
              '${context.t('Updated By')}: ${entry.updatedByUserId}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF78716C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime? value) {
    if (value == null) {
      return context.t('Not marked yet');
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }
}

class _HistoryTimeRow extends StatelessWidget {
  const _HistoryTimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF78716C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1917),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
