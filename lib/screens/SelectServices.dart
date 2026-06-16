// lib/screens/SelectServices.dart
import 'package:flutter/material.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

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

  /// Build the full list of selected services we will return to the parent.
  /// Each item: {id, name, price, qty} where price is in rupees (int).
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
            'price': s['priceMinor'], // already rupees
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

  /// Total in rupees (double only for display .00)
  double get total {
    double sum = 0;
    for (final c in categories) {
      final cat = c as Map<String, dynamic>;

      for (final s in (cat['services'] ?? [])) {
        final svc = s as Map<String, dynamic>;
        final int id = svc['id'] as int;
        final int qty = selectedQty[id] ?? 0;
        final num price = svc['priceMinor'] as num;
        sum += (price * qty).toDouble();
      }

      for (final sub in (cat['subCategories'] ?? [])) {
        for (final s in ((sub as Map<String, dynamic>)['services'] ?? [])) {
          final svc = s as Map<String, dynamic>;
          final int id = svc['id'] as int;
          final int qty = selectedQty[id] ?? 0;
          final num price = svc['priceMinor'] as num;
          sum += (price * qty).toDouble();
        }
      }
    }
    return sum;
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int price = (s['priceMinor'] ?? 0) as int; // rupees (e.g., 1220)
    final int qty = selectedQty[id] ?? 0;

    // ❌ DO NOT FILTER HERE.
    // Filtering is already handled inside _buildCategory().
    // Keeping it here hides your entire widget during search.

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "$name\n₹$price",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: qty > 0
                    ? () => setState(() => selectedQty[id] = qty - 1)
                    : null,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  qty.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
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

    return ExpansionTile(
      initiallyExpanded: searchQuery.isNotEmpty,
      title: Text(
        cat['displayName']?.toString() ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600),
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

          return ExpansionTile(
            initiallyExpanded: searchQuery.isNotEmpty,
            title: Text(subMap['displayName']?.toString() ?? ''),
            children: filteredSubServices
                .map<Widget>((s) =>
                    _buildServiceItem((s as Map).cast<String, dynamic>()))
                .toList(),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildProfileSubpageAppBar(
        title: translateText('Select Services'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    // maxLength: 60,
                    decoration: InputDecoration(
                      hintText: translateText('Search Services'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => searchQuery = val.trim()),
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) => _buildCategory(
                      (categories[i] as Map).cast<String, dynamic>(),
                    ),
                  ),
                ),

                // Bottom bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 6,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Total: ₹${total.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
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
      backgroundColor: AppColors.starColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: Text(translateText('Done')),
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
