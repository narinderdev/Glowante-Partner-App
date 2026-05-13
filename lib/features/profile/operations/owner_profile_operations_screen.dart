import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/stylist_branch_selection.dart';
import '../../../utils/api_service.dart';
import '../../../utils/colors.dart';
import '../../../utils/localization_helper.dart';
import '../../salon/widgets/owner_branch_header_selector.dart';
import '../widgets/profile_subpage_app_bar.dart';

part 'owner_profile_operations_widgets.dart';
part 'owner_profile_operations_form_shared.dart';
part 'owner_vendor.dart';
part 'owner_store.dart';
part 'owner_inventory_item.dart';
part 'owner_purchase_order.dart';
part 'owner_goods_receipt_note.dart';

enum OwnerOperationsModule { vendor, inventory }

enum _InventoryTab { store, inventoryItem, purchaseOrder, goodsReceiptNote }

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

String _stringValue(dynamic value) => value?.toString().trim() ?? '';

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final text = _stringValue(map[key]);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

bool _boolValue(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = _stringValue(value).toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

bool _responseSuccess(Map<String, dynamic> response) =>
    response['success'] != false;

String _responseMessage(
  Map<String, dynamic> response, {
  String fallback = 'Something went wrong',
}) {
  final message = _stringValue(response['message']);
  return message.isEmpty ? fallback : message;
}

Map<String, dynamic> _detailMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return raw;
  }
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _recordList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (raw is Map<String, dynamic>) {
    for (final key in const <String>[
      'data',
      'items',
      'rows',
      'results',
      'vendors',
      'stores',
      'purchaseOrders',
      'grns',
      'lines',
      'list',
    ]) {
      final nested = _recordList(raw[key]);
      if (nested.isNotEmpty) return nested;
    }
    for (final value in raw.values) {
      final nested = _recordList(value);
      if (nested.isNotEmpty) return nested;
    }
    return const <Map<String, dynamic>>[];
  }
  if (raw is Map) {
    return _recordList(Map<String, dynamic>.from(raw));
  }
  return const <Map<String, dynamic>>[];
}

List<String> _stringOptions(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item is Map
            ? _firstText(
                Map<String, dynamic>.from(item),
                const <String>['label', 'name', 'value', 'title'],
              )
            : _stringValue(item))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
  if (raw is Map) {
    return _stringOptions(
      raw['data'] ??
          raw['items'] ??
          raw['categories'] ??
          raw['options'] ??
          raw['rows'] ??
          raw['results'],
    );
  }
  return const <String>[];
}

String _statusLabel(Map<String, dynamic> record) {
  final explicit = _firstText(
    record,
    const <String>['status', 'state', 'inventoryStatus', 'orderStatus'],
  );
  if (explicit.isNotEmpty) return explicit.toUpperCase();
  return _boolValue(record['active'], fallback: true) ? 'ACTIVE' : 'INACTIVE';
}

String _formatDateValue(dynamic value, {String pattern = 'dd MMM yyyy'}) {
  final text = _stringValue(value);
  if (text.isEmpty) return 'N/A';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  return DateFormat(pattern).format(parsed.toLocal());
}

String _formatCurrency(dynamic value) {
  final amount = _toDouble(value);
  if (amount == null) return 'N/A';
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  ).format(amount);
}

String _vendorDisplayLabel(
  Map<String, dynamic> record,
  List<Map<String, dynamic>> vendors,
) {
  final direct = _firstText(
    record,
    const <String>['vendorName', 'vendor', 'primaryVendorName'],
  );
  if (direct.isNotEmpty) return direct;

  final vendorId = _toInt(record['vendorId'] ?? record['primaryVendorDbId']);
  if (vendorId != null) {
    for (final vendor in vendors) {
      if (_toInt(vendor['id']) == vendorId) {
        final label = _firstText(
          vendor,
          const <String>['vendorName', 'name', 'primaryVendorName'],
        );
        if (label.isNotEmpty) return label;
      }
    }
  }

  return 'N/A';
}

bool _purchaseOrderFullyReceived(List<Map<String, dynamic>> lines) {
  if (lines.isEmpty) return false;
  for (final line in lines) {
    final orderedQty = _toInt(line['orderedQty'] ?? line['quantity']) ?? 0;
    final receivedQty = _toInt(line['receivedQty']) ?? 0;
    if (receivedQty < orderedQty) {
      return false;
    }
  }
  return true;
}

class OwnerProfileOperationsScreen extends StatefulWidget {
  const OwnerProfileOperationsScreen({
    super.key,
    required this.initialModule,
  });

  final OwnerOperationsModule initialModule;

  @override
  State<OwnerProfileOperationsScreen> createState() =>
      _OwnerProfileOperationsScreenState();
}

class _OwnerProfileOperationsScreenState
    extends State<OwnerProfileOperationsScreen> {
  final ApiService _apiService = ApiService();

  List<_BranchOption> _branchOptions = const <_BranchOption>[];
  _BranchOption? _selectedBranch;
  bool _isLoadingBranches = true;
  bool _isLoadingContent = false;
  String? _branchError;
  String? _contentError;

  _InventoryTab _inventoryTab = _InventoryTab.store;

  List<Map<String, dynamic>> _vendors = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stores = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _inventoryItems = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _purchaseOrders = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _goodsReceiptNotes =
      const <Map<String, dynamic>>[];

  int _inventoryPage = 1;
  final int _inventoryLimit = 20;
  int _inventoryTotal = 0;

  bool get _isVendorModule =>
      widget.initialModule == OwnerOperationsModule.vendor;

  String get _moduleLogLabel =>
      _isVendorModule ? 'vendor' : 'inventory/${_inventoryTab.name}';

  void _logOperations(String event, {Object? details}) {
    debugPrint(
      '[OwnerOperations:$_moduleLogLabel] $event${details == null ? '' : ' | $details'}',
    );
  }

  String _t(String key, {Map<String, String>? params}) =>
      translateText(key, params: params);

  @override
  void initState() {
    super.initState();
    _logOperations('init');
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    _logOperations('load_branches_start');
    setState(() {
      _isLoadingBranches = true;
      _branchError = null;
    });

    try {
      final response = await _apiService.getSalonListApi();
      final options = <_BranchOption>[];
      final salons = (response['data'] as List?) ?? const <dynamic>[];
      for (final salonEntry in salons) {
        if (salonEntry is! Map) continue;
        final salon = Map<String, dynamic>.from(salonEntry);
        final salonId = _toInt(salon['id']);
        if (salonId == null) continue;
        final salonName = _stringValue(salon['name']);
        final branches = (salon['branches'] as List?) ?? const <dynamic>[];
        for (final branchEntry in branches) {
          if (branchEntry is! Map) continue;
          final branch = Map<String, dynamic>.from(branchEntry);
          final branchId = _toInt(branch['id']);
          if (branchId == null) continue;
          options.add(
            _BranchOption(
              salonId: salonId,
              branchId: branchId,
              salonName: salonName,
              branchName: _stringValue(branch['name']),
            ),
          );
        }
      }

      final saved = await StylistBranchSelectionStore.load();
      _BranchOption? selected;
      if (saved.branchId != null) {
        for (final option in options) {
          if (option.branchId == saved.branchId) {
            selected = option;
            break;
          }
        }
      }
      selected ??= options.isNotEmpty ? options.first : null;

      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranch = selected;
        _isLoadingBranches = false;
      });
      _logOperations(
        'load_branches_success',
        details:
            'count=${options.length}, selectedBranchId=${selected?.branchId}',
      );

      if (selected != null) {
        await _reloadCurrent();
      }
    } catch (error) {
      _logOperations('load_branches_failure', details: error);
      if (!mounted) return;
      setState(() {
        _isLoadingBranches = false;
        _branchError = error.toString();
      });
    }
  }

  Future<void> _switchBranch(_BranchOption option) async {
    if (_selectedBranch?.branchId == option.branchId) return;
    _logOperations(
      'switch_branch',
      details: 'from=${_selectedBranch?.branchId} to=${option.branchId}',
    );
    setState(() {
      _selectedBranch = option;
      _contentError = null;
    });
    await StylistBranchSelectionStore.save(
      salonId: option.salonId,
      branchId: option.branchId,
      salonName: option.salonName,
      branchName: option.branchName,
    );
    await _reloadCurrent();
  }

  Future<void> _reloadCurrent({bool showLoader = true}) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations(
      'reload_start',
      details: 'branchId=$branchId, showLoader=$showLoader',
    );

    if (showLoader) {
      setState(() {
        _isLoadingContent = true;
        _contentError = null;
      });
    } else {
      setState(() {
        _contentError = null;
      });
    }

    try {
      if (_isVendorModule) {
        await _loadVendors(branchId);
      } else {
        switch (_inventoryTab) {
          case _InventoryTab.store:
            await _loadStores(branchId);
            break;
          case _InventoryTab.inventoryItem:
            await _loadInventoryItems(branchId, page: _inventoryPage);
            break;
          case _InventoryTab.purchaseOrder:
            await _loadPurchaseOrders(branchId);
            break;
          case _InventoryTab.goodsReceiptNote:
            await _loadGoodsReceiptNotes(branchId);
            break;
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoadingContent = false;
      });
      _logOperations('reload_success', details: 'branchId=$branchId');
    } catch (error) {
      _logOperations('reload_failure', details: error);
      if (!mounted) return;
      setState(() {
        _isLoadingContent = false;
        _contentError = error.toString();
      });
    }
  }

  void _ensureSuccess(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    if (!_responseSuccess(response)) {
      throw Exception(_responseMessage(response, fallback: fallback));
    }
  }

  Future<void> _loadVendors(int branchId) async {
    _logOperations('load_vendors_start', details: 'branchId=$branchId');
    final response = await _apiService.getBranchVendors(branchId);
    final records = _recordList(response);
    _logOperations(
      'load_vendors_success',
      details: 'branchId=$branchId, count=${records.length}',
    );
    if (!mounted) return;
    setState(() {
      _vendors = records;
      _contentError = !_responseSuccess(response) && records.isEmpty
          ? _responseMessage(response, fallback: _t('Failed to load vendors'))
          : null;
    });
  }

  Future<void> _loadStores(int branchId) async {
    _logOperations('load_stores_start', details: 'branchId=$branchId');
    final response = await _apiService.getStores(branchId);
    final records = _recordList(response);
    _logOperations(
      'load_stores_success',
      details: 'branchId=$branchId, count=${records.length}',
    );
    if (!mounted) return;
    setState(() {
      _stores = records;
      _contentError = !_responseSuccess(response) && records.isEmpty
          ? _responseMessage(response, fallback: _t('Failed to load stores'))
          : null;
    });
  }

  Future<void> _loadInventoryItems(int branchId, {required int page}) async {
    _logOperations(
      'load_inventory_items_start',
      details: 'branchId=$branchId, page=$page, limit=$_inventoryLimit',
    );
    final response = await _apiService.fetchInventoryItems(
      branchId,
      page: page,
      limit: _inventoryLimit,
    );
    final payload = response['data'];
    final items = payload is Map<String, dynamic>
        ? _recordList(payload['items'] ?? payload['rows'] ?? payload)
        : _recordList(payload);
    final total = payload is Map<String, dynamic>
        ? _toInt(payload['total'] ?? payload['count'] ?? payload['totalItems'])
        : null;
    _logOperations(
      'load_inventory_items_success',
      details:
          'branchId=$branchId, page=$page, count=${items.length}, total=${total ?? items.length}',
    );
    if (!mounted) return;
    setState(() {
      _inventoryItems = items;
      _inventoryPage = page;
      _inventoryTotal = total ?? items.length;
      _contentError = !_responseSuccess(response) && items.isEmpty
          ? _responseMessage(
              response,
              fallback: _t('Failed to load inventory items'),
            )
          : null;
    });
  }

  Future<void> _loadPurchaseOrders(int branchId) async {
    _logOperations('load_purchase_orders_start', details: 'branchId=$branchId');
    final results = await Future.wait<Map<String, dynamic>>([
      _apiService.getPurchaseOrders(branchId),
      _apiService.getBranchVendors(branchId),
    ]);
    final response = results[0];
    final vendorResponse = results[1];
    final records = _recordList(response);
    final vendors = _recordList(vendorResponse);
    _logOperations(
      'load_purchase_orders_success',
      details: 'branchId=$branchId, count=${records.length}',
    );
    if (!mounted) return;
    setState(() {
      _vendors = vendors;
      _purchaseOrders = records;
      _contentError = !_responseSuccess(response) && records.isEmpty
          ? _responseMessage(
              response,
              fallback: _t('Failed to load purchase orders'),
            )
          : null;
    });
  }

  Future<void> _loadGoodsReceiptNotes(int branchId) async {
    _logOperations('load_grn_start', details: 'branchId=$branchId');
    final results = await Future.wait<Map<String, dynamic>>([
      _apiService.getGoodsReceiptNotes(branchId),
      _apiService.getBranchVendors(branchId),
    ]);
    final response = results[0];
    final vendorResponse = results[1];
    final records = _recordList(response);
    final vendors = _recordList(vendorResponse);
    _logOperations(
      'load_grn_success',
      details: 'branchId=$branchId, count=${records.length}',
    );
    if (!mounted) return;
    setState(() {
      _vendors = vendors;
      _goodsReceiptNotes = records;
      _contentError = !_responseSuccess(response) && records.isEmpty
          ? _responseMessage(
              response,
              fallback: _t('Failed to load goods receipt notes'),
            )
          : null;
    });
  }

  void _showToast(String message) {
    _logOperations('toast', details: message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFormDialog({
    required Widget Function(BuildContext dialogContext) builder,
    bool fullscreen = false,
    double? maxWidth,
    double? maxHeight,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: fullscreen
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? (fullscreen ? 980 : 700),
              maxHeight: maxHeight ?? (fullscreen ? 760 : 720),
            ),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  Future<void> _saveVendor(
    Map<String, dynamic> payload, {
    Map<String, dynamic>? editingVendor,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    final isEdit = editingVendor != null;
    final vendorId = _toInt(editingVendor?['id']);
    _logOperations(
      'save_vendor_start',
      details: 'branchId=$branchId, isEdit=$isEdit, vendorId=$vendorId',
    );
    final response = isEdit && vendorId != null
        ? await _apiService.updateVendor(
            branchId: branchId,
            vendorId: vendorId,
            payload: payload,
          )
        : await _apiService.createVendor(branchId: branchId, payload: payload);
    _ensureSuccess(
      response,
      fallback:
          isEdit ? _t('Failed to update vendor') : _t('Failed to save vendor'),
    );
    _logOperations(
      'save_vendor_success',
      details: 'branchId=$branchId, isEdit=$isEdit, vendorId=$vendorId',
    );
    await _loadVendors(branchId);
    _showToast(isEdit
        ? _t('Vendor updated successfully')
        : _t('Vendor saved successfully'));
  }

  Future<void> _saveStore(
    Map<String, dynamic> payload, {
    Map<String, dynamic>? editingStore,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    final isEdit = editingStore != null;
    final storeId = _toInt(editingStore?['id']);
    _logOperations(
      'save_store_start',
      details: 'branchId=$branchId, isEdit=$isEdit, storeId=$storeId',
    );
    final response = isEdit && storeId != null
        ? await _apiService.updateStore(
            branchId: branchId,
            storeId: storeId,
            payload: payload,
          )
        : await _apiService.createStore(branchId: branchId, payload: payload);
    _ensureSuccess(
      response,
      fallback:
          isEdit ? _t('Failed to update store') : _t('Failed to save store'),
    );
    _logOperations(
      'save_store_success',
      details: 'branchId=$branchId, isEdit=$isEdit, storeId=$storeId',
    );
    await _loadStores(branchId);
    _showToast(isEdit
        ? _t('Store updated successfully')
        : _t('Store saved successfully'));
  }

  Future<void> _saveInventoryItem(
    Map<String, dynamic> payload, {
    Map<String, dynamic>? editingItem,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    final isEdit = editingItem != null;
    final inventoryId = _toInt(editingItem?['id']);
    _logOperations(
      'save_inventory_item_start',
      details:
          'branchId=$branchId, isEdit=$isEdit, inventoryId=$inventoryId, page=$_inventoryPage',
    );
    final response = isEdit && inventoryId != null
        ? await _apiService.updateInventoryItem(
            branchId: branchId,
            inventoryId: inventoryId,
            payload: payload,
          )
        : await _apiService.createInventoryItem(
            branchId: branchId,
            payload: payload,
          );
    _ensureSuccess(
      response,
      fallback: isEdit
          ? _t('Failed to update inventory item')
          : _t('Failed to save inventory item'),
    );
    _logOperations(
      'save_inventory_item_success',
      details:
          'branchId=$branchId, isEdit=$isEdit, inventoryId=$inventoryId, page=$_inventoryPage',
    );
    await _loadInventoryItems(branchId, page: _inventoryPage);
    _showToast(
      isEdit
          ? _t('Inventory item updated successfully')
          : _t('Inventory item saved successfully'),
    );
  }

  Future<void> _savePurchaseOrder(Map<String, dynamic> payload) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations('save_purchase_order_start', details: 'branchId=$branchId');
    final response = await _apiService.createPurchaseOrder(
      branchId: branchId,
      payload: payload,
    );
    _ensureSuccess(response, fallback: _t('Failed to save purchase order'));
    _logOperations('save_purchase_order_success',
        details: 'branchId=$branchId');
    await _loadPurchaseOrders(branchId);
    _showToast(_t('Purchase order saved successfully'));
  }

  Future<void> _saveGoodsReceiptNote(Map<String, dynamic> payload) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations(
      'save_grn_start',
      details: 'branchId=$branchId',
    );
    final response = await _apiService.createGoodsReceiptNote(
      branchId: branchId,
      payload: payload,
    );
    _ensureSuccess(response, fallback: _t('Failed to save goods receipt note'));
    _logOperations(
      'save_grn_success',
      details: 'branchId=$branchId',
    );
    await _loadGoodsReceiptNotes(branchId);
    _showToast(_t('Goods receipt note saved successfully'));
  }

  Future<void> _openVendorFormDialog({
    Map<String, dynamic>? initialVendor,
  }) async {
    final isEdit = initialVendor != null;
    _logOperations(
      isEdit ? 'vendor_edit_dialog_open' : 'vendor_add_dialog_open',
      details: isEdit ? 'vendorId=${_toInt(initialVendor['id'])}' : null,
    );
    await _showFormDialog(
      builder: (dialogContext) => _VendorFormView(
        initialVendor: initialVendor,
        isEdit: isEdit,
        onBack: () => Navigator.of(dialogContext).pop(),
        onSubmit: (payload) async {
          await _saveVendor(payload, editingVendor: initialVendor);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _openStoreFormDialog({
    Map<String, dynamic>? initialStore,
  }) async {
    final isEdit = initialStore != null;
    _logOperations(
      isEdit ? 'store_edit_dialog_open' : 'store_add_dialog_open',
      details: isEdit ? 'storeId=${_toInt(initialStore['id'])}' : null,
    );
    await _showFormDialog(
      maxWidth: 560,
      maxHeight: 560,
      builder: (dialogContext) => _StoreFormView(
        initialStore: initialStore,
        isEdit: isEdit,
        onBack: () => Navigator.of(dialogContext).pop(),
        onSubmit: (payload) async {
          await _saveStore(payload, editingStore: initialStore);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _openInventoryItemFormDialog({
    Map<String, dynamic>? initialItem,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    final isEdit = initialItem != null;
    _logOperations(
      isEdit
          ? 'inventory_item_edit_dialog_open'
          : 'inventory_item_add_dialog_open',
      details: isEdit ? 'inventoryId=${_toInt(initialItem['id'])}' : null,
    );
    await _showFormDialog(
      builder: (dialogContext) => _InventoryItemFormView(
        branchId: branchId,
        initialItem: initialItem,
        isEdit: isEdit,
        onBack: () => Navigator.of(dialogContext).pop(),
        onSubmit: (payload) async {
          await _saveInventoryItem(payload, editingItem: initialItem);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _openPurchaseOrderFormDialog() async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations('purchase_order_add_dialog_open');
    await _showFormDialog(
      fullscreen: true,
      builder: (dialogContext) => _PurchaseOrderFormView(
        branchId: branchId,
        onBack: () => Navigator.of(dialogContext).pop(),
        onSubmit: (payload) async {
          await _savePurchaseOrder(payload);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _openGoodsReceiptNoteFormDialog({int? prefilledPoId}) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations(
      'grn_add_dialog_open',
      details: prefilledPoId == null ? null : 'prefilledPoId=$prefilledPoId',
    );
    await _showFormDialog(
      fullscreen: true,
      builder: (dialogContext) => _GoodsReceiptNoteFormView(
        branchId: branchId,
        prefilledPoId: prefilledPoId,
        onBack: () => Navigator.of(dialogContext).pop(),
        onSubmit: (payload) async {
          await _saveGoodsReceiptNote(payload);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _confirmVendorDelete(Map<String, dynamic> vendor) async {
    final branchId = _selectedBranch?.branchId;
    final vendorId = _toInt(vendor['id']);
    if (branchId == null || vendorId == null) return;
    _logOperations(
      'confirm_vendor_delete_open',
      details: 'branchId=$branchId, vendorId=$vendorId',
    );
    await _showDeleteDialog(
      title: _t('Delete Vendor'),
      description: _t('Are you sure you want to delete this vendor?'),
      onDelete: () async {
        _logOperations(
          'delete_vendor_start',
          details: 'branchId=$branchId, vendorId=$vendorId',
        );
        final response = await _apiService.deleteVendor(
          branchId: branchId,
          vendorId: vendorId,
        );
        _ensureSuccess(response, fallback: _t('Failed to delete vendor'));
        _logOperations(
          'delete_vendor_success',
          details: 'branchId=$branchId, vendorId=$vendorId',
        );
        await _loadVendors(branchId);
        _showToast(_t('Vendor deleted successfully'));
      },
    );
  }

  Future<void> _confirmStoreDelete(Map<String, dynamic> store) async {
    final branchId = _selectedBranch?.branchId;
    final storeId = _toInt(store['id']);
    if (branchId == null || storeId == null) return;
    _logOperations(
      'confirm_store_delete_open',
      details: 'branchId=$branchId, storeId=$storeId',
    );
    await _showDeleteDialog(
      title: _t('Delete Store'),
      description: _t('Are you sure you want to delete this store?'),
      onDelete: () async {
        _logOperations(
          'delete_store_start',
          details: 'branchId=$branchId, storeId=$storeId',
        );
        final response = await _apiService.deleteStore(
          branchId: branchId,
          storeId: storeId,
        );
        _ensureSuccess(response, fallback: _t('Failed to delete store'));
        _logOperations(
          'delete_store_success',
          details: 'branchId=$branchId, storeId=$storeId',
        );
        await _loadStores(branchId);
        _showToast(_t('Store deleted successfully'));
      },
    );
  }

  Future<void> _confirmInventoryItemDelete(Map<String, dynamic> item) async {
    final branchId = _selectedBranch?.branchId;
    final inventoryId = _toInt(item['id']);
    if (branchId == null || inventoryId == null) return;
    _logOperations(
      'confirm_inventory_item_delete_open',
      details: 'branchId=$branchId, inventoryId=$inventoryId',
    );
    await _showDeleteDialog(
      title: _t('Delete Inventory Item'),
      description: _t('Are you sure you want to delete this inventory item?'),
      onDelete: () async {
        _logOperations(
          'delete_inventory_item_start',
          details: 'branchId=$branchId, inventoryId=$inventoryId',
        );
        final response = await _apiService.deleteInventoryItem(
          branchId: branchId,
          inventoryId: inventoryId,
        );
        _ensureSuccess(response,
            fallback: _t('Failed to delete inventory item'));
        _logOperations(
          'delete_inventory_item_success',
          details: 'branchId=$branchId, inventoryId=$inventoryId',
        );
        await _loadInventoryItems(branchId, page: _inventoryPage);
        _showToast(_t('Inventory item deleted successfully'));
      },
    );
  }

  Future<void> _showDeleteDialog({
    required String title,
    required String description,
    required Future<void> Function() onDelete,
  }) async {
    _logOperations('delete_dialog_open', details: title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleDelete() async {
              setDialogState(() => isDeleting = true);
              try {
                await onDelete();
                _logOperations('delete_dialog_success', details: title);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (error) {
                _logOperations('delete_dialog_failure', details: error);
                if (!mounted) return;
                _showToast(error.toString());
                if (dialogContext.mounted) {
                  setDialogState(() => isDeleting = false);
                }
              }
            }

            return AlertDialog(
              title: Text(title),
              content: Text(description),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: Text(_t('Cancel')),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : handleDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isDeleting ? _t('Deleting...') : _t('Delete')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showVendorDetails(Map<String, dynamic> vendor) async {
    final branchId = _selectedBranch?.branchId;
    final vendorId = _toInt(vendor['id']);
    if (branchId == null || vendorId == null) return;
    _logOperations(
      'vendor_details_open',
      details: 'branchId=$branchId, vendorId=$vendorId',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AsyncDetailsDialog(
          title: _firstText(
            vendor,
            const <String>['name', 'vendorName'],
            fallback: 'Vendor Details',
          ),
          future: _apiService.getVendorDetails(
              branchId: branchId, vendorId: vendorId),
          builder: (detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                  label: 'Name',
                  value: _firstText(detail, const ['name', 'vendorName'],
                      fallback: 'N/A')),
              _DetailLine(label: 'Status', value: _statusLabel(detail)),
              _DetailLine(
                  label: 'Phone',
                  value: _firstText(
                      detail,
                      const [
                        'phoneNumber',
                        'phone',
                        'mobileNumber',
                        'contactNumber'
                      ],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Email',
                  value: _firstText(detail, const ['email'], fallback: 'N/A')),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _logOperations(
                      'vendor_edit_from_details',
                      details: 'branchId=$branchId, vendorId=$vendorId',
                    );
                    _openVendorFormDialog(initialVendor: detail);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Edit Vendor'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showStoreDetails(Map<String, dynamic> store) async {
    final branchId = _selectedBranch?.branchId;
    final storeId = _toInt(store['id']);
    if (branchId == null || storeId == null) return;
    _logOperations(
      'store_details_open',
      details: 'branchId=$branchId, storeId=$storeId',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AsyncDetailsDialog(
          title: _firstText(
            store,
            const <String>['name', 'storeName'],
            fallback: 'Store Details',
          ),
          maxWidth: 520,
          maxHeight: 420,
          future:
              _apiService.getStoreDetails(branchId: branchId, storeId: storeId),
          builder: (detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                  label: 'Name',
                  value: _firstText(detail, const ['name', 'storeName'],
                      fallback: 'N/A')),
              _DetailLine(label: 'Status', value: _statusLabel(detail)),
              _DetailLine(
                  label: 'Address',
                  value:
                      _firstText(detail, const ['address'], fallback: 'N/A')),
              _DetailLine(
                  label: 'Bin Description',
                  value: _firstText(detail, const ['binDescription', 'bin'],
                      fallback: 'N/A')),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _logOperations(
                      'store_edit_from_details',
                      details: 'branchId=$branchId, storeId=$storeId',
                    );
                    _openStoreFormDialog(initialStore: detail);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Edit Store'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInventoryItemDetails(Map<String, dynamic> item) async {
    final branchId = _selectedBranch?.branchId;
    final inventoryId = _toInt(item['id']);
    if (branchId == null || inventoryId == null) return;
    _logOperations(
      'inventory_item_details_open',
      details: 'branchId=$branchId, inventoryId=$inventoryId',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AsyncDetailsDialog(
          title: _firstText(
            item,
            const <String>['itemName', 'name', 'title'],
            fallback: 'Inventory Item Details',
          ),
          future: _apiService.getInventoryItemDetails(
            branchId: branchId,
            inventoryId: inventoryId,
          ),
          builder: (detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                  label: 'ID',
                  value: _firstText(detail, const ['id', 'itemId'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'SKU',
                  value: _firstText(detail, const ['skuNumber', 'sku'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Category',
                  value: _firstText(detail, const ['category', 'categoryName'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Brand',
                  value: _firstText(detail, const ['brand', 'manufacturer'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Stock Level',
                  value: _firstText(detail,
                      const ['stockLevel', 'availableStock', 'currentStock'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Reorder Point',
                  value: _firstText(detail, const ['reorderPoint'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Reorder Qty',
                  value: _firstText(
                      detail, const ['reorderQuantity', 'reorderQty'],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Cost Per Unit',
                  value: _formatCurrency(
                      detail['costPerUnit'] ?? detail['unitPrice'])),
              _DetailLine(
                  label: 'Vendor',
                  value: _firstText(
                      detail,
                      const [
                        'primaryVendorName',
                        'vendorName',
                        'vendorId',
                        'primaryVendorId',
                        'primaryVendorDbId',
                      ],
                      fallback: 'N/A')),
              _DetailLine(
                  label: 'Store ID',
                  value:
                      _firstText(detail, const ['storeId'], fallback: 'N/A')),
              _DetailLine(label: 'Status', value: _statusLabel(detail)),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _logOperations(
                      'inventory_item_edit_from_details',
                      details: 'branchId=$branchId, inventoryId=$inventoryId',
                    );
                    _openInventoryItemFormDialog(initialItem: detail);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Edit Inventory Item'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPurchaseOrderDetails(Map<String, dynamic> order) async {
    final branchId = _selectedBranch?.branchId;
    final poId = _toInt(order['id'] ?? order['poId']);
    if (branchId == null || poId == null) return;
    _logOperations(
      'purchase_order_details_open',
      details: 'branchId=$branchId, poId=$poId',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AsyncDetailsDialog(
          title: _firstText(order, const ['poId', 'id'],
              fallback: 'Purchase Order'),
          future: _apiService.getPurchaseOrderDetails(
              branchId: branchId, poId: poId),
          builder: (detail) {
            final lines = _recordList(detail['lines'] ?? detail['items']);
            final status = _statusLabel(detail);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailLine(
                    label: 'PO ID',
                    value: _firstText(detail, const ['poId', 'id'],
                        fallback: 'N/A')),
                _DetailLine(
                    label: 'Vendor',
                    value: _vendorDisplayLabel(detail, _vendors)),
                _DetailLine(
                    label: 'Required Date',
                    value: _formatDateValue(detail['requiredDeliveryDate'] ??
                        detail['requiredDate'])),
                _DetailLine(label: 'Status', value: status),
                const SizedBox(height: 12),
                const Text(
                  'Order Lines',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Text('No lines found')
                else
                  _LinesTable(
                    rows: lines
                        .map(
                          (line) => <String>[
                            _firstText(
                                line, const ['itemName', 'name', 'title'],
                                fallback: 'Item'),
                            _firstText(line, const ['orderedQty', 'quantity'],
                                fallback: '0'),
                            _formatCurrency(
                                line['unitPrice'] ?? line['costPerUnit']),
                          ],
                        )
                        .toList(),
                    headers: const <String>['Item', 'Qty', 'Unit Price'],
                  ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        _logOperations(
                          'purchase_order_status_dialog_from_details',
                          details:
                              'branchId=$branchId, poId=$poId, status=$status',
                        );
                        await _showPurchaseOrderStatusDialog(
                          poId: poId,
                          currentStatus: status,
                          lines: lines,
                        );
                      },
                      child: const Text('Update Status'),
                    ),
                    if (status == 'ISSUED')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _logOperations(
                            'purchase_order_convert_to_grn',
                            details: 'branchId=$branchId, poId=$poId',
                          );
                          _openGoodsReceiptNoteFormDialog(prefilledPoId: poId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Convert to GRN'),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPurchaseOrderStatusDialog({
    required int poId,
    required String currentStatus,
    List<Map<String, dynamic>> lines = const <Map<String, dynamic>>[],
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) return;
    _logOperations(
      'purchase_order_status_dialog_open',
      details: 'branchId=$branchId, poId=$poId, currentStatus=$currentStatus',
    );
    final canClose =
        currentStatus == 'CLOSED' || _purchaseOrderFullyReceived(lines);
    final statuses = <String>[
      'ISSUED',
      'ACCEPTED',
      'DELIVERED',
      'CANCELLED',
      if (canClose) 'CLOSED',
    ];
    String selected =
        statuses.contains(currentStatus) ? currentStatus : statuses.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isUpdating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleUpdate() async {
              setDialogState(() => isUpdating = true);
              try {
                _logOperations(
                  'purchase_order_status_update_start',
                  details: 'branchId=$branchId, poId=$poId, status=$selected',
                );
                final response = await _apiService.updatePurchaseOrderStatus(
                  branchId: branchId,
                  poId: poId,
                  payload: <String, dynamic>{
                    'newStatus': selected,
                    'status': selected,
                    'orderStatus': selected,
                  },
                );
                _ensureSuccess(
                  response,
                  fallback: 'Failed to update purchase order status',
                );
                _logOperations(
                  'purchase_order_status_update_success',
                  details: 'branchId=$branchId, poId=$poId, status=$selected',
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await _loadPurchaseOrders(branchId);
                _showToast('Purchase order status updated successfully');
              } catch (error) {
                _logOperations(
                  'purchase_order_status_update_failure',
                  details: error,
                );
                _showToast(error.toString());
                if (dialogContext.mounted) {
                  setDialogState(() => isUpdating = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Update PO Status'),
              content: DropdownButtonFormField<String>(
                key: ValueKey<String>(selected),
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: statuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                    )
                    .toList(),
                onChanged: isUpdating
                    ? null
                    : (value) {
                        if (value != null) selected = value;
                      },
              ),
              actions: [
                TextButton(
                  onPressed:
                      isUpdating ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating ? null : handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isUpdating ? 'Updating...' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showGoodsReceiptDetails(Map<String, dynamic> note) async {
    final branchId = _selectedBranch?.branchId;
    final grnId = _toInt(note['id'] ?? note['grnId']);
    if (branchId == null || grnId == null) return;
    _logOperations(
      'grn_details_open',
      details: 'branchId=$branchId, grnId=$grnId',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AsyncDetailsDialog(
          title:
              _firstText(note, const ['grnId', 'id'], fallback: 'GRN Details'),
          future: _apiService.getGoodsReceiptNoteDetails(
            branchId: branchId,
            grnId: grnId,
          ),
          builder: (detail) {
            final lines = _recordList(detail['lines'] ?? detail['items']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailLine(
                    label: 'GRN ID',
                    value: _firstText(detail, const ['grnId', 'id'],
                        fallback: 'N/A')),
                _DetailLine(
                    label: 'PO ID',
                    value: _firstText(detail, const ['poId', 'purchaseOrderId'],
                        fallback: 'N/A')),
                _DetailLine(
                    label: 'Vendor',
                    value: _vendorDisplayLabel(detail, _vendors)),
                _DetailLine(
                    label: 'Received Date',
                    value: _formatDateValue(
                        detail['receivedDate'] ?? detail['createdAt'])),
                _DetailLine(label: 'Status', value: _statusLabel(detail)),
                const SizedBox(height: 12),
                const Text(
                  'GRN Lines',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Text('No lines found')
                else
                  _LinesTable(
                    rows: lines
                        .map(
                          (line) => <String>[
                            _firstText(
                                line, const ['itemName', 'name', 'title'],
                                fallback: 'Item'),
                            _firstText(line, const ['orderedQty'],
                                fallback: '0'),
                            _firstText(line, const ['receivedQty'],
                                fallback: '0'),
                            _firstText(line, const ['returnQty'],
                                fallback: '0'),
                          ],
                        )
                        .toList(),
                    headers: const <String>[
                      'Item',
                      'Ordered',
                      'Received',
                      'Return'
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAddStore() async {
    _logOperations('open_add_store_warning');
    final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Weak Network Warning'),
            content: Text(
              _t(
                'If your network is unstable, saving store details may take longer. Continue?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(_t('Continue')),
              ),
            ],
          ),
        ) ??
        false;
    _logOperations('open_add_store_decision', details: 'proceed=$proceed');
    if (!proceed || !mounted) return;
    _openStoreFormDialog();
  }

  Widget _buildBranchSelector() {
    final selected = _selectedBranch;
    final options = _branchOptions
        .map(
          (item) => OwnerBranchHeaderSelectorOption<_BranchOption>(
            value: item,
            label: item.label,
            subtitle: item.branchName,
          ),
        )
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1EBE6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OwnerBranchHeaderSelector<_BranchOption>(
              label: selected?.label ?? context.t('Select Branch'),
              options: options,
              selectedValue: selected,
              placeholder: context.t('Select Branch'),
              isInteractive: _branchOptions.isNotEmpty,
              onSelected: _switchBranch,
            ),
          ),
          if (_selectedBranch != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: _isLoadingContent ? null : () => _reloadCurrent(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryTabs() {
    final tabs = <_InventoryTab, String>{
      _InventoryTab.store: context.t('Store'),
      _InventoryTab.inventoryItem: context.t('Inventory Item'),
      _InventoryTab.purchaseOrder: context.t('Purchase Order'),
      _InventoryTab.goodsReceiptNote: context.t('Goods Receipt Note'),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF111111)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        color: _inventoryTab == entry.key
                            ? const Color(0xFF111111)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _inventoryTab == entry.key,
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    onSelected: (selected) {
                      if (!selected) return;
                      _logOperations(
                        'inventory_tab_changed',
                        details:
                            'from=${_inventoryTab.name} to=${entry.key.name}',
                      );
                      setState(() {
                        _inventoryTab = entry.key;
                      });
                      _reloadCurrent();
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoadingBranches) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_branchError != null) {
      return _ErrorStateCard(
        message: _branchError!,
        onRetry: _loadBranches,
      );
    }

    if (_selectedBranch == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBranchSelector(),
          const SizedBox(height: 16),
          _EmptyStateCard(message: context.t('Select a branch to continue')),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.starColor,
      onRefresh: _reloadCurrent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBranchSelector(),
          const SizedBox(height: 16),
          if (!_isVendorModule) ...[
            _buildInventoryTabs(),
            const SizedBox(height: 16),
          ],
          if (_contentError != null && !_isLoadingContent)
            _ErrorStateCard(
              message: _contentError!,
              onRetry: _reloadCurrent,
            )
          else
            _buildModuleContent(),
        ],
      ),
    );
  }

  Widget _buildModuleContent() {
    if (_isVendorModule) {
      return _buildVendorList();
    }

    switch (_inventoryTab) {
      case _InventoryTab.store:
        return _buildStoreList();
      case _InventoryTab.inventoryItem:
        return _buildInventoryItemsList();
      case _InventoryTab.purchaseOrder:
        return _buildPurchaseOrdersList();
      case _InventoryTab.goodsReceiptNote:
        return _buildGoodsReceiptNotesList();
    }
  }

  Widget _buildVendorList() {
    return _SectionCard(
      title: context.t('Vendor'),
      actionLabel: context.t('Add Vendor'),
      onAction: () {
        _logOperations('vendor_add_open');
        _openVendorFormDialog();
      },
      child: _buildListState(
        records: _vendors,
        emptyText: context.t('No vendors found'),
        table: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(context.t('Name'))),
              DataColumn(label: Text(context.t('Phone'))),
              DataColumn(label: Text(context.t('Email'))),
              DataColumn(label: Text(context.t('Status'))),
              DataColumn(label: Text(context.t('Actions'))),
            ],
            rows: _vendors
                .map(
                  (vendor) => DataRow(
                    onSelectChanged: (_) => _showVendorDetails(vendor),
                    cells: [
                      DataCell(
                        Text(_firstText(vendor, const ['name', 'vendorName'],
                            fallback: 'N/A')),
                      ),
                      DataCell(
                        Text(_firstText(
                            vendor,
                            const [
                              'phoneNumber',
                              'phone',
                              'mobileNumber',
                              'contactNumber'
                            ],
                            fallback: 'N/A')),
                      ),
                      DataCell(
                        Text(_firstText(vendor, const ['email'],
                            fallback: 'N/A')),
                      ),
                      DataCell(Text(_statusLabel(vendor))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _logOperations(
                                  'vendor_edit_open',
                                  details: 'vendorId=${_toInt(vendor['id'])}',
                                );
                                _openVendorFormDialog(initialVendor: vendor);
                              },
                              child: Text(context.t('Edit')),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _confirmVendorDelete(vendor),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                              ),
                              child: Text(context.t('Delete')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    return _SectionCard(
      title: context.t('Store'),
      actionLabel: context.t('Add Store'),
      onAction: _openAddStore,
      child: _buildListState(
        records: _stores,
        emptyText: context.t('No stores found'),
        table: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            columns: [
              DataColumn(label: Text(context.t('Name'))),
              DataColumn(label: Text(context.t('Address'))),
              DataColumn(label: Text(context.t('Status'))),
              DataColumn(label: Text(context.t('Actions'))),
            ],
            rows: _stores
                .map(
                  (store) => DataRow(
                    onSelectChanged: (_) => _showStoreDetails(store),
                    cells: [
                      DataCell(Text(_firstText(
                          store, const ['name', 'storeName'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(store, const ['address'],
                          fallback: 'N/A'))),
                      DataCell(Text(_statusLabel(store))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _openStoreFormDialog(initialStore: store);
                              },
                              child: Text(context.t('Edit')),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _confirmStoreDelete(store),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                              ),
                              child: Text(context.t('Delete')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItemsList() {
    final canGoPrev = _inventoryPage > 1;
    final canGoNext = _inventoryPage * _inventoryLimit < _inventoryTotal;
    return _SectionCard(
      title: context.t('Inventory Item'),
      actionLabel: context.t('Add Inventory Item'),
      onAction: () {
        _logOperations('inventory_item_add_open');
        _openInventoryItemFormDialog();
      },
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: canGoPrev
                ? () => _loadInventoryItems(
                      _selectedBranch!.branchId,
                      page: _inventoryPage - 1,
                    )
                : null,
            child: Text(context.t('Prev')),
          ),
          const SizedBox(width: 10),
          Text('${context.t('Page')} $_inventoryPage'),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: canGoNext
                ? () => _loadInventoryItems(
                      _selectedBranch!.branchId,
                      page: _inventoryPage + 1,
                    )
                : null,
            child: Text(context.t('Next')),
          ),
        ],
      ),
      child: _buildListState(
        records: _inventoryItems,
        emptyText: context.t('No inventory items found'),
        table: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(context.t('Name'))),
              DataColumn(label: Text(context.t('SKU'))),
              DataColumn(label: Text(context.t('Category'))),
              DataColumn(label: Text(context.t('Brand'))),
              DataColumn(label: Text(context.t('Quantity'))),
              DataColumn(label: Text(context.t('Unit Price'))),
              DataColumn(label: Text(context.t('Status'))),
              DataColumn(label: Text(context.t('Actions'))),
            ],
            rows: _inventoryItems
                .map(
                  (item) => DataRow(
                    onSelectChanged: (_) => _showInventoryItemDetails(item),
                    cells: [
                      DataCell(Text(_firstText(
                          item, const ['itemName', 'name', 'title'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(item, const ['skuNumber', 'sku'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(
                          item, const ['category', 'categoryName'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(
                          item, const ['brand', 'manufacturer'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(
                          item,
                          const [
                            'stockLevel',
                            'availableStock',
                            'currentStock'
                          ],
                          fallback: '0'))),
                      DataCell(Text(_formatCurrency(
                          item['costPerUnit'] ?? item['unitPrice']))),
                      DataCell(Text(_statusLabel(item))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _logOperations(
                                  'inventory_item_edit_open',
                                  details: 'inventoryId=${_toInt(item['id'])}',
                                );
                                _openInventoryItemFormDialog(initialItem: item);
                              },
                              child: Text(context.t('Edit')),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  _confirmInventoryItemDelete(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                              ),
                              child: Text(context.t('Delete')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseOrdersList() {
    return _SectionCard(
      title: context.t('Purchase Order'),
      actionLabel: context.t('Add Purchase Order'),
      onAction: () {
        _logOperations('purchase_order_add_open');
        _openPurchaseOrderFormDialog();
      },
      child: _buildListState(
        records: _purchaseOrders,
        emptyText: context.t('No purchase orders found'),
        table: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(context.t('PO ID'))),
              DataColumn(label: Text(context.t('Vendor Name'))),
              DataColumn(label: Text(context.t('Required Date'))),
              DataColumn(label: Text(context.t('Status'))),
            ],
            rows: _purchaseOrders
                .map(
                  (order) => DataRow(
                    onSelectChanged: (_) => _showPurchaseOrderDetails(order),
                    cells: [
                      DataCell(Text(_firstText(order, const ['poId', 'id'],
                          fallback: 'N/A'))),
                      DataCell(Text(_vendorDisplayLabel(order, _vendors))),
                      DataCell(Text(_formatDateValue(
                          order['requiredDeliveryDate'] ??
                              order['requiredDate']))),
                      DataCell(Text(_statusLabel(order))),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGoodsReceiptNotesList() {
    return _SectionCard(
      title: context.t('Goods Receipt Note'),
      actionLabel: context.t('Add GRN'),
      onAction: () {
        _logOperations('grn_add_open');
        _openGoodsReceiptNoteFormDialog();
      },
      child: _buildListState(
        records: _goodsReceiptNotes,
        emptyText: context.t('No goods receipt notes found'),
        table: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(context.t('GRN ID'))),
              DataColumn(label: Text(context.t('PO ID'))),
              DataColumn(label: Text(context.t('Vendor Name'))),
              DataColumn(label: Text(context.t('Received Date'))),
              DataColumn(label: Text(context.t('Status'))),
            ],
            rows: _goodsReceiptNotes
                .map(
                  (note) => DataRow(
                    onSelectChanged: (_) => _showGoodsReceiptDetails(note),
                    cells: [
                      DataCell(Text(_firstText(note, const ['grnId', 'id'],
                          fallback: 'N/A'))),
                      DataCell(Text(_firstText(
                          note, const ['poId', 'purchaseOrderId'],
                          fallback: 'N/A'))),
                      DataCell(Text(_vendorDisplayLabel(note, _vendors))),
                      DataCell(Text(_formatDateValue(
                          note['receivedDate'] ?? note['createdAt']))),
                      DataCell(Text(_statusLabel(note))),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildListState({
    required List<Map<String, dynamic>> records,
    required String emptyText,
    required Widget table,
  }) {
    if (_isLoadingContent) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (records.isEmpty) {
      return _EmptyStateCard(message: emptyText);
    }
    return table;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title: _isVendorModule ? context.t('Vendor') : context.t('Inventory'),
      ),
      body: _buildBodyContent(),
    );
  }
}
