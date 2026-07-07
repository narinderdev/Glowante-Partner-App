import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const Color _reviewGold = Color(0xFF8B6500);
const Color _reviewInk = Color(0xFF1F1B18);
const Color _reviewMuted = Color(0xFF6F665E);
const Color _reviewBorder = Color(0xFFE8DED6);
const Color _reviewSoftGold = Color(0xFFF5EAD2);
const Color _reviewSurface = Color(0xFFFBFAF8);

class SalonReviews extends StatefulWidget {
  final int? branchId;

  const SalonReviews({super.key, this.branchId});

  @override
  State<SalonReviews> createState() => _SalonReviewsState();
}

class _SalonReviewsState extends State<SalonReviews>
    with SingleTickerProviderStateMixin {
  bool loading = true;

  List<Map<String, dynamic>> salonReviews = [];
  List<Map<String, dynamic>> professionalReviews = [];
  List<Map<String, dynamic>> clientReviews = [];

  double salonRating = 0;
  double professionalRating = 0;
  double clientRating = 0;

  List<_ReviewBranchOption> _branchOptions = const [];
  _ReviewBranchOption? _selectedBranch;
  int? _branchId;
  String? _error;

  late TabController _tabController;

  final dateFormat = DateFormat('dd MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBranchesAndReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  double _avg(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> _loadBranchesAndReviews() async {
    setState(() {
      loading = true;
      _error = null;
    });

    int? id = widget.branchId;
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getInt('selected_branch_id') ??
          (await StylistBranchSelectionStore.load()).branchId;
    }

    final response = await ApiService().getSalonListApi();
    final rawSalons =
        response['data'] is List ? response['data'] as List : const [];

    final options = _extractBranchOptions(rawSalons);
    final selected = options.cast<_ReviewBranchOption?>().firstWhere(
          (option) => option?.branchId == id,
          orElse: () => options.isEmpty ? null : options.first,
        );

    if (!mounted) return;

    setState(() {
      _branchOptions = options;
      _selectedBranch = selected;
      _branchId = selected?.branchId;
    });

    if (selected == null) {
      setState(() {
        loading = false;
        salonReviews = [];
        professionalReviews = [];
        clientReviews = [];
      });
      return;
    }

    await fetchReviews(selected.branchId);
  }

  List<_ReviewBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_ReviewBranchOption>[];

    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) continue;

      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _asInt(salon['id']);
      if (salonId == null) continue;

      final salonName = _cleanText(salon['name']);
      final branches = (salon['branches'] as List?) ?? const [];

      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;

        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asInt(branch['id']);
        if (branchId == null) continue;

        options.add(
          _ReviewBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _addressSummary(branch['address']),
          ),
        );
      }
    }

    return options;
  }

  String _addressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';

    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    for (final key in ['line1', 'line2', 'city', 'state']) {
      final value = _cleanText(address[key]);
      if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
    }

    return parts.take(2).join(', ');
  }

  Future<void> _switchBranch(_ReviewBranchOption branch) async {
    setState(() {
      _selectedBranch = branch;
      _branchId = branch.branchId;
      loading = true;
      _error = null;
    });

    await StylistBranchSelectionStore.save(
      salonId: branch.salonId,
      branchId: branch.branchId,
      salonName: branch.salonName,
      branchName: branch.branchName,
    );

    await fetchReviews(branch.branchId);
  }

  Future<void> fetchReviews(int branchId) async {
    try {
      final data = await ApiService.fetchBranchRatings(branchId);

      if (data["success"] == true && data["data"]?["appointments"] != null) {
        final appointments = data["data"]["appointments"] as List;

        final salonList = <Map<String, dynamic>>[];
        final professionalList = <Map<String, dynamic>>[];
        final clientList = <Map<String, dynamic>>[];

        final salonRatings = <int>[];
        final professionalRatings = <int>[];
        final clientRatings = <int>[];

        for (final appt in appointments) {
          final start = DateTime.parse(appt["startAt"]).toLocal();
          final end = DateTime.parse(appt["endAt"]).toLocal();

          final clientName =
              "${appt["client"]?["firstName"] ?? ""} ${appt["client"]?["lastName"] ?? ""}"
                  .trim();

          final common = {
            "appointmentId": appt["appointmentId"].toString(),
            "startAt": start,
            "endAt": end,
            "client": clientName,
          };

          // Client/User -> Salon
          if (appt["branchReview"] != null) {
            final r = appt["branchReview"];
            final rating = _asInt(r["rating"]) ?? 0;
            salonRatings.add(rating);

            salonList.add({
              ...common,
              "rating": rating,
              "comment": _cleanText(r["comment"]),
              "reviewer":
                  "${r["reviewer"]?["firstName"] ?? ""} ${r["reviewer"]?["lastName"] ?? ""}"
                      .trim(),
              "date": DateTime.parse(r["createdAt"]).toLocal(),
            });
          }

          // Client/User -> Professional(s)
          if (appt["professionalReviews"] != null) {
            for (final r in appt["professionalReviews"]) {
              final rating = _asInt(r["rating"]) ?? 0;
              professionalRatings.add(rating);

              professionalList.add({
                ...common,
                "professional":
                    "${r["professional"]?["firstName"] ?? "Unknown"} ${r["professional"]?["lastName"] ?? ""}"
                        .trim(),
                "rating": rating,
                "comment": _cleanText(r["comment"]),
                "date": DateTime.parse(r["createdAt"]).toLocal(),
              });
            }
          }

          // Salon Owner -> Client/User
          if (appt["clientReview"] != null) {
            final r = appt["clientReview"];
            final rating = _asInt(r["rating"]) ?? 0;
            clientRatings.add(rating);

            clientList.add({
              ...common,
              "rating": rating,
              "comment": _cleanText(r["comment"]),
              "reviewer":
                  "${r["recordedBy"]?["firstName"] ?? ""} ${r["recordedBy"]?["lastName"] ?? ""}"
                      .trim(),
              "target":
                  "${r["targetUser"]?["firstName"] ?? ""} ${r["targetUser"]?["lastName"] ?? ""}"
                      .trim(),
              "date": DateTime.parse(r["createdAt"]).toLocal(),
            });
          }
        }

        if (!mounted) return;

        setState(() {
          salonReviews = salonList;
          professionalReviews = professionalList;
          clientReviews = clientList;

          salonRating = _avg(salonRatings);
          professionalRating = _avg(professionalRatings);
          clientRating = _avg(clientRatings);

          loading = false;
          _error = null;
          _branchId = branchId;
        });
      } else {
        if (!mounted) return;

        setState(() {
          loading = false;
          salonReviews = [];
          professionalReviews = [];
          clientReviews = [];
          salonRating = 0;
          professionalRating = 0;
          clientRating = 0;
          _error = null;
          _branchId = branchId;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        _error = e.toString();
      });
    }
  }

  Widget buildStars(num rating) {
    final rounded = rating.round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rounded ? Icons.star : Icons.star_border,
          color: _reviewGold,
          size: 18,
        );
      }),
    );
  }

  Widget _statePanel({
    required IconData icon,
    required String title,
    required String message,
    bool loading = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _reviewBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _reviewSoftGold,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          color: _reviewGold,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Icon(icon, color: _reviewGold, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                translateText(title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _reviewInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                translateText(message),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _reviewMuted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    final selected = _selectedBranch;

    return OwnerBranchHeaderSelector<_ReviewBranchOption>(
      label: selected?.displayLabel ?? context.t('Select Branch'),
      options: _branchOptions
          .map(
            (option) => OwnerBranchHeaderSelectorOption<_ReviewBranchOption>(
              value: option,
              label: option.displayLabel,
              subtitle: option.address,
            ),
          )
          .toList(),
      selectedValue: selected,
      placeholder: context.t('Select Branch'),
      isInteractive: _branchOptions.length > 1,
      onSelected: _switchBranch,
    );
  }

  Widget _summaryCard({
    required double rating,
    required int total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _reviewBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _reviewSoftGold,
              shape: BoxShape.circle,
            ),
            child: Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: _reviewGold,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildStars(rating),
              const SizedBox(height: 4),
              Text(
                '($total ${translateText('Reviews')})',
                style: const TextStyle(
                  color: _reviewMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appointmentInfo(Map<String, dynamic> review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText('Appointment Details'),
          style: const TextStyle(
            color: _reviewInk,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${review["client"]}',
          style: const TextStyle(
            color: _reviewMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Start: ${dateFormat.format(review["startAt"])}',
          style: const TextStyle(color: _reviewMuted),
        ),
        Text(
          'End: ${dateFormat.format(review["endAt"])}',
          style: const TextStyle(color: _reviewMuted),
        ),
      ],
    );
  }

  Widget _reviewCard({
    required Map<String, dynamic> review,
    required String title,
    String? extraLabel,
    String? extraValue,
    bool showReviewer = true,
    bool showTarget = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _reviewBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _appointmentInfo(review),
            const SizedBox(height: 10),
            Text(
              translateText(title),
              style: const TextStyle(
                color: _reviewInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (extraLabel != null &&
                extraValue != null &&
                extraValue.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${translateText(extraLabel)}: $extraValue',
                style: const TextStyle(
                  color: _reviewInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                buildStars(review['rating']),
                const SizedBox(width: 5),
                Text('${review["rating"]}'),
              ],
            ),
            if ((review['comment'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review['comment'],
                style: const TextStyle(color: _reviewMuted),
              ),
            ],
            if (showReviewer &&
                (review['reviewer'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${translateText('Reviewer')}: ${review["reviewer"]}',
                style: const TextStyle(color: _reviewMuted),
              ),
            ],
            if (showTarget &&
                (review['target'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${translateText('Client')}: ${review["target"]}',
                style: const TextStyle(color: _reviewMuted),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${translateText('Created At')}: ${dateFormat.format(review["date"])}',
              style: const TextStyle(color: _reviewMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContent({
    required List<Map<String, dynamic>> reviews,
    required double rating,
    required String emptyTitle,
    required String emptyMessage,
    required String cardTitle,
    String? extraLabel,
    String? extraKey,
    bool showReviewer = true,
    bool showTarget = false,
  }) {
    if (reviews.isEmpty) {
      return _statePanel(
        icon: Icons.reviews_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryCard(rating: rating, total: reviews.length),
          ...reviews.map(
            (review) => _reviewCard(
              review: review,
              title: cardTitle,
              extraLabel: extraLabel,
              extraValue: extraKey == null ? null : review[extraKey],
              showReviewer: showReviewer,
              showTarget: showTarget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsContent(BuildContext context) {
    if (loading) {
      return _statePanel(
        icon: Icons.reviews_rounded,
        title: 'Loading reviews',
        message: 'Fetching customer and appointment reviews.',
        loading: true,
      );
    }

    if (_branchId == null) {
      return _statePanel(
        icon: Icons.storefront_rounded,
        title: 'Select a branch',
        message: 'Select a branch to view reviews.',
      );
    }

    if (_error != null) {
      return _statePanel(
        icon: Icons.error_outline_rounded,
        title: 'Failed to reach server',
        message: _error!,
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _tabContent(
          reviews: salonReviews,
          rating: salonRating,
          emptyTitle: 'No salon reviews yet',
          emptyMessage: 'Salon reviews will appear here after appointments.',
          cardTitle: 'Salon Review',
        ),
        _tabContent(
          reviews: professionalReviews,
          rating: professionalRating,
          emptyTitle: 'No professional reviews yet',
          emptyMessage:
              'Professional reviews will appear here after appointments.',
          cardTitle: 'Professional Review',
          extraLabel: 'Professional',
          extraKey: 'professional',
          showReviewer: false,
        ),
        _tabContent(
          reviews: clientReviews,
          rating: clientRating,
          emptyTitle: 'No client reviews yet',
          emptyMessage: 'Reviews given to clients will appear here.',
          cardTitle: 'Review Given To Client',
          showReviewer: true,
          showTarget: true,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_branchOptions.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildBranchSelector(),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _reviewBorder),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _reviewGold,
                unselectedLabelColor: _reviewMuted,
                indicatorColor: _reviewGold,
                tabs: [
                  Tab(text: translateText('Salon Reviews')),
                  Tab(text: translateText('Professional Reviews')),
                  Tab(text: translateText('Client Reviews')),
                ],
              ),
            ),
            Expanded(child: _buildReviewsContent(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _reviewSurface,
      appBar: buildProfileSubpageAppBar(title: translateText('Reviews')),
      body: _buildBody(context),
    );
  }
}

class _ReviewBranchOption {
  const _ReviewBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get displayLabel {
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (salonName.trim().isNotEmpty) return salonName.trim();
    return 'Branch #$branchId';
  }
}