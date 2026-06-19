import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../utils/price_formatter.dart';
import 'Adddeals.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

// ---- UI constants ----
const kDropdownFill = Color(0xFFF5F5F5); // grey-100 as const

class DealScreen extends StatefulWidget {
  @override
  _DealScreenState createState() => _DealScreenState();
}

class _DealScreenState extends State<DealScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;
  final Set<int> _deletingIds = {};
  final Set<int> _statusUpdatingIds = {};
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

      if (response['success'] == true && response['data'] is List) {
        final List data = response['data'];

        // Flatten: convert each salon + branch into a unified entry
        final List<Map<String, dynamic>> branchItems = data.expand((salon) {
          final List branches = salon['branches'] ?? [];
          return branches.map<Map<String, dynamic>>((branch) {
            return {
              'branchId': branch['id'],
              'branchName': branch['name'],
              'salonId': salon['id'],
              'salonName': salon['name'],
              'addressSummary': _branchAddressSummary(
                branch['address'] ?? salon['address'],
              ),
            };
          }).toList();
        }).toList();

        return branchItems;
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("Error fetching salon list: $e");
      return [];
    }
  }

  // ✅ Offer fetch with sanitization
  Future<void> _fetchOffers(int branchId) async {
    debugPrint('📡 Fetching offers for branch $branchId ...');
    setState(() {
      loadingOffers = true;
      offers = [];
    });

    final response = await ApiService.getBranchPackagesDeals(branchId);
    debugPrint('📩 Raw response: $response');

    if (!mounted) return;

    setState(() {
      loadingOffers = false;

      if (response['success'] == true && response['data'] is List) {
        final List<Map<String, dynamic>> allOffers =
            List<Map<String, dynamic>>.from(response['data']);

        // ✅ FILTER + SANITIZE: keep only DEAL (case-insensitive)
        offers = allOffers
            .where((offer) =>
                (offer['type']?.toString().toUpperCase() ?? '') == 'DEAL')
            .map((offer) => _sanitizeOffer(offer))
            .toList();

        debugPrint('✅ Filtered offers count: ${offers.length}');
        debugPrint(
            '✅ Filtered offers: ${offers.map((e) => e['name']).toList()}');
      } else {
        offers = [];
        debugPrint('❌ Failed to load offers: ${response['message']}');
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

  Future<void> _toggleOfferStatus(int offerId, bool makeLive) async {
    if (selectedSalonId == null) return;
    setState(() => _statusUpdatingIds.add(offerId));
    try {
      await ApiService().setBranchOfferStatus(
        branchId: selectedSalonId!,
        offerId: offerId,
        live: makeLive,
      );
      if (!mounted) return;
      await _fetchOffers(selectedSalonId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _statusUpdatingIds.remove(offerId));
      }
    }
  }

  // ✅ Sanitize every offer before rendering
  Map<String, dynamic> _sanitizeOffer(Map<String, dynamic> raw) {
    final o = Map<String, dynamic>.from(raw);
    o['name'] = o['name']?.toString() ?? '';
    o['status'] = o['status']?.toString() ?? 'UNKNOWN';
    o['type'] = o['type']?.toString() ?? 'N/A';
    o['pricingMode'] = o['pricingMode']?.toString() ?? 'FIXED';
    o['discountType'] = o['discountType']?.toString() ?? 'NONE';
    o['validFrom'] = o['validFrom']?.toString() ?? '';
    o['validTo'] = o['validTo']?.toString() ?? '';
    o['terms'] = o['terms']?.toString() ?? '';
    o['scope'] = o['scope']?.toString() ?? '';

    o['price'] = num.tryParse(o['price']?.toString() ?? '0') ?? 0;
    o['discount'] = num.tryParse(o['discount']?.toString() ?? '0') ?? 0;
    o['discountPct'] = num.tryParse(o['discountPct']?.toString() ?? '0') ?? 0;
    o['maxDiscount'] = num.tryParse(o['maxDiscount']?.toString() ?? '0') ?? 0;

    o['items'] = (o['items'] is List) ? List.from(o['items']) : [];
    o['itemSummary'] =
        (o['itemSummary'] is Map) ? Map.from(o['itemSummary']) : {};

    return o;
  }

  Future<void> _confirmDeleteOffer(int offerId, String offerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(translateText('Delete Deal')),
        content: Text(
          'Are you sure you want to delete "$offerName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(translateText('Cancel')),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.starColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(translateText('Delete'),
                style: const TextStyle(color: Colors.white)),
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
        SnackBar(content: Text(translateText('Please select a salon first'))),
      );
      return;
    }

    setState(() => _deletingIds.add(offerId));
    try {
      final res = await ApiService().deleteSalonBranchOfferApi(
        branchId: selectedSalonId!,
        offerId: offerId,
      );

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateText('Offer deleted successfully'))),
        );
        await _fetchOffers(selectedSalonId!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(res['message']?.toString() ?? 'Failed to delete deal'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(offerId));
    }
  }

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    if (selectedSalon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText("Please select a salon"))),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDealsScreen(
          branchId: selectedSalon!['branchId'],
          branchName: selectedSalon!['branchName'],
          source: 'DEAL',
          isEdit: true,
          existingOffer: offer,
          onPackageCreated: (branchId) => _fetchOffers(branchId),
        ),
      ),
    );

    if (selectedSalonId != null) {
      _fetchOffers(selectedSalonId!);
    }
  }

  String _rs(num? n) => formatMinorAmount(n ?? 0, trimZeroDecimals: true);

  Map<String, dynamic> _selectedSalonPayload(Map<String, dynamic> branch) {
    return {
      'salonId': branch['salonId'],
      'salonName': branch['salonName'],
      'branchId': branch['branchId'],
      'branchName': branch['branchName'],
      'addressSummary': branch['addressSummary'],
    };
  }

  String _branchLabel(Map<String, dynamic> branch) {
    final branchName = (branch['branchName'] ?? '').toString().trim();
    final salonName = (branch['salonName'] ?? '').toString().trim();
    return branchName.isNotEmpty ? branchName : salonName;
  }

  String _branchAddressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    void push(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty ||
          text.toLowerCase() == 'null' ||
          parts.contains(text)) {
        return;
      }
      parts.add(text);
    }

    push(address['line1']);
    push(address['line2']);
    push(address['village']);
    push(address['district']);
    push(address['city']);
    push(address['state']);
    push(address['postalCode']);
    push(address['country']);
    return parts.join(', ');
  }

  Future<void> _selectSalonBranch(Map<String, dynamic> branch) async {
    setState(() {
      selectedSalonId = branch['branchId'] as int?;
      selectedSalon = _selectedSalonPayload(branch);
    });
    final branchId = branch['branchId'];
    if (branchId is int) {
      await _fetchOffers(branchId);
    }
  }

  Widget _buildSalonSelector(List<Map<String, dynamic>> salons) {
    final selected = salons.cast<Map<String, dynamic>?>().firstWhere(
              (salon) => salon?['branchId'] == selectedSalonId,
              orElse: () => null,
            ) ??
        salons.first;

    return _BranchSelectorField(
      selectedBranch: selected,
      branches: salons,
      showDropdown: salons.length > 1,
      labelBuilder: _branchLabel,
      onSelected: _selectSalonBranch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Deal'),
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                        child: Text(translateText('No salons available'))),
                  ),
                ],
              );
            } else {
              final salons = snapshot.data!;
              if (!_didAutoSelect && salons.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  final first = salons.first;
                  setState(() {
                    _didAutoSelect = true;
                    selectedSalonId = first['branchId'] as int;
                    selectedSalon = {
                      'salonId': first['salonId'],
                      'salonName': first['salonName'],
                      'branchId': first['branchId'],
                      'branchName': first['branchName'],
                    };
                  });
                  await _fetchOffers(first['branchId']);
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSalonSelector(salons),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(builder: (context) {
                      if (selectedSalonId == null) {
                        return Center(
                          child: Text(translateText("Please select a salon")),
                        );
                      }
                      if (loadingOffers) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (offers.isEmpty) {
                        return Center(
                          child: Text(translateText("No deals available")),
                        );
                      }
                      return ListView.builder(
                        itemCount: offers.length,
                        itemBuilder: (context, i) {
                          final offer = offers[i];
                          final offerId =
                              num.tryParse(offer['id']?.toString() ?? '0')
                                      ?.toInt() ??
                                  0;
                          return _OfferCard(
                            offer: offer,
                            rs: _rs,
                            isDeleting: _deletingIds.contains(offerId),
                            isStatusUpdating:
                                _statusUpdatingIds.contains(offerId),
                            onToggleStatus: () => _toggleOfferStatus(
                              offerId,
                              (offer['status']?.toString().toUpperCase() ??
                                      '') !=
                                  'ACTIVE',
                            ),
                            onDelete: () =>
                                _confirmDeleteOffer(offerId, offer['name']),
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddDealsScreen(
                                    branchId: selectedSalon!['branchId'],
                                    branchName: selectedSalon!['branchName'],
                                    source: 'DEAL',
                                    isEdit: true,
                                    existingOffer: offer,
                                    onPackageCreated: (branchId) =>
                                        _fetchOffers(branchId),
                                  ),
                                ),
                              );
                              if (selectedSalonId != null) {
                                _fetchOffers(selectedSalonId!);
                              }
                            },
                          );
                        },
                      );
                    }),
                  ),
                ],
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'salon_deals_add_fab',
        onPressed: () {
          if (selectedSalon == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(translateText("Please select a salon"))),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDealsScreen(
                branchId: selectedSalon!['branchId'],
                branchName: selectedSalon!['branchName'],
                source: 'DEAL',
                isEdit: false,
                existingOffer: null,
                onPackageCreated: (branchId) => _fetchOffers(branchId),
              ),
            ),
          );
        },
        label: Text(
          translateText("Add Deal"),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: AppColors.starColor,
      ),
    );
  }
}

// ✅ _OfferCard widget stays as-is (no crash after sanitization)

// keep button styles and helpers as you already had them...
class _BranchSelectorField extends StatelessWidget {
  const _BranchSelectorField({
    required this.selectedBranch,
    required this.branches,
    required this.showDropdown,
    required this.labelBuilder,
    required this.onSelected,
  });

  final Map<String, dynamic> selectedBranch;
  final List<Map<String, dynamic>> branches;
  final bool showDropdown;
  final String Function(Map<String, dynamic>) labelBuilder;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final child = _BranchSelectorContent(
      branch: selectedBranch,
      labelBuilder: labelBuilder,
      showDropdown: showDropdown,
    );

    if (!showDropdown) return child;

    return PopupMenuButton<Map<String, dynamic>>(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      constraints: const BoxConstraints(minWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8DED6)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) {
        return branches.map((branch) {
          final isSelected = branch['branchId'] == selectedBranch['branchId'];
          return PopupMenuItem<Map<String, dynamic>>(
            value: branch,
            child: _BranchMenuItem(
              branch: branch,
              labelBuilder: labelBuilder,
              isSelected: isSelected,
            ),
          );
        }).toList();
      },
      child: child,
    );
  }
}

class _BranchSelectorContent extends StatelessWidget {
  const _BranchSelectorContent({
    required this.branch,
    required this.labelBuilder,
    required this.showDropdown,
  });

  final Map<String, dynamic> branch;
  final String Function(Map<String, dynamic>) labelBuilder;
  final bool showDropdown;

  @override
  Widget build(BuildContext context) {
    final address = (branch['addressSummary'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFF3E8D1),
            child: Icon(
              Icons.storefront_outlined,
              color: Color(0xFF8B6500),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labelBuilder(branch),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2D2926),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF756A61),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showDropdown)
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8B6500),
            ),
        ],
      ),
    );
  }
}

class _BranchMenuItem extends StatelessWidget {
  const _BranchMenuItem({
    required this.branch,
    required this.labelBuilder,
    required this.isSelected,
  });

  final Map<String, dynamic> branch;
  final String Function(Map<String, dynamic>) labelBuilder;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isSelected
              ? Icons.check_circle_outline_rounded
              : Icons.storefront_outlined,
          size: 18,
          color: const Color(0xFF8B6500),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BranchSelectorContent(
            branch: branch,
            labelBuilder: labelBuilder,
            showDropdown: false,
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.rs,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleStatus,
    required this.isDeleting,
    required this.isStatusUpdating,
  });

  final Map<String, dynamic> offer;
  final String Function(num? n) rs;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final bool isDeleting;
  final bool isStatusUpdating;

  @override
  Widget build(BuildContext context) {
    try {
      // --------- read from response safely ---------
      final String name = offer['name']?.toString() ?? '';
      final String status = offer['status']?.toString() ?? 'UNKNOWN';
      final bool isActive = status.toUpperCase() == 'ACTIVE';
      final String type = offer['type']?.toString() ?? 'N/A';
      final String pricingMode = offer['pricingMode']?.toString() ?? 'FIXED';
      final String discountType = offer['discountType']?.toString() ?? 'NONE';
      final String validFrom = offer['validFrom']?.toString() ?? '';
      final String validTo = offer['validTo']?.toString() ?? '';
      final String terms = offer['terms']?.toString() ?? '';

      // Defensive numeric parsing
      final num? discountPct = (offer['discountPct'] is num)
          ? offer['discountPct'] as num
          : num.tryParse(offer['discountPct']?.toString() ?? '');
      final num? discountAmt = (offer['discount'] is num)
          ? offer['discount'] as num
          : num.tryParse(offer['discount']?.toString() ?? '');
      final num finalPrice = (offer['price'] is num)
          ? offer['price'] as num
          : num.tryParse(offer['price']?.toString() ?? '0') ?? 0;

      final Map<String, dynamic> itemSummary = (offer['itemSummary'] is Map)
          ? Map<String, dynamic>.from(offer['itemSummary'])
          : {};
      final num actualPrice = (itemSummary['totalPrice'] is num)
          ? itemSummary['totalPrice'] as num
          : 0;

      final List items = (offer['items'] is List) ? offer['items'] as List : [];

      final bool isDiscount = pricingMode.toUpperCase() == 'DISCOUNT';
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

      // --------- build UI ---------
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
                      name.isNotEmpty ? name : 'Unnamed Offer',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
                  _pillChip(type),
                  _softChip(pricingMode),
                  if (discountChipText != null) _offChip(discountChipText),
                ],
              ),

              const SizedBox(height: 10),

              // --------- pricing block ---------
              // --------- pricing block ---------
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actualPrice > 0 && finalPrice < actualPrice) ...[
                    Text(
                      rs(actualPrice),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 1, // ✅ thin line
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rs(finalPrice),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDiscount ? Colors.orange : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      if (actualPrice > 0 && finalPrice < actualPrice)
                        Text(
                          'You save ${rs(actualPrice - finalPrice)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // --------- services as chips ---------
              if (items.isNotEmpty) ...[
                Text(
                  translateText('Includes'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: items.map((e) {
                    final m = Map<String, dynamic>.from(e as Map);
                    final n = (m['name'] ?? 'Service').toString();
                    final q = (m['qty'] ?? 1) as num;
                    return Chip(
                      label: Text('$n × ${q.toStringAsFixed(0)}'),
                      backgroundColor: const Color(0xFFF3F4F6),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity:
                          const VisualDensity(horizontal: -4, vertical: -4),
                    );
                  }).toList(),
                ),
              ],

              // --------- validity & terms ---------
              if (validFrom.isNotEmpty || validTo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatValidity(validFrom, validTo),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
              if (terms.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.article_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Terms: $terms',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),

              // --------- actions ---------
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   children: [
              //     ElevatedButton(
              //       onPressed: (isDeleting || isStatusUpdating)
              //           ? null
              //           : onToggleStatus,
              //       style: _blackButtonStyle,
              //       child: isStatusUpdating
              //           ? const SizedBox(
              //               width: 16,
              //               height: 16,
              //               child: CircularProgressIndicator(
              //                 strokeWidth: 2,
              //                 color: Colors.white,
              //               ),
              //             )
              //           : Text(
              //               translateText(
              //                 isActive ? 'Deactivate' : 'Make Live',
              //               ),
              //               style: const TextStyle(
              //                 fontSize: 12,
              //                 fontWeight: FontWeight.w600,
              //               ),
              //             ),
              //     ),
              //     const SizedBox(width: 10),
              //     ElevatedButton(
              //       onPressed: (isDeleting || isStatusUpdating) ? null : onEdit,
              //       style: _blackButtonStyle,
              //       child: Text(
              //         translateText('Edit'),
              //         style: const TextStyle(
              //             fontSize: 12, fontWeight: FontWeight.w600),
              //       ),
              //     ),
              //     const SizedBox(width: 10),
              //     ElevatedButton.icon(
              //       onPressed:
              //           (isDeleting || isStatusUpdating) ? null : onDelete,
              //       icon: isDeleting
              //           ? const SizedBox(
              //               width: 16,
              //               height: 16,
              //               child: CircularProgressIndicator(
              //                 strokeWidth: 2,
              //                 color: Colors.white,
              //               ),
              //             )
              //           : const Icon(Icons.delete, size: 16),
              //       label: Text(
              //         isDeleting ? 'Deleting...' : 'Delete',
              //         style: const TextStyle(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //       style: _blackButtonStyle,
              //     ),
              //   ],
              // ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      height: 38,
                      width: 120,
                      child: ElevatedButton(
                        onPressed: (isDeleting || isStatusUpdating)
                            ? null
                            : onToggleStatus,
                        style: _blackButtonStyle,
                        child: isStatusUpdating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                translateText(
                                  isActive ? 'Deactivate' : 'Make Live',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 38,
                      width: 78,
                      child: ElevatedButton(
                        onPressed:
                            (isDeleting || isStatusUpdating) ? null : onEdit,
                        style: _blackButtonStyle,
                        child: Text(
                          translateText('Edit'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 38,
                      width: 105,
                      child: ElevatedButton.icon(
                        onPressed:
                            (isDeleting || isStatusUpdating) ? null : onDelete,
                        icon: isDeleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.delete, size: 15),
                        label: Text(
                          isDeleting ? 'Deleting...' : translateText('Delete'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: _blackButtonStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      print('❌ ERROR while building offer card: $e');
      print('STACK TRACE:\n$st');
      print('OFFER DATA:\n${offer.toString()}');
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Error rendering offer: ${offer['name'] ?? 'Unknown'}\n$e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  // ---------- small UI helpers ----------
  Widget _statusChip(String? status) {
    final s = (status ?? '').toString().toUpperCase();
    final isActive = s == 'ACTIVE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDFF5E1) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.isEmpty ? 'UNKNOWN' : s,
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ✅ Shared button style
ButtonStyle get _blackButtonStyle => ElevatedButton.styleFrom(
      backgroundColor: AppColors.starColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ).copyWith(
      foregroundColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.disabled)
            ? Colors.white.withOpacity(0.6)
            : Colors.white,
      ),
    );

// ✅ Shared logic helpers
String _formatValidity(String? isoFrom, String? isoTo) {
  String fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year}';
    } catch (_) {
      return iso;
    }
  }

  final from = fmt(isoFrom);
  final to = fmt(isoTo);

  if (from.isNotEmpty && to.isNotEmpty) return 'Valid: $from - $to';
  if (from.isNotEmpty) return 'Valid from: $from';
  if (to.isNotEmpty) return 'Valid till: $to';
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
  if (actualPrice > 0 && finalPrice > 0) {
    final s = actualPrice - finalPrice;
    return s > 0 ? s : 0;
  }
  if (discountType == 'AMOUNT') return (discountAmt ?? 0);
  if (discountType == 'PERCENT' && actualPrice > 0) {
    final pct = (discountPct ?? 0).clamp(0, 100);
    return (actualPrice * (pct / 100.0));
  }
  return 0;
}
