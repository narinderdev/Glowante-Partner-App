import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'dart:convert';

import '../Viewmodels/AddSalonServiceRequest.dart';
import '../utils/colors.dart';

class AddServices extends StatefulWidget {
  final int salonId;
  final Map<String, dynamic>? selectedCategory;
  final List<dynamic>? categories; // multiple categories

  AddServices({
    required this.salonId,
    this.selectedCategory,
    this.categories,
  });

  @override
  _AddServicesState createState() => _AddServicesState();
}

/// --- Helpers: Title Case InputFormatter (Service name) ---
class TitleCaseInputFormatter extends TextInputFormatter {
  const TitleCaseInputFormatter();

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;
    final parts = input.split(RegExp(r'(\s+)'));
    final mapped = parts.map((p) {
      if (p.trim().isEmpty) return p; // preserve spaces
      if (p.length == 1) return p.toUpperCase();
      final firstAlpha = RegExp(r'[A-Za-z]').firstMatch(p);
      if (firstAlpha == null) return p; // no letters
      final i = firstAlpha.start;
      return p.substring(0, i) + p[i].toUpperCase() + p.substring(i + 1);
    }).toList();
    return mapped.join('');
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length >= oldValue.text.length) {
      final transformed = _toTitleCase(newValue.text);
      final baseOffset = newValue.selection.baseOffset;
      return TextEditingValue(
        text: transformed,
        selection: TextSelection.collapsed(offset: baseOffset),
      );
    }
    return newValue;
  }
}

class _AddServicesState extends State<AddServices> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // controllers
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController();

  // focus
  final FocusNode _nameFocus = FocusNode();

  // catalog data
  List<dynamic> serviceCatalog = [];

  /// Category dropdown state
  Map<String, dynamic>? selectedCategory; // full map for request
  String? selectedCategoryKey;            // "cat:<id>" or "sub:<id>"
  String? selectedCategoryType;           // 'category' or 'subCategory'

  /// Subcategory (right dropdown)
  Map<String, dynamic>? selectedService;  // full map for request

  @override
  void initState() {
    super.initState();
    selectedCategory = null;
    selectedService = null;
    fetchServiceCatalog();

    // Preselect incoming category (if any)
    if (widget.selectedCategory != null) {
      selectedCategory = widget.selectedCategory;
      final hasSub = (selectedCategory!['subCategories'] ?? []).isNotEmpty;
      selectedCategoryType = hasSub ? 'category' : 'subCategory';
      final id = selectedCategory!['id'];
      selectedCategoryKey = (selectedCategoryType == 'category') ? 'cat:$id' : 'sub:$id';
    }

    // Focus the Service Name field and open keyboard with Caps
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

  Future<void> fetchServiceCatalog() async {
    try {
      final response = await ApiService().getServiceCatalog();
      if (mounted && response['success'] == true) {
        setState(() => serviceCatalog = response['data']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch service catalog")),
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

  /// --- Submit: only call when form is valid ---
  Future<void> _addService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      int? salonCategoryId;
      int? salonSubCategoryId;

      final int masterSubCategoryId = selectedService!['id'];

      if (selectedCategoryType == 'category') {
        salonCategoryId = selectedCategory!['id'];
      } else if (selectedCategoryType == 'subCategory') {
        salonSubCategoryId = selectedCategory!['id'];
      }

      if (salonCategoryId != null && salonSubCategoryId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select either category or subcategory, not both")),
        );
        return;
      }

      final name = nameController.text.trim();
      final desc = descController.text.trim();
      final price = int.parse(priceController.text.trim());
      final duration = int.parse(durationController.text.trim());

      final request = AddSalonServiceRequest(
        masterSubCategoryId: masterSubCategoryId,
        salonCategoryId: salonCategoryId,
        salonSubCategoryId: salonSubCategoryId,
        name: name, // title-cased & validated
        description: desc.isEmpty ? "" : desc, // model expects non-null String
        defaultDurationMin: duration,
        defaultPriceMinor: price,
        priceType: "fixed",
        code: null,
        source: "custom",
        scope: "salon",
        ownerBranchId: widget.salonId,
        isActive: true,
      );

      await ApiService().addService(salonId: widget.salonId, request: request);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service added successfully!")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = "Failed to add service";
      try {
        String errorStr = e.toString();
        errorStr = errorStr.replaceFirst("Exception: ", "");
        errorStr = errorStr.replaceFirst("Failed to add service: ", "");
        final errorJson = jsonDecode(errorStr);

        if (errorJson['message'] is List && errorJson['message'].isNotEmpty) {
          errorMessage = _mapErrorMessage(errorJson['message'][0]);
        } else if (errorJson['message'] is String) {
          errorMessage = _mapErrorMessage(errorJson['message']);
        }
      } catch (_) {}
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Alert"),
          content: Text(errorMessage),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK")),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Validators ---
  String? _validateLabel(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return "Service name is required";
    final firstAlpha = RegExp(r'[A-Za-z]').firstMatch(v);
    if (firstAlpha != null) {
      final ch = v[firstAlpha.start];
      if (ch != ch.toUpperCase()) {
        return "Service name should start with a capital letter";
      }
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return "Price is required";
    final num? n = int.tryParse(v);
    if (n == null || n <= 0) return "Price must be a positive number";
    return null;
  }

  String? _validateDuration(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return "Duration is required";
    final num? n = int.tryParse(v);
    if (n == null || n <= 0) return "Duration must be a positive number";
    return null;
  }

  String? _validateCategory(Map<String, dynamic>? _) {
    if (selectedCategory == null) return "Category is required";
    return null;
  }

  String? _validateSubcategory(int? _) {
    if (selectedService == null) return "Subcategory is required";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.grey,
        iconTheme: const IconThemeData(color: AppColors.black),
        title: const Text(
          'Add Service',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.black),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _SectionCard(
                title: "Basic Info",
                subtitle: "Service name is required, description is optional",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel("Service Name *"),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      focusNode: _nameFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words, // open keyboard with Caps
                      inputFormatters: const [TitleCaseInputFormatter()],
                      decoration: _inputDecoration(
                        hint: "Add a service name",
                        icon: Icons.badge_outlined,
                      ),
                      validator: _validateLabel,
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel("Description (Optional)"),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences, // keyboard Caps, no validation
                      decoration: _inputDecoration(
                        hint: "Add a short description",
                        icon: Icons.description_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: "Categorization",
                subtitle: "Choose where this service belongs",
                child: Row(
                  children: [
                    // Left: Category (uses unique string keys)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel("Category *"),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedCategoryKey,
                            hint: const Text("Select Category"),
                            items: buildCategoryAndSubcategoryKeyItems(widget.categories ?? []),
                            onChanged: (key) {
                              if (key == null) return;
                              setState(() {
                                selectedCategoryKey = key;

                                if (key.startsWith('cat:')) {
                                  final id = int.parse(key.substring(4));
                                  selectedCategoryType = 'category';
                                  selectedCategory = findCategoryById(widget.categories ?? [], id);
                                } else {
                                  final id = int.parse(key.substring(4)); // 'sub:'
                                  selectedCategoryType = 'subCategory';
                                  selectedCategory = findSubcategoryById(widget.categories ?? [], id);
                                }
                              });
                            },
                            decoration: _inputDecoration(),
                            validator: (_) => _validateCategory(selectedCategory),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right: Subcategory (kept as int IDs)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel("Subcategory *"),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: selectedService?['id'],
                            hint: const Text("Select"),
                            items: serviceCatalog.expand<DropdownMenuItem<int>>((service) {
                              final subCats = service['subCategories'] ?? [];
                              return (subCats as List).map<DropdownMenuItem<int>>((sub) {
                                return DropdownMenuItem<int>(
                                  value: sub['id'] as int,
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
                            decoration: _inputDecoration(),
                            validator: (_) => _validateSubcategory(selectedService?['id']),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: "Pricing & Duration",
                subtitle: "Enter positive values only",
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration(
                          label: "Price *",
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
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration(
                          label: "Duration (min) *",
                          icon: Icons.timer_outlined,
                        ),
                        validator: _validateDuration,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_task_outlined),
                  label: Text(
                    _isLoading ? 'Adding...' : 'Add Service',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
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

/// ---------- UI bits ----------
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
    focusedErrorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.red),
      borderRadius: BorderRadius.circular(10),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.checklist_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
  }
}

/// ---------- Category dropdown helpers (unique keys) ----------

// Build unique items: "cat:<id>" for categories, "sub:<id>" for subcategories.
List<DropdownMenuItem<String>> buildCategoryAndSubcategoryKeyItems(List<dynamic> categories) {
  final List<DropdownMenuItem<String>> items = [];

  for (final category in categories) {
    final catId = category['id'] as int;
    items.add(
      DropdownMenuItem<String>(
        value: 'cat:$catId',
        // Enabled only if it has no subcategories (same behavior you had)
        enabled: category['subCategories'] == null || (category['subCategories'] as List).isEmpty,
        child: Text(
          category['name'] ?? '',
          style: TextStyle(
            color: (category['subCategories'] == null || (category['subCategories'] as List).isEmpty)
                ? Colors.black
                : Colors.grey,
          ),
        ),
      ),
    );

    for (final sub in (category['subCategories'] ?? []) as List) {
      final subId = sub['id'] as int;
      items.add(
        DropdownMenuItem<String>(
          value: 'sub:$subId',
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(sub['name'] ?? ''),
          ),
        ),
      );
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
