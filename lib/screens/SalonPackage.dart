import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/api_service.dart';
import '../utils/price_formatter.dart';
import 'Adddeals.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';

// ---- UI constants ----
const kDropdownFill = Color(0xFFF5F5F5); // grey-100 as const
const Color _offerGold = Color(0xFF8B6500);
const Color _offerInk = Color(0xFF1F1B18);
const Color _offerMuted = Color(0xFF6F665E);
const Color _offerBorder = Color(0xFFE8DED6);
const Color _offerFieldFill = Color(0xFFF7F4F3);
const Color _offerSurface = Color(0xFFFBFAF8);
const Color _offerSoftGold = Color(0xFFF5EAD2);

class PackageScreen extends StatefulWidget {
  @override
  _PackageScreenState createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
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

        // ✅ FILTER + SANITIZE: keep only PACKAGE (case-insensitive)
        offers = allOffers
            .where((offer) =>
                (offer['type']?.toString().toUpperCase() ?? '') == 'PACKAGE')
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
            style: ElevatedButton.styleFrom(backgroundColor: _offerGold),
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
          source: 'PACKAGE',
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

  Widget _offersHeader() {
    final branchName = (selectedSalon?['branchName'] ?? '').toString().trim();
    final salonName = (selectedSalon?['salonName'] ?? '').toString().trim();
    final subtitle = [
      if (branchName.isNotEmpty) branchName,
      if (salonName.isNotEmpty && salonName != branchName) salonName,
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _offerBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _offerSoftGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: _offerGold,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Salon Packages'),
                  style: const TextStyle(
                    color: _offerInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty
                      ? translateText('Manage service bundles for this branch')
                      : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _offerMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _offerFieldFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _offerBorder),
            ),
            child: Text(
              '${offers.length}',
              style: const TextStyle(
                color: _offerGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statePanel({
    required IconData icon,
    required String title,
    required String message,
    bool loading = false,
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _offerBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _offerSoftGold,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        color: _offerGold,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Icon(icon, color: _offerGold, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              translateText(title),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _offerInk,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              translateText(message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _offerMuted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offerSurface,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Packages'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _statePanel(
                icon: Icons.inventory_2_rounded,
                title: 'Loading packages',
                message: 'Fetching branch packages.',
                loading: true,
              );
            } else if (snapshot.hasError) {
              return _statePanel(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load packages',
                message: snapshot.error.toString(),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _statePanel(
                icon: Icons.storefront_rounded,
                title: 'No salons available',
                message: 'Create a salon branch before adding packages.',
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
                  if (salons.length > 1) ...[
                    _buildSalonSelector(salons),
                    const SizedBox(height: 12),
                  ],
                  _offersHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(builder: (context) {
                      if (selectedSalonId == null) {
                        return _statePanel(
                          icon: Icons.storefront_rounded,
                          title: 'Select a branch',
                          message: 'Choose a branch to view packages.',
                        );
                      }
                      if (loadingOffers) {
                        return _statePanel(
                          icon: Icons.inventory_2_rounded,
                          title: 'Loading packages',
                          message: 'Fetching branch packages.',
                          loading: true,
                        );
                      }
                      if (offers.isEmpty) {
                        return _statePanel(
                          icon: Icons.inventory_2_outlined,
                          title: 'No packages available',
                          message: 'Add a package to bundle services together.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
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
                            onEdit: () => _editOffer(offer),
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
        heroTag: 'salon_packages_add_fab',
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
                source: 'PACKAGE',
                isEdit: false,
                existingOffer: null,
                onPackageCreated: (branchId) => _fetchOffers(branchId),
              ),
            ),
          );
        },
        label: Text(
          translateText("Add Package"),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: _offerGold,
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
    return OwnerBranchHeaderSelector<int>(
      label: labelBuilder(selectedBranch),
      options: branches
          .map((branch) {
            final branchId = branch['branchId'];
            final id = branchId is int
                ? branchId
                : branchId is num
                    ? branchId.toInt()
                    : int.tryParse('${branchId ?? ''}');
            if (id == null) return null;
            return OwnerBranchHeaderSelectorOption<int>(
              value: id,
              label: labelBuilder(branch),
              subtitle: (branch['addressSummary'] ?? '').toString(),
            );
          })
          .whereType<OwnerBranchHeaderSelectorOption<int>>()
          .toList(),
      selectedValue: selectedBranch['branchId'] is int
          ? selectedBranch['branchId'] as int
          : int.tryParse('${selectedBranch['branchId'] ?? ''}'),
      placeholder: translateText('Select Branch'),
      isInteractive: showDropdown,
      onSelected: (branchId) {
        final branch = branches.firstWhere(
          (item) {
            final raw = item['branchId'];
            final id = raw is int
                ? raw
                : raw is num
                    ? raw.toInt()
                    : int.tryParse('${raw ?? ''}');
            return id == branchId;
          },
          orElse: () => selectedBranch,
        );
        onSelected(branch);
      },
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
      final String gender = offer['gender']?.toString().trim() ?? '';
      final String durationUnit =
          offer['durationUnit']?.toString().trim().toUpperCase() ?? '';

      // Defensive numeric parsing
      final num? durationValue = (offer['durationValue'] is num)
          ? offer['durationValue'] as num
          : num.tryParse(offer['durationValue']?.toString() ?? '');
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
      final num? itemCount = (itemSummary['itemCount'] is num)
          ? itemSummary['itemCount'] as num
          : num.tryParse(itemSummary['itemCount']?.toString() ?? '');
      final num? serviceDuration = (itemSummary['totalDuration'] is num)
          ? itemSummary['totalDuration'] as num
          : (offer['duration'] is num)
              ? offer['duration'] as num
              : num.tryParse(
                  itemSummary['totalDuration']?.toString() ??
                      offer['duration']?.toString() ??
                      '',
                );

      final List items = (offer['items'] is List) ? offer['items'] as List : [];

      final bool isDiscount = pricingMode.toUpperCase() == 'DISCOUNT';
      final String? durationText = _durationText(
        type: type,
        durationValue: durationValue,
        durationUnit: durationUnit,
        serviceDuration: serviceDuration,
      );
      final String? serviceCountText = _serviceCountText(itemCount);
      final String? genderText = _genderText(gender);
      final String durationLine =
          _serviceDurationLine(serviceDuration) ?? translateText('N/A');
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
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _offerBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (genderText != null) _genderRibbon(genderText),
            Padding(
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
                            color: _offerInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (genderText != null) const SizedBox(width: 70),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (items.isNotEmpty) _servicePreviewChips(items),
                  const SizedBox(height: 14),

                  _detailRow(
                    label: 'Actual Price',
                    value: actualPrice > 0 ? rs(actualPrice) : rs(finalPrice),
                    valueColor: _offerMuted,
                    strikeValue: actualPrice > 0 && finalPrice < actualPrice,
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    label: 'Discounted Price',
                    value: rs(finalPrice),
                    valueColor: _offerGold,
                    suffix: translateText('(Inc. taxes)'),
                    boldValue: true,
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    label: 'Duration',
                    value: durationLine,
                    valueColor: _offerInk,
                  ),

                  if (discountChipText != null || serviceCountText != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (durationText != null) _durationChip(durationText),
                        if (serviceCountText != null)
                          _metaChip(
                              Icons.inventory_2_outlined, serviceCountText),
                        if (discountChipText != null)
                          _offChip(discountChipText),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // --------- services as chips ---------
                  if (items.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            translateText('Includes'),
                            style: const TextStyle(
                              color: _offerInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _statusChip(status),
                      ],
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
                          labelStyle: const TextStyle(
                            color: _offerInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: _offerFieldFill,
                          side: const BorderSide(color: _offerBorder),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: _statusChip(status),
                    ),
                  ],

                  // --------- validity & terms ---------
                  if (validFrom.isNotEmpty || validTo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: _offerGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatValidity(validFrom, validTo),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _offerMuted,
                              fontWeight: FontWeight.w600,
                            ),
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
                              size: 16, color: _offerGold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Terms: $terms',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _offerMuted,
                                fontWeight: FontWeight.w600,
                              ),
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
                          width: 120,
                          height: 38,
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
                          width: 78,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: (isDeleting || isStatusUpdating)
                                ? null
                                : onEdit,
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
                          width: 105,
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: (isDeleting || isStatusUpdating)
                                ? null
                                : onDelete,
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
                              isDeleting
                                  ? 'Deleting...'
                                  : translateText('Delete'),
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
          ],
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
        color: isActive ? const Color(0xFFE9F8EF) : _offerFieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFFD4EBDD) : _offerBorder,
        ),
      ),
      child: Text(
        s.isEmpty ? 'UNKNOWN' : s,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isActive ? const Color(0xFF168546) : _offerMuted,
        ),
      ),
    );
  }

  Widget _offChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _offerGold,
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

  // Widget _genderRibbon(String text) {
  //   final normalized = text.trim().toLowerCase();
  //   final isFemale = normalized == translateText('Female').toLowerCase() ||
  //       normalized == 'female';
  //   final background =
  //       isFemale ? const Color(0xFFFFEEF5) : const Color(0xFFEFF6FF);
  //   final border = isFemale ? const Color(0xFFF5B8CF) : const Color(0xFFBFD7FF);
  //   final foreground =
  //       isFemale ? const Color(0xFFB4235A) : const Color(0xFF1D4E89);

  //   return Positioned(
  //     top: 12,
  //     right: -34,
  //     child: Transform.rotate(
  //       angle: math.pi / 4,
  //       child: Container(
  //         width: 112,
  //         padding: const EdgeInsets.symmetric(vertical: 5),
  //         decoration: BoxDecoration(
  //           color: background,
  //           border: Border.symmetric(
  //             horizontal: BorderSide(color: border),
  //           ),
  //         ),
  //         child: Text(
  //           text,
  //           maxLines: 1,
  //           overflow: TextOverflow.ellipsis,
  //           textAlign: TextAlign.center,
  //           style: TextStyle(
  //             color: foreground,
  //             fontSize: 10,
  //             fontWeight: FontWeight.w900,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
Widget _genderRibbon(String text) {
  return Positioned(
    top: 12,
    right: -34,
    child: Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(
          color: _offerGold, // same as Delete button
          border: Border.symmetric(
            horizontal: BorderSide(color: _offerGold),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white, // white text
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}



  Widget _servicePreviewChips(List items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.take(2).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final name = (m['name'] ?? 'Service').toString();
        final qty = (m['qty'] ?? 1) as num;
        final label = qty > 1 ? '$name x ${qty.toStringAsFixed(0)}' : name;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _offerFieldFill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _offerMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required Color valueColor,
    String? suffix,
    bool strikeValue = false,
    bool boldValue = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${translateText(label)}:',
            style: const TextStyle(
              color: _offerMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: boldValue ? FontWeight.w900 : FontWeight.w800,
                decoration: strikeValue
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
              children: [
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: const TextStyle(
                      color: _offerGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _durationChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8D2A8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 13, color: _offerGold),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: _offerGold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _offerFieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _offerBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _offerMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: _offerMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _durationText({
    required String type,
    required num? durationValue,
    required String durationUnit,
    required num? serviceDuration,
  }) {
    if (type.toUpperCase() != 'PACKAGE') return null;

    if (durationValue != null &&
        durationValue > 0 &&
        durationUnit.trim().isNotEmpty) {
      final value = durationValue % 1 == 0
          ? durationValue.toInt().toString()
          : durationValue.toString();
      final unit = _durationUnitLabel(durationUnit, durationValue);
      return '${translateText('Duration')}: $value $unit';
    }

    if (serviceDuration != null && serviceDuration > 0) {
      final minutes = serviceDuration % 1 == 0
          ? serviceDuration.toInt().toString()
          : serviceDuration.toString();
      return '${translateText('Service time')}: $minutes ${translateText('min')}';
    }

    return null;
  }

  String? _serviceCountText(num? itemCount) {
    if (itemCount == null || itemCount <= 0) return null;
    final count = itemCount % 1 == 0
        ? itemCount.toInt().toString()
        : itemCount.toString();
    final label = itemCount == 1 ? 'Service' : 'Services';
    return '$count ${translateText(label)}';
  }

  String? _serviceDurationLine(num? serviceDuration) {
    if (serviceDuration == null || serviceDuration <= 0) return null;
    final minutes = serviceDuration % 1 == 0
        ? serviceDuration.toInt().toString()
        : serviceDuration.toString();
    return '$minutes ${translateText(serviceDuration == 1 ? 'min' : 'mins')}';
  }

  String? _genderText(String gender) {
    final normalized = gender.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null') return null;

    switch (normalized) {
      case 'male':
        return translateText('Male');
      case 'female':
        return translateText('Female');
      case 'others':
      case 'other':
        return translateText('Others');
      default:
        return translateText(
            normalized[0].toUpperCase() + normalized.substring(1));
    }
  }

  String _durationUnitLabel(String unit, num value) {
    final singular = value == 1;
    switch (unit.toUpperCase()) {
      case 'DAY':
        return translateText(singular ? 'Day' : 'Days');
      case 'MONTH':
        return translateText(singular ? 'Month' : 'Months');
      case 'YEAR':
        return translateText(singular ? 'Year' : 'Years');
      default:
        return translateText(unit);
    }
  }
}

// ✅ Shared button style
ButtonStyle get _blackButtonStyle => ElevatedButton.styleFrom(
      backgroundColor: _offerGold,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.white.withValues(alpha: 0.6)
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
