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
                    branchName: _selection.label.isEmpty
                        ? context.t('Reviews')
                        : _selection.label,
                    rating: _overallRating,
                    totalReviews: _totalReviews,
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
    required this.branchName,
    required this.rating,
    required this.totalReviews,
  });

  final String branchName;
  final double rating;
  final int totalReviews;

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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.starColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 8),
                _ReviewStars(rating: rating),
                const SizedBox(height: 6),
                Text(
                  '$totalReviews ${context.t(totalReviews == 1 ? 'Review' : 'Reviews')}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78716C),
                    fontWeight: FontWeight.w600,
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
