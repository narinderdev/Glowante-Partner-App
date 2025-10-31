// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter/services.dart';
// import 'package:bloc_onboarding/utils/api_service.dart';
// import 'dart:convert';
// import '../utils/colors.dart';
// import '../Viewmodels/AddSalonServiceRequest.dart';
// import '../bloc/category/category_cubit.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';

// class AddServices extends StatefulWidget {
//   final int salonId;
//   final Map<String, dynamic>? selectedCategory;
//   final List<dynamic>? categories; // multiple categories

//   AddServices({
//     required this.salonId,
//     this.selectedCategory,
//     this.categories,
//   });

//   @override
//   _AddServicesState createState() => _AddServicesState();
// }

// /// --- Helpers: Title Case InputFormatter (Service name) ---
// class TitleCaseInputFormatter extends TextInputFormatter {
//   const TitleCaseInputFormatter();

//   String _toTitleCase(String input) {
//     if (input.isEmpty) return input; // no trim()
//     final parts = input.split(' ');
//     final mapped = parts.map((p) {
//       if (p.isEmpty) return p;
//       return p[0].toUpperCase() + p.substring(1);
//     }).toList();
//     return mapped.join(' ');
//   }

//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue oldValue, TextEditingValue newValue) {
//     if (newValue.text.length >= oldValue.text.length) {
//       final transformed = _toTitleCase(newValue.text);
//       final selection = newValue.selection;
//       final offset =

//       return TextEditingValue(
//         text: transformed,
//         selection: TextSelection.collapsed(offset: offset),
//       );
//     }
//     return newValue;
//   }
// }

// class _AddServicesState extends State<AddServices> {
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;
//   bool _autoValidate = false;

//   // controllers
//   final nameController = TextEditingController();
//   final descController = TextEditingController();
//   final priceController = TextEditingController();
//   final durationController = TextEditingController();

//   // focus
//   final FocusNode _nameFocus = FocusNode();

//   // catalog data
//   List<dynamic> serviceCatalog = [];

//   /// Category dropdown state
//   Map<String, dynamic>? selectedCategory; // full map for request
//   String? selectedCategoryKey; // "cat:<id>" or "sub:<id>"
//   String? selectedCategoryType; // 'category' or 'subCategory'

//   /// Subcategory (right dropdown)
//   Map<String, dynamic>? selectedService; // full map for request

//   @override
//   void initState() {
//     super.initState();
//     selectedCategory = null;
//     selectedService = null;
//     fetchServiceCatalog();

//     // Preselect incoming category (if any)
//     if (widget.selectedCategory != null) {
//       selectedCategory = widget.selectedCategory;
//       final hasSub = (selectedCategory!['subCategories'] ?? []).isNotEmpty;
//       selectedCategoryType = hasSub ? 'category' : 'subCategory';
//       final id = selectedCategory!['id'];
//       selectedCategoryKey =
//           (selectedCategoryType == 'category') ? 'cat:$id' : 'sub:$id';
//     }

//     // Focus the Service Name field and open keyboard with Caps
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) _nameFocus.requestFocus();
//     });
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     descController.dispose();
//     priceController.dispose();
//     durationController.dispose();
//     _nameFocus.dispose();
//     super.dispose();
//   }

//   // ---------- DROPDOWN VALIDATION HELPERS ----------
//   String? _validateSelectedCategoryKey(
//       String? currentKey, List<DropdownMenuItem<String>> items) {
//     if (currentKey == null) return null;
//     final validKeys = items.map((e) => e.value).whereType<String>().toSet();
//     if (!validKeys.contains(currentKey)) {
//       debugPrint('[Dropdown Fix] Resetting invalid selectedCategoryKey: $currentKey');
//       return null;
//     }
//     return currentKey;
//   }

//   int? _validateSelectedSubcategory(int? currentId, List<DropdownMenuItem<int>> items) {
//     if (currentId == null) return null;
//     final validIds = items.map((e) => e.value).whereType<int>().toSet();
//     if (!validIds.contains(currentId)) {
//       debugPrint('Resetting invalid subcategory id: $currentId');
//       return null;
//     }
//     return currentId;
//   }

//   // ---------- FETCH CATALOG ----------
//   Future<void> fetchServiceCatalog() async {
//     try {
//       final response = await ApiService().getServiceCatalog();
//       if (mounted && response['success'] == true) {
//         setState(() => serviceCatalog = response['data']);
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(translateText("Failed to fetch service catalog"))),
//       );
//     }
//   }

//   // ---------- ERROR MAPPING ----------
//   String _mapErrorMessage(String backendMessage) {
//     if (backendMessage.contains("defaultDurationMin")) {
//       return translateText("Duration must be a positive number");
//     }
//     if (backendMessage.contains("defaultPriceMinor")) {
//       return translateText("Price must be a positive number");
//     }
//     if (backendMessage.contains("name")) {
//       return translateText("Service name is required");
//     }
//     return backendMessage; // fallback
//   }

//   // ---------- ADD SERVICE ----------
//   Future<void> _addService() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);
//     try {
//       int? salonCategoryId;
//       int? salonSubCategoryId;
//       final int masterSubCategoryId = selectedService!['id'];

//       if (selectedCategoryType == 'category') {
//         salonCategoryId = selectedCategory!['id'];
//       } else if (selectedCategoryType == 'subCategory') {
//         salonSubCategoryId = selectedCategory!['id'];
//       }

//       if (salonCategoryId != null && salonSubCategoryId != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text(translateText(
//                   "Select either category or subcategory, not both"))),
//         );
//         return;
//       }

//       final displayName = nameController.text.trim();
//       final desc = descController.text.trim();
//       final price = int.parse(priceController.text.trim());
//       final duration = int.parse(durationController.text.trim());

//       final request = AddSalonServiceRequest(
//         branchCategoryId: salonCategoryId,
//         branchSubCategoryId: salonSubCategoryId,
//         displayName: displayName,
//         description: desc.isEmpty ? "" : desc,
//         durationMin: duration,
//         priceMinor: price,
//         priceType: "fixed",
//         isActive: true,
//       );

//       await ApiService().addService(branchId: widget.salonId, request: request);

//       if (!mounted) return;

//       try {
//         await context.read<CategoryCubit>().loadCategories(widget.salonId);
//       } catch (_) {}

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(translateText("Service added successfully!"))),
//       );
//       Navigator.pop(context, true);
//     } catch (e) {
//       if (!mounted) return;
//       String errorMessage = translateText("Failed to add service");
//       try {
//         String errorStr = e.toString();
//         errorStr = errorStr.replaceFirst("Exception: ", "");
//         errorStr = errorStr.replaceFirst("Failed to add service: ", "");
//         final errorJson = jsonDecode(errorStr);

//         if (errorJson['message'] is List && errorJson['message'].isNotEmpty) {
//           errorMessage = _mapErrorMessage(errorJson['message'][0]);
//         } else if (errorJson['message'] is String) {
//           errorMessage = _mapErrorMessage(errorJson['message']);
//         }
//       } catch (_) {}
//       showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           title: Text(translateText("Alert")),
//           content: Text(errorMessage),
//           actions: [
//             TextButton(
//                 onPressed: () => Navigator.of(ctx).pop(),
//                 child: Text(translateText("OK"))),
//           ],
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // ---------- VALIDATORS ----------
//   String? _validateLabel(String? value) {
//     final v = (value ?? '').trim();
//     if (v.isEmpty) return translateText("Service name is required");
//     final firstAlpha = RegExp(r'[A-Za-z]').firstMatch(v);
//     if (firstAlpha != null) {
//       final ch = v[firstAlpha.start];
//       if (ch != ch.toUpperCase()) {
//         return translateText("Service name should start with a capital letter");
//       }
//     }
//     return null;
//   }

//   String? _validatePrice(String? value) {
//     final v = (value ?? '').trim();
//     if (v.isEmpty) return translateText("Price is required");
//     final num? n = int.tryParse(v);
//     if (n == null || n <= 0)
//       return translateText("Price must be a positive number");
//     return null;
//   }

//   String? _validateDuration(String? value) {
//     final v = (value ?? '').trim();
//     if (v.isEmpty) return translateText("Duration is required");
//     final num? n = int.tryParse(v);
//     if (n == null || n <= 0)
//       return translateText("Duration must be a positive number");
//     return null;
//   }

//   String? _validateCategory(Map<String, dynamic>? _) {
//     if (selectedCategory == null) return translateText("Category is required");
//     return null;
//   }

//   String? _validateSubcategory(int? _) {
//     if (selectedService == null)
//       return translateText("Subcategory is required");
//     return null;
//   }

//   // ---------- BUILD ----------
//   @override
//   Widget build(BuildContext context) {
//     final categoryItems =
//         buildCategoryAndSubcategoryKeyItems(widget.categories ?? []);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(color: Colors.white),
//         title: Text(
//           translateText('Add Service'),
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [AppColors.starColor, AppColors.getStartedButton],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: Form(
//         key: _formKey,
//         autovalidateMode: _autoValidate
//             ? AutovalidateMode.onUserInteraction
//             : AutovalidateMode.disabled,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               _SectionCard(
//                 title: "",
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _FieldLabel(translateText("Service Name *")),
//                     const SizedBox(height: 6),
//                     TextFormField(
//                       controller: nameController,
//                       focusNode: _nameFocus,
//                       autofocus: true,
//                       textInputAction: TextInputAction.next,
//                       textCapitalization: TextCapitalization.words,
//                       inputFormatters: const [TitleCaseInputFormatter()],
//                       decoration: _inputDecoration(
//                         hint: translateText("Add a service name"),
//                         icon: Icons.badge_outlined,
//                       ),
//                       validator: _validateLabel,
//                     ),
//                     const SizedBox(height: 16),
//                     _FieldLabel(translateText("Description (Optional)")),
//                     const SizedBox(height: 6),
//                     TextFormField(
//                       controller: descController,
//                       maxLines: 2,
//                       textCapitalization: TextCapitalization.sentences,
//                       decoration: _inputDecoration(
//                         hint: translateText("Add a short description"),
//                         icon: Icons.description_outlined,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 16),

//               // CATEGORY & SUBCATEGORY SECTION
//               _SectionCard(
//                 title: "",
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _FieldLabel(translateText("Category *")),
//                           const SizedBox(height: 6),
//                           DropdownButtonFormField<String>(
//                             isExpanded: true,
//                             value: _validateSelectedCategoryKey(
//                                 selectedCategoryKey, categoryItems),
//                             hint: Text(translateText("Select Category")),
//                             items: categoryItems,
//                             onChanged: (key) {
//                               if (key == null) return;
//                               setState(() {
//                                 selectedCategoryKey = key;
//                                 selectedService = null; // reset subcategory
//                                 if (key.startsWith('cat:')) {
//                                   final id = int.parse(key.substring(4));
//                                   selectedCategoryType = 'category';
//                                   selectedCategory = findCategoryById(
//                                       widget.categories ?? [], id);
//                                 } else {
//                                   final id = int.parse(key.substring(4));
//                                   selectedCategoryType = 'subCategory';
//                                   selectedCategory = findSubcategoryById(
//                                       widget.categories ?? [], id);
//                                 }
//                               });
//                             },
//                             decoration: _inputDecoration(),
//                             validator: (_) =>
//                                 _validateCategory(selectedCategory),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _FieldLabel(translateText("Subcategory *")),
//                           const SizedBox(height: 6),
//                           Builder(
//                             builder: (_) {
//                               final subItems = serviceCatalog
//                                   .expand<DropdownMenuItem<int>>((service) {
//                                 final subCats = service['subCategories'] ?? [];
//                                 return (subCats as List)
//                                     .map<DropdownMenuItem<int>>((sub) {
//                                   return DropdownMenuItem<int>(
//                                     value: sub['id'] as int,
//                                     child: Text("${sub['name']}"),
//                                   );
//                                 }).toList();
//                               }).toList();

//                               if (subItems.isEmpty) {
//                                 return Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 12, vertical: 14),
//                                   decoration: BoxDecoration(
//                                     border: Border.all(
//                                         color: Colors.grey.shade300),
//                                     borderRadius: BorderRadius.circular(10),
//                                     color: const Color(0xFFF9FAFB),
//                                   ),
//                                   child: Text(
//                                     translateText("No subcategories available"),
//                                     style:
//                                         const TextStyle(color: Colors.grey),
//                                   ),
//                                 );
//                               }

//                               return DropdownButtonFormField<int>(
//                                 isExpanded: true,
//                                 value: _validateSelectedSubcategory(
//                                     selectedService?['id'], subItems),
//                                 hint: Text(translateText("Select")),
//                                 items: subItems,
//                                 onChanged: (value) {
//                                   if (value == null) return;
//                                   final found = serviceCatalog
//                                       .expand((service) =>
//                                           service['subCategories'] ?? [])
//                                       .firstWhere(
//                                           (sub) => sub['id'] == value);

//                                   setState(() {
//                                     selectedService = {
//                                       "id": found['id'],
//                                       "name": found['name'],
//                                       "parentId": found['parentId'] ?? 0,
//                                       "parentName":
//                                           found['parentName'] ?? "",
//                                     };
//                                   });
//                                 },
//                                 decoration: _inputDecoration(),
//                                 validator: (_) => _validateSubcategory(
//                                     selectedService?['id']),
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // PRICE + DURATION
//               _SectionCard(
//                 title: "",
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextFormField(
//                         controller: priceController,
//                         keyboardType: TextInputType.number,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly
//                         ],
//                         decoration: _inputDecoration(
//                           label: translateText("Price *"),
//                           icon: Icons.currency_rupee,
//                         ),
//                         validator: _validatePrice,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: TextFormField(
//                         controller: durationController,
//                         keyboardType: TextInputType.number,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly
//                         ],
//                         decoration: _inputDecoration(
//                           label: translateText("Duration (min) *"),
//                           icon: Icons.timer_outlined,
//                         ),
//                         validator: _validateDuration,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 24),

//               // SUBMIT BUTTON
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   icon: _isLoading
//                       ? const SizedBox(
//                           height: 18,
//                           width: 18,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2, color: Colors.white),
//                         )
//                       : const Icon(Icons.add_task_outlined),
//                   label: Text(
//                     _isLoading
//                         ? translateText('Adding...')
//                         : translateText('Add Service'),
//                     style:
//                         const TextStyle(fontSize: 16, color: Colors.white),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: AppColors.white,
//                     backgroundColor: AppColors.starColor,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     elevation: 0,
//                   ),
//                   onPressed: _isLoading
//                       ? null
//                       : () async {
//                           if (!_autoValidate) {
//                             setState(() => _autoValidate = true);
//                           }
//                           final valid = _formKey.currentState!.validate();
//                           if (!valid) return;
//                           await _addService();
//                         },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ---------- SUPPORT UI COMPONENTS ----------
// InputDecoration _inputDecoration({String? hint, String? label, IconData? icon}) {
//   return InputDecoration(
//     hintText: hint,
//     labelText: label,
//     prefixIcon: icon != null ? Icon(icon) : null,
//     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//     enabledBorder: OutlineInputBorder(
//       borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderSide: const BorderSide(color: Colors.black),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     errorBorder: OutlineInputBorder(
//       borderSide: const BorderSide(color: Colors.red),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     focusedErrorBorder: OutlineInputBorder(
//       borderSide: const BorderSide(color: Colors.red),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//   );
// }

// class _SectionCard extends StatelessWidget {
//   final String title;
//   final String? subtitle;
//   final Widget child;

//   const _SectionCard({
//     required this.title,
//     this.subtitle,
//     required this.child,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final bool hasTitle = title.trim().isNotEmpty;

//     return Card(
//       elevation: 0,
//       shadowColor: Colors.transparent,
//       color: const Color(0xFFF9FAFB),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       child: Padding(
//         padding: const EdgeInsets.all(14.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (hasTitle) ...[
//               Row(
//                 children: const [
//                   Icon(Icons.checklist_outlined, size: 18),
//                   SizedBox(width: 8),
//                 ],
//               ),
//               const SizedBox(height: 12),
//             ],
//             child,
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _FieldLabel extends StatelessWidget {
//   final String text;
//   const _FieldLabel(this.text);
//   @override
//   Widget build(BuildContext context) {
//     return Text(text,
//         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
//   }
// }

// // ---------- Category dropdown helpers ----------
// List<DropdownMenuItem<String>> buildCategoryAndSubcategoryKeyItems(
//     List<dynamic> categories) {
//   final List<DropdownMenuItem<String>> items = [];
//   for (final category in categories) {
//     final catId = category['id'] as int;
//     items.add(DropdownMenuItem<String>(
//       value: 'cat:$catId',
//       enabled: category['subCategories'] == null ||
//           (category['subCategories'] as List).isEmpty,
//       child: Text(category['displayName'] ?? ''),
//     ));
//     for (final sub in (category['subCategories'] ?? []) as List) {
//       final subId = sub['id'] as int;
//       items.add(DropdownMenuItem<String>(
//         value: 'sub:$subId',
//         child: Padding(
//           padding: const EdgeInsets.only(left: 20),
//           child: Text(sub['displayName'] ?? ''),
//         ),
//       ));
//     }
//   }
//   return items;
// }

// Map<String, dynamic>? findCategoryById(List<dynamic> categories, int id) {
//   for (final cat in categories) {
//     if (cat['id'] == id) return Map<String, dynamic>.from(cat);
//   }
//   return null;
// }

// Map<String, dynamic>? findSubcategoryById(List<dynamic> categories, int id) {
//   for (final cat in categories) {
//     for (final sub in (cat['subCategories'] ?? []) as List) {
//       if (sub['id'] == id) return Map<String, dynamic>.from(sub);
//     }
//   }
//   return null;
// }
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'dart:convert';
import '../utils/colors.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import '../bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class AddServices extends StatefulWidget {
  final int branchId;
  final Map<String, dynamic>? selectedCategory;
  final List<dynamic>? categories;

  const AddServices({
    required this.branchId,
    this.selectedCategory,
    this.categories,
  });

  @override
  State<AddServices> createState() => _AddServicesState();
}

class FirstLetterUpperFormatter extends TextInputFormatter {
  const FirstLetterUpperFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final match = RegExp(r'[A-Za-z]').firstMatch(text);
    if (match == null) return newValue;

    final index = match.start;
    final upper = text[index].toUpperCase();
    if (text[index] == upper) return newValue;

    final updated = text.replaceRange(index, index + 1, upper);
    return newValue.copyWith(text: updated);
  }
}

class _AddServicesState extends State<AddServices> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _autoValidate = false;

  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();

  List<dynamic> serviceCatalog = [];
  Map<String, dynamic>? selectedCategory;
  String? selectedCategoryKey;
  String? selectedCategoryType;
  Map<String, dynamic>? selectedService;

  @override
  void initState() {
    super.initState();
    fetchServiceCatalog();

    if (widget.selectedCategory != null) {
      selectedCategory = widget.selectedCategory;
      final hasSub = (selectedCategory!['subCategories'] ?? []).isNotEmpty;
      selectedCategoryType = hasSub ? 'category' : 'subCategory';
      final id = selectedCategory!['id'];
      selectedCategoryKey =
          (selectedCategoryType == 'category') ? 'cat:$id' : 'sub:$id';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    durationController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ------------------- Dropdown Safety -------------------
  String? _validateSelectedCategoryKey(
      String? currentKey, List<DropdownMenuItem<String>> items) {
    if (currentKey == null) return null;
    final validKeys = items.map((e) => e.value).whereType<String>().toSet();
    if (!validKeys.contains(currentKey)) {
      debugPrint('[Dropdown Fix] Resetting invalid selectedCategoryKey: $currentKey');
      return null;
    }
    return currentKey;
  }

  int? _validateSelectedSubcategory(int? currentId, List<DropdownMenuItem<int>> items) {
    if (currentId == null) return null;
    final validIds = items.map((e) => e.value).whereType<int>().toSet();
    if (!validIds.contains(currentId)) {
      debugPrint('[Dropdown Fix] Resetting invalid subcategory id: $currentId');
      return null;
    }
    return currentId;
  }

  // ------------------- Fetch Catalog -------------------
  Future<void> fetchServiceCatalog() async {
    try {
      final response = await ApiService().getServiceCatalog();
      if (mounted && response['success'] == true) {
        setState(() => serviceCatalog = response['data']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText("Failed to fetch service catalog"))),
      );
    }
  }

  // ------------------- Add Service -------------------
  Future<void> _addService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      int? branchCategoryId;
      int? branchSubCategoryId;

      if (selectedCategoryType == 'category') {
        branchCategoryId = selectedCategory!['id'];
      } else if (selectedCategoryType == 'subCategory') {
        branchSubCategoryId = selectedCategory!['id'];
      }

      final displayName = nameController.text.trim();
      final desc = descController.text.trim();
      final price = int.parse(priceController.text.trim());
      final duration = int.parse(durationController.text.trim());

      final request = AddSalonServiceRequest(
        branchCategoryId: branchCategoryId,
        branchSubCategoryId: branchSubCategoryId,
        displayName: displayName,
        description: desc.isEmpty ? "" : desc,
        durationMin: duration,
        priceMinor: price,
        priceType: "fixed",
        isActive: true,
      );

      await ApiService().addService(branchId: widget.branchId, request: request);

      if (!mounted) return;

      try {
        await context.read<CategoryCubit>().loadCategories(widget.branchId);
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText("Service added successfully!"))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = translateText("Failed to add service");
      try {
        String errorStr = e.toString();
        errorStr = errorStr.replaceFirst("Exception: ", "");
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
          title: Text(translateText("Alert")),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(translateText("OK")),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------- Validators -------------------
  String? _validateLabel(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return translateText("Service name is required");
    final firstAlpha = RegExp(r'[A-Za-z]').firstMatch(v);
    if (firstAlpha != null) {
      final ch = v[firstAlpha.start];
      if (ch != ch.toUpperCase()) {
        return translateText("Service name should start with a capital letter");
      }
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return translateText("Price is required");
    final num? n = int.tryParse(v);
    if (n == null || n <= 0) return translateText("Price must be positive");
    return null;
  }

  String? _validateDuration(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return translateText("Duration is required");
    final num? n = int.tryParse(v);
    if (n == null || n <= 0) return translateText("Duration must be positive");
    return null;
  }

  String? _validateCategory(Map<String, dynamic>? _) {
    if (selectedCategory == null) return translateText("Category is required");
    return null;
  }

  // ------------------- Build UI -------------------
  @override
  // Widget build(BuildContext context) {
  //   final categoryItems =
  //       buildCategoryAndSubcategoryKeyItems(widget.categories ?? []);

  //   return Scaffold(
  //     backgroundColor: Colors.white,
  //     appBar: AppBar(
  //       backgroundColor: Colors.transparent,
  //       elevation: 0,
  //       systemOverlayStyle: SystemUiOverlayStyle.light,
  //       iconTheme: const IconThemeData(color: Colors.white),
  //       title: Text(
  //         translateText('Add Service'),
  //         style: const TextStyle(
  //             color: Colors.white, fontWeight: FontWeight.bold),
  //       ),
  //       flexibleSpace: Container(
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             colors: [AppColors.starColor, AppColors.getStartedButton],
  //             begin: Alignment.topLeft,
  //             end: Alignment.bottomRight,
  //           ),
  //         ),
  //       ),
  //     ),
  //     body: Form(
  //       key: _formKey,
  //       autovalidateMode: _autoValidate
  //           ? AutovalidateMode.onUserInteraction
  //           : AutovalidateMode.disabled,
  //       child: SingleChildScrollView(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(children: [
  //           _SectionCard(
  //             title: "",
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 _FieldLabel(translateText("Service Name *")),
  //                 const SizedBox(height: 6),
  //                 TextFormField(
  //                   controller: nameController,
  //                   focusNode: _nameFocus,
  //                   autofocus: true,
  //                   textInputAction: TextInputAction.next,
  //                   textCapitalization: TextCapitalization.none,
  //                   inputFormatters: const [FirstLetterUpperFormatter()],
  //                   decoration: _inputDecoration(
  //                     hint: translateText("Add a service name"),
  //                     icon: Icons.badge_outlined,
  //                   ),
  //                   validator: _validateLabel,
  //                 ),
  //                 const SizedBox(height: 16),
  //                 _FieldLabel(translateText("Description (Optional)")),
  //                 const SizedBox(height: 6),
  //                 TextFormField(
  //                   controller: descController,
  //                   maxLines: 2,
  //                   textCapitalization: TextCapitalization.sentences,
  //                   decoration: _inputDecoration(
  //                     hint: translateText("Add a short description"),
  //                     icon: Icons.description_outlined,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           _SectionCard(
  //             title: "",
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       _FieldLabel(translateText("Category *")),
  //                       const SizedBox(height: 6),
  //                       DropdownButtonFormField<String>(
  //                         isExpanded: true,
  //                         value: _validateSelectedCategoryKey(
  //                             selectedCategoryKey, categoryItems),
  //                         hint: Text(translateText("Select Category")),
  //                         items: categoryItems,
  //                         onChanged: (key) {
  //                           if (key == null) return;
  //                           setState(() {
  //                             selectedCategoryKey = key;
  //                             selectedService = null;
  //                             if (key.startsWith('cat:')) {
  //                               final id = int.parse(key.substring(4));
  //                               selectedCategoryType = 'category';
  //                               selectedCategory = findCategoryById(
  //                                   widget.categories ?? [], id);
  //                             } else {
  //                               final id = int.parse(key.substring(4));
  //                               selectedCategoryType = 'subCategory';
  //                               selectedCategory = findSubcategoryById(
  //                                   widget.categories ?? [], id);
  //                             }
  //                           });
  //                         },
  //                         decoration: _inputDecoration(),
  //                         validator: (_) =>
  //                             _validateCategory(selectedCategory),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           _SectionCard(
  //             title: "",
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: TextFormField(
  //                     controller: priceController,
  //                     keyboardType: TextInputType.number,
  //                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //                     decoration: _inputDecoration(
  //                       label: translateText("Price *"),
  //                       icon: Icons.currency_rupee,
  //                     ),
  //                     validator: _validatePrice,
  //                   ),
  //                 ),
  //                 const SizedBox(width: 12),
  //                 Expanded(
  //                   child: TextFormField(
  //                     controller: durationController,
  //                     keyboardType: TextInputType.number,
  //                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //                     decoration: _inputDecoration(
  //                       label: translateText("Duration (min) *"),
  //                       icon: Icons.timer_outlined,
  //                     ),
  //                     validator: _validateDuration,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 24),
  //           SizedBox(
  //             width: double.infinity,
  //             child: ElevatedButton.icon(
  //               icon: _isLoading
  //                   ? const SizedBox(
  //                       height: 18,
  //                       width: 18,
  //                       child: CircularProgressIndicator(
  //                           strokeWidth: 2, color: Colors.white),
  //                     )
  //                   :  Icon(Icons.add_task_outlined, color: Colors.white),
  //               label: Text(
  //                 _isLoading
  //                     ? translateText('Adding...')
  //                     : translateText('Add Service'),
  //                 style: const TextStyle(fontSize: 16, color: Colors.white),
  //               ),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: AppColors.starColor,
  //                 padding: const EdgeInsets.symmetric(vertical: 14),
  //                 shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(12)),
  //               ),
  //               onPressed: _isLoading
  //                   ? null
  //                   : () async {
  //                       if (!_autoValidate) {
  //                         setState(() => _autoValidate = true);
  //                       }
  //                       final valid = _formKey.currentState!.validate();
  //                       if (!valid) return;
  //                       await _addService();
  //                     },
  //             ),
  //           ),
  //         ]),
  //       ),
  //     ),
  //   );
  // }
  @override
Widget build(BuildContext context) {
  final categoryItems =
      buildCategoryAndSubcategoryKeyItems(widget.categories ?? []);

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        translateText('Add Service'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.starColor, AppColors.getStartedButton],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
    body: Form(
      key: _formKey,
      autovalidateMode: _autoValidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SectionCard(
              title: "",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(translateText("Service Name *")),
                  const SizedBox(height: 6),
                  // ✅ Service Name (max 50 chars + counter)
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      TextFormField(
                        controller: nameController,
                        focusNode: _nameFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          const FirstLetterUpperFormatter(),
                          LengthLimitingTextInputFormatter(50),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecoration(
                          hint: translateText("Add a service name"),
                          icon: Icons.badge_outlined,
                        ).copyWith(counterText: ''),
                        validator: _validateLabel,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 8),
                        child: Text(
                          '${nameController.text.length}/50',
                          style: TextStyle(
                            fontSize: 12,
                            color: nameController.text.length >= 50
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel(translateText("Description (Optional)")),
                  const SizedBox(height: 6),
                  // ✅ Description (max 50 chars + counter)
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecoration(
                          hint: translateText("Add a short description"),
                          icon: Icons.description_outlined,
                        ).copyWith(counterText: ''),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 8),
                        child: Text(
                          '${descController.text.length}/50',
                          style: TextStyle(
                            fontSize: 12,
                            color: descController.text.length >= 50
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Category Section (unchanged)
            _SectionCard(
              title: "",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(translateText("Category *")),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _validateSelectedCategoryKey(
                        selectedCategoryKey, categoryItems),
                    hint: Text(translateText("Select Category")),
                    items: categoryItems,
                    onChanged: (key) {
                      if (key == null) return;
                      setState(() {
                        selectedCategoryKey = key;
                        selectedService = null;
                        if (key.startsWith('cat:')) {
                          final id = int.parse(key.substring(4));
                          selectedCategoryType = 'category';
                          selectedCategory =
                              findCategoryById(widget.categories ?? [], id);
                        } else {
                          final id = int.parse(key.substring(4));
                          selectedCategoryType = 'subCategory';
                          selectedCategory =
                              findSubcategoryById(widget.categories ?? [], id);
                        }
                      });
                    },
                    decoration: _inputDecoration(),
                    validator: (_) => _validateCategory(selectedCategory),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Price + Duration with limits
            _SectionCard(
              title: "",
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6), // ✅ 6 digits max
                      ],
                      decoration: _inputDecoration(
                        label: translateText("Price *"),
                        icon: Icons.currency_rupee,
                      ),
                      validator: _validatePrice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4), // ✅ 4 digits max
                      ],
                      decoration: _inputDecoration(
                        label: translateText("Duration (min) *"),
                        icon: Icons.timer_outlined,
                      ),
                      validator: _validateDuration,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Submit button (unchanged)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_task_outlined, color: Colors.white),
                label: Text(
                  _isLoading
                      ? translateText('Adding...')
                      : translateText('Add Service'),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!_autoValidate) {
                          setState(() => _autoValidate = true);
                        }
                        final valid = _formKey.currentState!.validate();
                        if (!valid) return;
                        await _addService();
                      },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}

// ------------------- Helper UI -------------------
InputDecoration _inputDecoration({String? hint, String? label, IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: icon != null ? Icon(icon) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.black),
      borderRadius: BorderRadius.circular(10),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.red),
      borderRadius: BorderRadius.circular(10),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
}

// ---------- Dropdown Helpers ----------
List<DropdownMenuItem<String>> buildCategoryAndSubcategoryKeyItems(
    List<dynamic> categories) {
  final items = <DropdownMenuItem<String>>[];
  for (final cat in categories) {
    final catId = cat['id'] as int;
    items.add(DropdownMenuItem<String>(
      value: 'cat:$catId',
      child: Text(cat['displayName'] ?? ''),
    ));
    for (final sub in (cat['subCategories'] ?? []) as List) {
      final subId = sub['id'] as int;
      items.add(DropdownMenuItem<String>(
        value: 'sub:$subId',
        child:
            Padding(padding: const EdgeInsets.only(left: 20), child: Text(sub['displayName'] ?? '')),
      ));
    }
  }
  return items;
}

Map<String, dynamic>? findCategoryById(List<dynamic> categories, int id) {
  for (final cat in categories) {
    if (cat['id'] == id) return Map<String, dynamic>.from(cat);
  }
  return null;
}

Map<String, dynamic>? findSubcategoryById(List<dynamic> categories, int id) {
  for (final cat in categories) {
    for (final sub in (cat['subCategories'] ?? []) as List) {
      if (sub['id'] == id) return Map<String, dynamic>.from(sub);
    }
  }
  return null;
}
