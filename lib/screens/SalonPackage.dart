import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'Adddeals.dart';

// ---- UI constants ----
const kDropdownFill = Color(0xFFF5F5F5); // grey-100 as const

class PackageScreen extends StatefulWidget {
  @override
  _PackageScreenState createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;
  int? selectedSalonId;
  Map<String, dynamic>? selectedSalon;

  // Offers state
  bool loadingOffers = false;
  List<Map<String, dynamic>> offers = [];

  // guard so we only auto-select once
  bool _didAutoSelect = false;

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
    if (mounted) {
      setState(() {
        loadingOffers = false;
        if (response['success'] == true && response['data'] is List) {
          // ✅ Filter only PACKAGE type
          final allOffers = List<Map<String, dynamic>>.from(response['data']);
          offers =
              allOffers.where((offer) => offer['type'] == 'PACKAGE').toList();
        } else {
          offers = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ?? "Failed to load offers",
              ),
            ),
          );
        }
      });
    }
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteOffer(offerId);
    }
  }

  // ✅ Call API to delete, then refresh offers
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
        const SnackBar(content: Text('Offer deleted successfully')),
      );
      await _fetchOffers(selectedSalonId!); // refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res['message']?.toString() ?? 'Failed to delete deal'),
        ),
      );
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
          source: 'DEAL', // keeping your original param
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
      appBar: AppBar(
        title:
            const Text("Package", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: Colors.black, // bold white header
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
              return const Center(child: Text("No salons found"));
            } else {
              final salons = snapshot.data!;

              // Auto-select first salon once
              if (!_didAutoSelect && salons.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  setState(() {
                    _didAutoSelect = true;
                    selectedSalonId = salons.first['id'] as int;
                    selectedSalon = {
                      'salonId': salons.first['id'],
                      'salonName': salons.first['name'],
                    };
                  });
                  await _fetchOffers(selectedSalonId!);
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Salon dropdown (filled UI)
                  DropdownButtonFormField<int>(
                    value: selectedSalonId,
                    isExpanded: true,
                    items: salons
                        .map<DropdownMenuItem<int>>(
                          (salon) => DropdownMenuItem(
                            value: salon['id'],
                            child: Text(
                              salon['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedSalonId = value;
                      });

                      if (value != null) {
                        final salon =
                            salons.firstWhere((s) => s['id'] == value);
                        selectedSalon = {
                          'salonId': salon['id'],
                          'salonName': salon['name'],
                        };
                        await _fetchOffers(salon['id']);
                      }
                    },
                    decoration: InputDecoration(
                      hintText:
                          salons.isEmpty ? 'No salons available' : 'Select Salon',
                      filled: true,
                      fillColor: kDropdownFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Offers list
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
                          return const Center(
                              child: Text("No packages available"));
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
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddDealsScreen(
                                      salonId: selectedSalon!['salonId'],
                                      salonName: selectedSalon!['salonName'],
                                      source: 'PACKAGE',
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
                source: 'PACKAGE',
                isEdit: false, // creating a new deal
                existingOffer: null,
                onPackageCreated: (salonId) {
                  _fetchOffers(salonId);
                },
              ),
            ),
          );
        },
        label: const Text("Add Package",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.black, // black bg, white text
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
  });

  final Map<String, dynamic> offer;
  final String Function(num? n) rs;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final items = (offer['items'] as List?) ?? const [];
    final itemNames = items
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(' + ');

    final itemSummary = (offer['itemSummary'] as Map?) ?? const {};
    final totalPrice = (itemSummary['totalPrice'] ?? 0) as num;
    final totalDuration = (itemSummary['totalDuration'] ?? 0) as num;

    final pricingMode = (offer['pricingMode'] ?? '').toString(); // FIXED | DISCOUNT
    final discountType =
        (offer['discountType'] ?? '').toString(); // PERCENT | AMOUNT | NONE
    final discountPct = offer['discountPct'] as num?;
    final discountAmt = offer['discount'] as num?;
    final price = (offer['price'] ?? 0) as num;
    final validFrom = offer['validFrom']?.toString();
    final validTo = offer['validTo']?.toString();
    final terms = offer['terms']?.toString();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (offer['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip((offer['status'] ?? '').toString()),
              ],
            ),

            if (itemNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(itemNames, style: const TextStyle(fontSize: 13)),
            ],

            const SizedBox(height: 8),

            // Pricing row like screenshot
            _pricingRow(
              pricingMode: pricingMode,
              discountType: discountType,
              totalPrice: totalPrice,
              price: price,
              discountPct: discountPct,
              discountAmt: discountAmt,
              rs: rs,
            ),

            const SizedBox(height: 8),
            Text(
              "Total Duration: ${totalDuration.toStringAsFixed(0)} Min",
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),

            if ((validFrom?.isNotEmpty ?? false) ||
                (validTo?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                (validFrom != null && validTo != null && validFrom.isNotEmpty && validTo.isNotEmpty)
                    ? "Valid: $validFrom - $validTo"
                    : (validFrom != null && validFrom.isNotEmpty)
                        ? "Valid from: $validFrom"
                        : "Valid till: $validTo",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            if ((terms ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Terms: $terms",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit -> black bg, white text
                ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Edit",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                // Delete -> black bg, white text
                ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text(
                    "Delete",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

  Widget _statusChip(String status) {
    final isActive = status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDFF5E1) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF138A36) : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _pricingRow({
    required String pricingMode,
    required String discountType,
    required num totalPrice,
    required num price,
    required num? discountPct,
    required num? discountAmt,
    required String Function(num? n) rs,
  }) {
    final children = <Widget>[];

    if (pricingMode == 'FIXED') {
      children.add(Text(
        rs(price),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ));
    } else if (pricingMode == 'DISCOUNT') {
      children.add(
        Text.rich(
          TextSpan(
            text: 'Actual Price ',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            children: [
              TextSpan(
                text: rs(totalPrice),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  decorationThickness: 2,
                ),
              ),
            ],
          ),
        ),
      );

      children.add(const SizedBox(width: 8));
      children.add(Text(
        rs(price),
        style: const TextStyle(
            fontSize: 16, color: Colors.orange, fontWeight: FontWeight.w700),
      ));

      if (discountType == 'PERCENT' && (discountPct ?? 0) > 0) {
        children.add(const SizedBox(width: 8));
        children.add(_offChip("${discountPct!.toStringAsFixed(0)}% OFF"));
      } else if (discountType == 'AMOUNT' && (discountAmt ?? 0) > 0) {
        children.add(const SizedBox(width: 8));
        children.add(_offChip("${rs(discountAmt)} OFF"));
      }
    } else {
      children.add(Text(
        rs(price),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: children,
    );
    }

  Widget _offChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange[400],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
