import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/api_service.dart';
import 'Adddeals.dart';

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
    debugPrint("Offers Response: $response");

    if (!mounted) return;
    setState(() {
      loadingOffers = false;
      if (response['success'] == true && response['data'] is List) {
        final all = List<Map<String, dynamic>>.from(response['data']);
        offers = all.where((o) => o['type'] == 'DEAL').toList();
      } else {
        offers = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message']?.toString() ?? "Failed to load offers")),
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
      await _deleteOffer(offerId);
    }
  }

  // ✅ 2) Call API to delete, then refresh offers
  Future<void> _deleteOffer(int offerId) async {
    if (selectedSalonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a salon first')),
      );
      return;
    }

    final res = await ApiService().deleteSalonOfferApi(
      salonId: selectedSalonId!,
      offerId: offerId,
    );

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal deleted successfully')),
      );
      await _fetchOffers(selectedSalonId!); // refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Failed to delete deal')),
      );
    }
  }

  String _rs(num? n) => "₹${(n ?? 0).toStringAsFixed(0)}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Deals")),
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
              return const Center(child: Text("No salons found"));
            } else {
              final salons = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<int>(
                    isExpanded: true,
                    value: selectedSalonId,
                    hint: const Text("Select Salon"),
                    items: salons
                        .map<DropdownMenuItem<int>>(
                          (salon) => DropdownMenuItem(
                            value: salon['id'],
                            child: Text(
                              salon['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      setState(() => selectedSalonId = value);

                      if (value != null) {
                        final salon = salons.firstWhere((s) => s['id'] == value);
                        selectedSalon = {
                          'salonId': salon['id'],
                          'salonName': salon['name'],
                        };

                        debugPrint("Selected Salon ID: ${salon['id']}");
                        debugPrint("Selected Salon Name: ${salon['name']}");

                        await _fetchOffers(salon['id']);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (selectedSalonId == null) {
                          return const Center(child: Text("Please select a salon"));
                        }
                        if (loadingOffers) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (offers.isEmpty) {
                          return const Center(child: Text("No deals available"));
                        }
                     return ListView.builder(
  itemCount: offers.length,
  itemBuilder: (context, i) {
    final offer = offers[i];
    return _OfferCard(
      offer: offer,
      rs: _rs,
      onDelete: () => _confirmDeleteOffer(
        (offer['id'] as num).toInt(),
        (offer['name'] ?? '').toString(),
      ),
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
                onPackageCreated: (salonId) {
        // After package is created, fetch updated offers
        _fetchOffers(salonId);  // Call the method to refresh the offers
      },
      source: 'DEAL',  
              ),
            ),
          );
        },
        label: const Text("Add Deal"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange[300],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.rs,
    required this.onDelete, 
  });

  final Map<String, dynamic> offer;
  final String Function(num? n) rs;
  final VoidCallback onDelete; 

  // dd-MM-yyyy formatter (safe)
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

  // Badge on the top-right: either discount chip or ACTIVE status chip
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
      final text = hasPct ? "${discountPct!.toStringAsFixed(0)}% OFF" : "${rs(discountAmt)} OFF";
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }

    // Otherwise show ACTIVE (green) or generic grey status
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
    // Comma-separated like your screenshot
    final itemNames = items
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(', ');

    final itemSummary = (offer['itemSummary'] as Map?) ?? const {};
    final totalPrice = (itemSummary['totalPrice'] ?? 0) as num;
    final totalDuration = (itemSummary['totalDuration'] ?? 0) as num;

    final pricingMode = (offer['pricingMode'] ?? '').toString();   // FIXED | DISCOUNT
    final discountType = (offer['discountType'] ?? '').toString(); // PERCENT | AMOUNT | NONE
    final discountPct = offer['discountPct'] as num?;
    final discountAmt = offer['discount'] as num?;
    final price = (offer['price'] ?? 0) as num;
    final status = (offer['status'] ?? '').toString();

    final validFrom = _fmt(offer['validFrom']);
    final validTo   = _fmt(offer['validTo']);
    final String? terms = (offer['terms'] as String?)?.trim();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              // FIXED / NONE
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

            // Valid line (only if at least one date exists)
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

            // Terms line (only if non-empty)
            if (terms != null && terms.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Terms: $terms",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 10),

            // Bottom row: Details + delete
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // TODO: navigate to a details page
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "Details",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 10),
            IconButton(
                  icon: Icon(Icons.delete, color: Colors.orange[400], size: 22),
                  onPressed: onDelete, // 👈 calls back into DealScreen
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
