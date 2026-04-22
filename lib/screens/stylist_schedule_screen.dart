import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/user_role_session.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistScheduleScreen extends StatefulWidget {
  const StylistScheduleScreen({super.key});

  @override
  State<StylistScheduleScreen> createState() => _StylistScheduleScreenState();
}

class _StylistScheduleScreenState extends State<StylistScheduleScreen> {
  List<Map<String, dynamic>> _branches = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final userBranches = await UserRoleSession.instance.loadUserBranches();
    if (!mounted) return;
    setState(() {
      _branches = userBranches;
      _isLoading = false;
    });
  }

  String _branchLabel(Map<String, dynamic> entry) {
    final rawBranch = entry['branch'];
    if (rawBranch is! Map) {
      return context.t('Schedule');
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

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Schedule')),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_branches.isEmpty)
              _ScheduleEmptyState(message: context.t('No schedules found'))
            else
              ..._branches.map((entry) {
                final schedules = _scheduleItems(entry);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                        child: Text(
                          _branchLabel(entry),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (schedules.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          child: Text(
                            context.t('No schedules found'),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        ...List.generate(schedules.length, (index) {
                          final schedule = schedules[index];
                          final day =
                              _formatDay((schedule['day'] ?? '').toString());
                          final startTime = _formatTime(
                            (schedule['startTime'] ?? '').toString(),
                          );
                          final endTime = _formatTime(
                            (schedule['endTime'] ?? '').toString(),
                          );

                          return Column(
                            children: [
                              if (index > 0) const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        day,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$startTime - $endTime',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
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
        ),
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
        borderRadius: BorderRadius.circular(20),
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
