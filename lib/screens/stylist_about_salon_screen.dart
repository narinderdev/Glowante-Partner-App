import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/app_loader.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistAboutSalonScreen extends StatefulWidget {
  const StylistAboutSalonScreen({super.key});

  @override
  State<StylistAboutSalonScreen> createState() =>
      _StylistAboutSalonScreenState();
}

class _StylistAboutSalonScreenState extends State<StylistAboutSalonScreen> {
  final ApiService _apiService = ApiService();

  StylistBranchSelection _selection = const StylistBranchSelection();
  Map<String, dynamic>? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Flip the loader on before ANY awaited work starts (including the
    // branch-selection lookup below), and only flip it off in `finally`
    // once every awaited step has finished — otherwise a pull-to-refresh
    // wouldn't show the loader during the selection-lookup phase.
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final selection = await StylistBranchSelectionStore.load();
      if (!mounted) return;
      setState(() {
        _selection = selection;
      });

      if (selection.branchId == null) {
        if (!mounted) return;
        setState(() {
          _details = null;
        });
        return;
      }

      final response = await _apiService.getBranchDetail(selection.branchId!);
      final rawData = response['data'];
      final details = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _details = details;
      });
    } catch (e) {
      // Keep any already-loaded details on screen when a refresh fails
      // instead of wiping them out from under the user.
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _readAddress(Map<String, dynamic> details) {
    final rawAddress = details['address'];
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[
      address['line1']?.toString().trim() ?? '',
      address['line2']?.toString().trim() ?? '',
      address['village']?.toString().trim() ?? '',
      address['district']?.toString().trim() ?? '',
      address['city']?.toString().trim() ?? '',
      address['state']?.toString().trim() ?? '',
      address['country']?.toString().trim() ?? '',
      address['postalCode']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(', ');
  }

  List<String> _photoUrls(Map<String, dynamic> details) {
    final urls = <String>[];
    final seen = <String>{};

    final imageUrl = details['imageUrl'];
    if (imageUrl is String &&
        imageUrl.trim().isNotEmpty &&
        seen.add(imageUrl.trim())) {
      urls.add(imageUrl.trim());
    }

    final imageUrls = details['imageUrls'];
    if (imageUrls is List) {
      for (final entry in imageUrls) {
        if (entry is String &&
            entry.trim().isNotEmpty &&
            seen.add(entry.trim())) {
          urls.add(entry.trim());
        }
      }
    }

    return urls;
  }

  static const List<String> _weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  // All 7 days, one row each, from this branch's own weekly schedule —
  // distinct from the per-team-member schedule shown on the Schedule
  // screen; this is always the salon/branch's own operating hours.
  List<(String day, String timeText)> _scheduleRows(
    Map<String, dynamic> details,
  ) {
    final rawSchedule = details['schedule'];
    final byDay = <String, dynamic>{};
    if (rawSchedule is List) {
      for (final item in rawSchedule.whereType<Map>()) {
        final day = (item['day'] ?? '').toString().toLowerCase().trim();
        if (day.isNotEmpty) byDay[day] = item['slots'];
      }
    }

    return _weekDays.map((day) {
      final slots = byDay[day];
      if (slots is! List || slots.isEmpty) {
        return (day, context.t('Closed'));
      }
      final timings = slots
          .whereType<Map>()
          .map((slot) {
            final start = _formatWorkingHours(
                (slot['start'] ?? slot['startTime'] ?? '').toString());
            final end = _formatWorkingHours(
                (slot['end'] ?? slot['endTime'] ?? '').toString());
            if (start.isEmpty || end.isEmpty) return '';
            return '$start - $end';
          })
          .where((value) => value.isNotEmpty)
          .toList();
      return (day, timings.isEmpty ? context.t('Closed') : timings.join(', '));
    }).toList();
  }

  String _formatDay(String rawDay) {
    if (rawDay.isEmpty) return context.t('Day');
    return context.t(rawDay[0].toUpperCase() + rawDay.substring(1));
  }

  String _formatWorkingHours(String rawTime) {
    final value = rawTime.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return value;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return value;
    }

    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.starColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final details = _details ?? const <String, dynamic>{};
    final name = (details['name'] ?? _selection.label).toString().trim();
    final description = (details['description'] ?? '').toString().trim();
    final phone = (details['phone'] ?? '').toString().trim();
    final scheduleRows = _scheduleRows(details);
    final address = _readAddress(details);
    final photos = _photoUrls(details);
    // Once details have loaded once, a pull-to-refresh re-triggers _loading
    // (and possibly _error), but the already-visible content below stays on
    // screen — the big AppLoader.page() overlay below is layered on top of
    // it instead of tearing it down and replacing it with the full-page
    // loader / empty states again.
    final hasDetails = _details != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('About Salon')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => RefreshFeedback.playAndDetach(_loadData),
            color: AppColors.starColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_loading && !hasDetails)
                  // Wrapped in a bounded SizedBox so Center inside AppLoader.page()
                  // has room to center within — a ListView gives unbounded main-
                  // axis height, so without this the loader just sits near the
                  // top of the screen instead of looking centered.
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(child: AppLoader.page()),
                  )
                else if (_selection.branchId == null && !hasDetails)
                  _EmptyState(
                      message: context.t('Select a salon in Bookings first'))
                else if (_error != null && !hasDetails)
                  _EmptyState(message: _error!)
                else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? context.t('About Salon') : name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_selection.label.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _selection.label,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasDetails) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_outlined,
                                    color: AppColors.starColor),
                                const SizedBox(width: 12),
                                Text(
                                  context.t('Working Hours'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...List.generate(scheduleRows.length, (index) {
                            final (day, timeText) = scheduleRows[index];
                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDay(day),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        timeText,
                                        style: const TextStyle(
                                          color: Colors.black54,
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
                    ),
                  ],
                  _infoTile(
                    icon: Icons.call_outlined,
                    title: context.t('Phone'),
                    value: phone,
                  ),
                  _infoTile(
                    icon: Icons.location_on_outlined,
                    title: context.t('Address'),
                    value: address,
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.t('Photos'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              photos[index],
                              width: 140,
                              height: 108,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 140,
                                height: 108,
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (_loading && hasDetails)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline,
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
