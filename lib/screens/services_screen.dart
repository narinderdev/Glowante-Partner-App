import 'package:flutter/material.dart';
import '../utils/api_service.dart';  // Make sure you have the ApiService class in a separate file

class ServicesScreen extends StatefulWidget {
  final int branchId;  // Accept branchId as a parameter

  const ServicesScreen({Key? key, required this.branchId}) : super(key: key);

  @override
  _ServicesScreenState createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool isLoading = true;
  Map<String, dynamic> serviceData = {};
  int? selectedCategoryId;
  int? selectedSubCategoryId; // Track selected subcategory
  List<dynamic> subCategories = []; // List to hold the selected category's subcategories
  List<dynamic> selectedSubCategoryServices = []; // List for selected subcategory's services

  // Method to fetch service data from API
  void fetchServices() async {
    ApiService apiService = ApiService();
    try {
      final data = await apiService.getBranchServiceDetail(widget.branchId);  // Use widget.branchId
      setState(() {
        serviceData = data;
        isLoading = false;
        // Automatically select the first category and subcategory (if available)
        if (data['categories']?.isNotEmpty ?? false) {
          selectedCategoryId = data['categories'][0]['id'];
          subCategories = data['categories'][0]['subCategories'];
          if (subCategories.isNotEmpty) {
            selectedSubCategoryId = subCategories[0]['id'];
            selectedSubCategoryServices = subCategories[0]['services'];
            print('Selected Category: ${data['categories'][0]['displayName']}');
            print('Selected Subcategory: ${subCategories[0]['displayName']}');
            print('Subcategory Services: ${selectedSubCategoryServices.isEmpty ? "No services available" : selectedSubCategoryServices}');
          }
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchServices();  // Fetch data when the screen is loaded
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: isLoading
          ? Center(child: CircularProgressIndicator())  // Show loading spinner
          : serviceData.isEmpty
              ? Center(child: Text('No service category found', style: TextStyle(color: Colors.black)))  // Fallback message with dark text
              : SingleChildScrollView(  // Make the screen scrollable
                  child: Column(
                    children: [
                      // Categories Section (Tab-like buttons)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,  // Align the text to the left
                          child: Text(
                            'Categories',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black), // Dark text color
                          ),
                        ),
                      ),
                      // Category Buttons
                      Container(
                        height: 60,  // Set height for the category buttons container
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: serviceData['categories']?.length ?? 0,
                          itemBuilder: (context, index) {
                            var category = serviceData['categories'][index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedCategoryId == category['id']
                                      ? Colors.purple
                                      : Colors.grey,  // Highlight selected category
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),  // More rounded corners
                                  ),
                                  minimumSize: Size(30, 20),  // Same small button size for both categories and subcategories
                                  elevation: 0, // Remove or reduce the shadow
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedCategoryId = category['id'];
                                    // Fetch subcategories when a category is selected
                                    subCategories = category['subCategories'];
                                    print('Selected Category: ${category['displayName']}');  // Debugging selection
                                    // If there are subcategories, select the first one
                                    if (subCategories.isNotEmpty) {
                                      selectedSubCategoryId = subCategories[0]['id'];
                                      selectedSubCategoryServices = subCategories[0]['services'];
                                      print('Selected Subcategory: ${subCategories[0]['displayName']}'); // Debugging selection
                                      print('Subcategory Services: ${selectedSubCategoryServices.isEmpty ? "No services available" : selectedSubCategoryServices}');
                                    } else {
                                      selectedSubCategoryServices = [];
                                    }
                                  });
                                },
                                child: Text(
                                  category['displayName'],
                                  style: TextStyle(color: Colors.white, fontSize: 12),  // Set font size to 12
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Subcategories Section
                      if (selectedCategoryId != null && subCategories.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,  // Align the text to the left
                            child: Text(
                              'Sub Categories',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black), // Dark text color
                            ),
                          ),
                        ),
                        // Display subcategories in a horizontal scrollable row
                        Container(
                          height: 60,
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: subCategories.length,
                            itemBuilder: (context, index) {
                              var subCategory = subCategories[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedSubCategoryId == subCategory['id']
                                        ? Colors.purple
                                        : Colors.grey,  // Highlight selected subcategory
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),  // More rounded corners
                                    ),
                                    minimumSize: Size(30, 20),  // Same small button size for both categories and subcategories
                                    elevation: 0, // Remove or reduce the shadow
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedSubCategoryId = subCategory['id']; // Set the selected subcategory
                                      selectedSubCategoryServices = subCategory['services']; // Get services for the selected subcategory
                                      print('Selected Subcategory: ${subCategory['displayName']}'); // Debugging selection
                                      print('Subcategory Services: ${selectedSubCategoryServices.isEmpty ? "No services available" : selectedSubCategoryServices}');
                                    });
                                  },
                                  child: Text(
                                    subCategory['displayName'],
                                    style: TextStyle(color: Colors.white, fontSize: 12),  // Set font size to 12
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Display services in a row and column
                        if (selectedSubCategoryServices.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // First two items in row
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${selectedSubCategoryServices[0]['displayName']}', style: TextStyle(fontSize: 12, color: Colors.black)),
                                      Text('${selectedSubCategoryServices[0]['description']}', style: TextStyle(fontSize: 12, color: Colors.black)),
                                    ],
                                  ),
                                ),
                                // Second two items in row
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [                                   
                                    Text('${selectedSubCategoryServices[0]['priceMinor']}', style: TextStyle(fontSize: 12, color: Colors.black)),
                                    Text('${selectedSubCategoryServices[0]['durationMin']} mins', style: TextStyle(fontSize: 12, color: Colors.black)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Display message if no services available for the selected subcategory
                        if (selectedSubCategoryServices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No services available',
                              style: TextStyle(fontSize: 14, color: Colors.black),  // Dark text color
                            ),
                          ),
                      ] else if (selectedCategoryId != null) ...[
                        // Show "No services available" message if there are no subcategories
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No services available',
                                style: TextStyle(fontSize: 14, color: Colors.black),  // Dark text color
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("Floating + button clicked");  // This will print when the button is clicked
          // You can add your desired functionality here
        },
        backgroundColor: Colors.purple,  // Purple color for the button
        child: Icon(Icons.add, color: Colors.white),  // White + icon
      ),
    );
  }
}
