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
  List<Map<String, dynamic>> _salons = [];
  bool loading = true;
  bool _loadingSalons = true;
  String? _salonError;
  List<Map<String, dynamic>> appointmentReviews = [];
  double overallRating = 0;
  int totalReviews = 0;

  int? _branchId; // ✅ Added
  String? _error; // ✅ Added

  final dateFormat = DateFormat("dd MMM yyyy, HH:mm 'UTC'");

  @override
  void initState() {
    super.initState();
    _loadSalons();
    _resolveBranchId();
  }
  List<Map<String, dynamic>> _normalizeSalonsList(Iterable<dynamic> raw) {
    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final rawBranches = (map['branches'] as List?) ?? const [];
        final branches = <Map<String, dynamic>>[];
        for (final branch in rawBranches) {
          if (branch is Map) {
            branches.add(Map<String, dynamic>.from(branch));
          }
        }
        map['branches'] = branches;
        result.add(map);
      }
    }
    return result;
  }

  String _branchAddressSummary(Map<String, dynamic> branch) {
    final address = branch['address'];
    if (address is Map) {
      final map = Map<String, dynamic>.from(address);
      final line1 = map['line1']?.toString().trim();
      if (line1 != null && line1.isNotEmpty) {
        return line1;
      }
    }
    return '';
  }

  List<_BranchOption> _computeBranchOptions() {
    final options = <_BranchOption>[];
    final seenBranchIds = <int>{};
    for (final salon in _salons) {
      final salonId = salon['id'];
      if (salonId is! int) continue;
      final salonName = (salon['name'] ?? '').toString();
      final branches = salon['branches'];
      if (branches is! List || branches.isEmpty) {
        continue;
      }
      for (final branchEntry in branches) {
        if (branchEntry is! Map || branchEntry.isEmpty) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = branch['id'];
        if (branchId is! int || !seenBranchIds.add(branchId)) continue;
        final branchName = (branch['name'] ?? '').toString();
        options.add(
          _BranchOption(
            salonId: salonId,
            salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
            branchId: branchId,
            branchName:
                branchName.isEmpty ? 'Branch #$branchId' : branchName,
            addressSummary: _branchAddressSummary(branch),
            branch: branch,
          ),
        );
      }
    }
    return options;
  }

  Future<void> _loadSalons() async {
    if (mounted) {
      setState(() {
        _loadingSalons = true;
        _salonError = null;
      });
    }
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final data = (response['data'] as List?)?.toList() ?? const [];
        final normalized = _normalizeSalonsList(data);
        if (!mounted) return;
        setState(() {
          _salons = normalized;
          _loadingSalons = false;
          _salonError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _salons = [];
          _loadingSalons = false;
          _salonError = (response['message'] ??
                  translateText('Failed to reach server'))
              .toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salons = [];
        _loadingSalons = false;
        _salonError = e.toString();
      });
    }
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

  Future<void> _onBranchSelected(_BranchOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_branch_id', option.branchId);
    await prefs.setInt('selected_salon_id', option.salonId);

    if (!mounted) return;
    setState(() {
      _branchId = option.branchId;
      loading = true;
      _error = null;
    });
    await fetchReviews(option.branchId);
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final branchOptions = _computeBranchOptions();
    _BranchOption? selectedOption;
    for (final option in branchOptions) {
      if (option.branchId == _branchId) {
        selectedOption = option;
        break;
      }
    }

    final branchHint = _loadingSalons
        ? context.t('Loading...')
        : (branchOptions.isEmpty
            ? context.t('No branches available')
            : context.t('Select Branch'));
    final List<DropdownMenuItem<int>> branchItems = branchOptions
        .map(
          (option) => DropdownMenuItem<int>(
            value: option.branchId,
            child: _BranchDropdownOption(option: option),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      translateText('Choose Branch'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_loadingSalons)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade100,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedOption?.branchId,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.starColor,
                      ),
                      dropdownColor: Colors.white,
                      items: branchItems,
                      selectedItemBuilder: branchItems.isNotEmpty
                          ? (context) => branchOptions
                              .map(
                                (option) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: _BranchDropdownOption(
                                    option: option,
                                    compact: true,
                                  ),
                                ),
                              )
                              .toList()
                          : null,
                      onChanged: _loadingSalons || branchOptions.isEmpty
                          ? null
                          : (newValue) {
                              if (newValue == null) return;
                              final option = branchOptions.firstWhere(
                                (element) => element.branchId == newValue,
                              );
                              _onBranchSelected(option);
                            },
                      hint: Text(
                        branchOptions.isEmpty
                            ? translateText('No branches available')
                            : branchHint,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_salonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _salonError!,
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
        if (selectedOption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '- ${translateText('Salon')}: ${selectedOption.salonName}',
                ),
                Text(
                  '- ${translateText('Branch')}: ${selectedOption.branchName}',
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Expanded(child: _buildReviewsContent(context)),
      ],
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
                      .where((appt) => appt['branchReview'] != null)
                      .map((appt) {
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
                            Text('Start: ${dateFormat.format(appt["startAt"])}'),
                            Text('End: ${dateFormat.format(appt["endAt"])}'),
                            const SizedBox(height: 10),
                            if (appt['branchReview'] != null) ...[
                              Text(
                                translateText('🏢 Review given for you'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
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
                              const Divider(),
                            ],
                            if ((appt['professionalReviews'] as List).isNotEmpty)
                              ...((appt['professionalReviews'] as List<Map<String, dynamic>>)
                                  .map((r) => Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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

class _BranchOption {
  const _BranchOption({
    required this.salonId,
    required this.salonName,
    required this.branchId,
    required this.branchName,
    required this.addressSummary,
    required this.branch,
  });

  final int salonId;
  final String salonName;
  final int branchId;
  final String branchName;
  final String addressSummary;
  final Map<String, dynamic> branch;
}

class _BranchDropdownOption extends StatelessWidget {
  const _BranchDropdownOption({required this.option, this.compact = false});

  final _BranchOption option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchLabel = option.branchName.trim();
    final address = option.addressSummary.trim();
    final displayTitle =
        branchLabel.isEmpty ? 'Branch #${option.branchId}' : branchLabel;

    if (compact) {
      return Text(
        displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront,
            color: AppColors.starColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (address.isNotEmpty)
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blueGrey.shade500,
                      ) ??
                      const TextStyle(color: Colors.blueGrey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
