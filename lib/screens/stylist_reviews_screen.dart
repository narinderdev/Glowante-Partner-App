import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
  StylistBranchSelection _selection = const StylistBranchSelection();
  List<Map<String, dynamic>> _appointmentReviews = const [];
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
        _appointmentReviews = const [];
        _overallRating = 0;
        _totalReviews = 0;
        _loading = false;
      });
      return;
    }

    try {
      final data = await ApiService.fetchBranchRatings(selection.branchId!);
      if (data['success'] == true && data['data']?['appointments'] != null) {
        final appointments = data['data']['appointments'] as List;

        final appointmentReviews = <Map<String, dynamic>>[];
        final allRatings = <int>[];

        for (final appt in appointments) {
          final start =
              DateTime.tryParse(appt['startAt']?.toString() ?? '')?.toLocal();
          final end =
              DateTime.tryParse(appt['endAt']?.toString() ?? '')?.toLocal();

          final appointmentData = <String, dynamic>{
            'appointmentId': appt['appointmentId']?.toString() ?? '',
            'startAt': start,
            'endAt': end,
            'client':
                '${appt['client']?['firstName'] ?? ''} ${appt['client']?['lastName'] ?? ''}'
                    .trim(),
            'branchReview': null,
            'professionalReviews': <Map<String, dynamic>>[],
          };

          final branchReview = appt['branchReview'];
          if (branchReview is Map) {
            final rating = branchReview['rating'];
            if (rating is int) {
              allRatings.add(rating);
            }
            appointmentData['branchReview'] = {
              'rating': branchReview['rating'],
              'comment': branchReview['comment'],
              'reviewer':
                  '${branchReview['reviewer']?['firstName'] ?? ''} ${branchReview['reviewer']?['lastName'] ?? ''}'
                      .trim(),
              'date':
                  DateTime.tryParse(branchReview['createdAt']?.toString() ?? '')
                      ?.toLocal(),
            };
          }

          final professionalReviews = appt['professionalReviews'];
          if (professionalReviews is List) {
            for (final review in professionalReviews) {
              if (review is! Map) continue;
              appointmentData['professionalReviews'].add({
                'professional':
                    '${review['professional']?['firstName'] ?? ''} ${review['professional']?['lastName'] ?? ''}'
                        .trim(),
                'rating': review['rating'],
                'comment': review['comment'],
                'date': DateTime.tryParse(review['createdAt']?.toString() ?? '')
                    ?.toLocal(),
              });
            }
          }

          appointmentReviews.add(appointmentData);
        }

        final overallRating = allRatings.isNotEmpty
            ? allRatings.reduce((a, b) => a + b) / allRatings.length
            : 0.0;

        if (!mounted) return;
        setState(() {
          _appointmentReviews = appointmentReviews;
          _overallRating = overallRating;
          _totalReviews = allRatings.length;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _appointmentReviews = const [];
          _overallRating = 0;
          _totalReviews = 0;
          _error = data['message']?.toString() ?? 'Failed to load reviews';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appointmentReviews = const [];
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
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          context.t('Reviews'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
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
                  message: context.t('Select a salon in Bookings first'))
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
                      _overallRating.toStringAsFixed(1),
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
              if (_appointmentReviews.isEmpty)
                _EmptyState(message: context.t('No reviews found'))
              else
                ..._appointmentReviews.map((appt) {
                  final branchReview =
                      appt['branchReview'] as Map<String, dynamic>?;
                  final professionalReviews =
                      (appt['professionalReviews'] as List?)
                              ?.cast<Map<String, dynamic>>() ??
                          const <Map<String, dynamic>>[];

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
                          (appt['client']?.toString().trim().isNotEmpty ??
                                  false)
                              ? appt['client'].toString()
                              : context.t('Customer'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (appt['startAt'] != null)
                          Text(
                            _dateFormat.format(appt['startAt'] as DateTime),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        if (branchReview != null) ...[
                          const SizedBox(height: 12),
                          _stars((branchReview['rating'] as num?)?.toDouble() ??
                              0),
                          const SizedBox(height: 8),
                          if ((branchReview['comment'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Text(
                              branchReview['comment'].toString(),
                              style: const TextStyle(color: Colors.black87),
                            ),
                        ],
                        if (professionalReviews.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            context.t('Professional Reviews'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...professionalReviews.map((review) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review['professional']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? review['professional'].toString()
                                        : context.t('Professional'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _stars(
                                      (review['rating'] as num?)?.toDouble() ??
                                          0),
                                  const SizedBox(height: 4),
                                  if ((review['comment'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      review['comment'].toString(),
                                      style: const TextStyle(
                                          color: Colors.black87),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
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
