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
const List<int> _durationOptions = <int>[15, 30, 45, 60, 90, 120, 180];
const int _defaultDurationMinutes = 60;
const bool _defaultPassiveWaitEnabled = true;
const int _defaultInitialBusyMinutes = 10;
const int _defaultPassiveWaitMinutes = 40;
const int _defaultFinalBusyMinutes = 10;
const int _minimumPassiveWaitMinutes = 1;

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
  bool _passiveWaitEnabled = _defaultPassiveWaitEnabled;
  int _initialBusyMinutes = _defaultInitialBusyMinutes;
  int _passiveWaitMinutes = _defaultPassiveWaitMinutes;
  int _finalBusyMinutes = _defaultFinalBusyMinutes;

  int? get _enteredPrice => int.tryParse(priceController.text.trim());
  bool get _hasValidPrice => (_enteredPrice ?? 0) > 0;
  bool get _isEditMode => widget.serviceToEdit != null;

  int? get _selectedDuration => _asInt(durationController.text.trim());

  List<int> get _durationMenuOptions {
    final selected = _selectedDuration;
    final options = <int>{..._durationOptions};
    if (selected != null && selected > 0) {
      options.add(selected);
    }
    final sorted = options.toList()..sort();
    return sorted;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  int _minimumPassiveWaitForDuration(int duration) {
    if (duration <= 0) return 0;
    return _clampInt(_minimumPassiveWaitMinutes, 0, duration);
  }

  void _setDefaultPassiveWaitForDuration(int duration) {
    if (duration <= 0) return;
    final busyStart =
        duration >= 20 ? 10 : _clampInt(duration ~/ 3, 0, duration);
    final remainingAfterStart = duration - busyStart;
    final busyEnd = duration >= 20
        ? _clampInt(10, 0, remainingAfterStart)
        : _clampInt(remainingAfterStart ~/ 2, 0, remainingAfterStart);
    _initialBusyMinutes = busyStart;
    _finalBusyMinutes = busyEnd;
    _passiveWaitMinutes = duration - busyStart - busyEnd;
  }

  void _normalizePassiveWaitForDuration(int duration) {
    if (duration <= 0) return;
    final minPassive =
        _passiveWaitEnabled ? _minimumPassiveWaitForDuration(duration) : 0;
    final initial = _clampInt(_initialBusyMinutes, 0, duration - minPassive);
    final passive = _clampInt(
      _passiveWaitMinutes,
      minPassive,
      duration - initial,
    );
    _initialBusyMinutes = initial;
    _passiveWaitMinutes = passive;
    _finalBusyMinutes = duration - initial - passive;
  }

  void _updatePassiveWaitFromRange(int duration, RangeValues values) {
    final minPassive = _minimumPassiveWaitForDuration(duration);
    final oldStart = _initialBusyMinutes;
    final oldEnd = _initialBusyMinutes + _passiveWaitMinutes;
    var start = _clampInt(values.start.round(), 0, duration - minPassive);
    var end = _clampInt(values.end.round(), start + minPassive, duration);

    if (end - start < minPassive) {
      final startMoved = (start - oldStart).abs() > (end - oldEnd).abs();
      if (startMoved) {
        start = _clampInt(end - minPassive, 0, duration - minPassive);
      } else {
        end = _clampInt(start + minPassive, minPassive, duration);
      }
    }

    _initialBusyMinutes = start;
    _passiveWaitMinutes = end - start;
    _finalBusyMinutes = duration - end;
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
      durationController.text = _defaultDurationMinutes.toString();
      _setDefaultPassiveWaitForDuration(_defaultDurationMinutes);

      final subCategories =
          (widget.selectedCategory!['subCategories'] as List?) ?? const [];
      if (subCategories.length == 1 && subCategories.first is Map) {
        selectedCategory = Map<String, dynamic>.from(subCategories.first);
        selectedCategoryType = 'subCategory';
        final id = selectedCategory!['id'];
        selectedCategoryKey = 'sub:$id';
      }
    } else {
      durationController.text = _defaultDurationMinutes.toString();
      _setDefaultPassiveWaitForDuration(_defaultDurationMinutes);
    }
  }

  void _populateServiceForEdit(Map<String, dynamic> service) {
    nameController.text =
        (service['displayName'] ?? service['name'] ?? '').toString();
    descController.text = (service['description'] ?? '').toString();
    durationController.text =
        (_asInt(service['durationMin'] ?? service['defaultDurationMin']) ?? '')
            .toString();
    final duration =
        _asInt(service['durationMin'] ?? service['defaultDurationMin']);
    if (duration != null && duration > 0) {
      _passiveWaitEnabled = service['passiveWaitEnabled'] != false;
      final initialBusy = _asInt(service['initialBusyMinutes']);
      final passiveWait = _asInt(service['passiveWaitMinutes']);
      final finalBusy = _asInt(service['finalBusyMinutes']);
      if (initialBusy != null && passiveWait != null && finalBusy != null) {
        _initialBusyMinutes = initialBusy;
        _passiveWaitMinutes = passiveWait;
        _finalBusyMinutes = finalBusy;
        _normalizePassiveWaitForDuration(duration);
      } else {
        _setDefaultPassiveWaitForDuration(duration);
      }
    }
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
      final branchSubCategoryId = _asInt(selectedCategory?['id']);
      final branchCategoryId = _asInt(selectedCategory?['branchCategoryId']) ??
          _asInt(selectedCategory?['categoryId']) ??
          _asInt(widget.selectedCategory?['id']) ??
          _findParentCategoryIdForSubCategory(branchSubCategoryId);

      if (branchSubCategoryId == null || branchCategoryId == null) {
        throw Exception(jsonEncode({
          "message":
              "Missing category/subcategory id. branchCategoryId=$branchCategoryId, branchSubCategoryId=$branchSubCategoryId"
        }));
      }

      final displayName = nameController.text.trim();
      final desc = descController.text.trim();
      final priceText = priceController.text.trim();
      final int? price = priceText.isEmpty ? null : int.tryParse(priceText);
      final int? priceMinor = price == null ? null : rupeesToMinorAmount(price);
      final duration = int.parse(durationController.text.trim());
      _normalizePassiveWaitForDuration(duration);
      final initialBusyMinutes =
          _passiveWaitEnabled ? _initialBusyMinutes : duration;
      final passiveWaitMinutes = _passiveWaitEnabled ? _passiveWaitMinutes : 0;
      final finalBusyMinutes = _passiveWaitEnabled ? _finalBusyMinutes : 0;
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
          'passiveWaitEnabled': _passiveWaitEnabled,
          'initialBusyMinutes': initialBusyMinutes,
          'passiveWaitMinutes': passiveWaitMinutes,
          'finalBusyMinutes': finalBusyMinutes,
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
          passiveWaitEnabled: _passiveWaitEnabled,
          initialBusyMinutes: initialBusyMinutes,
          passiveWaitMinutes: passiveWaitMinutes,
          finalBusyMinutes: finalBusyMinutes,
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

      final savedSubCategoryId = selectedCategoryType == 'subCategory'
          ? selectedCategory!['id']
          : null;
      final savedCategoryId = selectedCategoryType == 'subCategory'
          ? (widget.selectedCategory?['id'] ??
              _findParentCategoryIdForSubCategory(savedSubCategoryId))
          : selectedCategory?['id'];

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
      Navigator.pop(context, {
        'updated': true,
        'categoryId': savedCategoryId,
        'subCategoryId': savedSubCategoryId,
      });
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

  int? _findParentCategoryIdForSubCategory(dynamic subCategoryId) {
    final targetId = _asInt(subCategoryId);
    if (targetId == null) return null;

    for (final rawCategory in widget.categories ?? const []) {
      if (rawCategory is! Map) continue;
      final subCategories = rawCategory['subCategories'];
      if (subCategories is! List) continue;
      for (final rawSubCategory in subCategories) {
        if (rawSubCategory is Map && _asInt(rawSubCategory['id']) == targetId) {
          return _asInt(rawCategory['id']);
        }
      }
    }
    return null;
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

  String _durationLabel(int minutes) {
    if (minutes < 60) return '${minutes}m';
    if (minutes % 60 == 0) return '${minutes ~/ 60}h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
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

//   String? _validateCommissionMax(String? value) {
//   if (!_commissionEnabled || _commissionType != 'percentage') return null;

//   final price = _enteredPrice; // rupees from UI
//   final percentage =
//       double.tryParse(commissionValueController.text.trim()) ?? 0;

//   final v = (value ?? '').trim();
//   if (v.isEmpty) return null;

//   final parsed = int.tryParse(v);
//   if (parsed == null || parsed <= 0) {
//     return translateText("Enter a valid max commission amount");
//   }

//   if (price != null && price > 0 && percentage > 0) {
//     final priceMinor = rupeesToMinorAmount(price);
//     final maxMinor = rupeesToMinorAmount(parsed);
//     final allowedMaxMinor = (priceMinor * percentage / 100).floor();

//     if (maxMinor > allowedMaxMinor) {
//       final allowedMaxRupee = minorAmountToRupees(allowedMaxMinor);
//       return translateText(
//         "Max commission cannot exceed ${allowedMaxRupee?.toStringAsFixed(0) ?? allowedMaxMinor}",
//       );
//     }
//   }

//   return null;
// }
  String? _validateCommissionMax(String? value) {
    if (!_commissionEnabled || _commissionType != 'percentage') return null;

    final price = _enteredPrice;
    final percentage =
        double.tryParse(commissionValueController.text.trim()) ?? 0;

    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return translateText("Max commission amount is required");
    }

    final parsed = int.tryParse(v);
    if (parsed == null || parsed <= 0) {
      return translateText("Enter a valid max commission amount");
    }

    if (price != null && price > 0 && percentage > 0) {
      final priceMinor = rupeesToMinorAmount(price);
      final maxMinor = rupeesToMinorAmount(parsed);
      final allowedMaxMinor = (priceMinor * percentage / 100).floor();

      if (maxMinor > allowedMaxMinor) {
        final allowedMaxRupee = minorAmountToRupees(allowedMaxMinor);
        return translateText(
          "Max commission cannot exceed ${allowedMaxRupee?.toStringAsFixed(0) ?? allowedMaxMinor}",
        );
      }
    }

    return null;
  }

  String? _validateCategory(Map<String, dynamic>? _) {
    if (_isEditMode) return null;
    if (selectedCategory == null || selectedCategoryType != 'subCategory') {
      return translateText("Subcategory is required");
    }
    return null;
  }

  Widget _buildPassiveWaitSection(int duration) {
    final safeDuration = duration <= 0 ? 60 : duration;
    final minPassive =
        _passiveWaitEnabled ? _minimumPassiveWaitForDuration(safeDuration) : 0;
    final start = _clampInt(_initialBusyMinutes, 0, safeDuration - minPassive);
    final end = _clampInt(
      _initialBusyMinutes + _passiveWaitMinutes,
      start + minPassive,
      safeDuration,
    );
    final passive = end - start;
    final finalBusy = safeDuration - end;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _serviceGoldLight.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText('Passive wait'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _serviceInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      translateText(
                        'Split duration into busy start, passive wait, and busy end.',
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _serviceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: _passiveWaitEnabled,
                activeColor: _serviceGold,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) {
                  setState(() {
                    _passiveWaitEnabled = value ?? false;
                  });
                },
              ),
              Text(
                translateText('Enabled'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _serviceInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                rangeTrackShape: const _PassiveWaitRangeTrackShape(),
                activeTrackColor: _serviceGold,
                inactiveTrackColor: _serviceBorder,
              ),
              child: RangeSlider(
                values: RangeValues(start.toDouble(), end.toDouble()),
                min: 0,
                max: safeDuration.toDouble(),
                divisions: safeDuration,
                activeColor: _serviceGold,
                inactiveColor: _serviceBorder,
                labels: RangeLabels('${start}m', '${end}m'),
                onChanged: _passiveWaitEnabled
                    ? (values) {
                        setState(() {
                          _updatePassiveWaitFromRange(safeDuration, values);
                        });
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${translateText('Busy start')}: $start min',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _serviceMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${translateText('Passive wait')}: $passive min',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _serviceMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${translateText('Busy end')}: $finalBusy min',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _serviceMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryItems = buildSubcategoryKeyItems(
      widget.categories ?? [],
      selectedParentCategory: widget.selectedCategory,
    );
    final durationMenuOptions = _durationMenuOptions;

    return Scaffold(
      backgroundColor: _serviceSurface,
      appBar: buildProfileSubpageAppBar(
        title: translateText(_isEditMode ? 'Edit Service' : 'Add Service'),
        toolbarHeight: kToolbarHeight,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            Form(
              key: _formKey,
              autovalidateMode: _autoValidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLength: 50,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
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
                              _FieldLabel(
                                  translateText("Description (Optional)")),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: descController,
                                maxLines: 2,
                                maxLength: 50,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(50)
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: _inputDecoration(
                                  hint:
                                      translateText("Add a short description"),
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
                              _FieldLabel(translateText("Subcategory *")),
                              const SizedBox(height: 7),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _validateSelectedCategoryKey(
                                    selectedCategoryKey, categoryItems),
                                hint: Text(translateText("Select Subcategory")),
                                items: categoryItems,
                                onChanged: _isEditMode
                                    ? null
                                    : (key) {
                                        if (key == null) return;
                                        setState(() {
                                          selectedCategoryKey = key;
                                          selectedService = null;
                                          final id =
                                              int.parse(key.substring(4));
                                          selectedCategoryType = 'subCategory';
                                          selectedCategory =
                                              findSubcategoryById(
                                                  widget.categories ?? [], id);
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
                                        if (!_hasValidPrice &&
                                            _commissionEnabled) {
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
                                      currentLength:
                                          priceController.text.length,
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
                                    DropdownButtonFormField<int>(
                                      initialValue: durationMenuOptions
                                              .contains(_selectedDuration)
                                          ? _selectedDuration
                                          : null,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF6B665F),
                                      borderRadius: BorderRadius.circular(8),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: _serviceGold,
                                      ),
                                      selectedItemBuilder: (context) {
                                        return durationMenuOptions
                                            .map(
                                              (minutes) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  _durationLabel(minutes),
                                                  style: const TextStyle(
                                                    color: _serviceInk,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList();
                                      },
                                      items: durationMenuOptions.map((minutes) {
                                        final selected =
                                            minutes == _selectedDuration;
                                        return DropdownMenuItem<int>(
                                          value: minutes,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                child: selected
                                                    ? const Icon(
                                                        Icons.check_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _durationLabel(minutes),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          durationController.text =
                                              value.toString();
                                          _setDefaultPassiveWaitForDuration(
                                              value);
                                        });
                                      },
                                      decoration: _inputDecoration(
                                        hint: translateText("Duration"),
                                        suffixIcon: Icons.timer_outlined,
                                      ),
                                      validator: (value) => _validateDuration(
                                        value?.toString(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      translateText('Select service duration'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _serviceMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPassiveWaitSection(_selectedDuration ?? 60),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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
                                  onChanged: (_) {
                                    setState(() {});
                                    _formKey.currentState?.validate();
                                  },
                                  textInputAction:
                                      _commissionType == 'percentage'
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                  inputFormatters: _commissionType ==
                                          'percentage'
                                      ? [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                          LengthLimitingTextInputFormatter(6),
                                        ]
                                      : [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
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
                                      translateText("Commission Max *")),
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
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
            if (_isLoading)
              const Positioned.fill(child: _ServiceLoadingOverlay()),
          ],
        ),
      ),
    );
  }
}

class _ServiceLoadingOverlay extends StatelessWidget {
  const _ServiceLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.16),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _serviceGold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translateText('Please wait...'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B3A2A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassiveWaitRangeTrackShape extends RangeSliderTrackShape {
  const _PassiveWaitRangeTrackShape();

  static const double _trackHeight = 4;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const horizontalInset = 24.0;
    final trackLeft = offset.dx + horizontalInset;
    final trackTop = offset.dy + (parentBox.size.height - _trackHeight) / 2;
    final trackWidth = parentBox.size.width - (horizontalInset * 2);
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, _trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(trackRect.height / 2);
    final busyPaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? _serviceGold;
    final passivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? _serviceBorder;

    final startX = startThumbCenter.dx.clamp(trackRect.left, trackRect.right);
    final endX = endThumbCenter.dx.clamp(trackRect.left, trackRect.right);
    final leftThumbX = startX <= endX ? startX : endX;
    final rightThumbX = startX <= endX ? endX : startX;

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      passivePaint,
    );

    if (leftThumbX > trackRect.left) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            trackRect.left,
            trackRect.top,
            leftThumbX,
            trackRect.bottom,
          ),
          radius,
        ),
        busyPaint,
      );
    }

    if (rightThumbX < trackRect.right) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            rightThumbX,
            trackRect.top,
            trackRect.right,
            trackRect.bottom,
          ),
          radius,
        ),
        busyPaint,
      );
    }
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
String _serviceSortLabel(Map<String, dynamic> item) {
  for (final key in const [
    'displayName',
    'name',
    'serviceName',
    'title',
    'label',
    'code',
  ]) {
    final value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value.toLowerCase();
  }
  return '';
}

int _compareServiceItems(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final labelCompare =
      _serviceSortLabel(first).compareTo(_serviceSortLabel(second));
  if (labelCompare != 0) return labelCompare;
  final firstId = first['id'] is num ? (first['id'] as num).toInt() : 0;
  final secondId = second['id'] is num ? (second['id'] as num).toInt() : 0;
  return firstId.compareTo(secondId);
}

List<DropdownMenuItem<String>> buildSubcategoryKeyItems(
  List<dynamic> categories, {
  Map<String, dynamic>? selectedParentCategory,
}) {
  final items = <DropdownMenuItem<String>>[];
  final selectedParentCategoryId = selectedParentCategory?['id'];
  for (final cat in categories) {
    if (cat is! Map) continue;
    final catId = cat['id'];
    if (selectedParentCategoryId != null && catId != selectedParentCategoryId) {
      continue;
    }
    final subCategories = ((cat['subCategories'] as List?) ?? const [])
        .whereType<Map>()
        .map((sub) => Map<String, dynamic>.from(sub))
        .toList()
      ..sort(_compareServiceItems);
    for (final sub in subCategories) {
      final subId = sub['id'] as int;
      items.add(DropdownMenuItem<String>(
        value: 'sub:$subId',
        child: Text(sub['displayName'] ?? ''),
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

// Map<String, dynamic>? findSubcategoryById(List<dynamic> categories, int id) {
//   for (final cat in categories) {
//     for (final sub in (cat['subCategories'] ?? []) as List) {
//       if (sub['id'] == id) return Map<String, dynamic>.from(sub);
//     }
//   }
//   return null;
// }
Map<String, dynamic>? findSubcategoryById(List<dynamic> categories, int id) {
  for (final cat in categories) {
    if (cat is! Map) continue;

    for (final sub in (cat['subCategories'] ?? []) as List) {
      if (sub is Map && sub['id'] == id) {
        return {
          ...Map<String, dynamic>.from(sub),
          'branchCategoryId': cat['id'],
        };
      }
    }
  }
  return null;
}
