import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

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
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
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
            if (_branchOptions.isNotEmpty) ...[
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_branchId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t('Select a branch to view reviews'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('Failed to reach server'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalReviews > 0) ...[
            Row(
              children: [
                Text(
                  overallRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildStars(overallRating.round()),
                    Text(
                      '($totalReviews Reviews)',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          appointmentReviews.isEmpty
              ? Text(
                  translateText('No reviews yet.'),
                  style: const TextStyle(color: Colors.grey),
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

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translateText('Appointment Details'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text('${appt["client"]}'),
                            Text(
                                'Start: ${dateFormat.format(appt["startAt"])}'),
                            Text('End: ${dateFormat.format(appt["endAt"])}'),
                            const SizedBox(height: 10),
                            if (hasBranchReview) ...[
                              Text(
                                translateText('🏢 Review given for you'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
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
                                Text(appt['branchReview']['comment']),
                              if (hasClientReview || hasProfessionalReviews)
                                const Divider(),
                            ],
                            if (hasClientReview) ...[
                              Text(
                                translateText('Customer Review'),
                                style: const TextStyle(
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
                                Text(appt['clientReview']['comment']),
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
                                                fontWeight: FontWeight.bold,
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
                                              Text(r['comment']),
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
