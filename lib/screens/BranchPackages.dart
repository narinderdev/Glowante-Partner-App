import 'package:flutter/material.dart';
import '../screens/Adddeals.dart';  // Import the AddDealsScreen
import '../utils/api_service.dart'; // Import your API service to fetch offers

class BranchPackagesScreen extends StatefulWidget {
  final Map<String, dynamic> branchDetails;

  const BranchPackagesScreen({Key? key, required this.branchDetails}) : super(key: key);

  @override
  _BranchPackagesScreenState createState() => _BranchPackagesScreenState();
}

class _BranchPackagesScreenState extends State<BranchPackagesScreen> {
  late Future<Map<String, dynamic>> _offersData;

  @override
  void initState() {
    super.initState();
    _offersData = ApiService.getBranchPackagesDeals(widget.branchDetails['id']);
  }

  void onDelete(int offerId, String offerName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Delete Package'),
      content: Text(
        'Are you sure you want to delete "$offerName"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false), // Cancels the dialog
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () => Navigator.pop(ctx, true), // Confirms the dialog
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  // If confirmed, show the snackbar and do not call any API
  if (confirmed == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer deleted successfully')),
    );
    // Optionally, refresh the offers here (e.g., by calling _fetchOffers again)
  }
}
  String _rs(num? n) => "₹${(n ?? 0).toStringAsFixed(0)}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,  // No header
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _offersData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.data!['success'] == false) {
              return Center(child: Text('Error: ${snapshot.data!['message']}'));
            }

            List<dynamic> packages = [];

            // Separate Packages based on 'type'
            for (var offer in snapshot.data!['data']) {
              if (offer['type'] == 'PACKAGE') {
                packages.add(offer);
              }
            }

            return ListView(
              children: [
                if (packages.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Packages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...packages.map((package) {
                    final pricingMode = (package['pricingMode'] ?? '').toString(); // FIXED | DISCOUNT
                    final discountPct = package['discountPct'] as num?;
                    final price = (package['price'] ?? 0) as num;

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    (package['name'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _statusChip((package['status'] ?? '').toString()),
                              ],
                            ),
                            const SizedBox(height: 6),
                                               Text(
  // Extracting names from the 'items' list and joining them with commas
  (package['items'] as List?)
      ?.map((item) => item['name'] ?? '')
      .where((name) => name.isNotEmpty)
      .join(', ') ?? '',
  style: const TextStyle(fontSize: 14, color: Colors.black87),
),
                            const SizedBox(height: 6),
                            Text(
                              'Total Duration: ${package['itemSummary']['totalDuration']} Min',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            _pricingRow(
                              pricingMode: pricingMode,
                              discountPct: discountPct ?? 0,  // Ensure it's non-null by providing a default value if null
                              price: price,
                              rs: _rs,
                            ),
                           const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: Icon(Icons.delete, color: Colors.orange[400], size: 22),
                                onPressed: () {
                                  onDelete(
                                    (package['id'] as num).toInt(),
                                    (package['name'] ?? '').toString(),
                                  );
                                },
                                tooltip: 'Delete',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to AddDealsScreen with source: 'PACKAGE'
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDealsScreen(
                salonId: widget.branchDetails['id'],
                salonName: widget.branchDetails['name'],
                onPackageCreated: (id) {}, // Define your callback if needed
                source: 'PACKAGE',  // Pass 'PACKAGE' as the source
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Package'),
        backgroundColor: Colors.purple,
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
    required num discountPct, // Keep this as num
    required num price,
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
                text: rs(price),
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
        style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.w700),
      ));
      if (discountPct != null && discountPct > 0) { // check if discountPct is not null and greater than 0
        children.add(const SizedBox(width: 8));
        children.add(_offChip("${discountPct.toStringAsFixed(0)}% OFF"));
      }
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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
