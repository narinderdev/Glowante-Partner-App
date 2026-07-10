import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
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

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round() ? Icons.star : Icons.star_border,
          color: AppColors.starColor,
          size: 18,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Reviews')),
      body: RefreshIndicator(
        onRefresh: () => RefreshFeedback.playAndRun(_loadReviews),
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selection.branchId == null)
              _EmptyState(
                message: context.t('Select a salon in Bookings first'),
              )
            else if (_error != null)
              _EmptyState(message: _error!)
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _selection.label.isEmpty
                          ? context.t('Reviews')
                          : _selection.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _overallRating.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.starColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _stars(_overallRating),
                    const SizedBox(height: 8),
                    Text(
                      '($_totalReviews ${context.t('Reviews')})',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
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
                  final createdAt =
                      DateTime.tryParse(review['createdAt']?.toString() ?? '')
                          ?.toLocal();
                  final comment = (review['comment'] ?? '').toString().trim();
                  final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewerName.isNotEmpty
                              ? reviewerName
                              : context.t('Customer'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _dateFormat.format(createdAt),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _stars(rating),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            comment,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          '${context.t('Appointment')}: ${review['appointmentId'] ?? '--'}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${context.t('Item')}: ${review['appointmentItemId'] ?? '--'}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
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
        borderRadius: BorderRadius.circular(16),
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
