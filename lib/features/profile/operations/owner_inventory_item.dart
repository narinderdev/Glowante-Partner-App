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
  final _skuFieldKey = GlobalKey<FormFieldState<String>>();
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();
  final _reorderQtyFieldKey = GlobalKey<FormFieldState<String>>();
  final _costFieldKey = GlobalKey<FormFieldState<String>>();
  final _maxStockFieldKey = GlobalKey<FormFieldState<String>>();
  final _vendorFieldKey = GlobalKey<FormFieldState<int>>();
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
  final AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
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
  bool _showSkuError = false;
  bool _showNameError = false;
  bool _showCategoryError = false;
  bool _showReorderQtyError = false;
  bool _showCostError = false;
  bool _showMaxStockError = false;
  bool _showVendorError = false;

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
      text: _firstText(
        initial,
        const ['manufacturer', 'brand'],
      ),
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

  void _clearStringFieldError(
    GlobalKey<FormFieldState<String>> fieldKey,
    VoidCallback markClean,
  ) {
    markClean();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fieldKey.currentState?.validate();
    });
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
      _vendors = _recordList(results[1]).where(_isActiveRecord).toList();
      _stores = _recordList(results[2]).where(_isActiveRecord).toList();
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
    setState(() {
      _showSkuError = true;
      _showNameError = true;
      _showCategoryError = true;
      _showReorderQtyError = true;
      _showCostError = true;
      _showMaxStockError = true;
      _showVendorError = true;
    });

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
          ? const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.starColor),
              ),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: _inventoryInputDecorationTheme(),
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InventoryFormSection(
                      title: context.t('Basic Details'),
                      icon: Icons.inventory_2_outlined,
                      children: [
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
                          key: _skuFieldKey,
                          maxLength: 50,
                          controller: _skuController,
                          onChanged: (_) => _clearStringFieldError(
                            _skuFieldKey,
                            () => setState(() => _showSkuError = false),
                          ),
                          decoration:
                              InputDecoration(labelText: context.t('SKU')),
                          validator: (value) {
                            if (!_showSkuError) return null;
                            return _stringValue(value).isEmpty
                                ? context.t('SKU is required')
                                : null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: _nameFieldKey,
                          maxLength: 50,
                          controller: _nameController,
                          onChanged: (_) => _clearStringFieldError(
                            _nameFieldKey,
                            () => setState(() => _showNameError = false),
                          ),
                          decoration: InputDecoration(
                              labelText: context.t('Item Name')),
                          validator: (value) {
                            if (!_showNameError) return null;
                            return _stringValue(value).isEmpty
                                ? context.t('Item name is required')
                                : null;
                          },
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
                          key: _categoryFieldKey,
                          initialValue: _selectedCategory,
                          decoration:
                              InputDecoration(labelText: context.t('Category')),
                          isExpanded: true,
                          menuMaxHeight: 260,
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: _dropdownMenuText(category),
                                ),
                              )
                              .toList(),
                          validator: (value) {
                            if (!_showCategoryError) return null;
                            return _stringValue(value).isEmpty
                                ? context.t('Category is required')
                                : null;
                          },
                          onChanged: (value) {
                            setState(() => _selectedCategory = value);
                            _clearStringFieldError(
                              _categoryFieldKey,
                              () => setState(() => _showCategoryError = false),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          maxLength: 50,
                          controller: _brandController,
                          decoration:
                              InputDecoration(labelText: context.t('Brand')),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          maxLength: 10,
                          controller: _stockController,
                          inputFormatters: _integerInputFormatters(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.t('Stock Level')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InventoryFormSection(
                      title: context.t('Stock & Vendor Details'),
                      icon: Icons.local_shipping_outlined,
                      children: [
                        TextFormField(
                          maxLength: 10,
                          controller: _reorderPointController,
                          inputFormatters: _integerInputFormatters(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.t('Reorder Point')),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: _reorderQtyFieldKey,
                          maxLength: 10,
                          controller: _reorderQtyController,
                          inputFormatters: _integerInputFormatters(),
                          onChanged: (_) => _clearStringFieldError(
                            _reorderQtyFieldKey,
                            () => setState(() => _showReorderQtyError = false),
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.t('Reorder Qty')),
                          validator: (value) {
                            if (!_showReorderQtyError) return null;
                            final text = _stringValue(value);
                            if (text.isEmpty) {
                              return context.t('Reorder Qty is required');
                            }
                            final qty = _toInt(text);
                            if (qty == null || qty < 1) {
                              return context
                                  .t('Reorder Qty must be at least 1');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: _costFieldKey,
                          maxLength: 10,
                          controller: _costController,
                          inputFormatters: _decimalInputFormatters(),
                          onChanged: (_) => _clearStringFieldError(
                            _costFieldKey,
                            () => setState(() => _showCostError = false),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: context.t('Cost Per Unit')),
                          validator: (value) {
                            if (!_showCostError) return null;
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
                          maxLength: 15,
                          controller: _minStockController,
                          inputFormatters: _integerInputFormatters(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.t('Min Stock')),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: _maxStockFieldKey,
                          maxLength: 15,
                          controller: _maxStockController,
                          inputFormatters: _integerInputFormatters(),
                          onChanged: (_) => _clearStringFieldError(
                            _maxStockFieldKey,
                            () => setState(() => _showMaxStockError = false),
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.t('Max Stock')),
                          validator: (value) {
                            if (!_showMaxStockError) return null;
                            final text = _stringValue(value);
                            if (text.isEmpty) {
                              return context.t('Max Stock is required');
                            }
                            final maxStock = _toInt(text);
                            if (maxStock == null) {
                              return context.t('Max Stock must be a number');
                            }
                            if (maxStock < 1) {
                              return context.t('Max Stock must be at least 1');
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          key: _vendorFieldKey,
                          initialValue: _selectedVendorId,
                          decoration:
                              InputDecoration(labelText: context.t('Vendor')),
                          isExpanded: true,
                          menuMaxHeight: 260,
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
                              child: _dropdownMenuText(
                                _firstText(
                                  vendor,
                                  const [
                                    'name',
                                    'vendorName',
                                    'primaryVendorName'
                                  ],
                                  fallback: context.t('Vendor'),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedVendorId = value);
                            _clearIntFieldError(
                              _vendorFieldKey,
                              () => setState(() => _showVendorError = false),
                            );
                          },
                          validator: (value) {
                            if (!_showVendorError) return null;
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
                          key: ValueKey<String>(
                              'inventory-store-$_selectedStoreId'),
                          initialValue: _selectedStoreId,
                          decoration:
                              InputDecoration(labelText: context.t('Store')),
                          isExpanded: true,
                          menuMaxHeight: 260,
                          items: _stores.map((store) {
                            return DropdownMenuItem<int>(
                              value: _toInt(store['id']),
                              child: _dropdownMenuText(
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
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InventoryStatusSwitchCard(
                      active: _active,
                      enabled: !_isSaving,
                      onChanged: (value) => setState(() => _active = value),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.starColor.withValues(alpha: 0.55),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 5,
                          shadowColor: const Color(0x338B6500),
                        ),
                        label: Text(_isSaving
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
            ),
    );
  }

  InputDecorationTheme _inventoryInputDecorationTheme() {
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
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontSize: 11,
        height: 1.15,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
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

class _InventoryFormSection extends StatelessWidget {
  const _InventoryFormSection({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: Icon(icon, color: AppColors.starColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InventoryStatusSwitchCard extends StatelessWidget {
  const _InventoryStatusSwitchCard({
    required this.active,
    required this.enabled,
    required this.onChanged,
  });

  final bool active;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          context.t('Active'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1917),
          ),
        ),
        subtitle: Text(
          active
              ? context.t('Inventory item is active')
              : context.t('Inventory item is inactive'),
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontSize: 12,
          ),
        ),
        activeThumbColor: AppColors.starColor,
        activeTrackColor: AppColors.starColor.withValues(alpha: 0.35),
        value: active,
        onChanged: enabled ? onChanged : null,
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

class _InventoryItemDetailsView extends StatelessWidget {
  const _InventoryItemDetailsView({
    required this.detail,
    required this.stores,
    required this.onEdit,
  });

  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> stores;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = _firstText(
      detail,
      const <String>['itemName', 'name', 'title'],
      fallback: context.t('Inventory Item'),
    );
    final sku = _firstText(detail, const <String>['skuNumber', 'sku']);
    final active = _statusLabel(detail) == 'ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8DED6)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.starColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1C1917),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (sku.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${context.t('SKU')}: $sku',
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StoreStatusPill(active: active),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InventoryDetailsCard(
          title: context.t('Item Details'),
          rows: [
            _InventoryDetailRowData(
              icon: Icons.tag_outlined,
              label: context.t('Item ID'),
              value: _firstText(detail, const <String>['id', 'itemId']),
            ),
            _InventoryDetailRowData(
              icon: Icons.category_outlined,
              label: context.t('Category'),
              value: _firstText(
                detail,
                const <String>['category', 'categoryName'],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.business_outlined,
              label: context.t('Brand'),
              value: _firstText(
                detail,
                const <String>['brand', 'manufacturer'],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.currency_rupee_outlined,
              label: context.t('Cost Per Unit'),
              value:
                  _formatCurrency(detail['costPerUnit'] ?? detail['unitPrice']),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InventoryDetailsCard(
          title: context.t('Stock Details'),
          rows: [
            _InventoryDetailRowData(
              icon: Icons.warehouse_outlined,
              label: context.t('Stock Level'),
              value: _firstText(
                detail,
                const <String>['stockLevel', 'availableStock', 'currentStock'],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.add_outlined,
              label: context.t('Max Stock Level'),
              value: _firstText(
                detail,
                const <String>['maxStockLevel', 'maximumStock'],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.low_priority_outlined,
              label: context.t('Reorder Point'),
              value: _firstText(detail, const <String>['reorderPoint']),
            ),
            _InventoryDetailRowData(
              icon: Icons.add_box_outlined,
              label: context.t('Reorder Qty'),
              value: _firstText(
                detail,
                const <String>['reorderQuantity', 'reorderQty'],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.local_shipping_outlined,
              label: context.t('Vendor'),
              value: _firstText(
                detail,
                const <String>[
                  'primaryVendorName',
                  'vendorName',
                  'vendorId',
                  'primaryVendorId',
                  'primaryVendorDbId',
                ],
              ),
            ),
            _InventoryDetailRowData(
              icon: Icons.storefront_outlined,
              label: context.t('Store'),
              value: _storeDisplayLabel(detail, stores),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.t('Edit Inventory Item')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            elevation: 5,
            shadowColor: AppColors.starColor.withValues(alpha: 0.22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
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
    final poNumber = _firstText(
      order,
      const ['poNumber', 'poId', 'id'],
      fallback: 'N/A',
    );
    final requiredDate = _formatDateValue(
      order['requiredDeliveryDate'] ?? order['requiredDate'],
    );

    return _InventoryRecordCard(
      title: '${context.t('PO Number')} $poNumber',
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

class _InventoryDetailRowData {
  const _InventoryDetailRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InventoryDetailsCard extends StatelessWidget {
  const _InventoryDetailsCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_InventoryDetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows =
        rows.where((row) => row.value.trim().isNotEmpty).toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1C1917),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...visibleRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InventoryDetailsTile(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryDetailsTile extends StatelessWidget {
  const _InventoryDetailsTile({required this.row});

  final _InventoryDetailRowData row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(row.icon, color: AppColors.starColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF8A8178),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.value,
                style: const TextStyle(
                  color: Color(0xFF1C1917),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final poNumber = _firstText(
      note,
      const ['poNumber', 'poId', 'purchaseOrderId'],
      fallback: 'N/A',
    );

    return _InventoryRecordCard(
      title: '${context.t('GRN ID')} $grnId',
      subtitle: '${context.t('PO Number')}: $poNumber',
      icon: Icons.assignment_turned_in_outlined,
      status: _statusLabel(note),
      onTap: onView,
      facts: [
        _InventoryFactData(
          icon: Icons.receipt_long_outlined,
          label: context.t('Purchase Order'),
          value: poNumber,
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
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
