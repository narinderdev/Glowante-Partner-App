part of 'owner_profile_operations_screen.dart';

InputDecorationTheme _operationsFormInputDecorationTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE8DED6)),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    counterStyle: const TextStyle(
      color: Color(0xFF8A8178),
      fontWeight: FontWeight.w700,
    ),
    labelStyle: const TextStyle(
      color: Color(0xFF6F675F),
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    prefixIconColor: AppColors.starColor,
    suffixIconColor: AppColors.starColor,
    errorStyle: const TextStyle(
      color: Colors.redAccent,
      fontSize: 11,
      height: 1.15,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: border,
    enabledBorder: border,
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE8DED6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.starColor, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    ),
  );
}

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
  final _vendorFieldKey = GlobalKey<FormFieldState<int>>();
  final _storeFieldKey = GlobalKey<FormFieldState<int>>();
  final _createdByFieldKey = GlobalKey<FormFieldState<String>>();
  final _requiredDateFieldKey = GlobalKey<FormFieldState<DateTime?>>();
  final TextEditingController _createdByController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
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
  bool _showVendorError = false;
  bool _showStoreError = false;
  bool _showCreatedByError = false;
  bool _showRequiredDateError = false;

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
      _vendors = _recordList(results[0]).where(_isActiveRecord).toList();
      _stores = _recordList(results[1]).where(_isActiveRecord).toList();
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
    if (!_canAddLine) {
      Fluttertoast.showToast(
        msg: context.t('Each line must use a different item'),
      );
      return;
    }
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
    } else {
      line.unitPriceController.clear();
    }
  }

  Set<int> _selectedItemIds({int? excludeIndex}) {
    final ids = <int>{};
    for (var index = 0; index < _lines.length; index++) {
      if (excludeIndex != null && index == excludeIndex) continue;
      final itemId = _lines[index].itemId;
      if (itemId != null) ids.add(itemId);
    }
    return ids;
  }

  List<Map<String, dynamic>> _availableItemsForLine(int index) {
    final selectedElsewhere = _selectedItemIds(excludeIndex: index);
    return _items.where((item) {
      final itemId = _toInt(item['id']);
      if (itemId == null) return false;
      return !selectedElsewhere.contains(itemId) ||
          _lines[index].itemId == itemId;
    }).toList();
  }

  bool get _canAddLine => _items.isNotEmpty && _lines.length < _items.length;

  Future<void> _submit() async {
    final lineRequired =
        translateText('Each line must have an item and ordered qty');

    setState(() {
      _showVendorError = true;
      _showStoreError = true;
      _showCreatedByError = true;
      _showRequiredDateError = true;
      for (final line in _lines) {
        line.showItemError = true;
        line.showQtyError = true;
      }
    });

    if (!_formKey.currentState!.validate()) return;
    for (final line in _lines) {
      if (line.itemId == null || (_toInt(line.qtyController.text) ?? 0) <= 0) {
        Fluttertoast.showToast(msg: lineRequired);
        return;
      }
    }
    if (_selectedItemIds().length != _lines.length) {
      Fluttertoast.showToast(
        msg: context.t('Each line must use a different item'),
      );
      return;
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

  void _clearIntFieldError(
    GlobalKey<FormFieldState<int>> fieldKey,
    VoidCallback markClean,
  ) {
    markClean();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fieldKey.currentState?.validate();
    });
  }

  void _clearStringFieldError(
    GlobalKey<FormFieldState<String>> fieldKey,
    VoidCallback markClean,
  ) {
    markClean();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fieldKey.currentState?.validate();
    });
  }

  void _clearDateFieldError(
    GlobalKey<FormFieldState<DateTime?>> fieldKey,
    VoidCallback markClean,
  ) {
    markClean();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fieldKey.currentState?.validate();
    });
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
          ? const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.starColor),
              ),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: _operationsFormInputDecorationTheme(),
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InventoryFormSection(
                      title: context.t('Purchase Details'),
                      icon: Icons.receipt_long_outlined,
                      children: [
                        DropdownButtonFormField<int>(
                          key: _vendorFieldKey,
                          initialValue: _selectedVendorId,
                          decoration:
                              InputDecoration(labelText: context.t('Vendor')),
                          isExpanded: true,
                          menuMaxHeight: 260,
                          items: _vendors
                              .map(
                                (vendor) => DropdownMenuItem<int>(
                                  value: _toInt(vendor['id']),
                                  child: _dropdownMenuText(
                                    _firstText(
                                      vendor,
                                      const ['name', 'vendorName'],
                                      fallback: context.t('Vendor'),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              _showVendorError && value == null
                                  ? vendorRequired
                                  : null,
                          onChanged: (value) {
                            setState(() => _selectedVendorId = value);
                            _clearIntFieldError(
                              _vendorFieldKey,
                              () => setState(() => _showVendorError = false),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          key: _storeFieldKey,
                          initialValue: _selectedStoreId,
                          decoration: InputDecoration(
                            labelText: context.t('Delivery Address (Store)'),
                          ),
                          isExpanded: true,
                          menuMaxHeight: 260,
                          items: _stores
                              .map(
                                (store) => DropdownMenuItem<int>(
                                  value: _toInt(store['id']),
                                  child: _dropdownMenuText(
                                    _firstText(
                                      store,
                                      const ['name', 'storeName'],
                                      fallback: context.t('Store'),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) => _showStoreError && value == null
                              ? deliveryAddressRequired
                              : null,
                          onChanged: (value) {
                            setState(() => _selectedStoreId = value);
                            _clearIntFieldError(
                              _storeFieldKey,
                              () => setState(() => _showStoreError = false),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: _createdByFieldKey,
                          maxLength: 50,
                          controller: _createdByController,
                          decoration: InputDecoration(
                              labelText: context.t('Created By')),
                          validator: (value) =>
                              _showCreatedByError && _stringValue(value).isEmpty
                                  ? createdByRequired
                                  : null,
                          onChanged: (_) => _clearStringFieldError(
                            _createdByFieldKey,
                            () => setState(() => _showCreatedByError = false),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FormField<DateTime?>(
                          key: _requiredDateFieldKey,
                          initialValue: _requiredDate,
                          autovalidateMode: _autoValidateMode,
                          validator: (value) {
                            if (!_showRequiredDateError) return null;
                            if (value == null) {
                              return requiredDateRequired;
                            }
                            if (value.isBefore(DateTime.now()
                                .subtract(const Duration(days: 1)))) {
                              return translateText(
                                'Required date cannot be in the past',
                              );
                            }
                            return null;
                          },
                          builder: (field) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: _requiredDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  initialEntryMode:
                                      DatePickerEntryMode.calendarOnly,
                                );
                                if (selected == null) return;
                                field.didChange(selected);
                                setState(() => _requiredDate = selected);
                                _clearDateFieldError(
                                  _requiredDateFieldKey,
                                  () => setState(
                                      () => _showRequiredDateError = false),
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText:
                                      context.t('Required Delivery Date'),
                                  errorText: field.errorText,
                                  suffixIcon:
                                      const Icon(Icons.calendar_today_outlined),
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
                          maxLength: 50,
                          controller: _departmentController,
                          decoration: InputDecoration(
                              labelText: context.t('Department')),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          maxLength: 100,
                          controller: _remarksController,
                          maxLines: 1,
                          decoration:
                              InputDecoration(labelText: context.t('Remarks')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InventoryFormSection(
                      title: context.t('Item Lines'),
                      icon: Icons.playlist_add_check_outlined,
                      trailing: _canAddLine
                          ? TextButton.icon(
                              onPressed: _addLine,
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(context.t('Add Line')),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.starColor,
                              ),
                            )
                          : null,
                      children: [
                        ..._lines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF8),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE8DED6)),
                            ),
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  key: line.itemFieldKey,
                                  initialValue: line.itemId,
                                  decoration: InputDecoration(
                                      labelText: context.t('Item')),
                                  isExpanded: true,
                                  menuMaxHeight: 260,
                                  items: _availableItemsForLine(index)
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: _toInt(item['id']),
                                          child: _dropdownMenuText(
                                            _firstText(
                                              item,
                                              const [
                                                'itemName',
                                                'name',
                                                'title'
                                              ],
                                              fallback: context.t('Item'),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  validator: (value) {
                                    if (!line.showItemError) return null;
                                    if (value == null) return itemRequired;
                                    if (_selectedItemIds(excludeIndex: index)
                                        .contains(value)) {
                                      return context.t(
                                        'Item already selected in another line',
                                      );
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    setState(() {
                                      _syncLinePrice(line, value);
                                      line.showItemError = false;
                                    });
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        line.itemFieldKey.currentState
                                            ?.validate();
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: line.qtyFieldKey,
                                  maxLength: 15,
                                  controller: line.qtyController,
                                  inputFormatters: _integerInputFormatters(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: context.t('Ordered Qty'),
                                  ),
                                  validator: (value) {
                                    if (!line.showQtyError) return null;
                                    final text = _stringValue(value);
                                    if (text.isEmpty) {
                                      return orderedQtyRequired;
                                    }
                                    final qty = _toInt(text);
                                    if (qty == null || qty <= 0) {
                                      return orderedQtyRequired;
                                    }
                                    return null;
                                  },
                                  onChanged: (_) => _clearStringFieldError(
                                    line.qtyFieldKey,
                                    () => setState(
                                        () => line.showQtyError = false),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  maxLength: 15,
                                  controller: line.unitPriceController,
                                  enabled: false,
                                  inputFormatters: _decimalInputFormatters(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: context.t('Unit Price'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  maxLength: 15,
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
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.starColor,
                                      disabledForegroundColor:
                                          const Color(0xFFB8AFA6),
                                    ),
                                    child: Text(context.t('Remove')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          _isSaving
                              ? context.t('Saving...')
                              : context.t('Save Purchase Order'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.starColor.withValues(alpha: 0.55),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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

class _PurchaseOrderLineInput {
  _PurchaseOrderLineInput({
    String qty = '',
    String unitPrice = '',
    String remarks = '',
  })  : qtyController = TextEditingController(text: qty),
        unitPriceController = TextEditingController(text: unitPrice),
        remarksController = TextEditingController(text: remarks);

  int? itemId;
  final itemFieldKey = GlobalKey<FormFieldState<int>>();
  final qtyFieldKey = GlobalKey<FormFieldState<String>>();
  final TextEditingController qtyController;
  final TextEditingController unitPriceController;
  final TextEditingController remarksController;
  bool showItemError = false;
  bool showQtyError = false;

  void dispose() {
    qtyController.dispose();
    unitPriceController.dispose();
    remarksController.dispose();
  }
}
