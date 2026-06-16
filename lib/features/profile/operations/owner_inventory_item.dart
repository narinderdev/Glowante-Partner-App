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
      text: _firstText(initial, const ['costPerUnit', 'unitPrice']),
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
        'costPerUnit': _toDouble(_costController.text.trim()) ?? 0,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormSectionTitle(context.t('Basic Details')),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 120,
                    controller: _itemIdController,
                    decoration:
                        InputDecoration(labelText: context.t('Item ID')),
                    validator: widget.isEdit
                        ? (value) => _stringValue(value).isEmpty
                            ? context.t('Item ID is required')
                            : null
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _skuController,
                    decoration: InputDecoration(labelText: context.t('SKU')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('SKU is required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _nameController,
                    decoration:
                        InputDecoration(labelText: context.t('Item Name')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Item name is required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'inventory-category-$_selectedCategory',
                    ),
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
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
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
                    onChanged: (value) =>
                        setState(() => _selectedUnitOfMeasure = value),
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
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Reorder Qty')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _costController,
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
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: context.t('Max Stock')),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>(
                      'inventory-vendor-$_selectedVendorId',
                    ),
                    initialValue: _selectedVendorId,
                    decoration:
                        InputDecoration(labelText: context.t('Primary Vendor')),
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
                            const [
                              'name',
                              'vendorName',
                              'primaryVendorName',
                            ],
                            fallback: context.t('Vendor'),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedVendorId = value),
                  ),
                  if (_vendors.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        'No vendors found for this branch. Add a vendor first.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>(
                      'inventory-store-$_selectedStoreId',
                    ),
                    initialValue: _selectedStoreId,
                    decoration: InputDecoration(labelText: context.t('Store')),
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
                    onChanged: (value) =>
                        setState(() => _selectedStoreId = value),
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
