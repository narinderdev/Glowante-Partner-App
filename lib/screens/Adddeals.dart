import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // <-- for TextInputFormatter
import 'SelectServices.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';


class AddDealsScreen extends StatefulWidget {
  final int salonId;
  final String salonName;
  final Function(int salonId) onPackageCreated;
  final String source; // "DEAL" or "PACKAGE"
  final bool isEdit;
  final Map<String, dynamic>? existingOffer;

  const AddDealsScreen({
    Key? key,
    required this.salonId,
    required this.salonName,
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
    // Uppercase only the very first character; leave the rest unchanged
    final formatted = t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection,
      composing: newValue.composing, // keep IME composing intact
    );
  }
}


class _AddDealsScreenState extends State<AddDealsScreen> {
  // ----------------- FORM -----------------
  final _formKey = GlobalKey<FormState>();
  bool _showErrors = false; // turn on inline after first submit

  // Hide inline errors while user is typing/interacting
  bool _sTitle = false;
  bool _sValidFrom = false;
  bool _sValidTill = false;
  bool _sServices = false;
  bool _sAmountOff = false;
  bool _sMaxDiscount = false;
  bool _sDiscounted = false;

  // ----------------- CONTROLLERS -----------------
  final dealTitleController = TextEditingController();
  final validFromController = TextEditingController();
  final validTillController = TextEditingController();
  final originalPriceController = TextEditingController();
  final discountedPriceController = TextEditingController();
  final amountOffController = TextEditingController();   // flat or percent
  final maxDiscountController = TextEditingController(); // percent only
  final termsController = TextEditingController();       // optional

  // ----------------- UI STATE -----------------
  String pricingMode = 'Fixed'; // Fixed | Discount
  String discountType = 'Flat'; // Flat | Percent
  final pricingModes = const ['Fixed', 'Discount'];
  final discountTypes = const ['Flat', 'Percent'];

  List<Map<String, dynamic>> _selectedServices = [];

  bool _settingFields = false;
  bool _autoSetMaxFromPercent = true;

  // submit loader
  bool _isSubmitting = false;

  // ----------------- THEME -----------------
  final _bg = Colors.white;
  final _fg = Colors.black;
  final _border = const Color(0xFFE5E5E5);
  final _radius = BorderRadius.circular(12);

  @override
  void initState() {
    super.initState();
_showErrors = false;
    // live recompute
    amountOffController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent = true;
      _recalcDiscounted();
      if (_showErrors && !_sAmountOff) setState(() => _sAmountOff = true);
    });
    maxDiscountController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent = false;
      _recalcDiscounted();
      if (_showErrors && !_sMaxDiscount) setState(() => _sMaxDiscount = true);
    });

// if (widget.isEdit && widget.existingOffer != null) {
//   final o = widget.existingOffer!;

//   // UPPERCASE on prefill
//   dealTitleController.text = (o['name'] ?? '').toString();
//   termsController.text = (o['terms'] ?? '').toString();

//   // Format valid dates
//   String? fmtIn(dynamic v) {
//     if (v == null) return null;
//     try {
//       return DateFormat('dd-MM-yyyy').format(DateTime.parse(v.toString()));
//     } catch (_) {
//       return null;
//     }
//   }

//   final vf = fmtIn(o['validFrom']);
//   final vt = fmtIn(o['validTo']);
//   if (vf != null) validFromController.text = vf;
//   if (vt != null) validTillController.text = vt;

//   // Set Pricing Mode
//   final pmRaw = (o['pricingMode'] ?? '').toString().toUpperCase();
//   pricingMode = pmRaw == 'DISCOUNT' ? 'Discount' : 'Fixed';

//   // Set Discount Type and Amount Off
//   final dtRaw = (o['discountType'] ?? '').toString().toUpperCase(); // AMOUNT | PERCENT | NONE
//   if (pricingMode == 'Discount') {
//     if (dtRaw == 'PERCENT') {
//       discountType = 'Percent';
//       final pct = (o['discountPct'] as num?)?.toDouble() ?? 0.0;
//       if (pct > 0) amountOffController.text = pct.toStringAsFixed(0);
//       final maxD = (o['maxDiscount'] as num?)?.toDouble();
//       if (maxD != null && maxD > 0) {
//         maxDiscountController.text = maxD.toStringAsFixed(2);
//       }
//     } else {
//       discountType = 'Flat';
//       final amt = (o['discount'] as num?)?.toDouble()
//           ?? (o['amount'] as num?)?.toDouble()
//           ?? 0.0;
//       if (amt > 0) amountOffController.text = amt.toStringAsFixed(2);
//     }
//   } else {
//     // FIXED Pricing - set the flat amount off from discount or amount field
//     final amt = (o['discount'] as num?)?.toDouble()
//         ?? (o['amount'] as num?)?.toDouble()
//         ?? 0.0;

//     // If discount is null, check 'amount' and assign 0 if null
//     if (amt != null && amt > 0) {
//       amountOffController.text = amt.toStringAsFixed(2);  // Fill for Fixed
//     } else if (amt == null || amt == 0.0) {
//       // Ensure the value doesn't remain empty
//       amountOffController.text = '0.00';  // Default to 0 if no amount/discount is provided
//     }
//   }

//   // items -> selected
//   final items = (o['items'] as List?) ?? const [];
//   _selectedServices = items.map<Map<String, dynamic>>((e) {
//     final m = Map<String, dynamic>.from(e as Map);
//     final id = (m['salonServiceId'] ?? m['id']) as int?;
//     final qty = (m['qty'] ?? 1) as int;
//     final name = m['name'] ?? m['displayName'] ?? 'Service';
//     final price = m['price'] ?? m['priceMinor'] ?? 0;
//     return {
//       'id': id ?? 0,
//       'name': name,
//       'price': (price is num) ? price.toInt() : int.tryParse(price.toString()) ?? 0,
//       'qty': qty,
//     };
//   }).toList();

//   originalPriceController.text = _originalTotal().toStringAsFixed(2);

//   final price = (o['price'] as num?)?.toDouble();
//   if (price != null) discountedPriceController.text = price.toStringAsFixed(2);

//   _recalcDiscounted();
//   setState(() {});
// }
//   }

if (widget.isEdit && widget.existingOffer != null) {
  final o = widget.existingOffer!;

  // Prefill title & terms
  dealTitleController.text = (o['name'] ?? '').toString();
  termsController.text = (o['terms'] ?? '').toString();

  // Format valid dates
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

  // Pricing mode
  final pmRaw = (o['pricingMode'] ?? '').toString().toUpperCase();
  pricingMode = pmRaw == 'DISCOUNT' ? 'Discount' : 'Fixed';

  // Discount type
  final dtRaw = (o['discountType'] ?? '').toString().toUpperCase(); // AMOUNT | PERCENT | NONE
  if (pricingMode == 'Discount') {
    if (dtRaw == 'PERCENT') {
      discountType = 'Percent';
      final pct = (o['discountPct'] as num?)?.toDouble() ?? 0.0;
      if (pct > 0) amountOffController.text = pct.toStringAsFixed(0);

      final maxD = (o['maxDiscount'] as num?)?.toDouble();
      if (maxD != null && maxD > 0) {
        maxDiscountController.text = maxD.toStringAsFixed(2);
      }
    } else {
      discountType = 'Flat';
      final amt = (o['discount'] as num?)?.toDouble()
          ?? (o['amount'] as num?)?.toDouble()
          ?? 0.0;
      if (amt > 0) amountOffController.text = amt.toStringAsFixed(2);
    }
  } else {
    // Fixed pricing
    final amt = (o['discount'] as num?)?.toDouble()
        ?? (o['amount'] as num?)?.toDouble()
        ?? 0.0;
    amountOffController.text =
        (amt > 0 ? amt : 0.0).toStringAsFixed(2);
  }

  // Items → selected
  final items = (o['items'] as List?) ?? const [];
  // _selectedServices = items.map<Map<String, dynamic>>((e) {
  //   final m = Map<String, dynamic>.from(e as Map);
  //   final id = (m['salonServiceId'] ?? m['id']) as int?;
  //   final qty = (m['qty'] ?? 1) as int;
  //   final name = m['name'] ?? m['displayName'] ?? 'Service';
  //   final price = m['price'] ?? m['priceMinor'] ?? 0;
  //   return {
  //     'id': id ?? 0,
  //     'name': name,
  //     'price': (price is num) ? price.toInt() : int.tryParse(price.toString()) ?? 0,
  //     'qty': qty,
  //   };
  // }).toList();
_selectedServices = items.map<Map<String, dynamic>>((e) {
  final m = Map<String, dynamic>.from(e as Map);

  // ✅ Correct priority order
  final id = (m['serviceId'] ?? m['salonServiceId'] ?? m['id']) as int?;

  final qty = (m['qty'] ?? 1) as int;
  final name = m['name'] ?? m['displayName'] ?? 'Service';
  final price = m['price'] ?? m['priceMinor'] ?? 0;

  return {
    'id': id ?? -1, // invalid IDs become -1, not 0
    'name': name,
    'price': (price is num)
        ? price.toInt()
        : int.tryParse(price.toString()) ?? 0,
    'qty': qty,
  };
}).where((s) => s['id'] != -1).toList();

  // Prices
  originalPriceController.text = _originalTotal().toStringAsFixed(2);

  final price = (o['price'] as num?)?.toDouble();
  if (price != null) discountedPriceController.text = price.toStringAsFixed(2);

  // 👉 Auto-compute amountOff only for Flat or Fixed
  final orig = double.tryParse(originalPriceController.text) ?? 0.0;
  final disc = double.tryParse(discountedPriceController.text) ?? 0.0;

  if (pricingMode == 'Fixed' || (pricingMode == 'Discount' && discountType == 'Flat')) {
    if (orig > 0 && disc >= 0) {
      amountOffController.text = (orig - disc).toStringAsFixed(2);
    }
  }
  // ❌ For Percent → keep % value from API, don’t overwrite

  setState(() {});
} else {
  // Fresh create → always recalc
  _recalcDiscounted();
}
  }
  @override
  void dispose() {
    dealTitleController.dispose();
    validFromController.dispose();
    validTillController.dispose();
    originalPriceController.dispose();
    discountedPriceController.dispose();
    amountOffController.dispose();
    maxDiscountController.dispose();
    termsController.dispose();
    super.dispose();
  }

  // ----------------- HELPERS -----------------
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

  Future<void> _pickDate(TextEditingController c, {required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
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

  // ✅ Only revalidate if errors are currently visible
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
    c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
    _settingFields = false;
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

  // ----------------- VALIDATORS (shared) -----------------
  String? _vTitle(String? v) {
    if (_sTitle) return null;
    final x = (v ?? '').trim();
    return x.isEmpty ? translateText('Deal title is required.') : null;
  }

  DateTime? _parseUiDate(String s) {
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(s.trim());
    } catch (_) {
      return null;
    }
  }

  String? _vValidFrom(String? v) {
    if (_sValidFrom) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('Valid From is required.');
    if (_parseUiDate(x) == null) return translateText('Enter a valid start date.');
    return null;
  }

  String? _vValidTill(String? v) {
    if (_sValidTill) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('Valid Till is required.');
    final to = _parseUiDate(x);
    if (to == null) return translateText('Enter a valid end date.');
    final from = _parseUiDate(validFromController.text);
    if (from != null && to.isBefore(from)) {
      return translateText('Valid Till must be on or after Valid From.');
    }
    return null;
  }

  String? _vServices() {
    if (_sServices) return null;
    return _selectedServices.isEmpty ? translateText('Select at least one service') : null;
  }

  String? _vAmountOff(String? v) {
    if (_sAmountOff) return null;
    final x = (v ?? '').trim();
    if (pricingMode == 'Fixed') {
      final a = _parseCurrency(x);
      if (a == null || a <= 0) return translateText('Enter a valid amount off.');
    } else {
      if (discountType == 'Flat') {
        final a = _parseCurrency(x);
        if (a == null || a <= 0) return translateText('Enter a valid discount amount.');
      } else {
        final p = double.tryParse(x);
        if (p == null || p <= 0) return translateText('Enter a valid percentage off.');
        if (p > 100) return translateText('Percentage off cannot exceed 100.');
      }
    }
    return null;
  }

  String? _vMaxDiscount(String? v) {
    if (_sMaxDiscount) return null;
    if (pricingMode == 'Discount' && discountType == 'Percent') {
      final m = _parseCurrency(v ?? '');
      if (m == null || m <= 0) return translateText('Enter the maximum discount amount.');
    }
    return null;
  }

  String? _vDiscounted() {
    if (_sDiscounted) return null;
    final d = _parseCurrency(discountedPriceController.text);
    if (d == null || d <= 0) return translateText('Discounted price must be greater than 0.');
    return null;
  }

  // ----------------- ALERT -----------------
  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translateText('Please fix the following')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors
              .map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $m'),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(translateText('OK'))),
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
    // make inline visible and stop suppressing
    setState(() {
      _showErrors = true;
      _sTitle = _sValidFrom = _sValidTill = _sServices =
          _sAmountOff = _sMaxDiscount = _sDiscounted = false;
    });

    await _afterBuild();
    _formKey.currentState?.validate();

    final errors = <String>[];
    void push(String? s) {
      if (s != null && s.trim().isNotEmpty) errors.add(s);
    }

    push(_vTitle(dealTitleController.text));
    push(_vValidFrom(validFromController.text));
    push(_vValidTill(validTillController.text));
    push(_vServices());
    push(_vAmountOff(amountOffController.text));
    push(_vMaxDiscount(maxDiscountController.text));
    push(_vDiscounted());

    if (errors.isNotEmpty) {
      await _showValidationDialog(errors);
      return false;
    }
    return true;
  }

  // ----------------- SUBMIT -----------------
  Future<void> _submitOffer() async {
    if (_isSubmitting) return; // guard
    if (!await _validateFormAndShowAlert()) return;

    _recalcDiscounted();
  String capitalizeFirst(String value) =>
      value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value;

    final body = <String, dynamic>{
        'name': capitalizeFirst(dealTitleController.text.trim()),
      'type': widget.source, // "DEAL" | "PACKAGE"
      'status': 'ACTIVE',
      'validFrom': _toIsoDate(validFromController.text),
      'validTo': _toIsoDate(validTillController.text),
      'pricingMode': pricingMode.toUpperCase(), // FIXED | DISCOUNT
      'price': _parseCurrency(discountedPriceController.text) ?? 0,
      'terms': termsController.text.trim().isEmpty
          ? null
          : termsController.text.trim(),
      'items': _selectedServices
          .map((s) => {'serviceId': s['id'], 'qty': s['qty']})
          .toList(),
    };

    if (pricingMode == 'Fixed') {
      body['amountType'] = 'FLAT';
      body['amount'] = _parseCurrency(amountOffController.text) ?? 0;
      body['discount'] = body['amount'];
    } else {
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

      if (widget.isEdit && (widget.existingOffer?['id'] != null)) {
        final offerId = (widget.existingOffer!['id'] as num).toInt();
        final patch = Map<String, dynamic>.from(body)..removeWhere((k, v) => v == null);
        final res = await api.updateSalonOfferPatch(widget.salonId, offerId, patch);

        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateText('Offer updated successfully'))),
          );
          widget.onPackageCreated(widget.salonId);
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message']?.toString() ?? 'Failed to update offer')),
          );
        }
        return;
      }

      final res = await api.createSalonOffer(widget.salonId, body);

      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateText('Offer created successfully'))),
        );
        widget.onPackageCreated(widget.salonId);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to create offer')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ----------------- UI -----------------
  InputDecoration _decor({
    required String label,
    String? hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix, color: _fg),
      suffixIcon: suffix,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      );

  Widget _err(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    final showDiscountRow = pricingMode == 'Discount';
    final showFlatField =
        (pricingMode == 'Fixed') ||
        (pricingMode == 'Discount' && discountType == 'Flat');
    final showPercentField =
        pricingMode == 'Discount' && discountType == 'Percent';

    final buttonLabel = widget.isEdit ? 'Update Package' : 'Submit';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Let the gradient show through:
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Ensure status bar + icons look good on the gradient:
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: Colors.white, // back button color
        ),
        title: Text(translateText('Create Offers'),
          style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,),
        ),
        // Paint the gradient here:
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.starColor,        // your start color
                AppColors.getStartedButton, // your end color
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(translateText('Deal Information')),

                TextFormField(
                  controller: dealTitleController,
                  textCapitalization: TextCapitalization.none, // caps keyboard
                  inputFormatters:  [_SentenceCaseTextFormatter()], // force UPPER
                  autovalidateMode: _showErrors
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  decoration: _decor(
                    label: translateText('Package Title').trim() + ' *',
                    hint: translateText("E.G. MEN'S GROOMING PACKAGE"),
                  ),
                  validator: _vTitle,
                  onChanged: (_) {
                    if (!_sTitle) setState(() => _sTitle = true);
                  },
                ),

                SizedBox(height: 14),

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
                          label: '${translateText('Valid From')} *',
                          hint: 'dd-MM-yyyy',
                          prefix: Icons.calendar_today_outlined,
                          suffix: IconButton(
                            icon: Icon(Icons.date_range, color: Colors.black),
                            onPressed: () => _pickDate(validFromController, isFrom: true),
                          ),
                        ),
                        validator: _vValidFrom,
                        onTap: () => _pickDate(validFromController, isFrom: true),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: validTillController,
                        readOnly: true,
                        autovalidateMode: _showErrors
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        decoration: _decor(
                          label: '${translateText('Valid Till')} *',
                          hint: 'dd-MM-yyyy',
                          prefix: Icons.calendar_today_outlined,
                          suffix: IconButton(
                            icon: Icon(Icons.date_range, color: Colors.black),
                            onPressed: () => _pickDate(validTillController, isFrom: false),
                          ),
                        ),
                        validator: _vValidTill,
                        onTap: () => _pickDate(validTillController, isFrom: false),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18),

                _section(translateText('Pricing Option')),

                if (!showDiscountRow) ...[
                  DropdownButtonFormField<String>(
                    value: pricingMode,
                    autovalidateMode: _showErrors
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    items: pricingModes
                        .map((e) => DropdownMenuItem(value: e, child: Text(translateText(e))))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        pricingMode = v ?? 'Fixed';
                        _autoSetMaxFromPercent = true;
                      });
                      _recalcDiscounted();
                    },
                   decoration: _decor(label: '${translateText('Pricing Option')} *', prefix: Icons.local_offer_outlined),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: pricingMode,
                          autovalidateMode: _showErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          items: pricingModes
                              .map((e) => DropdownMenuItem(value: e, child: Text(translateText(e))))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              pricingMode = v ?? 'Discount';
                              _autoSetMaxFromPercent = true;
                            });
                            _recalcDiscounted();
                          },
                          decoration: _decor(label: '${translateText('Discount Type')} *', prefix: Icons.sell_outlined),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: discountType,
                          autovalidateMode: _showErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          items: discountTypes
                              .map((e) => DropdownMenuItem(value: e, child: Text(translateText(e))))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              discountType = v ?? 'Flat';
                              _autoSetMaxFromPercent = true;
                            });
                            _recalcDiscounted();
                          },
                          decoration: _decor(label: 'Discount Type *', prefix: Icons.sell_outlined),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 18),

               _section(translateText('Select Services')),

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
                          salonId: widget.salonId,
                          initialSelectedQty: initQty,
                        ),
                      ),
                    );
                    if (result == null) return;

                    if (result is List) {
                      setState(() {
                        _selectedServices = result.cast<Map<String, dynamic>>();
                        originalPriceController.text = _originalTotal().toStringAsFixed(2);
                        _sServices = true;
                        _sDiscounted = true;
                      });
                      _recalcDiscounted();
                      // _formKey.currentState?.validate();
                    }
                  },
                  borderRadius: _radius,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: _radius,
                      border: Border.all(color: _border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.black),
                        SizedBox(width: 8),
                        Text(translateText('Select services'),
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
                if (_showErrors)
                  FormField<List<Map<String, dynamic>>>(
                    autovalidateMode: AutovalidateMode.always,
                    validator: (_) => _vServices(),
                    builder: (state) =>
                        state.hasError ? _err(state.errorText!) : SizedBox.shrink(),
                  ),

                if (_selectedServices.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(translateText('Selected Services'),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 6),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                              Text('₹$price',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Qty: $qty × ₹$price',
                              style: const TextStyle(color: Colors.black54, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],

                SizedBox(height: 18),

                // Discount Inputs
                if (showFlatField) ...[
  TextFormField(
    controller: amountOffController,
    keyboardType: TextInputType.number,
    autovalidateMode: _showErrors
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    decoration: _decor(
      label: translateText('Amount Off (₹) *'),
      hint: translateText('e.g. 200'),
      prefix: Icons.currency_rupee,
    ),
    validator: _vAmountOff,
    onChanged: (_) {
      if (!_sAmountOff) setState(() => _sAmountOff = true);
    },
  ),
  SizedBox(height: 14),
],

if (showPercentField) ...[
  Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: amountOffController,
          keyboardType: TextInputType.number,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decor(
            label: translateText('Percentage Off (%) *'),
            hint: translateText('e.g. 20'),
            prefix: Icons.percent,
          ),
          validator: _vAmountOff,
          onChanged: (_) {
            if (!_sAmountOff) setState(() => _sAmountOff = true);
          },
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: TextFormField(
          controller: maxDiscountController,
          keyboardType: TextInputType.number,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decor(
            label: translateText('Max Discount (₹) *'),
            hint: translateText('auto from %'),
            prefix: Icons.currency_rupee,
          ),
          validator: _vMaxDiscount,
          onChanged: (_) {
            if (!_sMaxDiscount) setState(() => _sMaxDiscount = true);
          },
        ),
      ),
    ],
  ),
  SizedBox(height: 14),
],

Row(
  children: [
    Expanded(
      child: TextFormField(
        controller: originalPriceController,
        readOnly: true,
        decoration: _decor(
          label: translateText('Original Price *'),
          hint: translateText('auto from services'),
          prefix: Icons.currency_rupee,
        ),
      ),
    ),
    SizedBox(width: 12),
    Expanded(
      child: TextFormField(
        controller: discountedPriceController,
        readOnly: true,
        autovalidateMode: _showErrors
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        decoration: _decor(
          label: translateText('Discounted Price *'),
          hint: translateText('auto calculated'),
          prefix: Icons.currency_rupee,
        ),
        validator: (_) => _vDiscounted(),
      ),
    ),
  ],
),

SizedBox(height: 14),

TextFormField(
  controller: termsController,
  textCapitalization: TextCapitalization.none,
  inputFormatters: [
    _SentenceCaseTextFormatter(),
    NoSpecialCharsFormatter(), // 🔥 prevents special characters
  ],
  decoration: _decor(
    label: translateText('Terms (optional)'),
    hint: translateText('ANY TERMS & CONDITIONS…'),
    prefix: Icons.article_outlined,
  ),
),


                SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: _radius),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            buttonLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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
/// Blocks special characters in "Terms" field
class NoSpecialCharsFormatter extends TextInputFormatter {
  // Allow letters, digits, spaces, commas, periods, and basic punctuation
  final RegExp _allowed = RegExp(r"[a-zA-Z0-9\s,.\-']");


  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.split('').where((ch) => _allowed.hasMatch(ch)).join();
    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
