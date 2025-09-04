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
    if (serviceData.isEmpty) {
      return const Center(child: Text('No service category found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80), // space for potential FAB on parent
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: (serviceData['categories'] as List).length,
              itemBuilder: (context, index) {
                final category = serviceData['categories'][index];
                final bool selected = selectedCategoryId == category['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? Colors.purple : Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      minimumSize: const Size(30, 20),
                      elevation: 0,
                    ),
                    onPressed: () {
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
                    child: Text('${category['displayName']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                );
              },
            ),
          ),

          if (selectedCategoryId != null && subCategories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Sub Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                scrollDirection: Axis.horizontal,
                itemCount: subCategories.length,
                itemBuilder: (context, index) {
                  final subCategory = subCategories[index];
                  final bool selected = selectedSubCategoryId == subCategory['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected ? Colors.purple : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        minimumSize: const Size(30, 20),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedSubCategoryId = subCategory['id'];
                          selectedSubCategoryServices = subCategory['services'] ?? [];
                        });
                      },
                      child: Text('${subCategory['displayName']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  );
                },
              ),
            ),

            if (selectedSubCategoryServices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${selectedSubCategoryServices[0]['displayName']}', style: const TextStyle(fontSize: 12)),
                          Text('${selectedSubCategoryServices[0]['description'] ?? ''}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${selectedSubCategoryServices[0]['priceMinor']}', style: const TextStyle(fontSize: 12)),
                          Text('${selectedSubCategoryServices[0]['durationMin']} mins', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
    child: Text(
      'No services available',
      style: TextStyle(fontSize: 14),
    ),
  ),
              ),
          ] else if (selectedCategoryId != null) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
    child: Text(
      'No services available',
      style: TextStyle(fontSize: 14),
    ),
  ),
            ),
          ],
        ],
      ),
    );
  }
}
