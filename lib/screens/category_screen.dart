import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../Viewmodels/AddCategory.dart';
import '../screens/AddServices.dart'; // 👈 Import AddServices screen

class CategoryScreen extends StatefulWidget {
  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;

  int? selectedBranchId;
  Map<String, dynamic>? selectedBranch;
  List<dynamic> categories = [];
  bool loadingCategories = false;

  @override
  void initState() {
    super.initState();
    salonsList = getSalonListApi();
  }

  Future<List<Map<String, dynamic>>> getSalonListApi() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        List salons = response['data'];
        return salons.map((salon) {
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
      print("Error fetching salon list: $e");
      return [];
    }
  }
  
Future<void> fetchCategories() async {
  if (selectedBranch == null) return;
  setState(() => loadingCategories = true);

  try {
    final response =
        await ApiService().getService(salonId: selectedBranch!['salonId']);
    if (response['success'] == true) {
      setState(() {
        categories = response['data']['categories']; // 👈 categories with services
      });
      print("Categories fetched: $categories");  // Debugging line
    }
  } catch (e) {
    print("❌ Error fetching categories/services: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to fetch catalogue")),
    );
  } finally {
    setState(() => loadingCategories = false);
  }
}

  void _confirmDeleteService(int serviceId) {
    // For now just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Delete pressed for service $serviceId")),
    );
  }
void _addSubcategoryDialog(Map<String, dynamic>? subCategory, int categoryId) {
  // Initialize the controller with the subcategory name if editing, or an empty string if adding
  final nameController = TextEditingController(text: subCategory != null ? subCategory['name'] : '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              subCategory == null ? "Add Subcategory" : "Edit Subcategory", // Show appropriate title
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController, // Set the controller to pre-fill name if editing
              decoration: InputDecoration(
                labelText: "Subcategory Name",
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the modal
                    },
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final subcategoryName = nameController.text.trim();
                      if (subcategoryName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please enter a subcategory name")),
                        );
                        return;
                      }

                      try {
                        final apiService = ApiService();  // Create an instance of ApiService
                        if (subCategory == null) {
                          // Adding a new subcategory
                          final response = await apiService.addSubCategoryApi(
                            salonId: selectedBranch!['salonId'],  // dynamic salonId
                            categoryId: categoryId,  // Use categoryId passed as parameter
                            name: subcategoryName,
                          );
                        } else {
                          // Editing an existing subcategory
                          final response = await apiService.updateSubCategoryApi(
                            salonId: selectedBranch!['salonId'],  // dynamic salonId
                            subCategoryId: subCategory['id'],  // dynamic subcategory ID
                            name: subcategoryName,
                          );
                        }

                        // If the API call is successful, update state and UI
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(subCategory == null ? "Subcategory added successfully" : "Subcategory updated successfully")),
                        );

                        // Close the modal
                        Navigator.pop(context);

                        // Refetch the categories to reflect the new/edited subcategory
                        fetchCategories();
                      } catch (e) {
                        // If there's an error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error adding/editing subcategory: $e")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                    ),
                    child: Text("Save"),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  void _showAddCategorySheet({Map<String, dynamic>? category}) {
    final nameController =
        TextEditingController(text: category != null ? category['name'] : '');
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                category == null ? "Add Category" : "Edit Category",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Name",
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // ✅ Description input (not sent to API yet)
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: "Description",
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedBranch == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Please select a salon first")),
                          );
                          return;
                        }

                        try {
                          if (category == null) {
                            // Add Category
                            final request = AddCategoryRequest(
                              name: nameController.text.trim(),
                              sortOrder: 1,
                            );

                            await ApiService().addCategory(
                              salonId: selectedBranch!['salonId'],
                              request: request,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text("Category created successfully")),
                            );
                          } else {
                            // Update Category
                            await ApiService().updateCategory(
                              salonId: selectedBranch!['salonId'],
                              categoryId: category['id'],
                              name: nameController.text.trim(),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text("Category updated successfully")),
                            );
                          }

                          Navigator.pop(context);
                          fetchCategories();
                        } catch (e) {
                          print("❌ Error saving category: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to save category")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                      ),
                      child: Text("Save"),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Delete Category",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${category['name']}"?\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
              },
              child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                Navigator.pop(context); // close dialog first
                await _deleteCategory(category['id']);
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(int categoryId) async {
    try {
      await ApiService().deleteCategory(
        salonId: selectedBranch!['salonId'],
        categoryId: categoryId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Category deleted successfully")),
      );
      fetchCategories();
    } catch (e) {
      print("❌ Error deleting category: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete category")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Catalogue")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text("No salons found"));
            } else {
              final salons = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<int>(
                    isExpanded: true,
                    value: selectedBranchId,
                    hint: Text("Select Salon Branch"),
                    items: salons.expand((salon) {
                      final branches = salon['branches'] as List;
                      return branches
                          .map<DropdownMenuItem<int>>((branch) {
                        return DropdownMenuItem(
                          value: branch['id'],
                          child: Text(branch['name'],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList();
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBranchId = value;
                        if (value != null) {
                          final salon = salons.firstWhere((s) =>
                              (s['branches'] as List)
                                  .any((b) => b['id'] == value));
                          final branch = (salon['branches'] as List)
                              .firstWhere((b) => b['id'] == value);
                          selectedBranch = {
                            'salonId': salon['id'],
                            'branchId': branch['id'],
                            'branchName': branch['name'],
                          };
                          fetchCategories();
                        }
                      });
                    },
                  ),
                  SizedBox(height: 30),
Expanded(
  child: loadingCategories
      ? Center(child: CircularProgressIndicator())
      : categories.isEmpty
          ? Center(
              child: Text(
                "No categories found",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final subCategories = category['subCategories'] ?? [];

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.brown),
                                  onPressed: () =>
                                      _showAddCategorySheet(category: category),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.orange),
                                  onPressed: () => _confirmDeleteCategory(category),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Show subcategories with services count
      Text(
  "${subCategories.length} Subcategory",
  style: TextStyle(
       fontSize: 14, color: Colors.grey),
),


                        SizedBox(height: 8),
                        
                        // Show subcategories with services
                        for (var subCategory in subCategories) ...[
  Padding(
    padding: const EdgeInsets.only(left: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row for subcategory name and edit/delete icons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Display the subcategory name
            Text(
              subCategory['name'],
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,color: Colors.purple),
            ),
           Row(
      children: [
        // Edit icon button
     IconButton(
  icon: Icon(Icons.edit, color: Colors.brown),
  onPressed: () {
    _addSubcategoryDialog(subCategory, category['id']);  // Pass the subcategory and categoryId
  },
),


                // Delete icon button
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.orange),
                  onPressed: () {
                    // Handle the delete functionality
                    _confirmDeleteCategory(subCategory);
                  },
                ),
              ],
            ),
          ],
        ),
        
        // Display the number of services below the subcategory
        Text(
          "${subCategory['services'].length} Service${subCategory['services'].length == 1 ? '' : 's'}",
          style: TextStyle(
              fontSize: 14, color: Colors.grey),
        ),
        SizedBox(height: 4),

        // Show services of subcategory
        if (subCategory['services'] != null &&
            subCategory['services'].isNotEmpty)
          ...subCategory['services'].map<Widget>((service) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(service['displayName'] ?? "Unnamed Service"),
              subtitle: Text(
                  "Rs. ${service['priceMinor']} - ${service['durationMin']} min"),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.orange),
                onPressed: () =>
                    _confirmDeleteService(service['id']),
              ),
            );
          }).toList(),
        SizedBox(height: 8),
        Divider(),
        SizedBox(height: 8),
      ],
    ),
  ),
],


                        // Actions (subcategory + add service)
                        Row(
                          children: [
TextButton.icon(
  onPressed: () {
    _addSubcategoryDialog(null, category['id']);  // Pass null for adding a new subcategory
  },
  icon: Icon(Icons.add, color: Colors.orange),
  label: Text(
    "Add Subcategory",
    style: TextStyle(color: Colors.orange),
  ),
),



                            SizedBox(width: 20),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddServices(
                                      salonId: selectedBranch!['salonId'],
                                      selectedCategory: category,
                                      categories: categories,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.add, color: Colors.orange),
                              label: Text(
                                "Add Services",
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
),

],
        );
            };
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (selectedBranch == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Please select a salon branch to add category")),
            );
            return;
          }
          _showAddCategorySheet();
        },
        label: Text("Add Category"),
        icon: Icon(Icons.add),
        backgroundColor: Colors.orange[300],
      ),
    );
  }
}