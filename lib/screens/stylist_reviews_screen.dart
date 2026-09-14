import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/app_loader.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistReviewsScreen extends StatefulWidget {
  const StylistReviewsScreen({super.key});

  @override
  State<StylistReviewsScreen> createState() => _StylistReviewsScreenState();
}

class _StylistReviewsScreenState extends State<StylistReviewsScreen> {
  final ApiService _apiService = ApiService();

  StylistBranchSelection _selection = const StylistBranchSelection();
  List<Map<String, dynamic>> _reviews = const [];
  bool _loading = true;
  String? _error;
  double _overallRating = 0;
  int _totalReviews = 0;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final selection = await StylistBranchSelectionStore.load();
    if (!mounted) return;

    setState(() {
      _selection = selection;
      _loading = true;
      _error = null;
    });

    if (selection.branchId == null) {
      setState(() {
        _reviews = const [];
        _overallRating = 0;
        _totalReviews = 0;
        _loading = false;
      });
      return;
    }

    try {
      final response = await _apiService.fetchMyAppointmentRatings(
        selection.branchId!,
      );
      final payload = response['data'];
      final summary = payload is Map ? payload['summary'] : null;
      final rawReviews = payload is Map && payload['reviews'] is List
          ? payload['reviews'] as List
          : const [];
      final reviews = rawReviews
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _reviews = reviews;
          _overallRating = summary is Map
              ? (summary['averageRating'] as num?)?.toDouble() ?? 0.0
              : 0.0;
          _totalReviews = summary is Map
              ? (summary['totalReviews'] as num?)?.toInt() ?? reviews.length
              : reviews.length;
          _loading = false;
        });
      } else {
        setState(() {
          _reviews = const [];
          _overallRating = 0;
          _totalReviews = 0;
          _error = response['message']?.toString() ?? 'Failed to load reviews';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviews = const [];
        _overallRating = 0;
        _totalReviews = 0;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Reviews')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => RefreshFeedback.playAndDetach(_loadReviews),
            color: AppColors.starColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (_selection.branchId == null)
                  _EmptyState(
                    message: context.t('Select a salon in Bookings first'),
                  )
                else if (_error != null)
                  _EmptyState(message: _error!)
                else ...[
                  _ReviewSummaryCard(
                    subtitle: context.t(
                      'See what our customers are saying about us',
                    ),
                    rating: _overallRating,
                    totalReviews: _totalReviews,
                    reviews: _reviews,
                  ),
                  const SizedBox(height: 16),
                  if (_reviews.isEmpty)
                    _EmptyState(message: context.t('No reviews found'))
                  else
                    ..._reviews.map((review) {
                      final reviewer = review['reviewer'] is Map
                          ? Map<String, dynamic>.from(review['reviewer'] as Map)
                          : const <String, dynamic>{};
                      final reviewerName =
                          '${reviewer['firstName'] ?? ''} ${reviewer['lastName'] ?? ''}'
                              .trim();
                      final createdAt = DateTime.tryParse(
                              review['createdAt']?.toString() ?? '')
                          ?.toLocal();
                      final comment =
                          (review['comment'] ?? '').toString().trim();
                      final rating =
                          (review['rating'] as num?)?.toDouble() ?? 0.0;

                      return _ReviewCard(
                        reviewerName: reviewerName.isNotEmpty
                            ? reviewerName
                            : context.t('Customer'),
                        createdAtText: createdAt == null
                            ? ''
                            : _dateFormat.format(createdAt),
                        comment: comment,
                        rating: rating,
                        appointmentId:
                            review['appointmentId']?.toString() ?? '',
                        appointmentItemId:
                            review['appointmentItemId']?.toString() ?? '',
                      );
                    }),
                ],
              ],
            ),
          ),
          if (_loading)
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

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.subtitle,
    required this.rating,
    required this.totalReviews,
    required this.reviews,
  });

  final String subtitle;
  final double rating;
  final int totalReviews;
  final List<Map<String, dynamic>> reviews;

  int _bucketCount(int stars) {
    return reviews.where((review) {
      final value = review['rating'];
      final parsed =
          value is num ? value.toDouble() : double.tryParse('$value');
      return parsed?.round() == stars;
    }).length;
  }

  Widget _stars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: AppColors.starColor,
          size: 15,
        );
      }),
    );
  }

  Widget _bars(BuildContext context) {
    final rows = [
      (label: 'Excellent', stars: 5, color: const Color(0xFF22C55E)),
      (label: 'Good', stars: 4, color: const Color(0xFF22C55E)),
      (label: 'Average', stars: 3, color: const Color(0xFFE5E7EB)),
      (label: 'Bad', stars: 2, color: const Color(0xFFEF4444)),
      (label: 'Very Bad', stars: 1, color: const Color(0xFFEF4444)),
    ];

    return Column(
      children: rows.map((row) {
        final count = _bucketCount(row.stars);
        final percent = totalReviews <= 0 ? 0.0 : count / totalReviews;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  context.t(row.label),
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: percent,
                    color: row.color,
                    backgroundColor: const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${(percent * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;
          final ratingPanel = SizedBox(
            width: compact ? double.infinity : 106,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 4),
                _stars(),
                const SizedBox(height: 4),
                Text(
                  '$totalReviews ${context.t(totalReviews == 1 ? 'Professional Review' : 'Professional Reviews')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78716C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          final bars = _bars(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('Customer Reviews'),
                style: const TextStyle(
                  color: AppColors.starColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF78716C),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (compact) ...[
                ratingPanel,
                const SizedBox(height: 14),
                bars,
              ] else
                Row(
                  children: [
                    ratingPanel,
                    Container(
                      height: 104,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: 1,
                      color: const Color(0xFFE8DED6),
                    ),
                    Expanded(child: bars),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.reviewerName,
    required this.createdAtText,
    required this.comment,
    required this.rating,
    required this.appointmentId,
    required this.appointmentItemId,
  });

  final String reviewerName;
  final String createdAtText;
  final String comment;
  final double rating;
  final String appointmentId;
  final String appointmentItemId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    if (createdAtText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        createdAtText,
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ReviewStars(rating: rating),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              comment,
              style: const TextStyle(
                color: Color(0xFF44403C),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (appointmentId.isNotEmpty || appointmentItemId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (appointmentId.isNotEmpty)
                  _ReviewMetaChip(
                    label: '${context.t('Appointment')} $appointmentId',
                  ),
                if (appointmentItemId.isNotEmpty)
                  _ReviewMetaChip(
                      label: '${context.t('Item')} $appointmentItemId'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: AppColors.starColor,
          size: 18,
        );
      }),
    );
  }
}

class _ReviewMetaChip extends StatelessWidget {
  const _ReviewMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF57534E),
          fontWeight: FontWeight.w700,
        ),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
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
