import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import '../Viewmodels/AddCategory.dart';
import 'AddServices.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final Map<int, bool> _expandedSubcategories = {};
  int? _selectedBranchId;
  Map<String, dynamic>? _selectedBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salonCubit = context.read<SalonListCubit>();
      if (salonCubit.state.salons.isEmpty) {
        salonCubit.loadSalons();
      }
    });
  }

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
        context.read<CategoryCubit>().loadCategories(salon['id'] as int);
        break;
      }
    }
  }

  // ---------- ADD / EDIT CATEGORY (await the sheet) ----------
  Future<void> _showAddCategorySheet({Map<String, dynamic>? category}) async {
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a salon branch first.')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final isEdit = category != null;
        final nameController = TextEditingController(
          text: category?['name'] as String? ?? '',
        );
        final descriptionController = TextEditingController(
          text: category?['description'] as String? ?? '',
        );
        final enableToggle = ValueNotifier<bool>(category?['isDisabled'] == false);

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isEdit ? 'Edit Category' : 'Add Category',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: enableToggle,
                builder: (context, value, _) {
                  return SwitchListTile(
                    value: value,
                    onChanged: (newValue) => enableToggle.value = newValue,
                    title: const Text('Enable Category'),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Name is required.')),
                      );
                      return;
                    }

                    FocusScope.of(sheetContext).unfocus();

                    final payload = AddCategoryRequest(
                      name: name,
                      description: descriptionController.text.trim(),
                      isDisabled: !enableToggle.value,
                    );
                    final categoryId = category?['id'] as int?;

                    // Pop with the payload; no bloc call here
                    Navigator.of(sheetContext).pop(<String, dynamic>{
                      'request': payload,
                      'categoryId': categoryId,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Update Category' : 'Add Category'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    final cubit = context.read<CategoryCubit>();
    final req = result['request'] as AddCategoryRequest;
    final categoryId = result['categoryId'] as int?;

    if (categoryId != null) {
      cubit.updateCategory(salonId, categoryId, req);
    } else {
      cubit.addCategory(salonId, req);
    }
  }

  // ---------- ADD / EDIT SUBCATEGORY (await the sheet) ----------
  Future<void> _openSubcategorySheet({
    Map<String, dynamic>? subCategory,
    required int categoryId,
  }) async {
    if (_selectedBranch == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final controller = TextEditingController(
          text: subCategory?['name'] as String? ?? '',
        );
        final isEdit = subCategory != null;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isEdit ? 'Edit Subcategory' : 'Add Subcategory',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Subcategory Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Name is required.')),
                      );
                      return;
                    }

                    FocusScope.of(sheetContext).unfocus();

                    final subCategoryId = subCategory?['id'] as int?;
                    Navigator.of(sheetContext).pop(<String, dynamic>{
                      'name': name,
                      'subCategoryId': subCategoryId,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Update Subcategory' : 'Add Subcategory'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    final cubit = context.read<CategoryCubit>();
    final name = result['name'] as String;
    final subCategoryId = result['subCategoryId'] as int?;

    if (subCategoryId != null) {
      cubit.updateSubCategory(salonId, subCategoryId, name);
    } else {
      cubit.addSubCategory(salonId, categoryId, name);
    }
  }

  // ---------- CONFIRM DELETE (await the dialog) ----------
  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure you want to delete this category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
            TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteCategory(
      salonId,
      category['id'] as int,
    );
  }

  Future<void> _confirmDeleteSubCategory(Map<String, dynamic> subCategory) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subcategory'),
        content: const Text('Are you sure you want to delete this subcategory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteSubCategory(
      salonId,
      subCategory['id'] as int,
    );
  }

  // ---------- EDIT SERVICE (await the sheet) ----------
  Future<void> _showUpdateServiceSheet(Map<String, dynamic> service) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final nameController = TextEditingController(
          text: service['displayName'] ?? service['name'] ?? '',
        );
        final descriptionController = TextEditingController(
          text: service['description'] ?? '',
        );
        final durationController = TextEditingController(
          text: (service['durationMin'] ?? service['defaultDurationMin'])?.toString() ?? '',
        );
        final priceController = TextEditingController(
          text: (service['priceMinor'] ?? service['defaultPriceMinor'])?.toString() ?? '',
        );
        final isActive = ValueNotifier<bool>(service['isActive'] ?? true);

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (minor units)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: isActive,
                builder: (context, value, _) {
                  return SwitchListTile(
                    value: value,
                    onChanged: (newValue) => isActive.value = newValue,
                    title: const Text('Active'),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Name is required.')),
                      );
                      return;
                    }

                    FocusScope.of(sheetContext).unfocus();

                    final payload = {
                      'name': name,
                      'description': descriptionController.text.trim(),
                      'defaultDurationMin': int.tryParse(durationController.text.trim()),
                      'defaultPriceMinor': int.tryParse(priceController.text.trim()),
                      'isActive': isActive.value,
                    }..removeWhere((key, value) => value == null);

                    Navigator.of(sheetContext).pop(<String, dynamic>{
                      'serviceId': service['id'] as int,
                      'payload': payload,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Service'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final salonId = _selectedBranch!['salonId'] as int;
    final serviceId = result['serviceId'] as int;
    final payload = result['payload'] as Map<String, dynamic>;
    context.read<CategoryCubit>().updateService(salonId, serviceId, payload);
  }

  Future<void> _confirmDeleteService(int serviceId) async {
    if (_selectedBranch == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final salonId = _selectedBranch!['salonId'] as int;
    context.read<CategoryCubit>().deleteService(salonId, serviceId);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Catalogue')),
      body: BlocListener<CategoryCubit, CategoryState>(
        listenWhen: (previous, current) => previous.message != current.message,
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
            context.read<CategoryCubit>().clearMessage();
          }
        },
        child: BlocBuilder<CategoryCubit, CategoryState>(
          builder: (context, state) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlocBuilder<SalonListCubit, SalonListState>(
                        builder: (context, salonState) {
                          final salons = salonState.salons;
                          if (salonState.isLoading && salons.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (salonState.hasError && salons.isEmpty) {
                            return Text(
                              salonState.errorMessage ?? 'Failed to load salons',
                            );
                          }
                          if (salons.isEmpty) {
                            return const Text('No salons found');
                          }

                          return DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedBranchId,
                            hint: const Text('Select Salon Branch'),
                            items: salons.expand((salon) {
                              final branches =
                                  (salon['branches'] as List?)
                                      ?.cast<Map<String, dynamic>>() ??
                                  [];
                              return branches
                                  .map<DropdownMenuItem<int>>(
                                    (branch) => DropdownMenuItem(
                                      value: branch['id'] as int,
                                      child: Text(branch['name'] as String),
                                    ),
                                  )
                                  .toList();
                            }).toList(),
                            onChanged: (value) => _onBranchSelected(value, salons),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _buildCategoryContent(state)),
                    ],
                  ),
                ),
                if (state.isSubmitting) _buildLoaderOverlay(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange[300],
      ),
    );
  }

  Widget _buildCategoryContent(CategoryState state) {
    if (_selectedBranch == null) {
      return const Center(child: Text('Select a branch to view categories'));
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == CategoryStatus.failure) {
      return Center(child: Text(state.message ?? 'Failed to load categories'));
    }

    final categories = state.categories;
    if (categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index] as Map<String, dynamic>;
        final subCategories = (category['subCategories'] as List?) ?? [];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category['name'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.brown),
                          onPressed: () => _showAddCategorySheet(category: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.orange),
                          onPressed: () => _confirmDeleteCategory(category),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${subCategories.length} Subcategory${subCategories.length == 1 ? '' : 'ies'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                for (final subCategory in subCategories)
                  _buildSubcategoryTile(
                    category,
                    subCategory as Map<String, dynamic>,
                    categories,
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openSubcategorySheet(
                        categoryId: category['id'] as int,
                      ),
                      icon: const Icon(Icons.add, color: Colors.orange),
                      label: const Text(
                        'Add Subcategory',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _openAddService(category, categories),
                      icon: const Icon(Icons.add, color: Colors.orange),
                      label: const Text(
                        'Add Services',
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
    );
  }

  Widget _buildLoaderOverlay() {
    return const Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: Colors.black45),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildSubcategoryTile(
    Map<String, dynamic> category,
    Map<String, dynamic> subCategory,
    List<dynamic> categories,
  ) {
    final subCategoryId = subCategory['id'] as int;
    final isExpanded = _expandedSubcategories[subCategoryId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedSubcategories[subCategoryId] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subCategory['name'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              '${(subCategory['services'] as List?)?.length ?? 0} Services',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.brown),
                        onPressed: () => _openSubcategorySheet(
                          subCategory: subCategory,
                          categoryId: category['id'] as int,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.orange),
                        onPressed: () => _confirmDeleteSubCategory(subCategory),
                      ),
                      // Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isExpanded)
          Column(
            children: [
              for (final service in (subCategory['services'] as List?) ?? [])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    service['displayName'] as String? ?? 'Unnamed Service',
                  ),
                  subtitle: Text(
                    'Rs. ${service['priceMinor']} - ${service['durationMin']} min',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.brown),
                        onPressed: () => _showUpdateServiceSheet(service),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.orange),
                        onPressed: () => _confirmDeleteService(service['id'] as int),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
