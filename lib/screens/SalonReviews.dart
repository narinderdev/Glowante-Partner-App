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

class _SalonReviewsState extends State<SalonReviews> {
  bool loading = true;
  List<Map<String, dynamic>> appointmentReviews = [];
  double overallRating = 0;
  int totalReviews = 0;

  List<_ReviewBranchOption> _branchOptions = const <_ReviewBranchOption>[];
  _ReviewBranchOption? _selectedBranch;
  int? _branchId;
  String? _error;

  final dateFormat = DateFormat('dd MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _loadBranchesAndReviews();
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
        _branchId = null;
        _error = null;
        appointmentReviews = [];
        overallRating = 0;
        totalReviews = 0;
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

        List<Map<String, dynamic>> apptReviews = [];
        List<int> allRatings = [];

        for (var appt in appointments) {
          final start = DateTime.parse(appt["startAt"]).toLocal();
          final end = DateTime.parse(appt["endAt"]).toLocal();

          Map<String, dynamic> apptData = {
            "appointmentId": appt["appointmentId"].toString(),
            "startAt": start,
            "endAt": end,
            "client":
                "${appt["client"]?["firstName"] ?? ""} ${appt["client"]?["lastName"] ?? ""}",
            "branchReview": null,
            "clientReview": null,
            "professionalReviews": <Map<String, dynamic>>[],
          };

          // 🏢 Branch review (client → salon)
          if (appt["branchReview"] != null) {
            final r = appt["branchReview"];
            allRatings.add(r["rating"]);
            apptData["branchReview"] = {
              "rating": r["rating"],
              "comment": r["comment"],
              "reviewer":
                  "${r["reviewer"]?["firstName"] ?? ""} ${r["reviewer"]?["lastName"] ?? ""}",
              "date": DateTime.parse(r["createdAt"]).toLocal(),
            };
          }

          // 🙍 Client review (salon → client)
          if (appt["clientReview"] != null) {
            final r = appt["clientReview"];
            allRatings.add(r["rating"]);
            apptData["clientReview"] = {
              "rating": r["rating"],
              "comment": r["comment"],
              "reviewer":
                  "${r["recordedBy"]?["firstName"] ?? ""} ${r["recordedBy"]?["lastName"] ?? ""}",
              "target":
                  "${r["targetUser"]?["firstName"] ?? ""} ${r["targetUser"]?["lastName"] ?? ""}",
              "date": DateTime.parse(r["createdAt"]).toLocal(),
            };
          }

          // 👩‍🎨 Professional reviews (client → staff)
          if (appt["professionalReviews"] != null) {
            for (var r in appt["professionalReviews"]) {
              apptData["professionalReviews"].add({
                "professional":
                    "${r["professional"]?["firstName"] ?? "Unknown"} ${r["professional"]?["lastName"] ?? ""}",
                "rating": r["rating"],
                "comment": r["comment"],
                "date": DateTime.parse(r["createdAt"]).toLocal(),
              });
            }
          }

          apptReviews.add(apptData);
        }

        // ✅ Compute overall salon rating (only branch reviews)
        double avg = allRatings.isNotEmpty
            ? allRatings.reduce((a, b) => a + b) / allRatings.length
            : 0.0;

        setState(() {
          appointmentReviews = apptReviews;
          totalReviews = allRatings.length;
          overallRating = avg;
          loading = false;
          _error = null;
          _branchId = branchId;
        });
      } else {
        setState(() {
          loading = false;
          appointmentReviews = [];
          overallRating = 0;
          totalReviews = 0;
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

  Widget buildStars(int rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _reviewSurface,
      appBar: buildProfileSubpageAppBar(title: translateText('Reviews')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_branchOptions.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildBranchSelector(),
              ),
            ],
            Expanded(child: _buildReviewsContent(context)),
          ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalReviews > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
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
                      overallRating.toStringAsFixed(1),
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
                      buildStars(overallRating.round()),
                      const SizedBox(height: 4),
                      Text(
                        '($totalReviews Reviews)',
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
            ),
            const SizedBox(height: 20),
          ],
          appointmentReviews.isEmpty
              ? _statePanel(
                  icon: Icons.reviews_outlined,
                  title: 'No reviews yet',
                  message: 'Reviews will appear here after appointments.',
                )
              : Column(
                  children: appointmentReviews
                      .where(
                    (appt) =>
                        appt['branchReview'] != null ||
                        appt['clientReview'] != null ||
                        (appt['professionalReviews'] as List).isNotEmpty,
                  )
                      .map((appt) {
                    final hasBranchReview = appt['branchReview'] != null;
                    final hasClientReview = appt['clientReview'] != null;
                    final hasProfessionalReviews =
                        (appt['professionalReviews'] as List).isNotEmpty;

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
                              '${appt["client"]}',
                              style: const TextStyle(
                                color: _reviewMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Start: ${dateFormat.format(appt["startAt"])}',
                              style: const TextStyle(color: _reviewMuted),
                            ),
                            Text(
                              'End: ${dateFormat.format(appt["endAt"])}',
                              style: const TextStyle(color: _reviewMuted),
                            ),
                            const SizedBox(height: 10),
                            if (hasBranchReview) ...[
                              Text(
                                translateText('Review given for you'),
                                style: const TextStyle(
                                  color: _reviewInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  buildStars(appt['branchReview']['rating']),
                                  const SizedBox(width: 5),
                                  Text('${appt["branchReview"]["rating"]}'),
                                ],
                              ),
                              if ((appt['branchReview']['comment'] ?? '')
                                  .isNotEmpty)
                                Text(
                                  appt['branchReview']['comment'],
                                  style: const TextStyle(color: _reviewMuted),
                                ),
                              if (hasClientReview || hasProfessionalReviews)
                                const Divider(),
                            ],
                            if (hasClientReview) ...[
                              Text(
                                translateText('Customer Review'),
                                style: const TextStyle(
                                  color: _reviewInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  buildStars(appt['clientReview']['rating']),
                                  const SizedBox(width: 5),
                                  Text('${appt["clientReview"]["rating"]}'),
                                ],
                              ),
                              if ((appt['clientReview']['comment'] ?? '')
                                  .isNotEmpty)
                                Text(
                                  appt['clientReview']['comment'],
                                  style: const TextStyle(color: _reviewMuted),
                                ),
                              if (hasProfessionalReviews) const Divider(),
                            ],
                            if (hasProfessionalReviews)
                              ...((appt['professionalReviews']
                                      as List<Map<String, dynamic>>)
                                  .map((r) => Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${r["professional"]}',
                                              style: const TextStyle(
                                                color: _reviewInk,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                buildStars(r['rating']),
                                                const SizedBox(width: 5),
                                                Text('${r["rating"]}'),
                                              ],
                                            ),
                                            if ((r['comment'] ?? '').isNotEmpty)
                                              Text(
                                                r['comment'],
                                                style: const TextStyle(
                                                  color: _reviewMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
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
