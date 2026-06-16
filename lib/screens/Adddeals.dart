import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'offer_review_summary_screen.dart';
import 'package:flutter/services.dart';
import 'SelectServices.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class AddDealsScreen extends StatefulWidget {
  final int branchId;
  final String branchName;
  final Function(int branchId) onPackageCreated;
  final String source; // DEAL or PACKAGE
  final bool isEdit;
  final Map<String, dynamic>? existingOffer;

  const AddDealsScreen({
    Key? key,
    required this.branchId,
    required this.branchName,
    required this.onPackageCreated,
    required this.source,
    this.isEdit = false,
    this.existingOffer,
  }) : super(key: key);

  @override
  State<AddDealsScreen> createState() => _AddDealsScreenState();
}

class _SentenceCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    final formatted = t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

class _AddDealsScreenState extends State<AddDealsScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _showErrors = false;
  bool _sTitle = false;
  bool _sValidFrom = false;
  bool _sValidTill = false;
  bool _sServices = false;
  bool _sAmountOff = false;
  bool _sMaxDiscount = false;
  bool _sDiscounted = false;

  final dealTitleController = TextEditingController();
  final validFromController = TextEditingController();
  final validTillController = TextEditingController();
  final durationValueController = TextEditingController();
  final originalPriceController = TextEditingController();
  final discountedPriceController = TextEditingController();
  final amountOffController = TextEditingController();
  final maxDiscountController = TextEditingController();
  final termsController = TextEditingController();

  String pricingMode = 'Fixed';
  String discountType = 'Flat';

  final pricingModes = const ['Fixed', 'Discount'];
  final discountTypes = const ['Flat', 'Percent'];
  final durationUnits = const ['DAY', 'MONTH', 'YEAR'];
  String durationUnit = 'MONTH';

  List<Map<String, dynamic>> _selectedServices = [];

  bool _settingFields = false;
  bool _autoSetMaxFromPercent = true;
  bool _isSubmitting = false;

  final _fg = Colors.black;
  final _border = const Color(0xFFE5E5E5);
  final _radius = BorderRadius.circular(12);

  bool get _isPackage => widget.source.toUpperCase() == 'PACKAGE';

  @override
  void initState() {
    super.initState();

    amountOffController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent = true;
      _recalcDiscounted();

      if (_showErrors && !_sAmountOff) {
        setState(() => _sAmountOff = true);
      }
    });

    maxDiscountController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent = false;
      _recalcDiscounted();

      if (_showErrors && !_sMaxDiscount) {
        setState(() => _sMaxDiscount = true);
      }
    });

    if (widget.isEdit && widget.existingOffer != null) {
      _prefillEditData();
    } else {
      _recalcDiscounted();
    }
  }

  void _prefillEditData() {
    final o = widget.existingOffer!;

    dealTitleController.text = (o['name'] ?? '').toString();
    termsController.text = (o['terms'] ?? '').toString();

    String? fmtIn(dynamic v) {
      if (v == null) return null;

      try {
        return DateFormat('dd-MM-yyyy').format(DateTime.parse(v.toString()));
      } catch (_) {
        return null;
      }
    }

    final vf = fmtIn(o['validFrom']);
    final vt = fmtIn(o['validTo']);

    if (vf != null) validFromController.text = vf;
    if (vt != null) validTillController.text = vt;

    final existingDurationValue = o['durationValue'];
    if (existingDurationValue != null) {
      durationValueController.text = existingDurationValue.toString();
    }

    final existingDurationUnit = (o['durationUnit'] ?? '').toString().trim();
    if (existingDurationUnit.isNotEmpty &&
        durationUnits.contains(existingDurationUnit.toUpperCase())) {
      durationUnit = existingDurationUnit.toUpperCase();
    }

    final pmRaw = (o['pricingMode'] ?? '').toString().toUpperCase();
    pricingMode = pmRaw == 'DISCOUNT' ? 'Discount' : 'Fixed';

    final dtRaw = (o['discountType'] ?? '').toString().toUpperCase();

    if (pricingMode == 'Discount') {
      if (dtRaw == 'PERCENT') {
        discountType = 'Percent';

        final pct = (o['discountPct'] as num?)?.toDouble() ?? 0.0;
        if (pct > 0) {
          amountOffController.text = pct.toStringAsFixed(0);
        }

        final maxD = (o['maxDiscount'] as num?)?.toDouble();
        if (maxD != null && maxD > 0) {
          maxDiscountController.text = maxD.toStringAsFixed(2);
        }
      } else {
        discountType = 'Flat';

        final amt = (o['discount'] as num?)?.toDouble() ??
            (o['amount'] as num?)?.toDouble() ??
            0.0;

        if (amt > 0) {
          amountOffController.text = amt.toStringAsFixed(2);
        }
      }
    } else {
      final amt = (o['discount'] as num?)?.toDouble() ??
          (o['amount'] as num?)?.toDouble() ??
          0.0;

      amountOffController.text = (amt > 0 ? amt : 0.0).toStringAsFixed(2);
    }

    final List rawItems = (o['items'] as List?) ?? const [];
    final Map<int, int> selectedIdQty = {};
    _selectedServices = [];

    for (final item in rawItems) {
      if (item is! Map) continue;

      final map = Map<String, dynamic>.from(item);
      final int? id = _extractServiceId(map);

      if (id == null) continue;

      final int qty = _extractQty(map);
      selectedIdQty[id] = qty;

      _selectedServices.add({
        'id': id,
        'name': _extractServiceName(map),
        'price': _extractServicePrice(map),
        'qty': qty,
      });
    }

    final Map<String, dynamic> itemSummary = (o['itemSummary'] is Map)
        ? Map<String, dynamic>.from(o['itemSummary'])
        : const <String, dynamic>{};

    final double? originalTotal =
        _asDouble(itemSummary['totalPrice'] ?? itemSummary['total']);

    if (originalTotal != null && originalTotal > 0) {
      originalPriceController.text = originalTotal.toStringAsFixed(2);
    } else {
      originalPriceController.text = _originalTotal().toStringAsFixed(2);
    }

    final double? discountedTotal = _asDouble(
      o['price'] ??
          o['priceMinor'] ??
          itemSummary['totalDiscountedPrice'] ??
          itemSummary['totalAfterDiscount'],
    );

    if (discountedTotal != null && discountedTotal >= 0) {
      discountedPriceController.text = discountedTotal.toStringAsFixed(2);
    }

    final double originalVal =
        double.tryParse(originalPriceController.text) ?? 0.0;
    final double discountedVal =
        double.tryParse(discountedPriceController.text) ?? 0.0;

    if (pricingMode == 'Fixed') {
      if (originalVal > 0) {
        amountOffController.text = (originalVal - discountedVal)
            .clamp(0, originalVal)
            .toStringAsFixed(2);
      }
    } else if (pricingMode == 'Discount' && discountType == 'Flat') {
      final double? amt = _asDouble(
        o['discount'] ?? o['amount'] ?? itemSummary['totalDiscount'],
      );

      if (amt != null && amt > 0) {
        amountOffController.text = amt.toStringAsFixed(2);
      } else if (originalVal > 0) {
        amountOffController.text = (originalVal - discountedVal)
            .clamp(0, originalVal)
            .toStringAsFixed(2);
      }
    }

    final bool needsHydration = _selectedServices.isEmpty ||
        _selectedServices.any((svc) {
          final name = (svc['name'] ?? '').toString().trim();
          final price = (svc['price'] ?? 0) as int;
          return name.isEmpty || price <= 0;
        });

    if (needsHydration && selectedIdQty.isNotEmpty && widget.branchId > 0) {
      Future.microtask(
        () => _hydrateSelectedServices(Map<int, int>.from(selectedIdQty)),
      );
    }

    _recalcDiscounted();
  }

  @override
  void dispose() {
    dealTitleController.dispose();
    validFromController.dispose();
    validTillController.dispose();
    durationValueController.dispose();
    originalPriceController.dispose();
    discountedPriceController.dispose();
    amountOffController.dispose();
    maxDiscountController.dispose();
    termsController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  String? _toIsoDate(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    try {
      final d = DateFormat('dd-MM-yyyy').parseStrict(s);
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseUiDate(String s) {
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(s.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(
    TextEditingController c, {
    required bool isFrom,
  }) async {
    final now = DateTime.now();
    final DateTime? fromDate = _parseUiDate(validFromController.text);

    final firstDate = isFrom
        ? DateTime(now.year, now.month, now.day)
        : (fromDate != null && fromDate.isAfter(now)
            ? fromDate
            : DateTime(now.year, now.month, now.day));

    final picked = await showDatePicker(
      context: context,
      initialDate: now.isBefore(firstDate) ? firstDate : now,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        c.text = _formatDate(picked);

        if (isFrom) {
          _sValidFrom = true;
        } else {
          _sValidTill = true;
        }
      });

      if (_showErrors) {
        _formKey.currentState?.validate();
      }
    }
  }

  double _originalTotal() {
    double sum = 0;

    for (final s in _selectedServices) {
      final int price = (s['price'] ?? 0) as int;
      final int qty = (s['qty'] ?? 0) as int;
      sum += price * qty;
    }

    return sum;
  }

  double _parseNum(String s) => double.tryParse(s.trim()) ?? 0.0;

  double? _parseCurrency(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  void _setTextSafe(TextEditingController c, String v) {
    _settingFields = true;
    c.text = v;
    c.selection = TextSelection.fromPosition(
      TextPosition(offset: c.text.length),
    );
    _settingFields = false;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.round();
    }

    return 0;
  }

  int? _extractServiceId(Map<String, dynamic> item) {
    dynamic raw = item['branchServiceId'] ??
        item['serviceId'] ??
        item['salonServiceId'] ??
        item['id'];

    raw ??= (item['branchService'] is Map)
        ? (item['branchService'] as Map)['id']
        : null;

    raw ??= (item['service'] is Map)
        ? (item['service'] as Map)['id']
        : null;

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);

    return null;
  }

  int _extractQty(Map<String, dynamic> item) {
    final dynamic raw = item['qty'] ?? item['quantity'] ?? 1;

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 1;

    return 1;
  }

  String _extractServiceName(Map<String, dynamic> item) {
    for (final key in ['displayName', 'name', 'serviceName']) {
      final value = item[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    if (item['service'] is Map) {
      final service = item['service'] as Map;
      final value = service['displayName'] ?? service['name'];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    if (item['branchService'] is Map) {
      final branchService = item['branchService'] as Map;
      final value = branchService['displayName'] ?? branchService['name'];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  int _extractServicePrice(Map<String, dynamic> item) {
    for (final key in ['priceMinor', 'price', 'amount']) {
      final price = _toInt(item[key]);

      if (price > 0) return price;
    }

    if (item['service'] is Map) {
      final service = item['service'] as Map;

      for (final key in ['priceMinor', 'price']) {
        final price = _toInt(service[key]);

        if (price > 0) return price;
      }
    }

    if (item['branchService'] is Map) {
      final branchService = item['branchService'] as Map;

      for (final key in ['priceMinor', 'price']) {
        final price = _toInt(branchService[key]);

        if (price > 0) return price;
      }
    }

    return 0;
  }

  Future<void> _hydrateSelectedServices(Map<int, int> idQty) async {
    if (idQty.isEmpty) return;

    try {
      final resp = await ApiService().getService(branchId: widget.branchId);
      final List categories =
          (resp['data']?['categories'] as List?) ?? const [];

      final Map<int, Map<String, dynamic>> svcById = {};

      void collect(List? list) {
        if (list == null) return;

        for (final item in list) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final int id = _toInt(map['id']);

            if (id > 0) {
              svcById[id] = map;
            }
          }
        }
      }

      for (final cat in categories) {
        if (cat is Map) {
          collect(cat['services'] as List?);

          final subCats = cat['subCategories'] as List?;

          if (subCats != null) {
            for (final sub in subCats) {
              if (sub is Map) {
                collect(sub['services'] as List?);
              }
            }
          }
        }
      }

      if (svcById.isEmpty) return;

      setState(() {
        _selectedServices = idQty.entries.map((entry) {
          final service = svcById[entry.key];

          final name = service != null
              ? (service['displayName'] ?? service['name'] ?? '').toString()
              : '';

          final price = service != null
              ? _toInt(service['priceMinor'] ?? service['price'])
              : 0;

          return {
            'id': entry.key,
            'name': name,
            'price': price,
            'qty': entry.value,
          };
        }).toList();

        final total = _originalTotal();

        if (total > 0) {
          originalPriceController.text = total.toStringAsFixed(2);
        }

        _recalcDiscounted();
      });
    } catch (_) {
      // Keep existing data if hydration fails.
    }
  }

  void _recalcDiscounted() {
    final original = _parseNum(originalPriceController.text);

    if (original <= 0) {
      _setTextSafe(discountedPriceController, '');
      return;
    }

    double discounted = original;

    if (pricingMode == 'Fixed') {
      final off = _parseNum(amountOffController.text).clamp(0, original);
      discounted = original - off;
    } else {
      if (discountType == 'Flat') {
        final off = _parseNum(amountOffController.text).clamp(0, original);
        discounted = original - off;
      } else {
        final pct = _parseNum(amountOffController.text).clamp(0, 100);
        final pctValue = original * (pct / 100.0);

        if (_autoSetMaxFromPercent && maxDiscountController.text.isEmpty) {
          _setTextSafe(maxDiscountController, pctValue.toStringAsFixed(2));
        }

        final cap = _parseNum(maxDiscountController.text);
        final applied = cap > 0 ? math.min(pctValue, cap) : pctValue;
        discounted = (original - applied).clamp(0, original);
      }
    }

    _setTextSafe(discountedPriceController, discounted.toStringAsFixed(2));
  }

  String? _vTitle(String? v) {
    if (_sTitle) return null;

    final x = (v ?? '').trim();

    return x.isEmpty
        ? translateText(
            _isPackage
                ? 'Package title is required.'
                : 'Deal title is required.',
          )
        : null;
  }

  String? _vValidFrom(String? v) {
    if (_sValidFrom) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('Start Date is required.');

    if (_parseUiDate(x) == null) {
      return translateText('Enter a valid start date.');
    }

    return null;
  }

  String? _vValidTill(String? v) {
    if (_sValidTill) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('End Date is required.');

    final to = _parseUiDate(x);

    if (to == null) return translateText('Enter a valid end date.');

    final from = _parseUiDate(validFromController.text);

    if (from != null && to.isBefore(from)) {
      return translateText('End Date must be on or after Start Date.');
    }

    return null;
  }

  String? _vServices() {
    if (_sServices) return null;

    return _selectedServices.isEmpty
        ? translateText('Select at least one service')
        : null;
  }

  String? _vAmountOff(String? v) {
    if (_sAmountOff) return null;

    final x = (v ?? '').trim();

    if (pricingMode == 'Fixed') {
      final a = _parseCurrency(x);

      if (a == null || a <= 0) {
        return translateText('Enter a valid amount off.');
      }
    } else {
      if (discountType == 'Flat') {
        final a = _parseCurrency(x);

        if (a == null || a <= 0) {
          return translateText('Enter a valid discount amount.');
        }
      } else {
        final p = double.tryParse(x);

        if (p == null || p <= 0) {
          return translateText('Enter a valid percentage off.');
        }

        if (p > 100) {
          return translateText('Percentage off cannot exceed 100.');
        }
      }
    }

    return null;
  }

  String? _vMaxDiscount(String? v) {
    if (_sMaxDiscount) return null;

    if (pricingMode == 'Discount' && discountType == 'Percent') {
      final m = _parseCurrency(v ?? '');

      if (m == null || m <= 0) {
        return translateText('Enter the maximum discount amount.');
      }
    }

    return null;
  }

  String? _vDiscounted() {
    if (_sDiscounted) return null;

    final d = _parseCurrency(discountedPriceController.text);

    if (d == null || d <= 0) {
      return translateText('Discounted price must be greater than 0.');
    }

    return null;
  }

  String? _vPackageDuration() {
    if (!_isPackage) return null;

    final durationValue = int.tryParse(durationValueController.text.trim());

    if (durationValue == null || durationValue <= 0) {
      return translateText('Enter a valid duration.');
    }

    if (!durationUnits.contains(durationUnit)) {
      return translateText('Select a valid duration unit.');
    }

    return null;
  }

  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translateText('Please fix the following')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors
              .map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $m'),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translateText('OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _afterBuild() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  Future<bool> _validateFormAndShowAlert() async {
    setState(() {
      _showErrors = true;
      _sTitle = false;
      _sValidFrom = false;
      _sValidTill = false;
      _sServices = false;
      _sAmountOff = false;
      _sMaxDiscount = false;
      _sDiscounted = false;
    });

    await _afterBuild();
    _formKey.currentState?.validate();

    final errors = <String>[];

    void push(String? s) {
      if (s != null && s.trim().isNotEmpty) {
        errors.add(s);
      }
    }

    push(_vTitle(dealTitleController.text));
    push(_vServices());
    push(_vAmountOff(amountOffController.text));
    push(_vMaxDiscount(maxDiscountController.text));
    push(_vDiscounted());

    if (_isPackage) {
      push(_vPackageDuration());
    } else {
      push(_vValidFrom(validFromController.text));
      push(_vValidTill(validTillController.text));
    }

    if (errors.isNotEmpty) {
      await _showValidationDialog(errors);
      return false;
    }

    return true;
  }

  Future<void> _openReviewSummary() async {
    if (!await _validateFormAndShowAlert()) return;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferReviewSummaryScreen(
          isPackage: _isPackage,
          isEdit: widget.isEdit,
          title: dealTitleController.text.trim(),
          pricingMode: pricingMode,
          discountType: discountType,
          amountOff: amountOffController.text.trim(),
          maxDiscount: maxDiscountController.text.trim(),
          originalPrice: originalPriceController.text.trim(),
          discountedPrice: discountedPriceController.text.trim(),
          terms: termsController.text.trim(),
          durationValue: durationValueController.text.trim(),
          durationUnit: durationUnit,
          validFrom: validFromController.text.trim(),
          validTill: validTillController.text.trim(),
          selectedServices: _selectedServices,
          isSubmitting: _isSubmitting,
          onSubmit: _submitOffer,
        ),
      ),
    );
  }

  Future<void> _submitOffer() async {
    if (_isSubmitting) return;

    if (!await _validateFormAndShowAlert()) return;

    _recalcDiscounted();

    String capitalizeFirst(String value) {
      return value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value;
    }

    final body = <String, dynamic>{
      'name': capitalizeFirst(dealTitleController.text.trim()),
      'type': widget.source,
      'status': 'ACTIVE',
      if (!_isPackage) 'validFrom': _toIsoDate(validFromController.text),
      if (!_isPackage) 'validTo': _toIsoDate(validTillController.text),
      'pricingMode': pricingMode.toUpperCase(),
      'terms': termsController.text.trim().isEmpty
          ? null
          : termsController.text.trim(),
      'items': _selectedServices
          .map(
            (s) => {
              'branchServiceId': s['id'],
              'qty': s['qty'],
            },
          )
          .toList(),
      if (_isPackage)
        'durationValue': int.tryParse(durationValueController.text.trim()),
      if (_isPackage) 'durationUnit': durationUnit,
    };

    if (pricingMode == 'Fixed') {
      final fixedPrice = _parseCurrency(discountedPriceController.text) ?? 0;
      body[widget.isEdit ? 'priceOverride' : 'price'] = fixedPrice;
    } else {
      body['price'] = _parseCurrency(discountedPriceController.text) ?? 0;

      final isFlat = discountType == 'Flat';
      body['discountType'] = isFlat ? 'AMOUNT' : 'PERCENT';

      if (isFlat) {
        body['amountType'] = 'FLAT';
        body['amount'] = _parseCurrency(amountOffController.text) ?? 0;
        body['discount'] = body['amount'];
      } else {
        body['discountPct'] = int.tryParse(amountOffController.text.trim()) ?? 0;
        body['maxDiscount'] = _parseCurrency(maxDiscountController.text) ?? 0;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();

      if (widget.isEdit && widget.existingOffer?['id'] != null) {
        final offerId = (widget.existingOffer!['id'] as num).toInt();

        final patch = Map<String, dynamic>.from(body)
          ..removeWhere((k, v) => v == null);

        final res = await api.updateSalonBranchOfferPatch(
          widget.branchId,
          offerId,
          patch,
        );

        if (!mounted) return;

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateText('Offer updated successfully'))),
          );

          widget.onPackageCreated(widget.branchId);
          Navigator.pop(context, true);
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ?? 'Failed to update offer',
              ),
            ),
          );
        }

        return;
      }

      final res = await api.createSalonBranchOffer(widget.branchId, body);

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateText('Offer created successfully'))),
        );

        widget.onPackageCreated(widget.branchId);
        Navigator.pop(context, true);
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'Failed to create offer',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _decor({
    required String label,
    String? hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      counterText: '',
      labelText: label,
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix, color: _fg),
      suffixIcon: suffix,
      filled: false,
      helperText: ' ',
      helperStyle: const TextStyle(height: 1),
      errorStyle: const TextStyle(height: 1.1),
     contentPadding: const EdgeInsets.fromLTRB(14, 14, 70, 28),
      border: OutlineInputBorder(borderRadius: _radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.black, width: 1.6),
      ),
      errorMaxLines: 2,
    );
  }
Widget _fieldWithBottomCounter({
  required TextEditingController controller,
  required int maxLength,
  required Widget child,
}) {
  return Stack(
    children: [
      child,
      Positioned(
        right: 12,
        bottom: 22,
        child: IgnorePointer(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Text(
                '${value.text.length}/$maxLength',
                style: TextStyle(
                  fontSize: 11,
                  color: value.text.length >= maxLength
                      ? Colors.red
                      : Colors.grey,
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _err(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  // Widget _buildTitleAndPricingRow() {
  //   return Row(
  //     children: [
  //       Expanded(
  //         child: _fieldWithBottomCounter(
  //           controller: dealTitleController,
  //           maxLength: 50,
  //           child: TextFormField(
  //             controller: dealTitleController,
  //             maxLength: 50,
  //             keyboardType: TextInputType.text,
  //             textCapitalization: TextCapitalization.sentences,
  //             inputFormatters: [
  //               _SentenceCaseTextFormatter(),
  //               LengthLimitingTextInputFormatter(50),
  //             ],
  //             autovalidateMode: _showErrors
  //                 ? AutovalidateMode.always
  //                 : AutovalidateMode.disabled,
  //             decoration: _decor(
  //               label: _isPackage
  //                   ? '${translateText('Package Title')} *'
  //                   : '${translateText('Deal Title')} *',
  //               hint: translateText('Eg: Men: Grooming Package'),
  //             ),
  //             validator: _vTitle,
  //             onChanged: (_) {
  //               if (!_sTitle) {
  //                 setState(() => _sTitle = true);
  //               } else {
  //                 setState(() {});
  //               }
  //             },
  //           ),
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: DropdownButtonFormField<String>(
  //           value: pricingMode,
  //           autovalidateMode: _showErrors
  //               ? AutovalidateMode.onUserInteraction
  //               : AutovalidateMode.disabled,
  //           items: pricingModes
  //               .map(
  //                 (e) => DropdownMenuItem(
  //                   value: e,
  //                   child: Text(translateText(e)),
  //                 ),
  //               )
  //               .toList(),
  //           onChanged: (v) {
  //             setState(() {
  //               pricingMode = v ?? 'Fixed';
  //               _autoSetMaxFromPercent = true;
  //               amountOffController.clear();
  //               maxDiscountController.clear();
  //               discountedPriceController.clear();

  //               if (pricingMode == 'Fixed') {
  //                 discountType = 'Flat';
  //               }
  //             });

  //             _recalcDiscounted();
  //           },
  //           decoration: _decor(
  //             label: '${translateText('Pricing Option')} *',
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

Widget _buildTitleAndPricingRow() {
  return Column(
    children: [
      _fieldWithBottomCounter(
        controller: dealTitleController,
        maxLength: 50,
        child: TextFormField(
          controller: dealTitleController,
          maxLength: 50,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            _SentenceCaseTextFormatter(),
            LengthLimitingTextInputFormatter(50),
          ],
          autovalidateMode: _showErrors
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          decoration: _decor(
            label: _isPackage
                ? '${translateText('Package Title')} *'
                : '${translateText('Deal Title')} *',
            hint: translateText('Eg: Men: Grooming Package'),
          ),
          validator: _vTitle,
          onChanged: (_) {
            if (!_sTitle) {
              setState(() => _sTitle = true);
            } else {
              setState(() {});
            }
          },
        ),
      ),

      const SizedBox(height: 14),

      DropdownButtonFormField<String>(
        value: pricingMode,
        autovalidateMode: _showErrors
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        items: pricingModes
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(translateText(e)),
              ),
            )
            .toList(),
        onChanged: (v) {
          setState(() {
            pricingMode = v ?? 'Fixed';
            _autoSetMaxFromPercent = true;
            amountOffController.clear();
            maxDiscountController.clear();
            discountedPriceController.clear();

            if (pricingMode == 'Fixed') {
              discountType = 'Flat';
            }
          });

          _recalcDiscounted();
        },
        decoration: _decor(
          label: '${translateText('Pricing Option')} *',
        ),
      ),
    ],
  );
}
  Widget _buildSelectServicesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final initQty = <int, int>{
              for (final s in _selectedServices)
                (s['id'] as int): (s['qty'] as int),
            };

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelectServicesModal(
                  branchId: widget.branchId,
                  initialSelectedQty: initQty,
                ),
              ),
            );

            if (result == null) return;

            if (result is List) {
              setState(() {
                _selectedServices = result.cast<Map<String, dynamic>>();
                originalPriceController.text =
                    _originalTotal().toStringAsFixed(2);
                _sServices = true;
                _sDiscounted = true;
              });

              _recalcDiscounted();
            }
          },
          borderRadius: _radius,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: _radius,
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    translateText('Select services'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showErrors)
          FormField<List<Map<String, dynamic>>>(
            autovalidateMode: AutovalidateMode.always,
            validator: (_) => _vServices(),
            builder: (state) => state.hasError
                ? _err(state.errorText!)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildSelectedServicesList() {
    if (_selectedServices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          translateText('Selected Services'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        ..._selectedServices.map((s) {
          final name = (s['name'] ?? '').toString();
          final price = (s['price'] ?? 0) as int;
          final qty = (s['qty'] ?? 0) as int;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _radius,
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'Qty: $qty  ₹$price',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDiscountTypeField() {
    if (pricingMode != 'Discount') return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      value: discountType,
      autovalidateMode: _showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      items: discountTypes
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                translateText(e == 'Flat' ? 'Flat Amount' : 'Percentage'),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          discountType = v ?? 'Flat';
          _autoSetMaxFromPercent = true;
          amountOffController.clear();
          maxDiscountController.clear();
          discountedPriceController.clear();
        });

        _recalcDiscounted();
      },
      decoration: _decor(
        label: translateText('Discount Type *'),
      ),
    );
  }

  Widget _buildDiscountInputFields() {
    final showFlatField = pricingMode == 'Fixed' ||
        (pricingMode == 'Discount' && discountType == 'Flat');

    final showPercentField =
        pricingMode == 'Discount' && discountType == 'Percent';

    if (showFlatField) {
      return _fieldWithBottomCounter(
        controller: amountOffController,
        maxLength: 120,
        child: TextFormField(
          maxLength: 120,
          controller: amountOffController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(120),
          ],
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decor(
            label: translateText('Amount Off (₹) *'),
            hint: translateText('e.g. 100'),
          ),
          validator: _vAmountOff,
          onChanged: (_) {
            if (!_sAmountOff) {
              setState(() => _sAmountOff = true);
            } else {
              setState(() {});
            }
          },
        ),
      );
    }

    if (showPercentField) {
      return Row(
        children: [
          Expanded(
            child: _fieldWithBottomCounter(
              controller: amountOffController,
              maxLength: 120,
              child: TextFormField(
                maxLength: 120,
                controller: amountOffController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(120),
                ],
                autovalidateMode: _showErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                decoration: _decor(
                  label: translateText('Percentage Off (%) *'),
                  hint: translateText('e.g. 50'),
                ),
                validator: _vAmountOff,
                onChanged: (_) {
                  if (!_sAmountOff) {
                    setState(() => _sAmountOff = true);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _fieldWithBottomCounter(
              controller: maxDiscountController,
              maxLength: 120,
              child: TextFormField(
                maxLength: 120,
                controller: maxDiscountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(120),
                ],
                autovalidateMode: _showErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                decoration: _decor(
                  label: translateText('Max Discount Amount (₹) *'),
                  hint: translateText('e.g. 100'),
                ),
                validator: _vMaxDiscount,
                onChanged: (_) {
                  if (!_sMaxDiscount) {
                    setState(() => _sMaxDiscount = true);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPriceRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: originalPriceController,
            readOnly: true,
            decoration: _decor(
              label: translateText('Original Price *'),
              hint: translateText('0'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: discountedPriceController,
            readOnly: true,
            autovalidateMode: _showErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            decoration: _decor(
              label: translateText('Discounted Price *'),
              hint: translateText('0'),
            ),
            validator: (_) => _vDiscounted(),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsField() {
    return _fieldWithBottomCounter(
      controller: termsController,
      maxLength: 50,
      child: TextFormField(
        controller: termsController,
        maxLength: 50,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          _SentenceCaseTextFormatter(),
          NoSpecialCharsFormatter(),
          LengthLimitingTextInputFormatter(50),
        ],
        decoration: _decor(
          label: '${translateText('Terms')} (${translateText('optional')})',
          hint: translateText('Any terms & conditions...'),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPackageDurationFields() {
    return Row(
      children: [
        Expanded(
          child: _fieldWithBottomCounter(
            controller: durationValueController,
            maxLength: 4,
            child: TextFormField(
              controller: durationValueController,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _decor(
                label: '${translateText('Duration')} *',
                hint: translateText('e.g. 3'),
              ),
              validator: (_) => _vPackageDuration(),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: durationUnit,
            items: durationUnits
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(
                      translateText(
                        unit[0] + unit.substring(1).toLowerCase(),
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                durationUnit = value ?? 'MONTH';
              });
            },
            decoration: _decor(
              label: '${translateText('Unit')} *',
              hint: translateText('Select unit'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidityDateRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText('Validity Date Range'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: validFromController,
                readOnly: true,
                autovalidateMode: _showErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                decoration: _decor(
                  label: '${translateText('Start Date')} *',
                  hint: translateText('Select start date'),
                  suffix: IconButton(
                    icon: const Icon(Icons.date_range, color: Colors.black),
                    onPressed: () =>
                        _pickDate(validFromController, isFrom: true),
                  ),
                ),
                validator: _vValidFrom,
                onTap: () => _pickDate(validFromController, isFrom: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: validTillController,
                readOnly: true,
                autovalidateMode: _showErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                decoration: _decor(
                  label: '${translateText('End Date')} *',
                  hint: translateText('Select end date'),
                  suffix: IconButton(
                    icon: const Icon(Icons.date_range, color: Colors.black),
                    onPressed: () =>
                        _pickDate(validTillController, isFrom: false),
                  ),
                ),
                validator: _vValidTill,
                onTap: () => _pickDate(validTillController, isFrom: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.isEdit
        ? (_isPackage ? 'Update Package' : 'Update Deal')
        : (_isPackage ? 'Create Package' : 'Create Deal');

    final buttonLabel = translateText('Review Summary');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText(titleKey),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  translateText(
                    _isPackage ? 'Package Information' : 'Deal Information',
                  ),
                ),
                _buildTitleAndPricingRow(),
                const SizedBox(height: 14),
                Text(
                  '${translateText('Select Services')} *',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSelectServicesField(),
                _buildSelectedServicesList(),
                const SizedBox(height: 14),
                if (pricingMode == 'Discount') ...[
                  _buildDiscountTypeField(),
                  const SizedBox(height: 14),
                ],
                _buildDiscountInputFields(),
                const SizedBox(height: 14),
                _buildPriceRow(),
                const SizedBox(height: 14),
                _buildTermsField(),
                const SizedBox(height: 14),
                if (_isPackage) _buildPackageDurationFields(),
                if (!_isPackage) _buildValidityDateRange(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _openReviewSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: _radius,
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            buttonLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
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

class NoSpecialCharsFormatter extends TextInputFormatter {
  final RegExp _allowed = RegExp(r"[a-zA-Z0-9\s,.\-']");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered =
        newValue.text.split('').where((ch) => _allowed.hasMatch(ch)).join();

    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}