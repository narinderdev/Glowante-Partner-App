// lib/screens/SelectServices.dart
import 'package:flutter/material.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/price_formatter.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const Color _servicePickerGold = Color(0xFF8B6500);
const Color _servicePickerGoldLight = Color(0xFFD0A244);
const Color _servicePickerInk = Color(0xFF1F1B18);
const Color _servicePickerMuted = Color(0xFF6F665E);
const Color _servicePickerBorder = Color(0xFFE8DED6);
const Color _servicePickerFieldFill = Color(0xFFF7F4F3);
const Color _servicePickerSurface = Color(0xFFFBFAF8);
const Color _servicePickerSoftGold = Color(0xFFF5EAD2);

class SelectServicesModal extends StatefulWidget {
  final int? salonId;
  final int? branchId;

  /// Prefill the modal with existing selections (serviceId -> qty).
  /// Pass what you have on the parent screen so reopening the modal
  /// does not wipe earlier picks.
  final Map<int, int>? initialSelectedQty;

  const SelectServicesModal({
    Key? key,
    this.salonId,
    this.branchId,
    this.initialSelectedQty,
  })  : assert(salonId != null || branchId != null,
            'Either salonId or branchId must be provided.'),
        super(key: key);

  @override
  State<SelectServicesModal> createState() => _SelectServicesModalState();
}

class _SelectServicesModalState extends State<SelectServicesModal> {
  final TextEditingController _searchController = TextEditingController();

  List categories = [];

  /// serviceId -> quantity
  final Map<int, int> selectedQty = {};
  String searchQuery = '';
  bool isLoading = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // prefill with incoming selections
    if (widget.initialSelectedQty != null) {
      selectedQty.addAll(widget.initialSelectedQty!);
    }
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final resp = await ApiService().getService(
        salonId: widget.salonId,
        branchId: widget.branchId,
      );
      if (resp['success'] == true) {
        setState(() {
          categories = resp['data']?['categories'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  int _servicePriceMinor(Map<String, dynamic> service) {
    return _asInt(service['priceMinor'] ?? service['defaultPriceMinor']);
  }

  /// Build the full list of selected services we will return to the parent.
  /// Each item: {id, name, price, qty} where price stays in backend minor units.
  List<Map<String, dynamic>> _collectSelected() {
    final out = <Map<String, dynamic>>[];

    void pick(List list) {
      for (final raw in list) {
        final s = raw as Map<String, dynamic>;
        final int id = s['id'] as int;
        final int qty = selectedQty[id] ?? 0;
        if (qty > 0) {
          out.add({
            'id': id,
            'name': s['displayName'],
            'price': _servicePriceMinor(s),
            'qty': qty,
          });
        }
      }
    }

    for (final c in categories) {
      final cat = c as Map<String, dynamic>;
      pick(cat['services'] ?? []);
      for (final sub in (cat['subCategories'] ?? [])) {
        pick((sub as Map<String, dynamic>)['services'] ?? []);
      }
    }
    return out;
  }

  /// Total in backend minor units.
  double get total {
    double sum = 0;
    for (final c in categories) {
      final cat = c as Map<String, dynamic>;

      for (final s in (cat['services'] ?? [])) {
        final svc = s as Map<String, dynamic>;
        final int id = svc['id'] as int;
        final int qty = selectedQty[id] ?? 0;
        final price = _servicePriceMinor(svc);
        sum += (price * qty).toDouble();
      }

      for (final sub in (cat['subCategories'] ?? [])) {
        for (final s in ((sub as Map<String, dynamic>)['services'] ?? [])) {
          final svc = s as Map<String, dynamic>;
          final int id = svc['id'] as int;
          final int qty = selectedQty[id] ?? 0;
          final price = _servicePriceMinor(svc);
          sum += (price * qty).toDouble();
        }
      }
    }
    return sum;
  }

  int get _selectedCount => selectedQty.values.fold<int>(0, (sum, qty) {
        return sum + (qty > 0 ? qty : 0);
      });

  Widget _statePanel({
    required IconData icon,
    required String title,
    required String message,
    bool loading = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _servicePickerBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _servicePickerSoftGold,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          color: _servicePickerGold,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Icon(icon, color: _servicePickerGold, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                translateText(title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _servicePickerInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                translateText(message),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _servicePickerMuted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? _servicePickerSoftGold : _servicePickerFieldFill,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? _servicePickerGoldLight : _servicePickerBorder,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? _servicePickerGold : _servicePickerMuted,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int price = _servicePriceMinor(s);
    final int qty = selectedQty[id] ?? 0;

    // ❌ DO NOT FILTER HERE.
    // Filtering is already handled inside _buildCategory().
    // Keeping it here hides your entire widget during search.

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: qty > 0 ? _servicePickerGoldLight : _servicePickerBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: qty > 0 ? _servicePickerSoftGold : _servicePickerFieldFill,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              qty > 0 ? Icons.check_rounded : Icons.spa_rounded,
              color: _servicePickerGold,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _servicePickerInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMinorAmount(price),
                  style: const TextStyle(
                    color: _servicePickerGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              _quantityButton(
                icon: Icons.remove_rounded,
                onPressed: qty > 0
                    ? () => setState(() => selectedQty[id] = qty - 1)
                    : null,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                height: 34,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _servicePickerFieldFill,
                    border: Border.all(color: _servicePickerBorder),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    qty.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _servicePickerInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _quantityButton(
                icon: Icons.add_rounded,
                onPressed: () => setState(() => selectedQty[id] = qty + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final List services = cat['services'] as List? ?? [];
    final List subs = cat['subCategories'] as List? ?? [];

    final String q = searchQuery.toLowerCase();

    // Filter category-level services
    final filteredServices = services.where((s) {
      final name = (s['displayName'] ?? '').toString().toLowerCase();
      return q.isEmpty || name.contains(q);
    }).toList();

    // Handle subcategories
    final filteredSubs = subs.where((sub) {
      final subMap = (sub as Map).cast<String, dynamic>();
      final subName = (subMap['displayName'] ?? '').toString().toLowerCase();
      final subServices = (subMap['services'] ?? []) as List;
      if (subServices.isEmpty) return false;

      // check if subcategory name matches or if any service name matches
      final bool hasMatchingService = subServices.any((svc) =>
          (svc['displayName'] ?? '').toString().toLowerCase().contains(q));

      return q.isEmpty || subName.contains(q) || hasMatchingService;
    }).toList();

    // Hide category if nothing matches
    if (filteredServices.isEmpty && filteredSubs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _servicePickerBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: searchQuery.isNotEmpty,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: _servicePickerGold,
          collapsedIconColor: _servicePickerGold,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _servicePickerSoftGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.content_cut_rounded,
              color: _servicePickerGold,
              size: 19,
            ),
          ),
          title: Text(
            cat['displayName']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _servicePickerInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            // Category-level services
            ...filteredServices.map<Widget>(
                (s) => _buildServiceItem((s as Map).cast<String, dynamic>())),

            // Subcategories
            ...filteredSubs.map<Widget>((sub) {
              final subMap = (sub as Map).cast<String, dynamic>();
              final subName =
                  (subMap['displayName'] ?? '').toString().toLowerCase();
              final subServices = (subMap['services'] ?? []) as List;

              // 🔥 If the subcategory name matches, show all its services.
              // Otherwise, only show the ones that match the search.
              final bool subMatches = subName.contains(q);
              final filteredSubServices = subMatches
                  ? subServices
                  : subServices.where((svc) {
                      final name =
                          (svc['displayName'] ?? '').toString().toLowerCase();
                      return q.isEmpty || name.contains(q);
                    }).toList();

              return Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: _servicePickerFieldFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: searchQuery.isNotEmpty,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    iconColor: _servicePickerGold,
                    collapsedIconColor: _servicePickerGold,
                    title: Text(
                      subMap['displayName']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _servicePickerInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    children: filteredSubServices
                        .map<Widget>(
                          (s) => _buildServiceItem(
                            (s as Map).cast<String, dynamic>(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _servicePickerSurface,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Select Services'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _servicePickerGold),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: isLoading
          ? _statePanel(
              icon: Icons.content_cut_rounded,
              title: 'Loading services',
              message: 'Fetching services for this branch.',
              loading: true,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    // maxLength: 60,
                    cursorColor: _servicePickerGold,
                    style: const TextStyle(
                      color: _servicePickerInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: translateText('Search Services'),
                      hintStyle: const TextStyle(
                        color: _servicePickerMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _servicePickerGold,
                        size: 19,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _servicePickerMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear(); // clear UI text
                                  searchQuery = ''; // clear search filter
                                  FocusScope.of(context)
                                      .unfocus(); // hide keyboard (optional)
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _servicePickerBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _servicePickerBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _servicePickerGoldLight,
                          width: 1.2,
                        ),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => searchQuery = val.trim()),
                  ),
                ),

                // List
                Expanded(
                  child: categories.isEmpty
                      ? _statePanel(
                          icon: Icons.content_cut_rounded,
                          title: 'No services available',
                          message: 'Add services before creating deals.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 10),
                          itemCount: categories.length,
                          itemBuilder: (ctx, i) => _buildCategory(
                            (categories[i] as Map).cast<String, dynamic>(),
                          ),
                        ),
                ),

                // Bottom bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: _servicePickerBorder),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .05),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${translateText('Selected')}: $_selectedCount',
                              style: const TextStyle(
                                color: _servicePickerMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: .7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${translateText('Total')}: ${formatMinorAmount(total)}",
                              style: const TextStyle(
                                color: _servicePickerInk,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ElevatedButton(
                      //   onPressed: () {
                      //     // Return the FULL updated set
                      //     Navigator.pop(context, _collectSelected());
                      //   },
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: AppColors.starColor,
                      //     foregroundColor: Colors.white,
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(20),
                      //     ),
                      //   ),
                      //   child: Text(translateText('Done')),
                      // ),
                      SizedBox(
                        width: 110,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _collectSelected());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _servicePickerGold,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0x338B6500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: Text(
                            translateText('Done'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
