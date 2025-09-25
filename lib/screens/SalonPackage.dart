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
    final Set<int> _deletingIds = {};
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

  // Future<void> _confirmDeleteOffer(int offerId, String offerName) async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       title: const Text('Delete Deal'),
  //       content: Text(
  //         'Are you sure you want to delete "$offerName"? This action cannot be undone.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: const Text('Delete', style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed == true) {
  //     await _deleteOffer(offerId);
  //   }
  // }

  // // ✅ Call API to delete, then refresh offers
  // Future<void> _deleteOffer(int offerId) async {
  //   if (selectedSalonId == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please select a salon first')),
  //     );
  //     return;
  //   }

  //   final res = await ApiService().deleteSalonOfferApi(
  //     salonId: selectedSalonId!,
  //     offerId: offerId,
  //   );

  //   if (res['success'] == true) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Offer deleted successfully')),
  //     );
  //     await _fetchOffers(selectedSalonId!); // refresh list
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content:
  //             Text(res['message']?.toString() ?? 'Failed to delete deal'),
  //       ),
  //     );
  //   }
  // }
Future<void> _confirmDeleteOffer(int offerId, String offerName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Delete Deal'),
      content: Text('Are you sure you want to delete "$offerName"? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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

Future<void> _deleteOffer(int offerId) async {
  if (selectedSalonId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a salon first')),
    );
    return;
  }

  setState(() => _deletingIds.add(offerId));   // << start loader
  try {
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
        SnackBar(content: Text(res['message']?.toString() ?? 'Failed to delete deal')),
      );
    }
  } finally {
    if (mounted) setState(() => _deletingIds.remove(offerId));  // << stop loader
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
    final offerId = (offer['id'] as num).toInt();
    return _OfferCard(
      offer: offer,
      rs: _rs,
      isDeleting: _deletingIds.contains(offerId), // << here
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
    required this.isDeleting,
  });

  final Map<String, dynamic> offer;
  final String Function(num? n) rs;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    // --------- read from response ---------
    final String name         = (offer['name'] ?? '').toString();
    final String status       = (offer['status'] ?? '').toString();        // ACTIVE / INACTIVE
    final String type         = (offer['type'] ?? '').toString();          // PACKAGE / DEAL
    final String pricingMode  = (offer['pricingMode'] ?? '').toString();   // FIXED / DISCOUNT
    final String discountType = (offer['discountType'] ?? 'NONE').toString(); // PERCENT / AMOUNT / NONE
    final num?  discountPct   = offer['discountPct'] as num?;
    final num?  discountAmt   = offer['discount'] as num?;
    final num    finalPrice   = (offer['price'] ?? 0) as num;

    final Map itemSummary     = (offer['itemSummary'] as Map?) ?? const {};
    final num actualPrice     = (itemSummary['totalPrice'] ?? 0) as num;

    final List items          = (offer['items'] as List?) ?? const [];
    final String? validFrom   = offer['validFrom']?.toString();
    final String? validTo     = offer['validTo']?.toString();
    final String terms        = (offer['terms'] ?? '').toString();

    // --------- computed display helpers ---------
    final bool isDiscount = pricingMode == 'DISCOUNT';
    final num savings = _calcSavings(
      pricingMode: pricingMode,
      discountType: discountType,
      actualPrice: actualPrice,
      finalPrice: finalPrice,
      discountAmt: discountAmt,
      discountPct: discountPct,
    );

    final String? discountChipText = () {
      if (!isDiscount) return null;
      if (discountType == 'PERCENT' && (discountPct ?? 0) > 0) {
        return '${discountPct!.toStringAsFixed(0)}% OFF';
      }
      if (discountType == 'AMOUNT' && (discountAmt ?? 0) > 0) {
        return '${rs(discountAmt)} OFF';
      }
      return null;
    }();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------- header: title + chips ---------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _pillChip(type),                       // PACKAGE / DEAL
                _softChip(pricingMode),                // FIXED / DISCOUNT
                if (discountChipText != null) _offChip(discountChipText),
              ],
            ),

            const SizedBox(height: 10),

            // --------- pricing block ---------
            Row(
              children: [
                if (isDiscount && actualPrice > 0) ...[
                  Text(
                    rs(actualPrice),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                      decorationThickness: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  rs(finalPrice),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDiscount ? Colors.orange : Colors.black,
                  ),
                ),
                const Spacer(),
                if (savings > 0)
                  Text(
                    'You save ${rs(savings)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w700),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // --------- services as chips ---------
            if (items.isNotEmpty) ...[
              const Text('Includes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items.map((e) {
                  final m = Map<String, dynamic>.from(e as Map);
                  final n = (m['name'] ?? '').toString();
                  final q = (m['qty'] ?? 1) as num;
                  return Chip(
                    label: Text('$n × ${q.toStringAsFixed(0)}'),
                    backgroundColor: const Color(0xFFF3F4F6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  );
                }).toList(),
              ),
            ],

            // --------- validity & terms ---------
            if ((validFrom?.isNotEmpty ?? false) || (validTo?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatValidity(validFrom, validTo),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            if (terms.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.article_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Terms: $terms',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // --------- actions ---------
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: isDeleting ? null : onEdit,
                  style: _blackButtonStyle,
                  child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete, size: 16),
                  label: Text(
                    isDeleting ? 'Deleting...' : 'Delete',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: _blackButtonStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- tiny UI helpers ----------
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
          fontWeight: FontWeight.w700,
          color: isActive ? const Color(0xFF138A36) : Colors.grey[700],
        ),
      ),
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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  Widget _pillChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _softChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }
}

// keep the shared style you already use
ButtonStyle get _blackButtonStyle => ElevatedButton.styleFrom(
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  elevation: 0,
).copyWith(
  backgroundColor: MaterialStateProperty.resolveWith((_) => Colors.black),
  foregroundColor: MaterialStateProperty.resolveWith(
    (states) => states.contains(MaterialState.disabled)
        ? Colors.white.withOpacity(0.6)
        : Colors.white,
  ),
);

// ---------- logic helpers ----------
String _formatValidity(String? isoFrom, String? isoTo) {
  String fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}-'
             '${d.month.toString().padLeft(2, '0')}-'
             '${d.year}';
    } catch (_) {
      return iso; // fall back to raw
    }
  }

  if ((isoFrom?.isNotEmpty ?? false) && (isoTo?.isNotEmpty ?? false)) {
    return 'Valid: ${fmt(isoFrom!)} - ${fmt(isoTo!)}';
  }
  if (isoFrom?.isNotEmpty ?? false) return 'Valid from: ${fmt(isoFrom!)}';
  if (isoTo?.isNotEmpty ?? false)   return 'Valid till: ${fmt(isoTo!)}';
  return '';
}

num _calcSavings({
  required String pricingMode,
  required String discountType,
  required num actualPrice,
  required num finalPrice,
  required num? discountAmt,
  required num? discountPct,
}) {
  if (pricingMode != 'DISCOUNT') return 0;
  // Prefer exact delta (actual - final) if we have actual price
  if (actualPrice > 0 && finalPrice > 0) {
    final s = actualPrice - finalPrice;
    return s > 0 ? s : 0;
  }
  // Fallback from discount fields
  if (discountType == 'AMOUNT') return (discountAmt ?? 0);
  if (discountType == 'PERCENT' && actualPrice > 0) {
    final pct = (discountPct ?? 0).clamp(0, 100);
    return (actualPrice * (pct / 100.0));
  }
  return 0;
}
