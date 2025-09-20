import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/api_service.dart';

class ReviewsScreen extends StatefulWidget {
  final int branchId;

  const ReviewsScreen({required this.branchId, Key? key}) : super(key: key);

  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> appointmentReviews = [];
  double overallRating = 0;
  int totalReviews = 0;

  final dateFormat = DateFormat("dd MMM yyyy, HH:mm 'UTC'");

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
  try {
    final data = await ApiService.fetchBranchRatings(widget.branchId);
    if (data["success"] == true && data["data"]?["appointments"] != null) {
      final appointments = data["data"]["appointments"] as List;

      List<Map<String, dynamic>> apptReviews = [];
      List<int> allRatings = []; // only branch reviews now

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

        // 🏢 Branch review (client → salon) ✅ included in overall average
        if (appt["branchReview"] != null) {
          final r = appt["branchReview"];
          allRatings.add(r["rating"]); // ✅ only branch reviews counted
          apptData["branchReview"] = {
            "rating": r["rating"],
            "comment": r["comment"],
            "reviewer":
                "${r["reviewer"]?["firstName"] ?? ""} ${r["reviewer"]?["lastName"] ?? ""}",
            "date": DateTime.parse(r["createdAt"]).toUtc(),
          };
        }

        // 🙍 Client review (salon → client) ❌ not counted in overall
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

        // 👩‍🎨 Professional reviews (client → staff) ❌ not counted in overall
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

      // ✅ Compute overall salon rating only from branch reviews
      double avg = allRatings.isNotEmpty
          ? allRatings.reduce((a, b) => a + b) / allRatings.length
          : 0.0;

      setState(() {
        appointmentReviews = apptReviews;
        totalReviews = allRatings.length;
        overallRating = avg;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  } catch (e) {
    print("Error fetching reviews: $e");
    setState(() => loading = false);
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
      backgroundColor: Colors.grey[100],
      appBar: null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Overall salon rating
                  if (totalReviews > 0) ...[
                    Row(
                      children: [
                        Text(
                          overallRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildStars(overallRating.round()),
                            Text("($totalReviews Reviews)",
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ✅ Appointment reviews
                  appointmentReviews.isEmpty
                      ? const Text("No reviews yet.",
                          style: TextStyle(color: Colors.grey))
                      : Column(
                          children: appointmentReviews.map((appt) {
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 15),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 📅 Appointment details
                                    Text("Appointment Details",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    // Text("Appointment ID: ${appt["appointmentId"]}"),
                                    Text("Client: ${appt["client"]}"),
                                    Text("Start: ${dateFormat.format(appt["startAt"])}"),
                                    Text("End: ${dateFormat.format(appt["endAt"])}"),
                                    const SizedBox(height: 10),

                                    // 🏢 Branch review
                                    if (appt["branchReview"] != null) ...[
                                      const Text("🏢 Review given for you",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Row(
                                        children: [
                                          buildStars(appt["branchReview"]["rating"]),
                                          const SizedBox(width: 5),
                                          Text("${appt["branchReview"]["rating"]}"),
                                        ],
                                      ),
                                      if ((appt["branchReview"]["comment"] ?? "").isNotEmpty)
                                        Text(appt["branchReview"]["comment"]),
                                      Text(
                                          "Reviewer: ${appt["branchReview"]["reviewer"]}"),
                                      Text(
                                          "Created At: ${dateFormat.format(appt["branchReview"]["date"])}"),
                                      const Divider(),
                                    ],

                                    // 🙍 Client review (branch → client)
                                    if (appt["clientReview"] != null) ...[
                                      const Text("Review given by you",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Row(
                                        children: [
                                          buildStars(appt["clientReview"]["rating"]),
                                          const SizedBox(width: 5),
                                          Text("${appt["clientReview"]["rating"]}"),
                                        ],
                                      ),
                                      if ((appt["clientReview"]["comment"] ?? "").isNotEmpty)
                                        Text(appt["clientReview"]["comment"]),
                                      Text(
                                          "Recorded By: ${appt["clientReview"]["reviewer"]}"),
                                      Text(
                                          "Target User: ${appt["clientReview"]["target"]}"),
                                      Text(
                                          "Created At: ${dateFormat.format(appt["clientReview"]["date"])}"),
                                      const Divider(),
                                    ],

                                    // 👩‍🎨 Professional reviews
                                    if ((appt["professionalReviews"] as List).isNotEmpty) ...[
                                      const Text("Your professional",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      ...(appt["professionalReviews"]
                                              as List<Map<String, dynamic>>)
                                          .map((r) => Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text("Professional: ${r["professional"]}",
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                    Row(
                                                      children: [
                                                        buildStars(r["rating"]),
                                                        const SizedBox(width: 5),
                                                        Text("${r["rating"]}"),
                                                      ],
                                                    ),
                                                    if ((r["comment"] ?? "").isNotEmpty)
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
