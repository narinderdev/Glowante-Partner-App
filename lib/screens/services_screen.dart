import 'package:flutter/material.dart';
import '../utils/api_service.dart';  // Make sure you have the ApiService class in a separate file

class ServicesTab extends StatefulWidget {
  final int branchId;
  const ServicesTab({Key? key, required this.branchId}) : super(key: key);

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  bool isLoading = true;
  Map<String, dynamic> serviceData = {};
  int? selectedCategoryId;
  int? selectedSubCategoryId;
  List<dynamic> subCategories = [];
  List<dynamic> selectedSubCategoryServices = [];

  @override
  void initState() {
    super.initState();
    fetchServices();
  }

  Future<void> fetchServices() async {
    try {
      final data = await ApiService().getBranchServiceDetail(widget.branchId);
      setState(() {
        serviceData = data;
        isLoading = false;
        if ((data['categories'] as List?)?.isNotEmpty ?? false) {
          selectedCategoryId = data['categories'][0]['id'];
          subCategories = data['categories'][0]['subCategories'] ?? [];
          if (subCategories.isNotEmpty) {
            selectedSubCategoryId = subCategories[0]['id'];
            selectedSubCategoryServices = subCategories[0]['services'] ?? [];
          }
        }
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error: $e');
    }
  }
@override
Widget build(BuildContext context) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  // Check if there are any categories
  final categories = (serviceData['categories'] as List?) ?? [];
  if (categories.isEmpty) {
    return const Center(child: Text('No service category found'));
  }
  // Inside build method after data loaded
return SingleChildScrollView(
  padding: const EdgeInsets.only(bottom: 80),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Categories
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Text('Categories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 50,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            final bool selected = selectedCategoryId == category['id'];
            return ChoiceChip(
              label: Text('${category['displayName']}'),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedCategoryId = category['id'];
                  subCategories = category['subCategories'] ?? [];
                  if (subCategories.isNotEmpty) {
                    selectedSubCategoryId = subCategories[0]['id'];
                    selectedSubCategoryServices = subCategories[0]['services'] ?? [];
                  } else {
                    selectedSubCategoryId = null;
                    selectedSubCategoryServices = [];
                  }
                });
              },
              selectedColor: Colors.purple,
              backgroundColor: Colors.grey.shade200,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            );
          },
        ),
      ),

      if (subCategories.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Subcategories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: subCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final subCategory = subCategories[index];
              final bool selected = selectedSubCategoryId == subCategory['id'];
              return ChoiceChip(
                label: Text('${subCategory['displayName']}'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    selectedSubCategoryId = subCategory['id'];
                    selectedSubCategoryServices = subCategory['services'] ?? [];
                  });
                },
                selectedColor: Colors.purple,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ],

      const SizedBox(height: 16),

      // Services list
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: selectedSubCategoryServices.isNotEmpty
            ? Column(
                children: selectedSubCategoryServices.map<Widget>((service) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Name + description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${service['displayName']}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                if ((service['description'] ?? '').isNotEmpty)
                                  Text('${service['description']}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),

                          // Price & Duration
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\₹.${service['priceMinor']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('${service['durationMin']} min',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
            : const Center(
                child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No services available'),
              )),
      ),
    ],
  ),
);
  }
}
