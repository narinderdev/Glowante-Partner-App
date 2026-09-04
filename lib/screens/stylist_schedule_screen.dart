import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/user_role_session.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/app_loader.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const List<String> _kWeekDays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

class StylistScheduleScreen extends StatefulWidget {
  const StylistScheduleScreen({super.key});

  @override
  State<StylistScheduleScreen> createState() => _StylistScheduleScreenState();
}

class _StylistScheduleScreenState extends State<StylistScheduleScreen> {
  List<Map<String, dynamic>> _branches = const [];
  bool _isLoading = true;

  // Keyed by branchId — the branch's own weekly operating hours, used as a
  // fallback for any branch where this stylist has no per-day override of
  // their own (i.e. was assigned with scheduleMode "BRANCH_HOURS", so
  // entry['schedules'] is empty even though the branch itself has hours
  // for every day).
  final Map<int, List<dynamic>> _branchOwnSchedules = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  // Two shapes seen from the backend for a branch assignment entry: the
  // documented flat one ({branchId, branchName, ...}, from
  // getTeamMemberDetailV2) and a legacy nested one ({branch: {id, name,
  // salon: {...}}, ...}, from the cached login-time userBranches). Check
  // both — same dual-shape handling as the owner-side Team Member Details
  // screen.
  int? _branchId(Map<String, dynamic> entry) {
    final rawBranch = entry['branch'];
    if (rawBranch is Map) {
      final id = rawBranch['id'];
      if (id is int) return id;
      return int.tryParse('$id');
    }
    final id = entry['branchId'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  Future<void> _loadSchedules() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final freshBranches =
        await UserRoleSession.instance.fetchFreshUserBranches();
    // Fall back to the cached login data only if the live fetch produced
    // nothing at all (e.g. offline, or no salons resolved) — never
    // silently prefer stale data over a successful live result.
    final userBranches = freshBranches.isNotEmpty
        ? freshBranches
        : await UserRoleSession.instance.loadUserBranches();
    if (!mounted) return;

    _branchOwnSchedules.clear();
    final branchIdsNeedingFallback = <int>{};
    for (final entry in userBranches) {
      if (_scheduleItems(entry).isNotEmpty) continue;
      final branchId = _branchId(entry);
      if (branchId != null) branchIdsNeedingFallback.add(branchId);
    }

    await Future.wait(branchIdsNeedingFallback.map((branchId) async {
      try {
        final response = await ApiService().getBranchDetail(branchId);
        final data = response['data'];
        if (data is Map) {
          final schedule = data['schedule'];
          if (schedule is List) _branchOwnSchedules[branchId] = schedule;
        }
      } catch (e) {
        debugPrint(
            '[StylistSchedule] Failed to load branch $branchId hours: $e');
      }
    }));

    if (!mounted) return;
    setState(() {
      _branches = userBranches;
      _isLoading = false;
    });
  }

  String _branchLabel(Map<String, dynamic> entry) {
    final rawBranch = entry['branch'];
    if (rawBranch is! Map) {
      // Flat shape (getTeamMemberDetailV2) — no nested salon name at this
      // level, just the branch's own name.
      final branchName = (entry['branchName'] ?? '').toString().trim();
      return branchName.isNotEmpty ? branchName : context.t('Schedule');
    }

    final branch = Map<String, dynamic>.from(rawBranch);
    final branchName = (branch['name'] ?? '').toString().trim();
    final rawSalon = branch['salon'];
    final salon = rawSalon is Map ? Map<String, dynamic>.from(rawSalon) : null;
    final salonName = (salon?['name'] ?? '').toString().trim();

    if (salonName.isNotEmpty &&
        branchName.isNotEmpty &&
        salonName != branchName) {
      return '$salonName • $branchName';
    }
    if (branchName.isNotEmpty) return branchName;
    if (salonName.isNotEmpty) return salonName;
    return context.t('Schedule');
  }

  String _formatDay(String rawDay) {
    if (rawDay.isEmpty) return context.t('Day');
    final normalized =
        rawDay[0].toUpperCase() + rawDay.substring(1).toLowerCase();
    return context.t(normalized);
  }

  String _formatTime(String rawTime) {
    final value = rawTime.trim();
    if (value.isEmpty) return '--';

    try {
      final parts = value.split(':');
      if (parts.length < 2) return value;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final isPm = hour >= 12;
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final minuteText = minute.toString().padLeft(2, '0');
      final suffix = isPm ? 'PM' : 'AM';
      return '$displayHour:$minuteText $suffix';
    } catch (_) {
      return value;
    }
  }

  List<Map<String, dynamic>> _scheduleItems(Map<String, dynamic> entry) {
    final rawSchedules = entry['schedules'];
    if (rawSchedules is! List) {
      return const [];
    }

    return rawSchedules
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Always all 7 days, one row each — using this stylist's own per-day
  // schedule for this branch when they have one, falling back to the
  // branch's own operating hours (fetched in _loadSchedules) otherwise.
  List<(String day, String timeText)> _dayRows(Map<String, dynamic> entry) {
    final ownSchedule = _scheduleItems(entry);
    if (ownSchedule.isNotEmpty) {
      final byDay = <String, Map<String, dynamic>>{};
      for (final item in ownSchedule) {
        final day = (item['day'] ?? '').toString().toLowerCase().trim();
        if (day.isNotEmpty) byDay[day] = item;
      }
      return _kWeekDays.map((day) {
        final item = byDay[day];
        if (item == null) {
          return (day, context.t('Closed'));
        }
        final start = _formatTime((item['startTime'] ?? '').toString());
        final end = _formatTime((item['endTime'] ?? '').toString());
        return (day, '$start - $end');
      }).toList();
    }

    final branchId = _branchId(entry);
    final branchSchedule =
        branchId == null ? null : _branchOwnSchedules[branchId];
    final byDay = <String, dynamic>{};
    if (branchSchedule != null) {
      for (final item in branchSchedule.whereType<Map>()) {
        final day = (item['day'] ?? '').toString().toLowerCase().trim();
        if (day.isNotEmpty) byDay[day] = item['slots'];
      }
    }

    return _kWeekDays.map((day) {
      final slots = byDay[day];
      if (slots is! List || slots.isEmpty) {
        return (day, context.t('Closed'));
      }
      final timings = slots.whereType<Map>().map((slot) {
        final start =
            _formatTime((slot['start'] ?? slot['startTime'] ?? '').toString());
        final end =
            _formatTime((slot['end'] ?? slot['endTime'] ?? '').toString());
        return '$start - $end';
      }).toList();
      return (day, timings.isEmpty ? context.t('Closed') : timings.join(', '));
    }).toList();
  }

  int _openDayCount(List<(String day, String timeText)> rows) {
    return rows
        .where(
            (row) => row.$2.toLowerCase() != context.t('Closed').toLowerCase())
        .length;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Schedule')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => RefreshFeedback.playAndDetach(_loadSchedules),
            color: AppColors.starColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (_branches.isEmpty && !_isLoading)
                  _ScheduleEmptyState(message: context.t('No schedules found'))
                else ...[
                  _ScheduleSummaryCard(
                    branchCount: _branches.length,
                    title: _branches.length == 1
                        ? _branchLabel(_branches.first)
                        : context.t('Schedule'),
                  ),
                  const SizedBox(height: 14),
                  ..._branches.map((entry) {
                    final dayRows = _dayRows(entry);
                    final openDays = _openDayCount(dayRows);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8DED6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: AppColors.starColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _branchLabel(entry),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1C1917),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$openDays / 7 ${context.t('Open days')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF78716C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...List.generate(dayRows.length, (index) {
                            final (day, timeText) = dayRows[index];
                            final isClosed = timeText.toLowerCase() ==
                                context.t('Closed').toLowerCase();

                            return Column(
                              children: [
                                if (index > 0)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFF1EBE6),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDay(day),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1C1917),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 190),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isClosed
                                              ? const Color(0xFFF5F5F4)
                                              : const Color(0xFFECFDF3),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          timeText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isClosed
                                                ? const Color(0xFF78716C)
                                                : const Color(0xFF166534),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: const Color(0x99FBF9F8),
                  child: AppLoader.page(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.branchCount,
    required this.title,
  });

  final int branchCount;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.starColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule_outlined,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$branchCount ${context.t(branchCount == 1 ? 'Branch' : 'Branches')}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78716C),
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

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule_outlined,
            size: 42,
            color: Colors.black38,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
