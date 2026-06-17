import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'dart:convert';
import '../Viewmodels/AddSalonServiceRequest.dart';
import '../bloc/category/category_cubit.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';

const Color _serviceGold = Color(0xFF8B6500);
const Color _serviceGoldLight = Color(0xFFD0A244);
const Color _serviceInk = Color(0xFF1F1B18);
const Color _serviceMuted = Color(0xFF6F665E);
const Color _serviceBorder = Color(0xFFE3DCD7);
const Color _serviceFieldFill = Colors.white;
const Color _serviceSurface = Color(0xFFFBFAF8);

class AddServices extends StatefulWidget {
  final int branchId;
  final Map<String, dynamic>? selectedCategory;
  final List<dynamic>? categories;
  final Map<String, dynamic>? serviceToEdit;

  const AddServices({
    super.key,
    required this.branchId,
    this.selectedCategory,
    this.categories,
    this.serviceToEdit,
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
  final commissionValueController = TextEditingController();
  final commissionMaxController = TextEditingController();

  List<dynamic> serviceCatalog = [];
  Map<String, dynamic>? selectedCategory;
  String? selectedCategoryKey;
  String? selectedCategoryType;
  Map<String, dynamic>? selectedService;
  bool _commissionEnabled = false;
  String _commissionType = 'percentage';

  int? get _enteredPrice => int.tryParse(priceController.text.trim());
  bool get _hasValidPrice => (_enteredPrice ?? 0) > 0;
  bool get _isEditMode => widget.serviceToEdit != null;

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    fetchServiceCatalog();

    if (_isEditMode) {
      _populateServiceForEdit(widget.serviceToEdit!);
      _selectCategoryForService(widget.serviceToEdit!);
    } else if (widget.selectedCategory != null) {
      final subCategories =
          (widget.selectedCategory!['subCategories'] as List?) ?? const [];
      if (subCategories.isEmpty) {
        selectedCategory = widget.selectedCategory;
        selectedCategoryType = 'category';
        final id = selectedCategory!['id'];
        selectedCategoryKey = 'cat:$id';
      }
    }
  }

  void _populateServiceForEdit(Map<String, dynamic> service) {
    nameController.text =
        (service['displayName'] ?? service['name'] ?? '').toString();
    descController.text = (service['description'] ?? '').toString();
    durationController.text =
        (_asInt(service['durationMin'] ?? service['defaultDurationMin']) ?? '')
            .toString();
    final priceMinor =
        _asInt(service['priceMinor'] ?? service['defaultPriceMinor']);
    priceController.text = priceMinor == null
        ? ''
        : (minorAmountToRupees(priceMinor)?.toStringAsFixed(0) ?? '');

    _commissionEnabled = service['commissionEnabled'] == true;
    final type = (service['commissionType'] ?? '').toString().toLowerCase();
    _commissionType = type == 'fixed' ? 'fixed' : 'percentage';
    if (_commissionEnabled && _commissionType == 'fixed') {
      commissionValueController.text =
          (minorAmountToRupees(service['commissionFixedAmountMinor'])
                  ?.toStringAsFixed(0) ??
              '');
    } else if (_commissionEnabled) {
      final percentage = _asDouble(service['commissionPercentage']);
      commissionValueController.text = percentage == null
          ? ''
          : percentage.toStringAsFixed(
              percentage.truncateToDouble() == percentage ? 0 : 2,
            );
      commissionMaxController.text =
          (minorAmountToRupees(service['commissionMaxAmountMinor'])
                  ?.toStringAsFixed(0) ??
              '');
    }
  }

  void _selectCategoryForService(Map<String, dynamic> service) {
    final serviceId = _asInt(service['id']);
    final categories = widget.categories ?? const [];
    for (final rawCategory in categories) {
      if (rawCategory is! Map) continue;
      final category = Map<String, dynamic>.from(rawCategory);
      final categoryServices = category['services'];
      if (serviceId != null && categoryServices is List) {
        final hasService = categoryServices.any(
          (item) => item is Map && _asInt(item['id']) == serviceId,
        );
        if (hasService) {
          selectedCategory = category;
          selectedCategoryType = 'category';
          selectedCategoryKey = 'cat:${category['id']}';
          return;
        }
      }

      final subCategories = category['subCategories'];
      if (subCategories is! List) continue;
      for (final rawSubCategory in subCategories) {
        if (rawSubCategory is! Map) continue;
        final subCategory = Map<String, dynamic>.from(rawSubCategory);
        final services = subCategory['services'];
        if (serviceId != null && services is List) {
          final hasService = services.any(
            (item) => item is Map && _asInt(item['id']) == serviceId,
          );
          if (hasService) {
            selectedCategory = subCategory;
            selectedCategoryType = 'subCategory';
            selectedCategoryKey = 'sub:${subCategory['id']}';
            return;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    durationController.dispose();
    commissionValueController.dispose();
    commissionMaxController.dispose();
    super.dispose();
  }

  // ------------------- Dropdown Safety -------------------
  String? _validateSelectedCategoryKey(
      String? currentKey, List<DropdownMenuItem<String>> items) {
    if (currentKey == null) return null;
    final validKeys = items.map((e) => e.value).whereType<String>().toSet();
    if (!validKeys.contains(currentKey)) {
      debugPrint(
          '[Dropdown Fix] Resetting invalid selectedCategoryKey: $currentKey');
      return null;
    }
    return currentKey;
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
        SnackBar(
            content: Text(translateText("Failed to fetch service catalog"))),
      );
    }
  }

  // ------------------- Add / Edit Service -------------------
  Future<void> _saveService() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
      final priceMinor = rupeesToMinorAmount(price);
      final duration = int.parse(durationController.text.trim());
      final commissionValue = commissionValueController.text.trim();
      final commissionMax = commissionMaxController.text.trim();

      if (_isEditMode) {
        final serviceId = _asInt(widget.serviceToEdit!['id']);
        if (serviceId == null) {
          throw Exception('{"message":"Service id is missing"}');
        }

        final payload = {
          'displayName': displayName,
          'description': desc,
          'durationMin': duration,
          'priceMinor': priceMinor,
          'priceType': 'fixed',
          'isActive': widget.serviceToEdit!['isActive'] ?? true,
          'commissionEnabled': _commissionEnabled,
          'commissionType': _commissionEnabled ? _commissionType : null,
          'commissionFixedAmountMinor':
              _commissionEnabled && _commissionType == 'fixed'
                  ? _minorIntFromRupeeText(commissionValue)
                  : null,
          'commissionPercentage':
              _commissionEnabled && _commissionType == 'percentage'
                  ? double.tryParse(commissionValue)
                  : null,
          'commissionMaxAmountMinor': _commissionEnabled &&
                  _commissionType == 'percentage' &&
                  commissionMax.isNotEmpty
              ? _minorIntFromRupeeText(commissionMax)
              : null,
        }..removeWhere((key, value) => value == null);

        await ApiService().updateService(
          branchId: widget.branchId,
          branchServiceId: serviceId,
          body: payload,
        );
      } else {
        final request = AddSalonServiceRequest(
          branchCategoryId: branchCategoryId,
          branchSubCategoryId: branchSubCategoryId,
          displayName: displayName,
          description: desc.isEmpty ? "" : desc,
          durationMin: duration,
          priceMinor: priceMinor,
          priceType: "fixed",
          isActive: true,
          commissionEnabled: _commissionEnabled,
          commissionType: _commissionEnabled ? _commissionType : null,
          commissionFixedAmountMinor:
              _commissionEnabled && _commissionType == 'fixed'
                  ? _minorIntFromRupeeText(commissionValue)
                  : null,
          commissionPercentage:
              _commissionEnabled && _commissionType == 'percentage'
                  ? double.tryParse(commissionValue)
                  : null,
          commissionMaxAmountMinor: _commissionEnabled &&
                  _commissionType == 'percentage' &&
                  commissionMax.isNotEmpty
              ? _minorIntFromRupeeText(commissionMax)
              : null,
        );

        await ApiService()
            .addService(branchId: widget.branchId, request: request);
      }

      if (!mounted) return;

      try {
        await context.read<CategoryCubit>().loadCategories(widget.branchId);
      } catch (_) {}
      if (!mounted) return;

      FocusManager.instance.primaryFocus?.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText(
              _isEditMode
                  ? "Service updated successfully"
                  : "Service added successfully!",
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      String errorMessage = translateText(
        _isEditMode ? "Failed to update service" : "Failed to add service",
      );
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

  int? _minorIntFromRupeeText(String value) {
    final parsed = num.tryParse(value.trim());
    return parsed == null ? null : rupeesToMinorAmount(parsed);
  }

  String? _validateCommissionValue(String? value) {
    if (!_commissionEnabled) return null;
    final price = _enteredPrice;
    if (price == null || price <= 0) {
      return translateText("Enter price first to configure commission");
    }
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return _commissionType == 'percentage'
          ? translateText("Commission percentage is required")
          : translateText("Commission amount is required");
    }
    final parsed = _commissionType == 'percentage'
        ? double.tryParse(v)
        : double.tryParse(v);
    if (parsed == null || parsed <= 0) {
      return translateText("Enter a valid commission value");
    }
    if (_commissionType == 'percentage' && parsed > 100) {
      return translateText("Commission percentage cannot exceed 100");
    }
    if (_commissionType == 'fixed' && parsed > price) {
      return translateText("Commission amount cannot exceed price");
    }
    return null;
  }

  String? _validateCommissionMax(String? value) {
    if (!_commissionEnabled || _commissionType != 'percentage') return null;
    final price = _enteredPrice;
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final parsed = int.tryParse(v);
    if (parsed == null || parsed <= 0) {
      return translateText("Enter a valid max commission amount");
    }
    if (price != null && price > 0 && parsed > price) {
      return translateText("Commission max cannot exceed price");
    }
    return null;
  }

  String? _validateCategory(Map<String, dynamic>? _) {
    if (_isEditMode) return null;
    if (selectedCategory == null) return translateText("Category is required");
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categoryItems =
        buildCategoryAndSubcategoryKeyItems(widget.categories ?? []);

    return Scaffold(
      backgroundColor: _serviceSurface,
      appBar: buildProfileSubpageAppBar(
        title: translateText(_isEditMode ? 'Edit Service' : 'Add Service'),
        toolbarHeight: kToolbarHeight,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              14,
              16,
              14,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AddServiceSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(translateText("Service Name *")),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: nameController,
                            autofocus: false,
                            cursorColor: _serviceGold,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 50,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            inputFormatters: [
                              const FirstLetterUpperFormatter(),
                              LengthLimitingTextInputFormatter(50),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: _inputDecoration(
                              hint: translateText("Add a service name"),
                            ),
                            validator: _validateLabel,
                          ),
                          const SizedBox(height: 4),
                          _FieldCounter(
                            currentLength: nameController.text.length,
                            maxLength: 50,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(translateText("Description (Optional)")),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: descController,
                            maxLines: 2,
                            maxLength: 50,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50)
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: _inputDecoration(
                              hint: translateText("Add a short description"),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _FieldCounter(
                            currentLength: descController.text.length,
                            maxLength: 50,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(translateText("Category *")),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _validateSelectedCategoryKey(
                                selectedCategoryKey, categoryItems),
                            hint: Text(translateText("Select Category")),
                            items: categoryItems,
                            onChanged: _isEditMode
                                ? null
                                : (key) {
                                    if (key == null) return;
                                    setState(() {
                                      selectedCategoryKey = key;
                                      selectedService = null;
                                      if (key.startsWith('cat:')) {
                                        final id = int.parse(key.substring(4));
                                        selectedCategoryType = 'category';
                                        selectedCategory = findCategoryById(
                                            widget.categories ?? [], id);
                                      } else {
                                        final id = int.parse(key.substring(4));
                                        selectedCategoryType = 'subCategory';
                                        selectedCategory = findSubcategoryById(
                                            widget.categories ?? [], id);
                                      }
                                    });
                                  },
                            decoration: _inputDecoration(),
                            validator: (_) =>
                                _validateCategory(selectedCategory),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(translateText("Price *")),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: priceController,
                                  maxLength: 6,
                                  maxLengthEnforcement:
                                      MaxLengthEnforcement.enforced,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {
                                    if (!_hasValidPrice && _commissionEnabled) {
                                      _commissionEnabled = false;
                                      commissionValueController.clear();
                                      commissionMaxController.clear();
                                    }
                                  }),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  decoration: _inputDecoration(
                                    hint: translateText("Price"),
                                    suffixIcon: Icons.currency_rupee,
                                  ),
                                  validator: _validatePrice,
                                ),
                                const SizedBox(height: 4),
                                _FieldCounter(
                                  currentLength: priceController.text.length,
                                  maxLength: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(translateText("Duration *")),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: durationController,
                                  maxLength: 4,
                                  maxLengthEnforcement:
                                      MaxLengthEnforcement.enforced,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: _inputDecoration(
                                    hint: translateText("Minutes"),
                                    suffixIcon: Icons.timer_outlined,
                                  ),
                                  validator: _validateDuration,
                                ),
                                const SizedBox(height: 4),
                                _FieldCounter(
                                  currentLength: durationController.text.length,
                                  maxLength: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(height: 1, color: _serviceBorder),
                      const SizedBox(height: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      translateText("Commission"),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _serviceInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      translateText(
                                        "First enter the service price, then configure a fixed amount or percentage.",
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: _serviceMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _commissionEnabled,
                                activeThumbColor: _serviceGold,
                                onChanged: (value) {
                                  if (value && !_hasValidPrice) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          translateText(
                                              "Enter a valid price before enabling commission"),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _commissionEnabled = value;
                                    if (!value) {
                                      commissionValueController.clear();
                                      commissionMaxController.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_commissionEnabled) ...[
                            const SizedBox(height: 16),
                            _FieldLabel(translateText("Commission Type *")),
                            const SizedBox(height: 7),
                            DropdownButtonFormField<String>(
                              initialValue: _commissionType,
                              decoration: _inputDecoration(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('Fixed'),
                                ),
                                DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text('Percentage'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _commissionType = value;
                                  commissionValueController.clear();
                                  commissionMaxController.clear();
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            _FieldLabel(
                              translateText(
                                _commissionType == 'percentage'
                                    ? "Commission Percentage *"
                                    : "Commission Amount *",
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: commissionValueController,
                              maxLength: 6,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              keyboardType: _commissionType == 'percentage'
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true)
                                  : TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              textInputAction: _commissionType == 'percentage'
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              inputFormatters: _commissionType == 'percentage'
                                  ? [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                      LengthLimitingTextInputFormatter(6),
                                    ]
                                  : [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                              decoration: _inputDecoration(
                                hint: translateText(
                                  _commissionType == 'percentage'
                                      ? "Commission percentage"
                                      : "Commission amount",
                                ),
                                icon: _commissionType == 'percentage'
                                    ? Icons.percent_rounded
                                    : Icons.currency_rupee,
                              ),
                              validator: _validateCommissionValue,
                            ),
                            const SizedBox(height: 4),
                            _FieldCounter(
                              currentLength:
                                  commissionValueController.text.length,
                              maxLength: 6,
                            ),
                            if (_commissionType == 'percentage') ...[
                              const SizedBox(height: 14),
                              _FieldLabel(
                                translateText("Commission Max (optional)"),
                              ),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: commissionMaxController,
                                maxLength: 6,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => setState(() {}),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                decoration: _inputDecoration(
                                  hint: translateText("Maximum amount"),
                                  icon: Icons.currency_rupee,
                                ),
                                validator: _validateCommissionMax,
                              ),
                              const SizedBox(height: 4),
                              _FieldCounter(
                                currentLength:
                                    commissionMaxController.text.length,
                                maxLength: 6,
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _serviceGold,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _serviceGold.withValues(alpha: 0.55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  if (!_autoValidate) {
                                    setState(() => _autoValidate = true);
                                  }
                                  final valid =
                                      _formKey.currentState!.validate();
                                  if (!valid) return;
                                  await _saveService();
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      translateText(_isEditMode
                                          ? 'Update Service'
                                          : 'Add Service'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.add_task_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- Helper UI -------------------
InputDecoration _inputDecoration(
    {String? hint, String? label, IconData? icon, IconData? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    counterText: '',
    prefixIcon: icon == null
        ? null
        : Container(
            width: 48,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE4DDD8)),
              ),
            ),
            child: Icon(icon, color: _serviceGold, size: 19),
          ),
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, color: _serviceGold, size: 19)
        : null,
    filled: true,
    fillColor: _serviceFieldFill,
    hintStyle: const TextStyle(
      color: Color(0xFF948C84),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelStyle: const TextStyle(color: _serviceMuted),
    errorMaxLines: 3,
    errorStyle: const TextStyle(
      fontSize: 11,
      height: 1.2,
      color: Colors.redAccent,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _serviceBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _serviceGoldLight, width: 1.2),
      borderRadius: BorderRadius.circular(8),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: EdgeInsets.fromLTRB(
      16,
      14,
      suffixIcon == null ? 16 : 4,
      14,
    ),
  );
}

class _AddServiceSectionCard extends StatelessWidget {
  const _AddServiceSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFEAE0D7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF4B4038),
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 0.8,
      ));
}

class _FieldCounter extends StatelessWidget {
  const _FieldCounter({
    required this.currentLength,
    required this.maxLength,
  });

  final int currentLength;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$currentLength/$maxLength',
        style: TextStyle(
          fontSize: 12,
          color: currentLength >= maxLength ? Colors.red : _serviceMuted,
        ),
      ),
    );
  }
}

// ---------- Dropdown Helpers ----------
List<DropdownMenuItem<String>> buildCategoryAndSubcategoryKeyItems(
    List<dynamic> categories) {
  final items = <DropdownMenuItem<String>>[];
  for (final cat in categories) {
    final catId = cat['id'] as int;
    final subCategories = (cat['subCategories'] as List?) ?? const [];
    final hasSubCategories = subCategories.isNotEmpty;
    items.add(DropdownMenuItem<String>(
      value: 'cat:$catId',
      enabled: !hasSubCategories,
      child: Text(
        cat['displayName'] ?? '',
        style: TextStyle(
          color: hasSubCategories ? Colors.grey.shade500 : null,
        ),
      ),
    ));
    for (final sub in subCategories) {
      final subId = sub['id'] as int;
      items.add(DropdownMenuItem<String>(
        value: 'sub:$subId',
        child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(sub['displayName'] ?? '')),
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
