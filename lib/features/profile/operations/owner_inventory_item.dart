part of 'owner_profile_operations_screen.dart';

class _InventoryItemFormView extends StatefulWidget {
  const _InventoryItemFormView({
    required this.branchId,
    required this.isEdit,
    required this.onBack,
    required this.onSubmit,
    this.initialItem,
  });

  final int branchId;
  final bool isEdit;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;
  final Map<String, dynamic>? initialItem;

  @override
  State<_InventoryItemFormView> createState() => _InventoryItemFormViewState();
}

class _InventoryItemFormViewState extends State<_InventoryItemFormView> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  static const List<String> _unitOptions = <String>[
    'EACH',
    'METER',
    'LITER',
    'KG',
    'BOX',
    'SET',
    'PACK',
  ];
  late final TextEditingController _itemIdController;
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _stockController;
  late final TextEditingController _reorderPointController;
  late final TextEditingController _reorderQtyController;
  late final TextEditingController _costController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _active = true;
  bool _isSaving = false;
  bool _isLoadingOptions = true;
  List<String> _categories = const <String>[];
  List<Map<String, dynamic>> _vendors = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stores = const <Map<String, dynamic>>[];
  String? _selectedCategory;
  String? _selectedUnitOfMeasure;
  int? _selectedVendorId;
  int? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem ?? const <String, dynamic>{};
    _itemIdController = TextEditingController(
      text: _firstText(initial, const ['itemId', 'id']),
    );
    _skuController = TextEditingController(
      text: _firstText(initial, const ['sku', 'skuNumber']),
    );
    _nameController = TextEditingController(
      text: _firstText(initial, const ['itemName', 'name', 'title']),
    );
    _brandController = TextEditingController(
      text: _firstText(initial, const ['brand']),
    );
    _stockController = TextEditingController(
      text: _firstText(
        initial,
        const ['stockLevel', 'availableStock', 'currentStock'],
      ),
    );
    _reorderPointController = TextEditingController(
      text: _firstText(initial, const ['reorderPoint']),
    );
    _reorderQtyController = TextEditingController(
      text: _firstText(initial, const ['reorderQuantity', 'reorderQty']),
    );
    _costController = TextEditingController(
      text:
          _firstTextMinorAsRupees(initial, const ['costPerUnit', 'unitPrice']),
    );
    _minStockController = TextEditingController(
      text: _firstText(initial, const ['minStockLevel', 'minStock']),
    );
    _maxStockController = TextEditingController(
      text: _firstText(initial, const ['maxStockLevel', 'maxStock']),
    );
    _active = _boolValue(initial['active'], fallback: true);
    _selectedCategory = _firstText(initial, const ['category', 'categoryName']);
    final initialUnit = _firstText(
      initial,
      const ['unitOfMeasure', 'unit', 'unitName'],
    ).toUpperCase();
    _selectedUnitOfMeasure =
        _unitOptions.contains(initialUnit) ? initialUnit : 'EACH';
    _selectedVendorId = _toInt(initial['vendorId'] ??
        initial['primaryVendorId'] ??
        initial['primaryVendorDbId']);
    _selectedStoreId = _toInt(initial['storeId']);
    _loadOptions();
  }

  void _validateOnlyAfterSubmit() {
    if (_autoValidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = true);
    final results = await Future.wait<Map<String, dynamic>>([
      _apiService.getInventoryItemCategories(widget.branchId),
      _apiService.getBranchVendors(widget.branchId),
      _apiService.getStores(widget.branchId),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = _stringOptions(results[0]['data'] ?? results[0]);
      _vendors = _recordList(results[1]);
      _stores = _recordList(results[2]);
      if (_selectedCategory != null &&
          !_categories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
      if (!_vendors
          .any((vendor) => _toInt(vendor['id']) == _selectedVendorId)) {
        _selectedVendorId = null;
      }
      if (!_stores.any((store) => _toInt(store['id']) == _selectedStoreId)) {
        _selectedStoreId = null;
      }
      _isLoadingOptions = false;
    });
  }

  @override
  void dispose() {
    _itemIdController.dispose();
    _skuController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _stockController.dispose();
    _reorderPointController.dispose();
    _reorderQtyController.dispose();
    _costController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final resolvedItemId = widget.isEdit
          ? _itemIdController.text.trim()
          : (_itemIdController.text.trim().isEmpty
              ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
              : _itemIdController.text.trim());
      final payload = <String, dynamic>{
        'itemId': resolvedItemId,
        'sku': _skuController.text.trim(),
        'skuNumber': _skuController.text.trim(),
        'itemName': _nameController.text.trim(),
        'category': _selectedCategory,
        'unitOfMeasure': _selectedUnitOfMeasure,
        'brand': _brandController.text.trim(),
        'manufacturer': _brandController.text.trim(),
        'stockLevel': _toInt(_stockController.text.trim()) ?? 0,
        'reorderPoint': _toInt(_reorderPointController.text.trim()) ?? 0,
        'reorderQuantity': _toInt(_reorderQtyController.text.trim()) ?? 0,
        'costPerUnit': rupeesToMinorAmount(
          _toDouble(_costController.text.trim()) ?? 0,
        ),
        'minStockLevel': _toInt(_minStockController.text.trim()) ?? 0,
        'maxStockLevel': _toInt(_maxStockController.text.trim()) ?? 0,
        'vendorId': _selectedVendorId,
        'primaryVendorDbId': _selectedVendorId,
        'storeId': _selectedStoreId,
        'active': _active,
      };
      await widget.onSubmit(payload);
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: extractErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: widget.isEdit
          ? context.t('Edit Inventory Item')
          : context.t('Add Inventory Item'),
      onBack: widget.onBack,
      child: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: _autoValidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormSectionTitle(context.t('Basic Details')),
                  const SizedBox(height: 12),
                  // TextFormField(
                  //   maxLength: 120,
                  //   controller: _itemIdController,
                  //   decoration:
                  //       InputDecoration(labelText: context.t('Item ID')),
                  //   validator: widget.isEdit
                  //       ? (value) => _stringValue(value).isEmpty
                  //           ? context.t('Item ID is required')
                  //           : null
                  //       : null,
                  // ),
                  // const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _skuController,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                    decoration: InputDecoration(labelText: context.t('SKU')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('SKU is required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _nameController,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                    decoration:
                        InputDecoration(labelText: context.t('Item Name')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Item name is required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  // DropdownButtonFormField<String>(
                  //   key: ValueKey<String>(
                  //     'inventory-category-$_selectedCategory',
                  //   ),
                  //   initialValue: _selectedCategory,
                  //   decoration:
                  //       InputDecoration(labelText: context.t('Category')),
                  //   items: _categories
                  //       .map(
                  //         (category) => DropdownMenuItem<String>(
                  //           value: category,
                  //           child: Text(category),
                  //         ),
                  //       )
                  //       .toList(),
                  //   onChanged: (value) =>
                  //       setState(() => _selectedCategory = value),
                  // ),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                        'inventory-category-$_selectedCategory'),
                    initialValue: _selectedCategory,
                    decoration:
                        InputDecoration(labelText: context.t('Category')),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Category is required')
                        : null,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      _validateOnlyAfterSubmit();
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'inventory-unit-$_selectedUnitOfMeasure',
                    ),
                    initialValue: _selectedUnitOfMeasure,
                    decoration: InputDecoration(
                      labelText: context.t('Unit of Measure'),
                    ),
                    items: _unitOptions
                        .map(
                          (unit) => DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit),
                          ),
                        )
                        .toList(),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Unit of Measure is required')
                        : null,
                    onChanged: (value) {
                      setState(() => _selectedUnitOfMeasure = value);
                      _validateOnlyAfterSubmit();
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _brandController,
                    decoration: InputDecoration(labelText: context.t('Brand')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Stock Level')),
                  ),
                  const SizedBox(height: 24),
                  _FormSectionTitle(context.t('Stock & Vendor Details')),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 120,
                    controller: _reorderPointController,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Reorder Point')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _reorderQtyController,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Reorder Qty')),
                    validator: (value) {
                      final qty = _toInt(value);
                      if (qty == null || qty < 1) {
                        return context.t('Reorder Qty must be at least 1');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _costController,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: context.t('Cost Per Unit')),
                    validator: (value) {
                      final amount = _toDouble(value);
                      if (amount == null || amount <= 0) {
                        return context
                            .t('Cost Per Unit must be greater than 0');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Min Stock')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _maxStockController,
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Max Stock')),
                    validator: (value) {
                      final maxStock = _toInt(value);

                      if (maxStock == null) {
                        return context.t('Max Stock is required');
                      }

                      if (maxStock < 1) {
                        return context.t('Max Stock must be at least 1');
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<int>(
                    key:
                        ValueKey<String>('inventory-vendor-$_selectedVendorId'),
                    initialValue: _selectedVendorId,
                    decoration: InputDecoration(labelText: context.t('Vendor')),
                    hint: Text(
                      _vendors.isEmpty
                          ? context.t('No vendors found')
                          : context.t('Select Vendor'),
                    ),
                    items: _vendors.map((vendor) {
                      final vendorId = _toInt(
                        vendor['id'] ??
                            vendor['vendorId'] ??
                            vendor['primaryVendorDbId'],
                      );

                      return DropdownMenuItem<int>(
                        value: vendorId,
                        child: Text(
                          _firstText(
                            vendor,
                            const ['name', 'vendorName', 'primaryVendorName'],
                            fallback: context.t('Vendor'),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedVendorId = value);
                      _validateOnlyAfterSubmit();
                    },
                    validator: (value) {
                      if (_toInt(value) == null) {
                        return context.t('Vendor is required');
                      }
                      return null;
                    },
                  ),

                  if (_vendors.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                          'No vendors found for this branch. Add a vendor first.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('inventory-store-$_selectedStoreId'),
                    initialValue: _selectedStoreId,
                    decoration: InputDecoration(labelText: context.t('Store')),
                    items: _stores.map((store) {
                      return DropdownMenuItem<int>(
                        value: _toInt(store['id']),
                        child: Text(
                          _firstText(
                            store,
                            const ['name', 'storeName'],
                            fallback: context.t('Store'),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStoreId = value);
                      _validateOnlyAfterSubmit();
                    },
                  ),

                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('Active')),
                    value: _active,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isSaving
                          ? (widget.isEdit
                              ? context.t('Updating...')
                              : context.t('Saving...'))
                          : (widget.isEdit
                              ? context.t('Update Inventory Item')
                              : context.t('Save Inventory Item'))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> store;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name =
        _firstText(store, const ['name', 'storeName'], fallback: 'N/A');
    final address = _firstText(store, const ['address'], fallback: 'N/A');

    return _InventoryRecordCard(
      title: name,
      subtitle: context.t('Store location'),
      icon: Icons.storefront_outlined,
      status: _statusLabel(store),
      onTap: onView,
      facts: [
        _InventoryFactData(
          icon: Icons.location_on_outlined,
          label: context.t('Address'),
          value: address,
        ),
      ],
      actions: _InventoryCardActions(
        onView: onView,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({
    required this.item,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = _firstText(
      item,
      const ['itemName', 'name', 'title'],
      fallback: 'N/A',
    );
    final sku = _firstText(item, const ['skuNumber', 'sku'], fallback: 'N/A');
    final category =
        _firstText(item, const ['category', 'categoryName'], fallback: 'N/A');
    final stock = _firstText(
      item,
      const ['stockLevel', 'availableStock', 'currentStock'],
      fallback: '0',
    );

    return _InventoryRecordCard(
      title: name,
      subtitle: '${context.t('SKU')}: $sku',
      icon: Icons.inventory_2_outlined,
      status: _statusLabel(item),
      onTap: onView,
      facts: [
        _InventoryFactData(
          icon: Icons.category_outlined,
          label: context.t('Category'),
          value: category,
        ),
        _InventoryFactData(
          icon: Icons.warehouse_outlined,
          label: context.t('Stock'),
          value: stock,
        ),
        _InventoryFactData(
          icon: Icons.sell_outlined,
          label: context.t('Unit Price'),
          value: _formatCurrency(item['costPerUnit'] ?? item['unitPrice']),
        ),
      ],
      actions: _InventoryCardActions(
        onView: onView,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({
    required this.order,
    required this.vendors,
    required this.onView,
  });

  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> vendors;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final poId = _firstText(order, const ['poId', 'id'], fallback: 'N/A');
    final requiredDate = _formatDateValue(
      order['requiredDeliveryDate'] ?? order['requiredDate'],
    );

    return _InventoryRecordCard(
      title: '${context.t('PO ID')} $poId',
      subtitle: _vendorDisplayLabel(order, vendors),
      icon: Icons.receipt_long_outlined,
      status: _statusLabel(order),
      onTap: onView,
      facts: [
        _InventoryFactData(
          icon: Icons.local_shipping_outlined,
          label: context.t('Vendor'),
          value: _vendorDisplayLabel(order, vendors),
        ),
        _InventoryFactData(
          icon: Icons.event_outlined,
          label: context.t('Required Date'),
          value: requiredDate,
        ),
      ],
      actions: _InventoryCardActions(onView: onView),
    );
  }
}

class _GoodsReceiptNoteCard extends StatelessWidget {
  const _GoodsReceiptNoteCard({
    required this.note,
    required this.vendors,
    required this.onView,
  });

  final Map<String, dynamic> note;
  final List<Map<String, dynamic>> vendors;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final grnId = _firstText(note, const ['grnId', 'id'], fallback: 'N/A');
    final poId = _firstText(
      note,
      const ['poId', 'purchaseOrderId'],
      fallback: 'N/A',
    );

    return _InventoryRecordCard(
      title: '${context.t('GRN ID')} $grnId',
      subtitle: '${context.t('PO ID')}: $poId',
      icon: Icons.assignment_turned_in_outlined,
      status: _statusLabel(note),
      onTap: onView,
      facts: [
        _InventoryFactData(
          icon: Icons.receipt_long_outlined,
          label: context.t('Purchase Order'),
          value: poId,
        ),
        _InventoryFactData(
          icon: Icons.local_shipping_outlined,
          label: context.t('Vendor'),
          value: _vendorDisplayLabel(note, vendors),
        ),
        _InventoryFactData(
          icon: Icons.event_available_outlined,
          label: context.t('Received Date'),
          value: _formatDateValue(note['receivedDate'] ?? note['createdAt']),
        ),
      ],
      actions: _InventoryCardActions(onView: onView),
    );
  }
}

class _InventoryFactData {
  const _InventoryFactData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InventoryCardActions {
  const _InventoryCardActions({
    required this.onView,
    this.onEdit,
    this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
}

class _InventoryRecordCard extends StatelessWidget {
  const _InventoryRecordCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.facts,
    required this.actions,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String status;
  final List<_InventoryFactData> facts;
  final _InventoryCardActions actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8DED6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8C774)),
                  ),
                  child: Icon(icon, color: AppColors.starColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1C1917),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _InventoryStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  facts.map((fact) => _InventoryFact(fact: fact)).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: actions.onView,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: Text(context.t('View')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                if (actions.onEdit != null) ...[
                  const SizedBox(width: 10),
                  _InventoryActionButton(
                    icon: Icons.edit_outlined,
                    color: AppColors.starColor,
                    onPressed: actions.onEdit!,
                  ),
                ],
                if (actions.onDelete != null) ...[
                  const SizedBox(width: 8),
                  _InventoryActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    onPressed: actions.onDelete!,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryStatusPill extends StatelessWidget {
  const _InventoryStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final positive = !normalized.contains('inactive') &&
        (normalized.contains('active') ||
            normalized.contains('approved') ||
            normalized.contains('received') ||
            normalized.contains('completed'));
    final color = positive ? const Color(0xFF168546) : AppColors.starColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InventoryFact extends StatelessWidget {
  const _InventoryFact({required this.fact});

  final _InventoryFactData fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fact.icon, size: 16, color: AppColors.starColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fact.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryActionButton extends StatelessWidget {
  const _InventoryActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: EdgeInsets.zero,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }
}
