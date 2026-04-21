import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistInventoryScreen extends StatefulWidget {
  const StylistInventoryScreen({
    super.key,
    this.refreshSignal = 0,
  });

  final int refreshSignal;

  @override
  State<StylistInventoryScreen> createState() => _StylistInventoryScreenState();
}

class _StylistInventoryScreenState extends State<StylistInventoryScreen> {
  final ApiService _apiService = ApiService();

  StylistBranchSelection _selection = const StylistBranchSelection();
  List<Map<String, dynamic>> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StylistInventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _text(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  void _debugPrintChunked(
    String tag,
    Object? message, {
    int chunkSize = 800,
  }) {
    final text = (message ?? '').toString();
    if (text.isEmpty) {
      debugPrint('[$tag] ');
      return;
    }

    for (int start = 0; start < text.length; start += chunkSize) {
      final end =
          (start + chunkSize < text.length) ? start + chunkSize : text.length;
      debugPrint('[$tag] ${text.substring(start, end)}');
    }
  }

  Future<void> _loadData() async {
    final selection = await StylistBranchSelectionStore.load();
    debugPrint(
      '[StylistInventory] opening inventory for branchId=${selection.branchId}, salonId=${selection.salonId}, label=${selection.label}',
    );

    if (!mounted) return;
    setState(() {
      _selection = selection;
      _isLoading = true;
      _errorMessage = null;
    });

    if (selection.branchId == null) {
      debugPrint('[StylistInventory] no branch selected, skipping API call');
      setState(() {
        _items = const [];
        _totalItems = 0;
        _isLoading = false;
      });
      return;
    }

    final response = await _apiService.fetchInventoryItems(selection.branchId!);
    _debugPrintChunked('StylistInventory response', response);
    final payload = response['data'];

    List<dynamic> rawItems = const [];
    int total = 0;
    if (payload is Map<String, dynamic>) {
      rawItems = (payload['items'] as List?) ?? const [];
      total = _asInt(payload['total']) ?? rawItems.length;
    } else if (payload is List) {
      rawItems = payload;
      total = rawItems.length;
    }

    if (!mounted) return;
    setState(() {
      _items = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _totalItems = total;
      _errorMessage =
          response['success'] == true ? null : response['message']?.toString();
      _isLoading = false;
    });
    debugPrint(
      '[StylistInventory] parsed ${_items.length} items, total=$_totalItems, error=$_errorMessage',
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.t('Inventory'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SelectionHeader(
              title: context.t('Current Salon'),
              value: _selection.label.isEmpty
                  ? context.t('Select a salon in Bookings first')
                  : _selection.label,
            ),
            if (_totalItems > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${context.t('Inventory')}: $_totalItems',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selection.branchId == null)
              _InventoryEmptyState(
                message: context.t('Select a salon in Bookings first'),
              )
            else if (_errorMessage != null && _items.isEmpty)
              _InventoryEmptyState(message: _errorMessage!)
            else if (_items.isEmpty)
              _InventoryEmptyState(
                message: context.t('No inventory items found for this branch'),
              )
            else
              ..._items.map((item) {
                final name = _text(
                  item,
                  const ['itemName', 'name', 'displayName', 'title'],
                );
                final code = _text(
                  item,
                  const ['skuNumber', 'sku', 'code', 'itemId'],
                );
                final unit = _text(
                  item,
                  const ['unitOfMeasure', 'unit', 'unitName'],
                );
                final category =
                    _text(item, const ['category', 'categoryName']);
                final storeName = _text(item, const ['storeName']);
                final stock = _asInt(
                  item['stockLevel'] ??
                      item['availableStock'] ??
                      item['currentStock'] ??
                      item['stock'] ??
                      item['quantity'],
                );

                final subtitle = <String>[
                  if (code.isNotEmpty) 'SKU: $code',
                  if (category.isNotEmpty) category,
                  if (unit.isNotEmpty) unit,
                  if (storeName.isNotEmpty) storeName,
                ].join(' • ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      name.isEmpty ? context.t('Inventory') : name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.starColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.t('Stock'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${stock ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
