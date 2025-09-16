import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SelectServices.dart';
import '../utils/api_service.dart';
import 'dart:math' as math;

class AddDealsBranchScreen extends StatefulWidget {
  final int salonId;
  final String salonName;
  final Function(int salonId) onPackageCreated;
  final String source; // "DEAL" or "PACKAGE"

  const AddDealsBranchScreen({
    Key? key,
    required this.salonId,
    required this.salonName,
    required this.onPackageCreated,
    required this.source,
  }) : super(key: key);

  @override
  State<AddDealsBranchScreen> createState() => _AddDealsBranchScreenState();
}

class _AddDealsBranchScreenState extends State<AddDealsBranchScreen> {
  // controllers
  final TextEditingController dealTitleController = TextEditingController();
  final TextEditingController validFromController = TextEditingController();
  final TextEditingController validTillController = TextEditingController();
  final TextEditingController originalPriceController = TextEditingController();
  final TextEditingController discountedPriceController =
      TextEditingController();
  final TextEditingController amountOffController =
      TextEditingController(); // Flat or Percent
  final TextEditingController maxDiscountController =
      TextEditingController(); // only for Percent
  // controllers
  final TextEditingController discountAmountController =
      TextEditingController(); // For amount off
  final TextEditingController discountPercentController =
      TextEditingController(); // For percent off

  // ui state
  String pricingMode = 'Fixed'; // Fixed | Discount
  String discountType = 'Flat'; // Flat | Percent
  final List<String> pricingModes = const ['Fixed', 'Discount'];
  final List<String> discountTypes = const ['Flat', 'Percent'];

  // Selected services from modal
  List<Map<String, dynamic>> _selectedServices = [];

  // internal flags
  bool _settingFields = false;
  bool _autoSetMaxFromPercent =
      false; // auto-fill "Max Discount" once from Percent Off

  // styles
  final _radius = BorderRadius.circular(12);
  final _accent = const Color(0xFFDD8B1F);
  Map<String, dynamic> offerData = {};
  @override
  void initState() {
    super.initState();
    amountOffController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent =
          true; // allow auto-fill again when typing percent
      _recalcDiscounted();
    });
    maxDiscountController.addListener(() {
      if (_settingFields) return;
      _autoSetMaxFromPercent = false; // user edited max discount manually
      _recalcDiscounted();
    });
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
    discountAmountController.dispose(); // Dispose of discountAmountController
    discountPercentController.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  String _formatDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  Future<void> _pickDate(TextEditingController c) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) c.text = _formatDate(picked);
  }

  int _originalTotalInt() {
    int sum = 0;
    for (final s in _selectedServices) {
      final int price = (s['price'] ?? 0) as int;
      final int qty = (s['qty'] ?? 0) as int;
      sum += price * qty;
    }
    return sum;
  }

  String _rsInt(int v) => '₹$v';
  String _rs2(num v) => '₹${v.toStringAsFixed(2)}';

  double _parseNum(String s) {
    if (s.trim().isEmpty) return 0;
    return double.tryParse(s.trim()) ?? 0;
  }

  String _moneyStr(num v) => v.toStringAsFixed(2);

  void _setTextSafe(TextEditingController c, String v) {
    _settingFields = true;
    c.text = v;
    c.selection = TextSelection.fromPosition(
      TextPosition(offset: c.text.length),
    );
    _settingFields = false;
  }

  void _recalcDiscounted() {
    final original = _parseNum(originalPriceController.text);
    if (original <= 0) {
      _setTextSafe(discountedPriceController, '');
      return;
    }

    Future<void> _showValidationDialog(List<String> errors) async {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Please fix the following'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors
                .map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ' + message),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    double? _parseCurrency(String value) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
      if (sanitized.isEmpty) {
        return null;
      }
      return double.tryParse(sanitized);
    }

    Future<bool> _validateForm() async {
      final errors = <String>[];

      if (dealTitleController.text.trim().isEmpty) {
        errors.add('Deal title is required.');
      }

      if (_selectedServices.isEmpty) {
        errors.add('Select at least one service.');
      }

      final discounted = _parseCurrency(discountedPriceController.text);
      if (discounted == null || discounted <= 0) {
        errors.add('Discounted price must be greater than 0.');
      }

      final amountText = amountOffController.text.trim();
      if (pricingMode == 'Fixed') {
        final amount = _parseCurrency(amountText);
        if (amount == null || amount <= 0) {
          errors.add('Enter a valid amount off.');
        }
      } else {
        if (discountType == 'Flat') {
          final amount = _parseCurrency(amountText);
          if (amount == null || amount <= 0) {
            errors.add('Enter a valid discount amount.');
          }
        } else {
          final percent = double.tryParse(amountText);
          if (percent == null || percent <= 0) {
            errors.add('Enter a valid percentage off.');
          } else if (percent > 100) {
            errors.add('Percentage off cannot exceed 100.');
          }
          final maxDiscount = _parseCurrency(maxDiscountController.text);
          if (maxDiscount == null || maxDiscount <= 0) {
            errors.add('Enter the maximum discount amount.');
          }
        }
      }

      if (errors.isNotEmpty) {
        await _showValidationDialog(errors);
        return false;
      }
      return true;
    }

    Future<void> _submitOffer() async {
      if (!await _validateForm()) {
        return;
      }

      _recalcDiscounted();

      if (pricingMode == 'Discount' && discountType == 'Percent') {
        discountPercentController.text = amountOffController.text.trim();
      }

      final offerData = {
        'name': dealTitleController.text,
        'type': widget.source,
        'status': 'ACTIVE',
        'validFrom': validFromController.text.isNotEmpty
            ? validFromController.text
            : null,
        'validTo': validTillController.text.isNotEmpty
            ? validTillController.text
            : null,
        'pricingMode': pricingMode.toUpperCase(),
        'price': _parseCurrency(discountedPriceController.text) ?? 0,
        'terms': 'Valid on weekdays only.',
        'items': _selectedServices
            .map(
              (service) => {
                'branchServiceId': service['id'],
                'qty': service['qty'],
              },
            )
            .toList(),
      };

      if (pricingMode == 'Fixed') {
        offerData['amountType'] = 'FLAT';
        offerData['amount'] = _parseCurrency(amountOffController.text) ?? 0;
        offerData['discount'] = offerData['amount'];
      } else {
        offerData['discountType'] = discountType == 'Flat'
            ? 'AMOUNT'
            : 'PERCENT';
        if (discountType == 'Flat') {
          offerData['amountType'] = 'FLAT';
          offerData['amount'] = _parseCurrency(amountOffController.text) ?? 0;
          offerData['discount'] = offerData['amount'];
        } else {
          offerData['discountPct'] =
              int.tryParse(discountPercentController.text) ?? 0;
          offerData['maxDiscount'] =
              _parseCurrency(maxDiscountController.text) ?? 0;
        }
      }

      final apiService = ApiService();
      final response = await apiService.createSalonBranchOffer(
        widget.salonId,
        offerData,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offer created successfully')),
          );
          widget.onPackageCreated(widget.salonId);
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          await _showValidationDialog([
            response['message']?.toString() ?? 'Failed to create offer.',
          ]);
        }
      }
    }

    double discounted = original;

    if (pricingMode == 'Fixed') {
      // Case 1: Fixed → user enters Amount Off (Rs)
      final amountOff = _parseNum(amountOffController.text);
      final applied = amountOff.clamp(0, original);
      discounted = original - applied;
    } else {
      // pricingMode = Discount
      if (discountType == 'Flat') {
        // Case 2: Discount + Flat
        final amountOff = _parseNum(amountOffController.text);
        final applied = amountOff.clamp(0, original);
        discounted = original - applied;
      } else {
        // Case 3: Discount + Percent
        // Case 3: Discount + Percent
        final percent = _parseNum(amountOffController.text).clamp(0, 100);
        final percentDiscount = original * (percent / 100.0);

        // Auto-fill max discount only if user hasn't overridden it
        if (_autoSetMaxFromPercent && maxDiscountController.text.isEmpty) {
          _setTextSafe(maxDiscountController, _moneyStr(percentDiscount));
        }

        final maxCap = _parseNum(maxDiscountController.text);
        final applied = maxCap > 0
            ? math.min(percentDiscount, maxCap)
            : percentDiscount;

        discounted = (original - applied).clamp(0, original);
      }
    }

    _setTextSafe(discountedPriceController, _moneyStr(discounted));
  }

  // If modal returns {id: qty} instead of full objects, map them here
  Future<List<Map<String, dynamic>>> _hydrateFromIds(
    Map<int, int> idQty,
  ) async {
    final resp = await ApiService().getService(salonId: widget.salonId);
    final cats = (resp['data']?['categories'] ?? []) as List;
    // Flatten services
    final svcById = <int, Map<String, dynamic>>{};
    void addAll(List list) {
      for (final s in list) {
        svcById[s['id'] as int] = s as Map<String, dynamic>;
      }
    }

    for (final c in cats) {
      addAll(c['services'] ?? []);
      for (final sub in c['subCategories'] ?? []) {
        addAll(sub['services'] ?? []);
      }
    }
    final out = <Map<String, dynamic>>[];
    idQty.forEach((id, qty) {
      final s = svcById[id];
      if (s != null && qty > 0) {
        out.add({
          'id': id,
          'name': s['displayName'],
          'price': s['priceMinor'],
          'qty': qty,
        });
      }
    });
    return out;
  }

  InputDecoration _decor({
    required String label,
    String? hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix),
      suffixIcon: suffix,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: _radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: Colors.black.withOpacity(.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: _accent, width: 1.6),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final showDiscountRow = pricingMode == 'Discount';
    // Flat field visible in Fixed OR Discount+Flat
    final showFlatField =
        (pricingMode == 'Fixed') ||
        (pricingMode == 'Discount' && discountType == 'Flat');
    final showPercentField =
        pricingMode == 'Discount' && discountType == 'Percent';

    return Scaffold(
      appBar: AppBar(title: const Text('Create Package Deal')),
      body: Container(
        color: const Color(0xFFFEFBF5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deal Information
              _sectionTitle('Deal Information'),

              // Text('Salon: ${widget.salonName}, Branch ID: ${widget.salonId}'),
              TextField(
                controller: dealTitleController,
                decoration: _decor(
                  label: 'Deal Title *',
                  hint: "e.g. Men's Grooming Package",
                ),
              ),
              const SizedBox(height: 16),

              // Pricing Mode / Discount Type
              if (!showDiscountRow) ...[
                Text(
                  'Pricing Mode *',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: pricingMode,
                  items: pricingModes
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      pricingMode = v ?? 'Fixed';
                      _autoSetMaxFromPercent = true;
                    });
                    _recalcDiscounted();
                  },
                  decoration: _decor(
                    label: '',
                    prefix: Icons.local_offer_outlined,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pricing Mode *',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: pricingMode,
                            items: pricingModes
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                pricingMode = v ?? 'Discount';
                                _autoSetMaxFromPercent = true;
                              });
                              _recalcDiscounted();
                            },
                            decoration: _decor(
                              label: '',
                              prefix: Icons.local_offer_outlined,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discount Type *',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: discountType,
                            items: discountTypes
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                discountType = v ?? 'Flat';
                                _autoSetMaxFromPercent = true;
                              });
                              _recalcDiscounted();
                            },
                            decoration: _decor(
                              label: '',
                              prefix: Icons.sell_outlined,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Services
              _sectionTitle('Services'),
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
                      originalPriceController.text = _originalTotalInt()
                          .toDouble()
                          .toStringAsFixed(2);
                    });
                    _recalcDiscounted();
                  } else if (result is Map) {
                    final hydrated = await _hydrateFromIds(
                      Map<int, int>.from(result),
                    );
                    setState(() {
                      _selectedServices = hydrated;
                      originalPriceController.text = _originalTotalInt()
                          .toDouble()
                          .toStringAsFixed(2);
                    });
                    _recalcDiscounted();
                  }
                },
                borderRadius: _radius,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _radius,
                    border: Border.all(color: Colors.black.withOpacity(.12)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Color(0xFF946317)),
                      SizedBox(width: 8),
                      Text(
                        'Select Services',
                        style: TextStyle(
                          color: Color(0xFF946317),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedServices.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Selected Services',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ..._selectedServices.map((s) {
                  final name = (s['name'] ?? '').toString();
                  final price = (s['price'] ?? 0) as int;
                  final qty = (s['qty'] ?? 0) as int;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: _radius,
                      border: Border.all(color: Colors.black.withOpacity(.12)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                              _rsInt(price),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: $qty × ${_rsInt(price)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 18),

              // Discount-specific fields
              if (showFlatField) ...[
                TextField(
                  controller: amountOffController,
                  keyboardType: TextInputType.number,
                  decoration: _decor(
                    label: pricingMode == 'Fixed'
                        ? 'Amount Off (Rs) *'
                        : 'Amount Off (Rs) *',
                    hint: 'e.g. 200',
                    prefix: Icons.currency_rupee,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (showPercentField) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountOffController,
                        keyboardType: TextInputType.number,
                        decoration: _decor(
                          label: 'Percent Off (%) *',
                          hint: 'e.g. 20',
                          prefix: Icons.percent,
                        ),
                        onChanged: (value) {
                          setState(() {
                            final discountPercent =
                                int.tryParse(
                                  discountPercentController.text.trim(),
                                ) ??
                                0;
                            offerData['discountPct'] = discountPercent;
                            _recalcDiscounted();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxDiscountController,
                        keyboardType: TextInputType.number,
                        readOnly: false, // let user override
                        decoration: _decor(
                          label: 'Max Discount (Rs)',
                          hint: 'auto from %',
                          prefix: Icons.currency_rupee,
                        ),
                        onChanged: (_) {
                          _autoSetMaxFromPercent =
                              false; // stop auto-overwriting if user edits
                          _recalcDiscounted();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Original / Discounted Price
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: originalPriceController,
                      readOnly: true, // auto-filled from selected services
                      keyboardType: TextInputType.number,
                      decoration: _decor(
                        label: 'Original Price *',
                        hint: 'eg. 2400',
                        prefix: Icons.currency_rupee,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: discountedPriceController,
                      keyboardType: TextInputType.number,
                      readOnly: true, // auto-calculated
                      decoration: _decor(
                        label: 'Discounted Price *',
                        hint: 'eg. 2400',
                        prefix: Icons.currency_rupee,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              // Add Packages button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitOffer,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(borderRadius: _radius),
                  ),
                  child: const Text(
                    'Add Packages',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
