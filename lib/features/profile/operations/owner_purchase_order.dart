part of 'owner_profile_operations_screen.dart';
class _PurchaseOrderFormView extends StatefulWidget {
  const _PurchaseOrderFormView({
    required this.branchId,
    required this.onBack,
    required this.onSubmit,
  });

  final int branchId;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_PurchaseOrderFormView> createState() => _PurchaseOrderFormViewState();
}

class _PurchaseOrderFormViewState extends State<_PurchaseOrderFormView> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _createdByController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  List<Map<String, dynamic>> _vendors = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stores = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  List<_PurchaseOrderLineInput> _lines = <_PurchaseOrderLineInput>[
    _PurchaseOrderLineInput(),
  ];
  int? _selectedVendorId;
  int? _selectedStoreId;
  DateTime? _requiredDate;
  bool _isLoadingOptions = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final results = await Future.wait<Map<String, dynamic>>([
      _apiService.getBranchVendors(widget.branchId),
      _apiService.getStores(widget.branchId),
      _apiService.fetchInventoryItems(widget.branchId, page: 1, limit: 200),
    ]);
    if (!mounted) return;
    final itemsPayload = results[2]['data'];
    setState(() {
      _vendors = _recordList(results[0]);
      _stores = _recordList(results[1]);
      _items = itemsPayload is Map<String, dynamic>
          ? _recordList(itemsPayload['items'] ?? itemsPayload)
          : _recordList(itemsPayload);
      _isLoadingOptions = false;
    });
  }

  @override
  void dispose() {
    _createdByController.dispose();
    _departmentController.dispose();
    _remarksController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() {
      _lines = <_PurchaseOrderLineInput>[..._lines, _PurchaseOrderLineInput()];
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final next = List<_PurchaseOrderLineInput>.from(_lines);
    next.removeAt(index).dispose();
    setState(() => _lines = next);
  }

  void _syncLinePrice(_PurchaseOrderLineInput line, int? itemId) {
    line.itemId = itemId;
    final selectedItem = _items.cast<Map<String, dynamic>?>().firstWhere(
          (item) => _toInt(item?['id']) == itemId,
          orElse: () => null,
        );
    if (selectedItem != null) {
      final price = _toDouble(
        selectedItem['costPerUnit'] ?? selectedItem['unitPrice'],
      );
      line.unitPriceController.text = price == null
          ? ''
          : (minorAmountToRupees(price) ?? 0).toStringAsFixed(0);
    }
  }

  Future<void> _submit() async {
    final vendorRequired = translateText('Vendor is required');
    final deliveryAddressRequired =
        translateText('Delivery Address is required');
    final lineRequired =
        translateText('Each line must have an item and ordered qty');

    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) {
      Fluttertoast.showToast(msg: vendorRequired);
      return;
    }
    if (_selectedStoreId == null) {
      Fluttertoast.showToast(msg: deliveryAddressRequired);
      return;
    }
    for (final line in _lines) {
      if (line.itemId == null || (_toInt(line.qtyController.text) ?? 0) <= 0) {
        Fluttertoast.showToast(msg: lineRequired);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final createdBy = _createdByController.text.trim();
      await widget.onSubmit(<String, dynamic>{
        'vendorId': _selectedVendorId,
        'deliveryStoreId': _selectedStoreId,
        'createdBy': createdBy,
        'createdByUserId': createdBy,
        'requiredDeliveryDate': DateFormat('yyyy-MM-dd').format(_requiredDate!),
        'department': _departmentController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'lines': _lines
            .map(
              (line) => <String, dynamic>{
                'itemId': line.itemId,
                'orderedQty': _toInt(line.qtyController.text) ?? 0,
                'unitPrice': rupeesToMinorAmount(
                  _toDouble(line.unitPriceController.text) ?? 0,
                ),
                'remarks': line.remarksController.text.trim(),
              },
            )
            .toList(),
      });
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorRequired = translateText('Vendor is required');
    final deliveryAddressRequired =
        translateText('Delivery Address is required');
    final requiredDateRequired = translateText('Delivery date is required');
    final createdByRequired = translateText('Created By is required');
    final orderedQtyRequired = translateText('Ordered Qty is required');
    final itemRequired = translateText('Item is required');

    return _FormCard(
      title: context.t('Add Purchase Order'),
      onBack: widget.onBack,
      child: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: _autoValidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('po-vendor-$_selectedVendorId'),
                    initialValue: _selectedVendorId,
                    decoration: InputDecoration(labelText: context.t('Vendor')),
                    items: _vendors
                        .map(
                          (vendor) => DropdownMenuItem<int>(
                            value: _toInt(vendor['id']),
                            child: Text(
                              _firstText(
                                vendor,
                                const ['name', 'vendorName'],
                                fallback: context.t('Vendor'),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => value == null ? vendorRequired : null,
                    onChanged: (value) =>
                        setState(() => _selectedVendorId = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('po-store-$_selectedStoreId'),
                    initialValue: _selectedStoreId,
                    decoration: InputDecoration(
                      labelText: context.t('Delivery Address (Store)'),
                    ),
                    items: _stores
                        .map(
                          (store) => DropdownMenuItem<int>(
                            value: _toInt(store['id']),
                            child: Text(
                              _firstText(
                                store,
                                const ['name', 'storeName'],
                                fallback: context.t('Store'),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? deliveryAddressRequired : null,
                    onChanged: (value) =>
                        setState(() => _selectedStoreId = value),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _createdByController,
                    decoration:
                        InputDecoration(labelText: context.t('Created By')),
                    validator: (value) =>
                        _stringValue(value).isEmpty ? createdByRequired : null,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  FormField<DateTime?>(
                    initialValue: _requiredDate,
                    autovalidateMode: _autoValidateMode,
                    validator: (value) {
                      if (value == null) {
                        return requiredDateRequired;
                      }
                      if (value.isBefore(
                          DateTime.now().subtract(const Duration(days: 1)))) {
                        return translateText(
                          'Required date cannot be in the past',
                        );
                      }
                      return null;
                    },
                    builder: (field) {
                      return InkWell(
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _requiredDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (selected == null) return;
                          setState(() => _requiredDate = selected);
                          field.didChange(selected);
                          if (_autoValidateMode != AutovalidateMode.disabled) {
                            _formKey.currentState?.validate();
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.t('Required Delivery Date'),
                            border: const OutlineInputBorder(),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _requiredDate == null
                                ? context.t('Select date')
                                : DateFormat('dd MMM yyyy')
                                    .format(_requiredDate!),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _departmentController,
                    decoration:
                        InputDecoration(labelText: context.t('Department')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _remarksController,
                    maxLines: 1,
                    decoration:
                        InputDecoration(labelText: context.t('Remarks')),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('Item Lines'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add),
                        label: Text(context.t('Add Line')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            key: ValueKey<String>(
                                'po-line-$index-${line.itemId}'),
                            initialValue: line.itemId,
                            decoration:
                                InputDecoration(labelText: context.t('Item')),
                            items: _items
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: _toInt(item['id']),
                                    child: Text(
                                      _firstText(
                                        item,
                                        const ['itemName', 'name', 'title'],
                                        fallback: context.t('Item'),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (value) =>
                                value == null ? itemRequired : null,
                            onChanged: (value) => setState(() {
                              _syncLinePrice(line, value);
                              if (_autoValidateMode !=
                                  AutovalidateMode.disabled) {
                                _formKey.currentState?.validate();
                              }
                            }),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            maxLength: 120,
                            controller: line.qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.t('Ordered Qty'),
                            ),
                            validator: (value) {
                              final qty = _toInt(value);
                              if (qty == null || qty <= 0) {
                                return orderedQtyRequired;
                              }
                              return null;
                            },
                            onChanged: (_) {
                              if (_autoValidateMode !=
                                  AutovalidateMode.disabled) {
                                _formKey.currentState?.validate();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            maxLength: 120,
                            controller: line.unitPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.t('Unit Price'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            maxLength: 120,
                            controller: line.remarksController,
                            decoration: InputDecoration(
                                labelText: context.t('Remarks')),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _lines.length == 1
                                  ? null
                                  : () => _removeLine(index),
                              child: Text(context.t('Remove')),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isSaving
                          ? context.t('Saving...')
                          : context.t('Save Purchase Order')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PurchaseOrderLineInput {
  _PurchaseOrderLineInput({
    String qty = '',
    String unitPrice = '',
    String remarks = '',
  })  : qtyController = TextEditingController(text: qty),
        unitPriceController = TextEditingController(text: unitPrice),
        remarksController = TextEditingController(text: remarks);

  int? itemId;
  final TextEditingController qtyController;
  final TextEditingController unitPriceController;
  final TextEditingController remarksController;

  void dispose() {
    qtyController.dispose();
    unitPriceController.dispose();
    remarksController.dispose();
  }
}
