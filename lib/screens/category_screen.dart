// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
// import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
// import '../Viewmodels/AddCategory.dart';
// import 'AddServices.dart';

// class CategoryScreen extends StatefulWidget {
//   const CategoryScreen({super.key});

//   @override
//   State<CategoryScreen> createState() => _CategoryScreenState();
// }

// class _CategoryScreenState extends State<CategoryScreen> {
//   final Map<int, bool> _expandedSubcategories = {};
//   int? _selectedBranchId;
//   Map<String, dynamic>? _selectedBranch;

// @override
// void initState() {
//   super.initState();
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     final salonCubit = context.read<SalonListCubit>();

//     if (salonCubit.state.salons.isEmpty) {
//       salonCubit.loadSalons();
//     } else if (salonCubit.state.selectedBranch != null) {
//       setState(() {
//         _selectedBranch = salonCubit.state.selectedBranch;
//         _selectedBranchId = _selectedBranch!['branchId'];
//       });
//       // context.read<CategoryCubit>().loadCategories(_selectedBranch!['salonId']);
//     }
//   });
// }


//   void _onBranchSelected(int? value, List<Map<String, dynamic>> salons) {
//     if (value == null) return;

//     for (final salon in salons) {
//       final branches =
//           (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
//       final Map<String, dynamic> match = branches.firstWhere(
//         (branch) => branch['id'] == value,
//         orElse: () => <String, dynamic>{},
//       );
//       if (match.isNotEmpty) {
//         setState(() {
//           _selectedBranchId = value;
//           _selectedBranch = {
//             'salonId': salon['id'],
//             'branchId': match['id'],
//             'branchName': match['name'],
//           };
//           _expandedSubcategories.clear();
//         });
//         context.read<SalonListCubit>().setSelectedBranch(_selectedBranch!);
//         context.read<CategoryCubit>().loadCategories(salon['id'] as int);
//         break;
//       }
//     }
//   }

//   // ---------- ADD / EDIT CATEGORY (await the sheet) ----------
//   Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
//     if (_selectedBranch == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Select a salon branch first.')),
//       );
//       return;
//     }

//     final result = await showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (sheetContext) {
//         final isEdit = category != null;
//         final nameController = TextEditingController(
//           text: category?['name'] as String? ?? '',
//         );
//         final descriptionController = TextEditingController(
//           text: category?['description'] as String? ?? '',
//         );
//         return Padding(
//           padding: EdgeInsets.only(
//             left: 16,
//             right: 16,
//             top: 16,
//             bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[400],
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 isEdit ? 'Edit Category' : 'Add Category',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//              TextField(
//   controller: nameController,
//   textCapitalization: TextCapitalization.words, // 👈
//   decoration: const InputDecoration(
//     labelText: 'Category Name',
//     border: OutlineInputBorder(),
//   ),
// ),

//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     final name = nameController.text.trim();
//                     if (name.isEmpty) {
//                       ScaffoldMessenger.of(sheetContext).showSnackBar(
//                         const SnackBar(content: Text('Name is required.')),
//                       );
//                       return;
//                     }

//                     FocusScope.of(sheetContext).unfocus();

//                     final payload = AddCategoryRequest(
//                       name: name,
//                       description: descriptionController.text.trim(),
//                       // isDisabled: !enableToggle.value,
//                     );
//                     final categoryId = category?['id'] as int?;

//                     // Pop with the payload; no bloc call here
//                     Navigator.of(sheetContext).pop(<String, dynamic>{
//                       'request': payload,
//                       'categoryId': categoryId,
//                     });
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: Text(isEdit ? 'Update Category' : 'Add Category'),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );

//     if (!mounted || result == null) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     final cubit = context.read<CategoryCubit>();
//     final req = result['request'] as AddCategoryRequest;
//     final categoryId = result['categoryId'] as int?;

//     if (categoryId != null) {
//       cubit.updateCategory(salonId, categoryId, req);
//     } else {
//       cubit.addCategory(salonId, req);
//     }
//   }

//   // ---------- ADD / EDIT SUBCATEGORY (await the sheet) ----------
//   Future<void> _openSubcategorySheet({
//     Map<String, dynamic>? subCategory,
//     required int categoryId,
//   }) async {
//     if (_selectedBranch == null) return;

//     final result = await showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (sheetContext) {
//         final controller = TextEditingController(
//           text: subCategory?['name'] as String? ?? '',
//         );
//         final isEdit = subCategory != null;

//         return Padding(
//           padding: EdgeInsets.only(
//             left: 16,
//             right: 16,
//             top: 16,
//             bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[400],
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 isEdit ? 'Edit Subcategory' : 'Add Subcategory',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: controller,
//                 textCapitalization: TextCapitalization.words,
//                 decoration: const InputDecoration(
//                   labelText: 'Subcategory Name',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     final name = controller.text.trim();
//                     if (name.isEmpty) {
//                       ScaffoldMessenger.of(sheetContext).showSnackBar(
//                         const SnackBar(content: Text('Name is required.')),
//                       );
//                       return;
//                     }
//   if (!RegExp(r'^[A-Z]').hasMatch(name)) {
//                     ScaffoldMessenger.of(sheetContext).showSnackBar(
//                       const SnackBar(
//                         content:
//                             Text('Name must start with an uppercase letter'),
//                       ),
//                     );
//                     return;
//                   }
//                     FocusScope.of(sheetContext).unfocus();

//                     final subCategoryId = subCategory?['id'] as int?;
//                     Navigator.of(sheetContext).pop(<String, dynamic>{
//                       'name': name,
//                       'subCategoryId': subCategoryId,
//                     });
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: Text(
//                     isEdit ? 'Update Subcategory' : 'Add Subcategory',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );

//     if (!mounted || result == null) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     final cubit = context.read<CategoryCubit>();
//     final name = result['name'] as String;
//     final subCategoryId = result['subCategoryId'] as int?;

//     if (subCategoryId != null) {
//       cubit.updateSubCategory(salonId, subCategoryId, name);
//     } else {
//       cubit.addSubCategory(salonId, categoryId, name);
//     }
//   }

//   // ---------- CONFIRM DELETE (await the dialog) ----------
//   Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
//     if (_selectedBranch == null) return;

//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: const Text('Delete Category'),
//         content: const Text('Are you sure you want to delete this category?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(true),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (!mounted || confirmed != true) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     context.read<CategoryCubit>().deleteCategory(
//       salonId,
//       category['id'] as int,
//     );
//   }

//   Future<void> _confirmDeleteSubCategory(
//     Map<String, dynamic> subCategory,
//   ) async {
//     if (_selectedBranch == null) return;

//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: const Text('Delete Subcategory'),
//         content: const Text(
//           'Are you sure you want to delete this subcategory?',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(true),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (!mounted || confirmed != true) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     context.read<CategoryCubit>().deleteSubCategory(
//       salonId,
//       subCategory['id'] as int,
//     );
//   }

//   // ---------- EDIT SERVICE (await the sheet) ----------
//   Future<void> _showUpdateServiceSheet(Map<String, dynamic> service) async {
//     final result = await showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (sheetContext) {
//         final nameController = TextEditingController(
//           text: service['displayName'] ?? service['name'] ?? '',
//         );
//         final descriptionController = TextEditingController(
//           text: service['description'] ?? '',
//         );
//         final durationController = TextEditingController(
//           text:
//               (service['durationMin'] ?? service['defaultDurationMin'])
//                   ?.toString() ??
//               '',
//         );
//         final priceController = TextEditingController(
//           text:
//               (service['priceMinor'] ?? service['defaultPriceMinor'])
//                   ?.toString() ??
//               '',
//         );
//         final isActive = ValueNotifier<bool>(service['isActive'] ?? true);

//         return Padding(
//           padding: EdgeInsets.only(
//             left: 16,
//             right: 16,
//             top: 16,
//             bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[400],
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Edit Service',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: nameController,
//                 textCapitalization: TextCapitalization.words,
//                 decoration: const InputDecoration(
//                   labelText: 'Service Name',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: descriptionController,
//                 maxLines: 1,
//                 decoration: const InputDecoration(
//                   labelText: 'Description',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: durationController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   labelText: 'Duration (minutes)',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: priceController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   labelText: 'Price (minor units)',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               ValueListenableBuilder<bool>(
//                 valueListenable: isActive,
//                 builder: (context, value, _) {
//                   return SwitchListTile(
//                     value: value,
//                     onChanged: (newValue) => isActive.value = newValue,
//                     title: const Text('Active'),
//                   );
//                 },
//               ),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     final name = nameController.text.trim();
//                     if (name.isEmpty) {
//                       ScaffoldMessenger.of(sheetContext).showSnackBar(
//                         const SnackBar(content: Text('Name is required.')),
//                       );
//                       return;
//                     }
//   if (!RegExp(r'^[A-Z]').hasMatch(name)) { // 👈 must start uppercase
//     ScaffoldMessenger.of(sheetContext).showSnackBar(
//       const SnackBar(content: Text('Name must start with an uppercase letter')),
//     );
//     return;
//   }

//                     FocusScope.of(sheetContext).unfocus();

//                     final payload = {
//                       'name': name,
//                       'description': descriptionController.text.trim(),
//                       'defaultDurationMin': int.tryParse(
//                         durationController.text.trim(),
//                       ),
//                       'defaultPriceMinor': int.tryParse(
//                         priceController.text.trim(),
//                       ),
//                       'isActive': isActive.value,
//                     }..removeWhere((key, value) => value == null);

//                     Navigator.of(sheetContext).pop(<String, dynamic>{
//                       'serviceId': service['id'] as int,
//                       'payload': payload,
//                     });
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: const Text('Update Service'),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );

//     if (!mounted || result == null) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     final serviceId = result['serviceId'] as int;
//     final payload = result['payload'] as Map<String, dynamic>;
//     context.read<CategoryCubit>().updateService(salonId, serviceId, payload);
//   }

//   Future<void> _confirmDeleteService(int serviceId) async {
//     if (_selectedBranch == null) return;

//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: const Text('Delete Service'),
//         content: const Text('Are you sure you want to delete this service?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(true),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (!mounted || confirmed != true) return;

//     final salonId = _selectedBranch!['salonId'] as int;
//     context.read<CategoryCubit>().deleteService(salonId, serviceId);
//   }

//   void _openAddService(
//     Map<String, dynamic> category,
//     List<dynamic> categories,
//   ) {
//     if (_selectedBranch == null) return;

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddServices(
//           salonId: _selectedBranch!['salonId'] as int,
//           selectedCategory: category,
//           categories: categories,
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('My Catalogue')),
//       body: BlocListener<CategoryCubit, CategoryState>(
//         listenWhen: (previous, current) => previous.message != current.message,
//         listener: (context, state) {
//           if (state.message != null) {
//             ScaffoldMessenger.of(
//               context,
//             ).showSnackBar(SnackBar(content: Text(state.message!)));
//             context.read<CategoryCubit>().clearMessage();
//           }
//         },
//         child: BlocBuilder<CategoryCubit, CategoryState>(
//           builder: (context, state) {
//             return Stack(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       BlocBuilder<SalonListCubit, SalonListState>(
//                         builder: (context, salonState) {
//                           final salons = salonState.salons;
//                           if (salonState.isLoading && salons.isEmpty) {
//                             return const Center(
//                               child: CircularProgressIndicator(),
//                             );
//                           }
//                           if (salonState.hasError && salons.isEmpty) {
//                             return Text(
//                               salonState.errorMessage ??
//                                   'Failed to load salons',
//                             );
//                           }
//                           if (salons.isEmpty) {
//                             return const Text('No salons found');
//                           }
// if (salonState.isLoading && salons.isEmpty) {
//   return const Center(child: CircularProgressIndicator());
// }

//                           return DropdownButton<int>(
//                             isExpanded: true,
//                             value: _selectedBranchId,
//                             hint: const Text('Select Salon Branch'),
//                             items: salons.expand((salon) {
//                               final branches =
//                                   (salon['branches'] as List?)
//                                       ?.cast<Map<String, dynamic>>() ??
//                                   [];
//                               return branches
//                                   .map<DropdownMenuItem<int>>(
//                                     (branch) => DropdownMenuItem(
//                                       value: branch['id'] as int,
//                                       child: Text(branch['name'] as String),
//                                     ),
//                                   )
//                                   .toList();
//                             }).toList(),
//                             onChanged: (value) =>
//                                 _onBranchSelected(value, salons),
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 24),
//                       Expanded(child: _buildCategoryContent(state)),
//                     ],
//                   ),
//                 ),
//                 if (state.isSubmitting) _buildLoaderOverlay(),
//               ],
//             );
//           },
//         ),
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () => _showAddCategorySheet(),
//         label: const Text('Add Category'),
//         icon: const Icon(Icons.add),
//         backgroundColor: Colors.orange[300],
//       ),
//     );
//   }

//   Widget _buildCategoryContent(CategoryState state) {
//     if (_selectedBranch == null) {
//       return const Center(child: Text('Select a branch to view categories'));
//     }

//     if (state.isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (state.status == CategoryStatus.failure) {
//       return Center(child: Text(state.message ?? 'Failed to load categories'));
//     }

//     final categories = state.categories;
//     if (categories.isEmpty) {
//       return const Center(child: Text('No categories found'));
//     }

//     return ListView.builder(
//       itemCount: categories.length,
//       itemBuilder: (context, index) {
//         final category = categories[index] as Map<String, dynamic>;
//         final subCategories = (category['subCategories'] as List?) ?? [];
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           elevation: 2,
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       category['name'] as String,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.purple,
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.edit, color: Colors.brown),
//                           onPressed: () =>
//                               _showAddCategorySheet(category: category),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.delete, color: Colors.orange),
//                           onPressed: () => _confirmDeleteCategory(category),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//  Text(
//   '${subCategories.length} Subcategory',
//   style: const TextStyle(fontSize: 14, color: Colors.grey),
// ),


//                 const SizedBox(height: 12),
//                 for (final subCategory in subCategories)
//                   _buildSubcategoryTile(
//                     category,
//                     subCategory as Map<String, dynamic>,
//                     categories,
//                   ),
//                 Row(
//                   children: [
//                     TextButton.icon(
//                       onPressed: () => _openSubcategorySheet(
//                         categoryId: category['id'] as int,
//                       ),
//                       icon: const Icon(Icons.add, color: Colors.orange),
//                       label: const Text(
//                         'Add Subcategory',
//                         style: TextStyle(color: Colors.orange),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     TextButton.icon(
//                       onPressed: () => _openAddService(category, categories),
//                       icon: const Icon(Icons.add, color: Colors.orange),
//                       label: const Text(
//                         'Add Services',
//                         style: TextStyle(color: Colors.orange),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLoaderOverlay() {
//     return const Positioned.fill(
//       child: Stack(
//         children: [
//           ModalBarrier(dismissible: false, color: Colors.black45),
//           Center(child: CircularProgressIndicator()),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubcategoryTile(
//     Map<String, dynamic> category,
//     Map<String, dynamic> subCategory,
//     List<dynamic> categories,
//   ) {
//     final subCategoryId = subCategory['id'] as int;
//     final isExpanded = _expandedSubcategories[subCategoryId] ?? false;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     _expandedSubcategories[subCategoryId] = !isExpanded;
//                   });
//                 },
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 8,
//                     horizontal: 12,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               subCategory['name'] as String,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.purple,
//                               ),
//                             ),
//                             Text(
//                               '${(subCategory['services'] as List?)?.length ?? 0} Services',
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.edit, color: Colors.brown),
//                         onPressed: () => _openSubcategorySheet(
//                           subCategory: subCategory,
//                           categoryId: category['id'] as int,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.orange),
//                         onPressed: () => _confirmDeleteSubCategory(subCategory),
//                       ),
//                       // Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         if (isExpanded)
//           Column(
//             children: [
//               for (final service in (subCategory['services'] as List?) ?? [])
//                 ListTile(
//                   dense: true,
//                   contentPadding: EdgeInsets.zero,
//                   title: Text(
//                     service['displayName'] as String? ?? 'Unnamed Service',
//                   ),
//                   subtitle: Text(
//                     'Rs. ${service['priceMinor']} - ${service['durationMin']} min',
//                   ),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.edit, color: Colors.brown),
//                         onPressed: () => _showUpdateServiceSheet(service),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.orange),
//                         onPressed: () =>
//                             _confirmDeleteService(service['id'] as int),
//                       ),
//                     ],
//                   ),
//                 ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         const SizedBox(height: 12),
//       ],
//     );
//   }
// }
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import '../Viewmodels/AddCategory.dart';
import 'AddServices.dart';

/// Shared function signature for opening the subcategory sheet
typedef SubcategoryOp = Future<void> Function({
  Map<String, dynamic>? subCategory,
  required int categoryId,
});

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final Map<int, bool> _expandedSubcategories = {};
  int? _selectedBranchId;
  Map<String, dynamic>? _selectedBranch;

  // ---------- LIFECYCLE ----------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salonCubit = context.read<SalonListCubit>();

      if (salonCubit.state.salons.isEmpty) {
        salonCubit.loadSalons();
      } else if (salonCubit.state.selectedBranch != null) {
        setState(() {
          _selectedBranch = salonCubit.state.selectedBranch;
          _selectedBranchId = _selectedBranch!['branchId'];
        });
      }
    });
  }

  // ---------- BRANCH HANDLING ----------
  void _onBranchSelected(int? value, List<Map<String, dynamic>> salons) {
    if (value == null) return;

    for (final salon in salons) {
      final branches =
          (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final Map<String, dynamic> match = branches.firstWhere(
        (branch) => branch['id'] == value,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        setState(() {
          _selectedBranchId = value;
          _selectedBranch = {
            'salonId': salon['id'],
            'branchId': match['id'],
            'branchName': match['name'],
          };
          _expandedSubcategories.clear();
        });
        context.read<SalonListCubit>().setSelectedBranch(_selectedBranch!);
        context.read<CategoryCubit>().loadCategories(salon['id'] as int);
        break;
      }
    }
  }

  // ---------- ADD / EDIT CATEGORY ----------
  Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
    if (_selectedBranch == null) {
      _toast('Select a salon branch first.');
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditCategorySheet(category: category),
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    final req = result['request'] as AddCategoryRequest;
    final categoryId = result['categoryId'] as int?;
    final cubit = context.read<CategoryCubit>();

    if (categoryId != null) {
      cubit.updateCategory(salonId, categoryId, req);
    } else {
      cubit.addCategory(salonId, req);
    }
  }

  // ---------- ADD / EDIT SUBCATEGORY ----------
  Future<void> _openSubcategorySheet({
    Map<String, dynamic>? subCategory,
    required int categoryId,
  }) async {
    if (_selectedBranch == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _EditSubcategorySheet(subCategory: subCategory),
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    final name = result['name'] as String;
    final subCategoryId = result['subCategoryId'] as int?;
    final cubit = context.read<CategoryCubit>();

    if (subCategoryId != null) {
      cubit.updateSubCategory(salonId, subCategoryId, name);
    } else {
      cubit.addSubCategory(salonId, categoryId, name);
    }
  }

  // ---------- CONFIRM DELETE CATEGORY ----------
  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Delete Category',
        message: 'Are you sure you want to delete this category?',
        confirmColor: Colors.red,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteCategory(
          salonId,
          category['id'] as int,
        );
  }

  // ---------- CONFIRM DELETE SUBCATEGORY ----------
  Future<void> _confirmDeleteSubCategory(
    Map<String, dynamic> subCategory,
  ) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Delete Subcategory',
        message: 'Are you sure you want to delete this subcategory?',
        confirmColor: Colors.red,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteSubCategory(
          salonId,
          subCategory['id'] as int,
        );
  }

  // ---------- EDIT SERVICE ----------
  Future<void> _showUpdateServiceSheet(Map<String, dynamic> service) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditServiceSheet(service: service),
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().updateService(
          salonId,
          result['serviceId'] as int,
          result['payload'] as Map<String, dynamic>,
        );
  }

  // ---------- CONFIRM DELETE SERVICE ----------
  Future<void> _confirmDeleteService(int serviceId) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Delete Service',
        message: 'Are you sure you want to delete this service?',
        confirmColor: Colors.red,
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteService(salonId, serviceId);
  }

  // ---------- OPEN ADD SERVICE SCREEN ----------
  void _openAddService(
    Map<String, dynamic> category,
    List<dynamic> categories,
  ) {
    if (_selectedBranch == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddServices(
          salonId: _selectedBranch!['salonId'] as int,
          selectedCategory: category,
          categories: categories,
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
       title: const Text(
      'My Catalogue',
      style: TextStyle(
        color: Colors.black,        // white text
        fontWeight: FontWeight.w800 // bold
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white), // optional: white icons
  ),
      body: BlocListener<CategoryCubit, CategoryState>(
        listenWhen: (previous, current) => previous.message != current.message,
        listener: (context, state) {
          if (state.message != null) {
            _toast(state.message!);
            context.read<CategoryCubit>().clearMessage();
          }
        },
        child: BlocBuilder<CategoryCubit, CategoryState>(
          builder: (context, catState) {
            return Stack(
              children: [
                RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: () async {
                    if (_selectedBranch != null) {
                      context
                          .read<CategoryCubit>()
                          .loadCategories(_selectedBranch!['salonId'] as int);
                    } else {
                      context.read<SalonListCubit>().loadSalons();
                    }
                  },
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      _BranchPicker(
                        selectedBranchId: _selectedBranchId,
                        onSelected: _onBranchSelected,
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Categories',
                        // trailing: _selectedBranch != null
                        //     ? _SecondaryAction(
                        //         icon: Icons.add_rounded,
                        //         label: 'Add Category',
                        //         onTap: () => _showAddCategorySheet(),
                        //       )
                        //     : null,
                      ),
                      const SizedBox(height: 8),
                      if (_selectedBranch == null)
                        _EmptyState(
                          icon: Icons.store_mall_directory_outlined,
                          title: 'Select a branch',
                          subtitle:
                              'Choose a salon branch to view and manage its categories.',
                        )
                      else if (catState.isLoading)
                        const _LoaderCard()
                      else if (catState.status == CategoryStatus.failure)
                        _ErrorCard(
                          message:
                              catState.message ?? 'Failed to load categories',
                          onRetry: () {
                            final salonId =
                                _selectedBranch?['salonId'] as int?;
                            if (salonId != null) {
                              context
                                  .read<CategoryCubit>()
                                  .loadCategories(salonId);
                            }
                          },
                        )
                      else
                        _CategoryList(
                          categories: catState.categories,
                          // same handler for add & edit
                          onAddSubcategory: _openSubcategorySheet,
                          onEditSubcategory: _openSubcategorySheet,
                          onAddServices: _openAddService,
                          onEditCategory: _showAddCategorySheet,
                          onDeleteCategory: _confirmDeleteCategory,
                          onDeleteSubcategory: _confirmDeleteSubCategory,
                          onEditService: _showUpdateServiceSheet,
                          onDeleteService: _confirmDeleteService,
                          expanded: _expandedSubcategories,
                          toggleExpanded: (id) => setState(() {
                            _expandedSubcategories[id] =
                                !(_expandedSubcategories[id] ?? false);
                          }),
                          accent: Colors.orange,
                          titleColor: onBg.withOpacity(0.9),
                        ),
                    ],
                  ),
                ),
                if (catState.isSubmitting) _buildLoaderOverlay(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange[400],
      ),
    );
  }

  // ---------- OVERLAY ----------
  Widget _buildLoaderOverlay() {
    return const Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: Colors.black45),
          Center(child: CircularProgressIndicator(color: Colors.orange)),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* =======================  UI BUILDING BLOCKS  ======================= */

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({
    required this.selectedBranchId,
    required this.onSelected,
  });

  final int? selectedBranchId;
  final void Function(int?, List<Map<String, dynamic>>) onSelected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalonListCubit, SalonListState>(
      builder: (context, salonState) {
        final salons = salonState.salons;

        if (salonState.isLoading && salons.isEmpty) {
          return const _LoaderCard();
        }
        if (salonState.hasError && salons.isEmpty) {
          return _ErrorCard(
            message: salonState.errorMessage ?? 'Failed to load salons',
            onRetry: () => context.read<SalonListCubit>().loadSalons(),
          );
        }
        if (salons.isEmpty) {
          return const _EmptyState(
            icon: Icons.store_mall_directory_outlined,
            title: 'No salons found',
            subtitle: 'Add a salon first to manage categories.',
          );
        }

        return _FormCard(
          title: 'Salon Branch',
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: selectedBranchId,
            decoration: const InputDecoration(
              hintText: 'Select Salon Branch',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: salons
                .expand((salon) {
                  final branches = (salon['branches'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                      [];
                  return branches.map<DropdownMenuItem<int>>(
                    (branch) => DropdownMenuItem(
                      value: branch['id'] as int,
                      child: Text(branch['name'] as String),
                    ),
                  );
                })
                .toList()
                .cast<DropdownMenuItem<int>>(),
            onChanged: (value) =>
                onSelected(value, salons.cast<Map<String, dynamic>>()),
          ),
        );
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    required this.onAddServices,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onDeleteSubcategory,
    required this.onEditService,
    required this.onDeleteService,
    required this.expanded,
    required this.toggleExpanded,
    required this.accent,
    required this.titleColor,
  });

  final List<dynamic> categories;

  // BOTH share the same named-parameter signature
  final SubcategoryOp onAddSubcategory;
  final SubcategoryOp onEditSubcategory;

  final void Function(Map<String, dynamic> category, List<dynamic> categories)
      onAddServices;

  final Future<void> Function({Map<String, dynamic>? category})
      onEditCategory;

  final Future<void> Function(Map<String, dynamic> category)
      onDeleteCategory;

  final Future<void> Function(Map<String, dynamic>) onDeleteSubcategory;
  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int serviceId) onDeleteService;

  final Map<int, bool> expanded;
  final void Function(int id) toggleExpanded;
  final Color accent;
  final Color titleColor;

  String _pluralize(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories found',
        subtitle: 'Tap “Add Category” to create your first one.',
      );
    }

    return ListView.separated(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = categories[index] as Map<String, dynamic>;
        final subCategories =
            (category['subCategories'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
        final subCount = subCategories.length;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category['name'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _IconButton(
                      icon: Icons.edit_rounded,
                      color: Colors.brown,
                      tooltip: 'Edit category',
                      onTap: () => onEditCategory(category: category),
                    ),
                    _IconButton(
                      icon: Icons.delete_rounded,
                      color: Colors.redAccent,
                      tooltip: 'Delete category',
                      onTap: () => onDeleteCategory(category),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Badge(
                      icon: Icons.view_agenda_outlined,
                      label: _pluralize(subCount, 'Subcategory'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Subcategories
                if (subCategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No subcategories',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final sub in subCategories)
                        _SubcategoryTile(
                          categoryId: category['id'] as int,
                          subCategory: sub,
                          isExpanded: expanded[(sub['id'] as int)] ?? false,
                          toggle: () => toggleExpanded(sub['id'] as int),
                          onEditSubcategory: onEditSubcategory,
                          onDeleteSubcategory: onDeleteSubcategory,
                          onEditService: onEditService,
                          onDeleteService: onDeleteService,
                          accent: accent,
                        ),
                    ],
                  ),

                // Actions
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TextAction(
                      icon: Icons.add_rounded,
                      label: 'Add Subcategory',
                      color: accent,
                      onTap: () => onAddSubcategory(
                        categoryId: category['id'] as int,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _TextAction(
                      icon: Icons.design_services_rounded,
                      label: 'Add Services',
                      color: accent,
                      onTap: () => onAddServices(category, categories),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.categoryId,
    required this.subCategory,
    required this.isExpanded,
    required this.toggle,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
    required this.onEditService,
    required this.onDeleteService,
    required this.accent,
  });

  final int categoryId;
  final Map<String, dynamic> subCategory;
  final bool isExpanded;
  final VoidCallback toggle;

  final SubcategoryOp onEditSubcategory;
  final Future<void> Function(Map<String, dynamic>) onDeleteSubcategory;

  final Future<void> Function(Map<String, dynamic>) onEditService;
  final Future<void> Function(int) onDeleteService;

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final services =
        (subCategory['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final serviceCount = services.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: toggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _SubcategoryHeader(
                        name: subCategory['name'] as String,
                        serviceCount: serviceCount,
                      ),
                    ),
                    _IconButton(
                      icon: Icons.edit_rounded,
                      color: Colors.brown,
                      tooltip: 'Edit subcategory',
                      onTap: () => onEditSubcategory(
                        subCategory: subCategory,
                        categoryId: categoryId,
                      ),
                    ),
                    _IconButton(
                      icon: Icons.delete_rounded,
                      color: Colors.redAccent,
                      tooltip: 'Delete subcategory',
                      onTap: () => onDeleteSubcategory(subCategory),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),

            // Services
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: !isExpanded
                  ? const SizedBox.shrink()
                  : Column(
                      key: ValueKey('expanded_${subCategory['id']}'),
                      children: [
                        const Divider(height: 1),
                        if (services.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'No services',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          ...services.map((service) {
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: Text(
                                service['displayName'] as String? ??
                                    'Unnamed Service',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Rs. ${service['priceMinor']} · ${service['durationMin']} min',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _IconButton(
                                    icon: Icons.edit_rounded,
                                    color: Colors.brown,
                                    tooltip: 'Edit service',
                                    onTap: () => onEditService(service),
                                  ),
                                  _IconButton(
                                    icon: Icons.delete_rounded,
                                    color: Colors.redAccent,
                                    tooltip: 'Delete service',
                                    onTap: () => onDeleteService(
                                      service['id'] as int,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryHeader extends StatelessWidget {
  const _SubcategoryHeader({
    required this.name,
    required this.serviceCount,
  });

  final String name;
  final int serviceCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$serviceCount ${serviceCount == 1 ? 'Service' : 'Services'}',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/* =======================  SMALL WIDGETS  ======================= */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.9);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.orange),
      label: Text(
        label,
        style: const TextStyle(color: Colors.orange),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface.withOpacity(0.9);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  color: onBg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      splashRadius: 22,
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface.withOpacity(0.75);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: onBg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBg.withOpacity(0.8),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoaderCard extends StatelessWidget {
  const _LoaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      ),
    );
  }
}

class _BottomSheetScaffold extends StatelessWidget {
  const _BottomSheetScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Rounded top + safe padding + drag handle
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: const InputDecoration(
        labelText: '',
        border: OutlineInputBorder(),
      ).copyWith(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/* =======================  SHEET WIDGETS (own controllers)  ======================= */

class _EditServiceSheet extends StatefulWidget {
  const _EditServiceSheet({required this.service});
  final Map<String, dynamic> service;

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController durationController;
  late final TextEditingController priceController;
  late final ValueNotifier<bool> isActive;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    nameController =
        TextEditingController(text: s['displayName'] ?? s['name'] ?? '');
    descriptionController =
        TextEditingController(text: s['description'] ?? '');
    durationController = TextEditingController(
      text: (s['durationMin'] ?? s['defaultDurationMin'])?.toString() ?? '',
    );
    priceController = TextEditingController(
      text: (s['priceMinor'] ?? s['defaultPriceMinor'])?.toString() ?? '',
    );
    isActive = ValueNotifier<bool>(s['isActive'] ?? true);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    priceController.dispose();
    isActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return _BottomSheetScaffold(
      title: 'Edit Service',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabeledField(
            label: 'Service Name',
            controller: nameController,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Description',
            controller: descriptionController,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Duration (minutes)',
            controller: durationController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Price (minor units)',
            controller: priceController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: (nv) => isActive.value = nv,
                title: const Text('Active'),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  toast('Name is required.');
                  return;
                }
                if (!RegExp(r'^[A-Z]').hasMatch(name)) {
                  toast('Name must start with an uppercase letter');
                  return;
                }

                FocusScope.of(context).unfocus();

                final payload = {
                  'name': name,
                  'description': descriptionController.text.trim(),
                  'defaultDurationMin':
                      int.tryParse(durationController.text.trim()),
                  'defaultPriceMinor':
                      int.tryParse(priceController.text.trim()),
                  'isActive': isActive.value,
                }..removeWhere((k, v) => v == null);

                Navigator.of(context).pop(<String, dynamic>{
                  'serviceId': widget.service['id'] as int,
                  'payload': payload,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: const Text('Update Service'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCategorySheet extends StatefulWidget {
  const _EditCategorySheet({this.category});
  final Map<String, dynamic>? category;

  @override
  State<_EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<_EditCategorySheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;

  bool get isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.category?['name'] as String? ?? '');
    descriptionController = TextEditingController(
        text: widget.category?['description'] as String? ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return _BottomSheetScaffold(
      title: isEdit ? 'Edit Category' : 'Add Category',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabeledField(
            label: 'Category Name',
            controller: nameController,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Description (optional)',
            controller: descriptionController,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  toast('Name is required.');
                  return;
                }

                FocusScope.of(context).unfocus();

                final payload = AddCategoryRequest(
                  name: name,
                  description: descriptionController.text.trim(),
                );
                final categoryId = widget.category?['id'] as int?;
                Navigator.of(context).pop(<String, dynamic>{
                  'request': payload,
                  'categoryId': categoryId,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(isEdit ? 'Update Category' : 'Add Category'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSubcategorySheet extends StatefulWidget {
  const _EditSubcategorySheet({this.subCategory});
  final Map<String, dynamic>? subCategory;

  @override
  State<_EditSubcategorySheet> createState() => _EditSubcategorySheetState();
}

class _EditSubcategorySheetState extends State<_EditSubcategorySheet> {
  late final TextEditingController controller;
  bool get isEdit => widget.subCategory != null;

  @override
  void initState() {
    super.initState();
    controller =
        TextEditingController(text: widget.subCategory?['name'] as String? ?? '');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return _BottomSheetScaffold(
      title: isEdit ? 'Edit Subcategory' : 'Add Subcategory',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabeledField(
            label: 'Subcategory Name',
            controller: controller,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  toast('Name is required.');
                  return;
                }
                if (!RegExp(r'^[A-Z]').hasMatch(name)) {
                  toast('Name must start with an uppercase letter');
                  return;
                }

                FocusScope.of(context).unfocus();
                final subCategoryId = widget.subCategory?['id'] as int?;
                Navigator.of(context).pop(<String, dynamic>{
                  'name': name,
                  'subCategoryId': subCategoryId,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(isEdit ? 'Update Subcategory' : 'Add Subcategory'),
            ),
          ),
        ],
      ),
    );
  }
}
