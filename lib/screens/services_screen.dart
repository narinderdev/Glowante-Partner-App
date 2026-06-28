// import 'package:flutter/material.dart';
// import '../utils/api_service.dart';  // Make sure you have the ApiService class in a separate file

// class ServicesTab extends StatefulWidget {
//   final int branchId;
//   const ServicesTab({Key? key, required this.branchId}) : super(key: key);

//   @override
//   State<ServicesTab> createState() => _ServicesTabState();
// }

// class _ServicesTabState extends State<ServicesTab> {
//   bool isLoading = true;
//   Map<String, dynamic> serviceData = {};
//   int? selectedCategoryId;
//   int? selectedSubCategoryId;
//   List<dynamic> subCategories = [];
//   List<dynamic> selectedSubCategoryServices = [];

//   @override
//   void initState() {
//     super.initState();
//     fetchServices();
//   }

//   Future<void> fetchServices() async {
//     try {
//       final data = await ApiService().getBranchServiceDetail(widget.branchId);
//       setState(() {
//         serviceData = data;
//         isLoading = false;
//         if ((data['categories'] as List?)?.isNotEmpty ?? false) {
//           selectedCategoryId = data['categories'][0]['id'];
//           subCategories = data['categories'][0]['subCategories'] ?? [];
//           if (subCategories.isNotEmpty) {
//             selectedSubCategoryId = subCategories[0]['id'];
//             selectedSubCategoryServices = subCategories[0]['services'] ?? [];
//           }
//         }
//       });
//     } catch (e) {
//       setState(() => isLoading = false);
//       debugPrint('Error: $e');
//     }
//   }
// @override
// Widget build(BuildContext context) {
//   if (isLoading) {
//     return Center(child: CircularProgressIndicator());
//   }

//   // Check if there are any categories
//   final categories = (serviceData['categories'] as List?) ?? [];
//   if (categories.isEmpty) {
//     return Center(child: Text('No service category found'));
//   }
//   // Inside build method after data loaded
// return SingleChildScrollView(
//   padding: const EdgeInsets.only(bottom: 80),
//   child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       // Categories
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
//         child: Text('Categories',
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//       ),
//       SizedBox(
//         height: 50,
//         child: ListView.separated(
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           scrollDirection: Axis.horizontal,
//           itemCount: categories.length,
//           separatorBuilder: (_, __) => SizedBox(width: 8),
//           itemBuilder: (context, index) {
//             final category = categories[index];
//             final bool selected = selectedCategoryId == category['id'];
//             return ChoiceChip(
//               label: Text('${category['displayName']}'),
//               selected: selected,
//               onSelected: (_) {
//                 setState(() {
//                   selectedCategoryId = category['id'];
//                   subCategories = category['subCategories'] ?? [];
//                   if (subCategories.isNotEmpty) {
//                     selectedSubCategoryId = subCategories[0]['id'];
//                     selectedSubCategoryServices = subCategories[0]['services'] ?? [];
//                   } else {
//                     selectedSubCategoryId = null;
//                     selectedSubCategoryServices = [];
//                   }
//                 });
//               },
//               selectedColor: Colors.orange,
//               backgroundColor: Colors.grey.shade200,
//               checkmarkColor: Colors.white,
//               labelStyle: TextStyle(
//                 color: selected ? Colors.white : Colors.black87,
//                 fontSize: 12,
//               ),
//             );
//           },
//         ),
//       ),

//       if (subCategories.isNotEmpty) ...[
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Text('Subcategories',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         ),
//         SizedBox(
//           height: 50,
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             scrollDirection: Axis.horizontal,
//             itemCount: subCategories.length,
//             separatorBuilder: (_, __) => SizedBox(width: 8),
//             itemBuilder: (context, index) {
//               final subCategory = subCategories[index];
//               final bool selected = selectedSubCategoryId == subCategory['id'];
//               return ChoiceChip(
//                 label: Text('${subCategory['displayName']}'),
//                 selected: selected,
//                 onSelected: (_) {
//                   setState(() {
//                     selectedSubCategoryId = subCategory['id'];
//                     selectedSubCategoryServices = subCategory['services'] ?? [];
//                   });
//                 },
//                 selectedColor: Colors.orange,
//                 checkmarkColor: Colors.white,
//                 backgroundColor: Colors.grey.shade200,
//                 labelStyle: TextStyle(
//                   color: selected ? Colors.white : Colors.black87,
//                   fontSize: 12,
//                 ),
//               );
//             },
//           ),
//         ),
//       ],

//       SizedBox(height: 16),

//       // Services list
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         child: selectedSubCategoryServices.isNotEmpty
//             ? Column(
//                 children: selectedSubCategoryServices.map<Widget>((service) {
//                   return Card(
//                     margin: const EdgeInsets.symmetric(vertical: 6),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     elevation: 1,
//                     child: Padding(
//                       padding: const EdgeInsets.all(12.0),
//                       child: Row(
//                         children: [
//                           // Name + description
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text('${service['displayName']}',
//                                     style: const TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.bold)),
//                                 if ((service['description'] ?? '').isNotEmpty)
//                                   Text('${service['description']}',
//                                       style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey.shade600)),
//                               ],
//                             ),
//                           ),

//                           // Price & Duration
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                              Text('₹${service['priceMinor']}',
//     style: const TextStyle(
//         fontWeight: FontWeight.bold),
// ),

//                               Text('${service['durationMin']} min',
//                                   style: const TextStyle(
//                                       fontSize: 12, color: Colors.grey)),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               )
//             : Center(
//                 child: Padding(
//                 padding: EdgeInsets.symmetric(vertical: 40),
//                 child: Text('No services available'),
//               )),
//       ),
//     ],
//   ),
// );
//   }
// }

import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';

import '../utils/api_service.dart'; // your ApiService (with updateBCategory, deleteBCategory, updateBSubCategory, deleteBSubCategory, updateBService, deleteBService)

class ServicesTab extends StatefulWidget {
  final int branchId;
  const ServicesTab({Key? key, required this.branchId}) : super(key: key);

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  bool isLoading = true;
  bool _busy = false; // <-- overlay loader flag

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

  // ---------- Loader helpers ----------
  void _setBusy(bool v) {
    if (!mounted) return;
    setState(() => _busy = v);
  }

  Future<T> _withLoader<T>(Future<T> Function() fn) async {
    _setBusy(true);
    try {
      return await fn();
    } finally {
      _setBusy(false);
    }
  }
  // ------------------------------------

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _commissionMaxValueLabel(dynamic value) {
    final amount = minorAmountToRupees(value);
    if (amount == null) return '';
    final fixed = amount.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _commissionTypeLabel(Map service) {
    if (service['commissionEnabled'] != true) {
      return translateText('Commission off');
    }

    final type = (service['commissionType'] ?? '').toString().toLowerCase();
    if (type == 'fixed') return translateText('Fixed commission');
    if (type == 'percentage') return translateText('Percentage commission');
    return translateText('Commission enabled');
  }

  String _commissionValueLabel(Map service) {
    if (service['commissionEnabled'] != true) {
      return translateText('No commission');
    }

    final type = (service['commissionType'] ?? '').toString().toLowerCase();
    if (type == 'fixed') {
      final amount = _asInt(service['commissionFixedAmountMinor']);
      return amount != null
          ? formatMinorAmount(amount, trimZeroDecimals: true)
          : translateText('Fixed');
    }

    if (type == 'percentage') {
      final percent = _asDouble(service['commissionPercentage']);
      final maxAmount = _asInt(service['commissionMaxAmountMinor']);
      final percentLabel = percent == null
          ? translateText('Percentage')
          : '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}%';
      return maxAmount != null
          ? '$percentLabel • max ${_commissionMaxValueLabel(maxAmount)}'
          : percentLabel;
    }

    return translateText('Enabled');
  }

  Future<void> fetchServices() async {
    try {
      final data = await ApiService().getBranchServiceDetail(widget.branchId);
      setState(() {
        serviceData = data;
        isLoading = false;
        final categories = _categories;
        if (categories.isNotEmpty) {
          selectedCategoryId = categories[0]['id'];
          subCategories = categories[0]['subCategories'] ?? [];
          if (subCategories.isNotEmpty) {
            selectedSubCategoryId = subCategories[0]['id'];
            selectedSubCategoryServices = subCategories[0]['services'] ?? [];
          }
        }
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(translateText('Failed to load services: {error}',
                  params: {'error': e.toString()}))),
        );
      }
    }
  }

  List<dynamic> get _categories =>
      (serviceData['categories'] as List?)?.toList() ?? [];

  int _selectedCategoryIndex() =>
      _categories.indexWhere((c) => c['id'] == selectedCategoryId);

  int _selectedSubCategoryIndex() =>
      subCategories.indexWhere((sc) => sc['id'] == selectedSubCategoryId);

  // -------------------- CATEGORY: EDIT / DELETE --------------------
  Future<void> _onEditCategory() async {
    if (selectedCategoryId == null) return;
    final idx = _selectedCategoryIndex();
    if (idx == -1) return;

    final current = _categories[idx];
    final nameCtrl =
        TextEditingController(text: current['displayName']?.toString() ?? '');

    final updatedName = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(translateText('Edit category'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close))
              ]),
              SizedBox(height: 8),
              TextField(
                maxLength: 120,
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: translateText('Name'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(translateText('Cancel'))),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                    child: Text(translateText('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updatedName == null || updatedName.isEmpty) return;

    try {
      final res = await _withLoader(() => ApiService.updateBCategoryPatch(
            widget.branchId,
            selectedCategoryId!,
            {
              "displayName": updatedName
            }, // isActive/sortOrder handled server-side
          ));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          final categories = _categories;
          categories[idx] = {
            ...categories[idx],
            "displayName": updatedName,
            "isActive": true,
            "sortOrder": 200,
          };
          serviceData['categories'] = categories;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Updated category "{name}"',
                    params: {'name': updatedName}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translateText('Update failed: {error}',
                params: {'error': e.toString()}))));
      }
    }
  }

  Future<void> _onDeleteCategory() async {
    if (selectedCategoryId == null) return;
    final idx = _selectedCategoryIndex();
    if (idx == -1) return;

    final current = _categories[idx];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translateText('Delete category?')),
        content: Text(
            'Are you sure you want to delete "${current['displayName']}" and its subcategories/services from this branch?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(translateText('Cancel'))),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(translateText('Delete'))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _withLoader(() =>
          ApiService.deleteBCategory(widget.branchId, selectedCategoryId!));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          final categories = _categories;
          categories.removeAt(idx);
          serviceData['categories'] = categories;

          if (categories.isEmpty) {
            selectedCategoryId = null;
            subCategories = [];
            selectedSubCategoryId = null;
            selectedSubCategoryServices = [];
          } else {
            selectedCategoryId = categories.first['id'];
            subCategories = categories.first['subCategories'] ?? [];
            if (subCategories.isNotEmpty) {
              selectedSubCategoryId = subCategories.first['id'];
              selectedSubCategoryServices =
                  subCategories.first['services'] ?? [];
            } else {
              selectedSubCategoryId = null;
              selectedSubCategoryServices = [];
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Deleted "{name}"',
                    params: {'name': current['displayName']}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translateText('Delete failed: {error}',
                params: {'error': e.toString()}))));
      }
    }
  }

  // -------------------- SUBCATEGORY: EDIT / DELETE --------------------
  Future<void> _onDeleteSubCategory() async {
    if (selectedSubCategoryId == null) return;
    final scIdx = _selectedSubCategoryIndex();
    if (scIdx == -1) return;

    final current = subCategories[scIdx];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translateText('Delete subcategory?')),
        content: Text(
            'Are you sure you want to delete "${current['displayName']}" and its services from this branch?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(translateText('Cancel'))),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(translateText('Delete'))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _withLoader(() => ApiService.deleteBSubCategory(
          widget.branchId, selectedSubCategoryId!));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          subCategories.removeAt(scIdx);
          // reflect in categories tree
          final cIdx = _selectedCategoryIndex();
          if (cIdx != -1) {
            final cats = _categories;
            cats[cIdx]['subCategories'] = subCategories;
            serviceData['categories'] = cats;
          }

          if (subCategories.isEmpty) {
            selectedSubCategoryId = null;
            selectedSubCategoryServices = [];
          } else {
            selectedSubCategoryId = subCategories.first['id'];
            selectedSubCategoryServices = subCategories.first['services'] ?? [];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Deleted "{name}"',
                    params: {'name': current['displayName']}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translateText('Delete failed: {error}',
                params: {'error': e.toString()}))));
      }
    }
  }

  Future<void> _onEditSubCategory() async {
    if (selectedSubCategoryId == null) return;
    final scIdx = _selectedSubCategoryIndex();
    if (scIdx == -1) return;

    final current = subCategories[scIdx];
    final nameCtrl = TextEditingController(
      text: current['displayName']?.toString() ?? '',
    );

    final updatedName = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(translateText('Edit subcategory'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close)),
              ]),
              SizedBox(height: 8),
              TextField(
                maxLength: 120,
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: translateText('Name'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(translateText('Cancel'))),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                    child: Text(translateText('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updatedName == null || updatedName.isEmpty) return;

    try {
      final res = await _withLoader(() => ApiService.updateBSubCategoryPatch(
            widget.branchId,
            selectedSubCategoryId!,
            {
              "displayName": updatedName,
              "isActive": true,
              "sortOrder": 200,
            },
          ));

      if ((res.statusCode >= 200 && res.statusCode < 300)) {
        setState(() {
          subCategories[scIdx] = {
            ...subCategories[scIdx],
            "displayName": updatedName,
            "isActive": true,
            "sortOrder": 200,
          };
          final cIdx = _selectedCategoryIndex();
          if (cIdx != -1) {
            final cats = _categories;
            cats[cIdx]['subCategories'] = subCategories;
            serviceData['categories'] = cats;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Updated subcategory "{name}"',
                    params: {'name': updatedName}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(translateText('Update failed: {error}',
                  params: {'error': e.toString()}))),
        );
      }
    }
  }

  // -------------------- SERVICE: EDIT / DELETE --------------------
  Future<void> _onDeleteService(Map<String, dynamic> service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translateText('Delete service?')),
        content: Text(
          'Are you sure you want to delete "${service['displayName']}"?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(translateText('Cancel'))),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(translateText('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _withLoader(
          () => ApiService.deleteBService(widget.branchId, service['id']));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          selectedSubCategoryServices
              .removeWhere((s) => s['id'] == service['id']);
          final scIndex = _selectedSubCategoryIndex();
          if (scIndex != -1) {
            final list = (subCategories[scIndex]['services'] as List?) ?? [];
            list.removeWhere((s) => s['id'] == service['id']);
            subCategories[scIndex]['services'] = list;

            final cIdx = _selectedCategoryIndex();
            if (cIdx != -1) {
              final cats = _categories;
              cats[cIdx]['subCategories'] = subCategories;
              serviceData['categories'] = cats;
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Deleted "{name}"',
                    params: {'name': service['displayName']}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(translateText('Delete failed: {error}',
                  params: {'error': e.toString()}))),
        );
      }
    }
  }

  Future<void> _onEditService(Map<String, dynamic> service) async {
    final nameCtrl =
        TextEditingController(text: service['displayName']?.toString() ?? '');
    final priceCtrl = TextEditingController(
      text:
          minorAmountToRupees(service['priceMinor'])?.toStringAsFixed(0) ?? '',
    );
    final durationCtrl =
        TextEditingController(text: service['durationMin']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: service['description']?.toString() ?? '');

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(translateText('Edit service'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close)),
              ]),
              SizedBox(height: 8),
              TextField(
                maxLength: 120,
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: translateText('Name'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    maxLength: 120,
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: translateText('Price (₹)'),
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: '₹',
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    maxLength: 120,
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: translateText('Duration (min)'),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 10),
              TextField(
                maxLength: 120,
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: translateText('Description'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              SizedBox(height: 14),
              Row(children: [
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(translateText('Cancel'))),
                SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final price = int.tryParse(priceCtrl.text.trim());
                    final dur = int.tryParse(durationCtrl.text.trim());
                    if (price == null || dur == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(
                                translateText('Enter valid price & duration'))),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      "displayName": nameCtrl.text.trim(),
                      "description": descCtrl.text.trim(),
                      "durationMin": dur,
                      "priceMinor": rupeesToMinorAmount(price),
                      "priceType": "fixed",
                      "isActive": true,
                    });
                  },
                  child: Text(translateText('Save')),
                )
              ]),
            ],
          ),
        ),
      ),
    );

    if (updated == null) return;

    try {
      final res = await _withLoader(() => ApiService.updateBServicePatch(
            widget.branchId,
            service['id'],
            updated,
          ));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          // update in current list
          final idx = selectedSubCategoryServices
              .indexWhere((s) => s['id'] == service['id']);
          if (idx != -1) {
            selectedSubCategoryServices[idx] = {
              ...selectedSubCategoryServices[idx],
              ...updated,
            };
          }
          // reflect in subcategory tree
          final scIndex = _selectedSubCategoryIndex();
          if (scIndex != -1) {
            final list = (subCategories[scIndex]['services'] as List?) ?? [];
            final li = list.indexWhere((s) => s['id'] == service['id']);
            if (li != -1) list[li] = {...list[li], ...updated};
            subCategories[scIndex]['services'] = list;

            final cIdx = _selectedCategoryIndex();
            if (cIdx != -1) {
              final cats = _categories;
              cats[cIdx]['subCategories'] = subCategories;
              serviceData['categories'] = cats;
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(translateText('Updated "{name}"',
                    params: {'name': updated['displayName']}))),
          );
        }
      } else {
        throw Exception('Server responded ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(translateText('Update failed: {error}',
                  params: {'error': e.toString()}))),
        );
      }
    }
  }

  // -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    Widget body;

    if (isLoading) {
      body = Center(child: CircularProgressIndicator());
    } else {
      final categories = _categories;
      if (categories.isEmpty) {
        body = Center(child: Text(translateText('No service category found')));
      } else {
        body = SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Categories + actions for selected category
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    Text(translateText('Categories'),
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (selectedCategoryId != null) ...[
                      Tooltip(
                        message: 'Edit selected category',
                        child: IconButton(
                          onPressed: _onEditCategory,
                          icon: Icon(Icons.edit_outlined, size: 20),
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          splashRadius: 18,
                        ),
                      ),
                      Tooltip(
                        message: 'Delete selected category',
                        child: IconButton(
                          onPressed: _onDeleteCategory,
                          icon: Icon(Icons.delete_outline, size: 20),
                          color: Colors.redAccent,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          splashRadius: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Category chips
              SizedBox(
                height: 50,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8),
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
                            selectedSubCategoryServices =
                                subCategories[0]['services'] ?? [];
                          } else {
                            selectedSubCategoryId = null;
                            selectedSubCategoryServices = [];
                          }
                        });
                      },
                      selectedColor: Colors.orange,
                      backgroundColor: Colors.grey.shade200,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),

              if (subCategories.isNotEmpty) ...[
                // Header row: Subcategories + actions for selected subcategory
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(translateText('Subcategories'),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (selectedSubCategoryId != null) ...[
                        Tooltip(
                          message: 'Edit selected subcategory',
                          child: IconButton(
                            onPressed: _onEditSubCategory,
                            icon: Icon(Icons.edit_outlined, size: 20),
                            visualDensity: const VisualDensity(
                                horizontal: -4, vertical: -4),
                            splashRadius: 18,
                          ),
                        ),
                        Tooltip(
                          message: 'Delete selected subcategory',
                          child: IconButton(
                            onPressed: _onDeleteSubCategory,
                            icon: Icon(Icons.delete_outline, size: 20),
                            color: Colors.redAccent,
                            visualDensity: const VisualDensity(
                                horizontal: -4, vertical: -4),
                            splashRadius: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Subcategory chips
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: subCategories.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final subCategory = subCategories[index];
                      final bool selected =
                          selectedSubCategoryId == subCategory['id'];
                      return ChoiceChip(
                        label: Text('${subCategory['displayName']}'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selectedSubCategoryId = subCategory['id'];
                            selectedSubCategoryServices =
                                subCategory['services'] ?? [];
                          });
                        },
                        selectedColor: Colors.orange,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
              ],

              SizedBox(height: 16),

              // Services list (with per-card edit/delete)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: selectedSubCategoryServices.isNotEmpty
                    ? Column(
                        children:
                            selectedSubCategoryServices.map<Widget>((service) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name + description
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${service['displayName']}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold)),
                                        if ((service['description'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              '${service['description']}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _ServiceInfoPill(
                                              text:
                                                  _commissionTypeLabel(service),
                                              backgroundColor:
                                                  const Color(0xFFF6EFE3),
                                              textColor:
                                                  const Color(0xFF8B6500),
                                            ),
                                            _ServiceInfoPill(
                                              text: _commissionValueLabel(
                                                  service),
                                              backgroundColor:
                                                  const Color(0xFFF3F4F6),
                                              textColor: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price & Duration
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatMinorAmount(
                                          service['priceMinor'],
                                          trimZeroDecimals: true,
                                        ),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${service['durationMin']} min',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),

                                  SizedBox(width: 8),

                                  // Edit/Delete icons
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'Edit',
                                        child: IconButton(
                                          onPressed: () =>
                                              _onEditService(service),
                                          icon: Icon(Icons.edit_outlined),
                                          visualDensity: const VisualDensity(
                                              horizontal: -4, vertical: -4),
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          splashRadius: 18,
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Delete',
                                        child: IconButton(
                                          onPressed: () =>
                                              _onDeleteService(service),
                                          icon: Icon(Icons.delete_outline),
                                          visualDensity: const VisualDensity(
                                              horizontal: -4, vertical: -4),
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          splashRadius: 18,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    : Center(
                        child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(translateText('No services available')),
                      )),
              ),
            ],
          ),
        );
      }
    }

    return Stack(
      children: [
        body,
        if (_busy)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.08),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceInfoPill extends StatelessWidget {
  const _ServiceInfoPill({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
