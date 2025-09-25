import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/api_service.dart';
import 'Adddeals.dart';

final kDropdownFill = Colors.grey.shade100; // ← shared color for dropdown & cards

class DealScreen extends StatefulWidget {
  @override
  _DealScreenState createState() => _DealScreenState();
}

class _DealScreenState extends State<DealScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;
  int? selectedSalonId;
  Map<String, dynamic>? selectedSalon;

  bool loadingOffers = false;
  List<Map<String, dynamic>> offers = [];

  bool _autoPicked = false; // ensure we only auto-pick once

  // NEW: track which offers are deleting (show per-button loader)
  final Set<int> _deletingOfferIds = <int>{};

  @override
  void initState() {
    super.initState();
    salonsList = getSalonListApi();
  }

  Future<List<Map<String, dynamic>>> getSalonListApi() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final List salons = response['data'];
        return salons.map<Map<String, dynamic>>((salon) {
          return {
            'id': salon['id'],
            'name': salon['name'],
            'branches': salon['branches'],
          };
        }).toList();
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      debugPrint("Error fetching salon list: $e");
      return [];
    }
  }

  Future<void> _fetchOffers(int salonId) async {
    setState(() {
      loadingOffers = true;
      offers = [];
    });

    final response = await ApiService().getSalonPackagesDealsApi(salonId);
    print("Offers Response: $response");

    if (!mounted) return;
    setState(() {
      loadingOffers = false;
      if (response['success'] == true && response['data'] is List) {
        final all = List<Map<String, dynamic>>.from(response['data']);
        // ✅ Only DEALs
        offers = all
            .where((o) => (o['type'] ?? '').toString().toUpperCase() == 'DEAL')
            .toList();
      } else {
        offers = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  response['message']?.toString() ?? "Failed to load offers")),
        );
      }
    });
  }

  Future<void> _confirmDeleteOffer(int offerId, String offerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Deal'),
        content: Text(
          'Are you sure you want to delete "$offerName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteOfferWithLoader(offerId);
    }
  }

  // NEW: delete with per-button loader
  Future<void> _deleteOfferWithLoader(int offerId) async {
    if (selectedSalonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a salon first')),
      );
      return;
    }

    setState(() {
      _deletingOfferIds.add(offerId);
    });

    try {
      final res = await ApiService().deleteSalonOfferApi(
        salonId: selectedSalonId!,
        offerId: offerId,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer deleted successfully')),
        );
        await _fetchOffers(selectedSalonId!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'Failed to delete deal',
            ),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _deletingOfferIds.remove(offerId);
      });
    }
  }

  // 👉 Navigate to edit
  Future<void> _editOffer(Map<String, dynamic> offer) async {
    if (selectedSalon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a salon")),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDealsScreen(
          salonId: selectedSalon!['salonId'],
          salonName: selectedSalon!['salonName'],
          source: 'DEAL',
          isEdit: true,
          existingOffer: offer,
          onPackageCreated: (salonId) {
            _fetchOffers(salonId);
          },
        ),
      ),
    );

    if (selectedSalonId != null) {
      _fetchOffers(selectedSalonId!);
    }
  }

  String _rs(num? n) => "₹${(n ?? 0).toStringAsFixed(0)}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Header: bold + white
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Deals",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // No salons at all
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: null,
                    items: const <DropdownMenuItem<int>>[],
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: "Salon",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: "No salons available",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Expanded(
                    child: Center(child: Text("No salons found")),
                  ),
                ],
              );
            } else {
              final salons = snapshot.data!;

              // Auto-pick first salon once
              if (!_autoPicked && selectedSalonId == null && salons.isNotEmpty) {
                _autoPicked = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    selectedSalonId = salons.first['id'] as int;
                    selectedSalon = {
                      'salonId': salons.first['id'],
                      'salonName': salons.first['name'],
                    };
                  });
                  _fetchOffers(selectedSalonId!);
                });
              }

              final hasAnySalon = salons.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Styled dropdown
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: hasAnySalon ? selectedSalonId : null,
                    items: hasAnySalon
                        ? salons
                            .map<DropdownMenuItem<int>>(
                              (salon) => DropdownMenuItem<int>(
                                value: salon['id'] as int,
                                child: Text(
                                  salon['name'].toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                            .toList()
                        : const <DropdownMenuItem<int>>[],
                    onChanged: hasAnySalon
                        ? (value) async {
                            setState(() => selectedSalonId = value);
                            if (value != null) {
                              final salon =
                                  salons.firstWhere((s) => s['id'] == value);
                              selectedSalon = {
                                'salonId': salon['id'],
                                'salonName': salon['name'],
                              };

                              debugPrint(
                                  "Selected Salon ID: ${salon['id']} | Selected Salon Name: ${salon['name']}");

                              await _fetchOffers(salon['id'] as int);
                            }
                          }
                        : null,
                    decoration: InputDecoration(
                      labelText: "Salon",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: hasAnySalon
                          ? "Select salon"
                          : "No salons available",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (selectedSalonId == null) {
                          return const Center(
                              child: Text("Please select a salon"));
                        }
                        if (loadingOffers) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (offers.isEmpty) {
                          return const Center(child: Text("No deals available"));
                        }
                        return ListView.builder(
                          itemCount: offers.length,
                          itemBuilder: (context, i) {
                            final offer = offers[i];
                            final offerId = (offer['id'] as num).toInt();
                            final isDeleting = _deletingOfferIds.contains(offerId);

                            return _OfferCard(
                              offer: offer,
                              rs: _rs,
                              isDeleting: isDeleting, // NEW
                              onDelete: () => _confirmDeleteOffer(
                                offerId,
                                (offer['name'] ?? '').toString(),
                              ),
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddDealsScreen(
                                      salonId: selectedSalon!['salonId'],
                                      salonName: selectedSalon!['salonName'],
                                      source: 'DEAL',
                                      isEdit: true,
                                      existingOffer: offer,
                                      onPackageCreated: (sid) =>
                                          _fetchOffers(sid),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
      // FAB: black bg, white text/icon
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (selectedSalon == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select a salon")),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDealsScreen(
                salonId: selectedSalon!['salonId'],
                salonName: selectedSalon!['salonName'],
                source: 'DEAL',
                isEdit: false, // creating a new deal
                existingOffer: null,
                onPackageCreated: (salonId) {
                  _fetchOffers(salonId);
                },
              ),
            ),
          );
        },
        label: const Text("Add Deal"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.rs,
    required this.onDelete,
    required this.onEdit,
    required this.isDeleting, // NEW
  });

  final Map<String, dynamic> offer;
  final String Function(num? n) rs;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool isDeleting; // NEW

  String? _fmt(dynamic date) {
    if (date == null) return null;
    final s = date.toString();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  Widget _headerBadge({
    required String status,
    required String pricingMode,
    required String discountType,
    required num? discountPct,
    required num? discountAmt,
  }) {
    final hasPct = discountType == 'PERCENT' && (discountPct ?? 0) > 0;
    final hasAmt = discountType == 'AMOUNT' && (discountAmt ?? 0) > 0;

    if (pricingMode == 'DISCOUNT' && (hasPct || hasAmt)) {
      final text =
          hasPct ? "${discountPct!.toStringAsFixed(0)}% OFF" : "${rs(discountAmt)} OFF";
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }

    final isActive = status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDFF5E1) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isActive ? const Color(0xFF138A36) : Colors.grey[700],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (offer['items'] as List?) ?? const [];
    final itemNames = items
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(', ');

    final itemSummary = (offer['itemSummary'] as Map?) ?? const {};
    final totalPrice = (itemSummary['totalPrice'] ?? 0) as num;
    final totalDuration = (itemSummary['totalDuration'] ?? 0) as num;

    final pricingMode = (offer['pricingMode'] ?? '').toString(); // FIXED | DISCOUNT
    final discountType = (offer['discountType'] ?? '').toString(); // PERCENT | AMOUNT | NONE
    final discountPct = offer['discountPct'] as num?;
    final discountAmt = offer['discount'] as num?;
    final price = (offer['price'] ?? 0) as num;
    final status = (offer['status'] ?? '').toString();

    final validFrom = _fmt(offer['validFrom']);
    final validTo = _fmt(offer['validTo']);
    final String? terms = (offer['terms'] as String?)?.trim();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: kDropdownFill,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (offer['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _headerBadge(
                  status: status,
                  pricingMode: pricingMode,
                  discountType: discountType,
                  discountPct: discountPct,
                  discountAmt: discountAmt,
                ),
              ],
            ),

            if (itemNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(itemNames, style: const TextStyle(fontSize: 13)),
            ],

            const SizedBox(height: 8),

            // Pricing section
            if (pricingMode == 'DISCOUNT') ...[
              Text.rich(
                TextSpan(
                  text: 'Actual Price: ',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  children: [
                    TextSpan(
                      text: rs(totalPrice),
                      style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Discounted Price: ${rs(price)}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.orange,
                ),
              ),
            ] else ...[
              Text(
                "Price: ${rs(totalPrice)}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              "Duration: ${totalDuration.toStringAsFixed(0)} Min",
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),

            if (validFrom != null || validTo != null) ...[
              const SizedBox(height: 4),
              Text(
                (validFrom != null && validTo != null)
                    ? "Valid: $validFrom - $validTo"
                    : (validFrom != null)
                        ? "Valid from: $validFrom"
                        : "Valid till: $validTo",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            if (terms != null && terms.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Terms: $terms",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 10),

            // Bottom row: Edit + delete (delete shows loader when isDeleting)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit -> black bg, white text
                ElevatedButton(
                  onPressed: isDeleting ? null : onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Edit",
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),

                // Delete -> when deleting, show spinner
                ElevatedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete, size: 16),
                  label: Text(
                    isDeleting ? "Deleting..." : "Delete",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
