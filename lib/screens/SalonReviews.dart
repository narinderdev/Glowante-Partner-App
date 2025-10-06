import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';

class SalonReviews extends StatefulWidget {
  final int? branchId;

  const SalonReviews({Key? key, this.branchId}) : super(key: key);

  @override
  _SalonReviewsState createState() => _SalonReviewsState();
}

class _SalonReviewsState extends State<SalonReviews> {
  bool loading = true;
  List<Map<String, dynamic>> appointmentReviews = [];
  double overallRating = 0;
  int totalReviews = 0;

  int? _branchId; // ✅ Added
  String? _error; // ✅ Added

  final dateFormat = DateFormat("dd MMM yyyy, HH:mm 'UTC'");

  @override
  void initState() {
    super.initState();
    _resolveBranchId();
  }

  Future<void> _resolveBranchId() async {
    int? id = widget.branchId;
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getInt('selected_branch_id');
    }

    if (!mounted) return;

    if (id == null) {
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

    setState(() {
      _branchId = id;
      loading = true;
      _error = null;
    });

    await fetchReviews(id);
  }

  Future<void> fetchReviews(int branchId) async {
    try {
      final data = await ApiService.fetchBranchRatings(branchId);
      if (data["success"] == true && data["data"]?["appointments"] != null) {
        final appointments = data["data"]["appointments"] as List;

        List<Map<String, dynamic>> apptReviews = [];
        List<int> allRatings = [];

        for (var appt in appointments) {
          final start = DateTime.parse(appt["startAt"]).toUtc();
          final end = DateTime.parse(appt["endAt"]).toUtc();

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
              "date": DateTime.parse(r["createdAt"]).toUtc(),
            };
          }

          // 🙍 Client review (salon → client)
          if (appt["clientReview"] != null) {
            final r = appt["clientReview"];
            apptData["clientReview"] = {
              "rating": r["rating"],
              "comment": r["comment"],
              "reviewer":
                  "${r["recordedBy"]?["firstName"] ?? ""} ${r["recordedBy"]?["lastName"] ?? ""}",
              "target":
                  "${r["targetUser"]?["firstName"] ?? ""} ${r["targetUser"]?["lastName"] ?? ""}",
              "date": DateTime.parse(r["createdAt"]).toUtc(),
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
                "date": DateTime.parse(r["createdAt"]).toUtc(),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(translateText('Reviews'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (_branchId == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.t('Select a branch to view reviews'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : (_error != null)
                  ? Center(
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
                    )
                  : SingleChildScrollView(
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
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    buildStars(overallRating.round()),
                                    Text("($totalReviews Reviews)",
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          appointmentReviews.isEmpty
                              ? Text(
                                  translateText("No reviews yet."),
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : Column(
                                  children: appointmentReviews.map((appt) {
                                    return Card(
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(bottom: 15),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              translateText(
                                                  "Appointment Details"),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                            Text("Client: ${appt["client"]}"),
                                            Text(
                                                "Start: ${dateFormat.format(appt["startAt"])}"),
                                            Text(
                                                "End: ${dateFormat.format(appt["endAt"])}"),
                                            const SizedBox(height: 10),

                                            // 🏢 Branch review
                                            if (appt["branchReview"] !=
                                                null) ...[
                                              Text(
                                                translateText(
                                                    "🏢 Review given for you"),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              Row(
                                                children: [
                                                  buildStars(appt["branchReview"]
                                                      ["rating"]),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                      "${appt["branchReview"]["rating"]}"),
                                                ],
                                              ),
                                              if ((appt["branchReview"]
                                                          ["comment"] ??
                                                      "")
                                                  .isNotEmpty)
                                                Text(appt["branchReview"]
                                                    ["comment"]),
                                              Text(
                                                  "Reviewer: ${appt["branchReview"]["reviewer"]}"),
                                              Text(
                                                  "Created At: ${dateFormat.format(appt["branchReview"]["date"])}"),
                                              const Divider(),
                                            ],

                                            // 🙍 Client review
                                            if (appt["clientReview"] !=
                                                null) ...[
                                              Text(
                                                translateText(
                                                    "Review given by you"),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              Row(
                                                children: [
                                                  buildStars(appt["clientReview"]
                                                      ["rating"]),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                      "${appt["clientReview"]["rating"]}"),
                                                ],
                                              ),
                                              if ((appt["clientReview"]
                                                          ["comment"] ??
                                                      "")
                                                  .isNotEmpty)
                                                Text(appt["clientReview"]
                                                    ["comment"]),
                                              Text(
                                                  "Recorded By: ${appt["clientReview"]["reviewer"]}"),
                                              Text(
                                                  "Target User: ${appt["clientReview"]["target"]}"),
                                              Text(
                                                  "Created At: ${dateFormat.format(appt["clientReview"]["date"])}"),
                                              const Divider(),
                                            ],

                                            // 👩‍🎨 Professional reviews
                                            if ((appt["professionalReviews"]
                                                    as List)
                                                .isNotEmpty) ...[
                                              Text(
                                                translateText(
                                                    "Your professional"),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              ...(appt["professionalReviews"]
                                                      as List<
                                                          Map<String, dynamic>>)
                                                  .map((r) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 8),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "Professional: ${r["professional"]}",
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                            Row(
                                                              children: [
                                                                buildStars(
                                                                    r["rating"]),
                                                                const SizedBox(
                                                                    width: 5),
                                                                Text(
                                                                    "${r["rating"]}"),
                                                              ],
                                                            ),
                                                            if ((r["comment"] ??
                                                                    "")
                                                                .isNotEmpty)
                                                              Text(r["comment"]),
                                                            Text(
                                                                "Created At: ${dateFormat.format(r["date"])}"),
                                                          ],
                                                        ),
                                                      ))
                                            ]
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                        ],
                      ),
                    ),
    );
  }
}
