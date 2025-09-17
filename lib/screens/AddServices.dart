// import 'package:flutter/material.dart';
// import 'package:bloc_onboarding/utils/api_service.dart';
// import '../Viewmodels/AddSalonServiceRequest.dart';
// import 'dart:convert';

// class AddServices extends StatefulWidget {
//   final int salonId;
//   final Map<String, dynamic>? selectedCategory;
//   final List<dynamic>? categories; // ✅ multiple categories

//   AddServices({
//     required this.salonId,
//     this.selectedCategory,
//     this.categories,
//   });

//   @override
//   _AddServicesState createState() => _AddServicesState();
// }

// class _AddServicesState extends State<AddServices> {
//   List<dynamic> serviceCatalog = [];
//   Map<String, dynamic>? selectedCategory;
//   Map<String, dynamic>? selectedService;
// String? selectedCategoryType;
//   final nameController = TextEditingController();
//   final descController = TextEditingController();
//   final priceController = TextEditingController();
//   final durationController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     selectedCategory = widget.selectedCategory; // pre-select if passed
//      selectedCategory = null; // Reset the selected category here
//   selectedService = null; 
//     fetchServiceCatalog();
//   }

//   Future<void> fetchServiceCatalog() async {
//     try {
//       final response = await ApiService().getServiceCatalog();
//       if (response['success'] == true) {
//         setState(() {
//           serviceCatalog = response['data'];
//         });
//       }
//     } catch (e) {
//       print("❌ Error fetching service catalog: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to fetch service catalog")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Add Service")),
//       body: SingleChildScrollView( // ✅ scrollable
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [

//             // Service Name
//             Text("Service name *"),
//             SizedBox(height: 6),
//             TextField(
//               controller: nameController,
//               decoration: InputDecoration(
//                 hintText: "Add a service name",
//                 prefixIcon: Icon(Icons.work_outline),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             SizedBox(height: 20),

//             // Category + Service Row
//             Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("Select Category *"),
//                       SizedBox(height: 6),

// DropdownButtonFormField<Map<String, dynamic>>(
//   isExpanded: true,
//   value: selectedCategory,
//   hint: Text("Select Category"),
//   items: _getCategoryAndSubcategoryItems(widget.categories ?? []),
//   onChanged: (item) {
//   if (item == null) return;

//   bool isSubCategory = item['subCategories'] == null || item['subCategories'].isEmpty;

//   setState(() {
//     selectedCategory = item;
//     selectedCategoryType = isSubCategory ? 'subCategory' : 'category';
//   });

//   print("Selected ${isSubCategory ? 'Subcategory' : 'Category'} ID: ${item['id']}");
//   print("Selected ${isSubCategory ? 'Subcategory' : 'Category'} Name: ${item['name']}");
// },

//   decoration: InputDecoration(
//     border: OutlineInputBorder(),
//   ),
// ),

//        ],
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("Subcategory *"),
//                       SizedBox(height: 6),
//                DropdownButtonFormField<int>(
//   isExpanded: true,
//   value: selectedService?['id'], // store only the ID
//   hint: Text("Select"),
//   items: serviceCatalog.expand<DropdownMenuItem<int>>((service) {
//     final parentName = service['name'];
//     final subCats = service['subCategories'] ?? [];

//     return subCats.map<DropdownMenuItem<int>>((sub) {
//       return DropdownMenuItem<int>(
//         value: sub['id'], // 👈 only the ID
//         child: Text("${sub['name']}"), // ✅ keep your original display
//       );
//     }).toList();
//   }).toList(),
// onChanged: (value) {
//   if (value == null) return;
  
//   // Find the full object by id
//   final found = serviceCatalog
//       .expand((service) => service['subCategories'] ?? [])
//       .firstWhere((sub) => sub['id'] == value);

//   setState(() {
//     selectedService = {
//       "id": found['id'],
//       "name": found['name'],
//       "parentId": found['parentId'] ?? 0,
//       "parentName": found['parentName'] ?? "",
//     };
//   });

//   // Update the print statements to use selectedService instead of selectedSubCategory
//   print("Selected SubCategory ID: ${selectedService?['id']}");
//   print("Selected SubCategory Name: ${selectedService?['name']}");
// },

//   // Assuming `selectedSubCategory` holds the selected value from the dropdown


//   decoration: InputDecoration(
//     border: OutlineInputBorder(),
//   ),
// ),


//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 20),

//             // Description
//             Text("Description (Optional)"),
//             SizedBox(height: 6),
//             TextField(
//               controller: descController,
//               decoration: InputDecoration(
//                 hintText: "Add a short description",
//                 prefixIcon: Icon(Icons.description_outlined),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             SizedBox(height: 20),

//             // Pricing and Duration
//             Text("Pricing and duration"),
//             SizedBox(height: 6),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: priceController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: "Price *",
//                       prefixIcon: Icon(Icons.currency_rupee),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: TextField(
//                     controller: durationController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: "Duration (min) *",
//                       prefixIcon: Icon(Icons.timer),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 30),

//             // Save Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange[700],
//                   padding: EdgeInsets.symmetric(vertical: 14),
//                 ),
// onPressed: () async {
//   if (selectedCategory == null || selectedService == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Please select category and service")),
//     );
//     return;
//   }

//   try {
//     int? salonCategoryId;
//     int? salonSubCategoryId;
//     int masterSubCategoryId = selectedService!['id']; // master service ID

//     // Decide based on category type
//     if (selectedCategoryType == 'category') {
//       // User selected only a category
//       salonCategoryId = selectedCategory!['id'];
//     } else if (selectedCategoryType == 'subCategory') {
//       // User selected a subcategory
//       salonSubCategoryId = selectedCategory!['id'];
//     }

//     // Safety check: cannot send both
//     if (salonCategoryId != null && salonSubCategoryId != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Select either category or subcategory, not both")),
//       );
//       return;
//     }

//     // Build request
//     final request = AddSalonServiceRequest(
//       masterSubCategoryId: masterSubCategoryId,
//       salonCategoryId: salonCategoryId,
//       salonSubCategoryId: salonSubCategoryId,
//       name: nameController.text.trim(),
//       description: descController.text.trim(),
//       defaultDurationMin: int.tryParse(durationController.text) ?? 0,
//       defaultPriceMinor: int.tryParse(priceController.text) ?? 0,
//       priceType: "fixed",
//       code: null,
//       source: "custom",
//       scope: "salon",
//       ownerBranchId: widget.salonId,
//       isActive: true,
//     );

//     print("➡️ Final Request JSON: ${jsonEncode(request.toJson())}");

//     final response = await ApiService().addService(
//       salonId: widget.salonId,
//       request: request,
//     );

//     print("✅ Service Added: $response");

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Service added successfully!")),
//     );

//     Navigator.pop(context, true);

//   } catch (e) {
//     print("❌ Error adding service: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Failed to add service")),
//     );
//   }
// },


//                 child: Text("Add Service", style: TextStyle(fontSize: 16)),
//               ),
//             ),

//             Center(
//               child: TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Helper method to flatten categories and subcategories
// List<DropdownMenuItem<Map<String, dynamic>>> _getCategoryAndSubcategoryItems(List<dynamic> categories) {
//   List<DropdownMenuItem<Map<String, dynamic>>> items = [];

//   for (var category in categories) {
//     // If category has subcategories, make it non-selectable by using `null` for `onChanged`
//     items.add(
//       DropdownMenuItem<Map<String, dynamic>>(
//         value: category,
//         enabled: category['subCategories'] == null || category['subCategories'].isEmpty, // Disable if it has subcategories
//         child: Text(
//           category['name'],
//           style: TextStyle(
//             color: (category['subCategories'] == null || category['subCategories'].isEmpty)
//                 ? Colors.black // Allow selection if no subcategories
//                 : Colors.grey, // Disable if subcategories exist
//           ),
//         ),
//       ),
//     );

//     // Add subcategories under the category (with indentation)
//     for (var subCategory in category['subCategories'] ?? []) {
//       items.add(
//         DropdownMenuItem<Map<String, dynamic>>(
//           value: subCategory,
//           child: Padding(
//             padding: EdgeInsets.only(left: 20), // Indent subcategory
//             child: Text(subCategory['name']),
//           ),
//         ),
//       );
//     }
//   }

//   return items;
// }

import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import 'dart:convert';

class AddServices extends StatefulWidget {
  final int salonId;
  final Map<String, dynamic>? selectedCategory;
  final List<dynamic>? categories; // ✅ multiple categories

  AddServices({
    required this.salonId,
    this.selectedCategory,
    this.categories,
  });

  @override
  _AddServicesState createState() => _AddServicesState();
}

class _AddServicesState extends State<AddServices> {
  List<dynamic> serviceCatalog = [];
  Map<String, dynamic>? selectedCategory;
  Map<String, dynamic>? selectedService;
  String? selectedCategoryType;
bool _isLoading = false;

  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedCategory = null;
    selectedService = null;
    fetchServiceCatalog();
  }

  Future<void> fetchServiceCatalog() async {
    try {
      final response = await ApiService().getServiceCatalog();
      if (response['success'] == true) {
        setState(() {
          serviceCatalog = response['data'];
        });
      }
    } catch (e) {
      print("❌ Error fetching service catalog: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch service catalog")),
      );
    }
  }

  String _mapErrorMessage(String backendMessage) {
    if (backendMessage.contains("defaultDurationMin")) {
      return "Duration must be a positive number";
    }
    if (backendMessage.contains("defaultPriceMinor")) {
      return "Price must be a positive number";
    }
    if (backendMessage.contains("name")) {
      return "Service name is required";
    }
    return backendMessage; // fallback
  }
//   Future<void> _addService() async {
//   try {
//     int? salonCategoryId;
//     int? salonSubCategoryId;
//     int masterSubCategoryId = selectedService!['id'];

//     if (selectedCategoryType == 'category') {
//       salonCategoryId = selectedCategory!['id'];
//     } else if (selectedCategoryType == 'subCategory') {
//       salonSubCategoryId = selectedCategory!['id'];
//     }

//     if (salonCategoryId != null && salonSubCategoryId != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Select either category or subcategory, not both")),
//       );
//       return;
//     }

//     final request = AddSalonServiceRequest(
//       masterSubCategoryId: masterSubCategoryId,
//       salonCategoryId: salonCategoryId,
//       salonSubCategoryId: salonSubCategoryId,
//       name: nameController.text.trim(),
//       description: descController.text.trim(),
//       defaultDurationMin: int.parse(durationController.text),
//       defaultPriceMinor: int.parse(priceController.text),
//       priceType: "fixed",
//       code: null,
//       source: "custom",
//       scope: "salon",
//       ownerBranchId: widget.salonId,
//       isActive: true,
//     );

//     print("➡️ Final Request JSON: ${jsonEncode(request.toJson())}");

//     final response = await ApiService().addService(
//       salonId: widget.salonId,
//       request: request,
//     );

//     print("✅ Service Added: $response");

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Service added successfully!")),
//     );
//     Navigator.pop(context, true);

//   } catch (e) {
//     print("❌ Error adding service: $e");

//     String errorMessage = "Failed to add service";

//     try {
//       // Clean the exception string first
//       String errorStr = e.toString();
//       errorStr = errorStr.replaceFirst("Exception: ", "");
//       errorStr = errorStr.replaceFirst("Failed to add service: ", "");

//       final errorJson = jsonDecode(errorStr);

//       if (errorJson['message'] is List && errorJson['message'].isNotEmpty) {
//         errorMessage = errorJson['message'][0]; // ✅ show backend message
//       } else if (errorJson['message'] is String) {
//         errorMessage = errorJson['message'];
//       }
//     } catch (parseError) {
//       print("⚠️ Error parsing backend message: $parseError");
//       // fallback stays as "Failed to add service"
//     }

//     // Show AlertDialog with final errorMessage
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text("Alert"),
//         content: Text(errorMessage),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }
// }
Future<void> _addService() async {
    setState(() => _isLoading = true); // show loader
    try {
      int? salonCategoryId;
      int? salonSubCategoryId;
      int masterSubCategoryId = selectedService!['id'];

      if (selectedCategoryType == 'category') {
        salonCategoryId = selectedCategory!['id'];
      } else if (selectedCategoryType == 'subCategory') {
        salonSubCategoryId = selectedCategory!['id'];
      }

      if (salonCategoryId != null && salonSubCategoryId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Select either category or subcategory, not both")),
        );
        return;
      }

      final request = AddSalonServiceRequest(
        masterSubCategoryId: masterSubCategoryId,
        salonCategoryId: salonCategoryId,
        salonSubCategoryId: salonSubCategoryId,
        name: nameController.text.trim(),
        description: descController.text.trim(),
        defaultDurationMin: int.parse(durationController.text),
        defaultPriceMinor: int.parse(priceController.text),
        priceType: "fixed",
        code: null,
        source: "custom",
        scope: "salon",
        ownerBranchId: widget.salonId,
        isActive: true,
      );

      final response = await ApiService().addService(
        salonId: widget.salonId,
        request: request,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Service added successfully!")),
      );
      Navigator.pop(context, true);

    } catch (e) {
      String errorMessage = "Failed to add service";
      try {
        String errorStr = e.toString();
        errorStr = errorStr.replaceFirst("Exception: ", "");
        errorStr = errorStr.replaceFirst("Failed to add service: ", "");
        final errorJson = jsonDecode(errorStr);

        if (errorJson['message'] is List && errorJson['message'].isNotEmpty) {
          errorMessage = errorJson['message'][0];
        } else if (errorJson['message'] is String) {
          errorMessage = errorJson['message'];
        }
      } catch (_) {}

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Alert"),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false); // hide loader
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Service")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Service name *"),
            SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Add a service name",
                prefixIcon: Icon(Icons.work_outline),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Select Category *"),
                      SizedBox(height: 6),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        isExpanded: true,
                        value: selectedCategory,
                        hint: Text("Select Category"),
                        items: _getCategoryAndSubcategoryItems(widget.categories ?? []),
                        onChanged: (item) {
                          if (item == null) return;
                          bool isSubCategory = item['subCategories'] == null || item['subCategories'].isEmpty;
                          setState(() {
                            selectedCategory = item;
                            selectedCategoryType = isSubCategory ? 'subCategory' : 'category';
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Subcategory *"),
                      SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: selectedService?['id'],
                        hint: Text("Select"),
                        items: serviceCatalog.expand<DropdownMenuItem<int>>((service) {
                          final subCats = service['subCategories'] ?? [];
                          return subCats.map<DropdownMenuItem<int>>((sub) {
                            return DropdownMenuItem<int>(
                              value: sub['id'],
                              child: Text("${sub['name']}"),
                            );
                          }).toList();
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final found = serviceCatalog
                              .expand((service) => service['subCategories'] ?? [])
                              .firstWhere((sub) => sub['id'] == value);

                          setState(() {
                            selectedService = {
                              "id": found['id'],
                              "name": found['name'],
                              "parentId": found['parentId'] ?? 0,
                              "parentName": found['parentName'] ?? "",
                            };
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            Text("Description (Optional)"),
            SizedBox(height: 6),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                hintText: "Add a short description",
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            Text("Pricing and duration"),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Price *",
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Duration (min) *",
                      prefixIcon: Icon(Icons.timer),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
             SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoading
                    ? null // disable button when loading
                    : () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Service name is required")),
                          );
                          return;
                        }
                        if (selectedCategory == null || selectedService == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Please select category and service")),
                          );
                          return;
                        }
                        if (priceController.text.trim().isEmpty ||
                            int.tryParse(priceController.text) == null ||
                            int.parse(priceController.text) <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Price must be a positive number")),
                          );
                          return;
                        }
                        if (durationController.text.trim().isEmpty ||
                            int.tryParse(durationController.text) == null ||
                            int.parse(durationController.text) <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Duration must be a positive number")),
                          );
                          return;
                        }
                        await _addService();
                      },
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text("Add Service", style: TextStyle(fontSize: 16)),
              ),
            ),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context,true),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
              ),
            )
          ],
        ),
      ),
    );
  }
}

List<DropdownMenuItem<Map<String, dynamic>>> _getCategoryAndSubcategoryItems(List<dynamic> categories) {
  List<DropdownMenuItem<Map<String, dynamic>>> items = [];

  for (var category in categories) {
    items.add(
      DropdownMenuItem<Map<String, dynamic>>(
        value: category,
        enabled: category['subCategories'] == null || category['subCategories'].isEmpty,
        child: Text(
          category['name'],
          style: TextStyle(
            color: (category['subCategories'] == null || category['subCategories'].isEmpty)
                ? Colors.black
                : Colors.grey,
          ),
        ),
      ),
    );

    for (var subCategory in category['subCategories'] ?? []) {
      items.add(
        DropdownMenuItem<Map<String, dynamic>>(
          value: subCategory,
          child: Padding(
            padding: EdgeInsets.only(left: 20),
            child: Text(subCategory['name']),
          ),
        ),
      );
    }
  }

  return items;
}
