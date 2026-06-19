import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../utils/price_formatter.dart';

class OwnerBranchClientsScreen extends StatefulWidget {
  const OwnerBranchClientsScreen({super.key});

  @override
  State<OwnerBranchClientsScreen> createState() =>
      _OwnerBranchClientsScreenState();
}

class _OwnerBranchClientsScreenState extends State<OwnerBranchClientsScreen> {
  static const double _nameColWidth = 220;
  static const double _visitsColWidth = 120;
  static const double _spendColWidth = 140;
  static const double _lastVisitColWidth = 160;
  static const double _statusColWidth = 120;
  static const double _actionColWidth = 120;
  static const double _tableHorizontalPadding = 16;

  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  void _logClients(String event, {Object? details}) {
    debugPrint(
      '[OwnerClients] $event${details == null ? '' : ' | $details'}',
    );
  }

  List<_OwnerBranchOption> _branchOptions = const [];
  List<Map<String, dynamic>> _clients = const [];
  Map<String, dynamic>? _dashboardData;
  int? _selectedBranchId;
  String _selectedDateRange = 'this_month';
  String _activeCustomerTab = 'all_customers';
  int _currentPage = 1;
  bool _isLoadingBranches = true;
  bool _isLoadingClients = false;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _logClients(
        'search_changed',
        details:
            'query=${_searchController.text.trim()}, results=${_filteredClients.length}',
      );
    });
    _logClients('init');
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _logClients('load_data_started');
    setState(() {
      _isLoadingBranches = true;
      _errorMessage = null;
    });

    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await _apiService.getSalonListApi();
      final data = (response['data'] as List?) ?? const [];
      final options = _extractBranchOptions(data);
      final selectedBranchId = options.any(
        (option) => option.branchId == selection.branchId,
      )
          ? selection.branchId
          : (options.isNotEmpty ? options.first.branchId : null);

      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranchId = selectedBranchId;
        _isLoadingBranches = false;
      });
      _logClients(
        'load_data_success',
        details:
            'branches=${options.length}, selectedBranchId=$selectedBranchId',
      );

      if (selectedBranchId != null) {
        await _loadClientsForBranch(selectedBranchId, saveSelection: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingBranches = false;
        _errorMessage = error.toString();
      });
      _logClients('load_data_failed', details: error);
    }
  }

  List<_OwnerBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_OwnerBranchOption>[];
    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) continue;
      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _asInt(salon['id']);
      if (salonId == null) continue;
      final salonName = (salon['name'] ?? '').toString().trim();
      final branches = (salon['branches'] as List?) ?? const [];
      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asInt(branch['id']);
        if (branchId == null) continue;
        options.add(
          _OwnerBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: (branch['name'] ?? '').toString().trim(),
            address: _composeAddress(
              branch['address'] is Map
                  ? Map<String, dynamic>.from(branch['address'] as Map)
                  : null,
            ),
          ),
        );
      }
    }
    return options;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  String _composeAddress(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return '';
    final segments = <String>[];

    void push(dynamic value) {
      final text = _cleanText(value);
      if (text.isNotEmpty && !segments.contains(text)) {
        segments.add(text);
      }
    }

    push(data['line1']);
    push(data['line2']);
    push(data['village']);
    push(data['district']);
    push(data['city']);
    push(data['state']);
    push(data['country']);
    push(data['postalCode']);
    return segments.join(', ');
  }

  List<Map<String, dynamic>> _extractClients(dynamic raw) {
    if (raw is Map) {
      final dashboard = Map<String, dynamic>.from(raw);
      final customerManagement = dashboard['customerManagement'];
      if (customerManagement is Map) {
        final table = customerManagement['table'];
        if (table is Map) {
          final rows = table['rows'];
          if (rows is List) {
            return rows
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
      }
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (raw is Map) {
      for (final key in const ['clients', 'items', 'results', 'data']) {
        final nested = raw[key];
        if (nested != null) {
          final extracted = _extractClients(nested);
          if (extracted.isNotEmpty) {
            return extracted;
          }
        }
      }
      return raw.isEmpty ? const [] : [Map<String, dynamic>.from(raw)];
    }
    return const [];
  }

  List<Map<String, dynamic>> _dashboardList(String key) {
    final value = _dashboardData?[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _summaryCards =>
      _dashboardList('summaryCards');

  List<Map<String, dynamic>> get _dateRanges {
    final filters = _dashboardData?['filters'];
    final ranges = filters is Map ? filters['availableDateRanges'] : null;
    if (ranges is List) {
      return ranges
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [
      {'label': 'Today', 'value': 'today'},
      {'label': 'This Week', 'value': 'this_week'},
      {'label': 'This Month', 'value': 'this_month'},
      {'label': 'This Year', 'value': 'this_year'},
    ];
  }

  List<Map<String, dynamic>> get _customerTabs {
    final management = _dashboardData?['customerManagement'];
    final tabs = management is Map ? management['tabs'] : null;
    if (tabs is List) {
      return tabs
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [
      {'label': 'All Customers', 'value': 'all_customers'},
      {'label': 'New Customers', 'value': 'new_customers'},
      {'label': 'Loyal Customers', 'value': 'loyal_customers'},
      {'label': 'Inactive Customers', 'value': 'inactive_customers'},
    ];
  }

  Map<String, dynamic> get _pagination {
    final management = _dashboardData?['customerManagement'];
    final table = management is Map ? management['table'] : null;
    final pagination = table is Map ? table['pagination'] : null;
    return pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
  }

  Future<void> _loadClientsForBranch(
    int branchId, {
    bool saveSelection = true,
  }) async {
    _logClients(
      'load_clients_started',
      details: 'branchId=$branchId, saveSelection=$saveSelection',
    );
    setState(() {
      _isLoadingClients = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getBranchClients(
        branchId,
        selectedDateRange: _selectedDateRange,
        tab: _activeCustomerTab,
        page: _currentPage,
      );
      final dashboardData = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final clients = _extractClients(dashboardData);
      if (saveSelection) {
        final selected = _branchOptions.firstWhere(
          (option) => option.branchId == branchId,
        );
        await StylistBranchSelectionStore.save(
          salonId: selected.salonId,
          branchId: selected.branchId,
          salonName: selected.salonName,
          branchName: selected.branchName,
        );
      }

      if (!mounted) return;
      setState(() {
        _selectedBranchId = branchId;
        _dashboardData = dashboardData;
        _clients = clients;
        _isLoadingClients = false;
      });
      _logClients(
        'load_clients_success',
        details: 'branchId=$branchId, clients=${clients.length}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingClients = false;
        _errorMessage = error.toString();
      });
      _logClients('load_clients_failed', details: error);
    }
  }

  Future<void> _reloadSelectedBranch({bool resetPage = true}) async {
    final branchId = _selectedBranchId;
    if (branchId == null) return;
    if (resetPage) _currentPage = 1;
    await _loadClientsForBranch(branchId, saveSelection: false);
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;
    return _clients.where((client) {
      final first = _cleanText(client['firstName']).toLowerCase();
      final last = _cleanText(client['lastName']).toLowerCase();
      final customerName = _clientName(client).toLowerCase();
      final email = _cleanText(client['email']).toLowerCase();
      final phone = _cleanText(
        client['phoneNumber'] ?? client['fullPhoneNumber'],
      ).toLowerCase();
      final fullName = '$first $last'.trim();
      return customerName.contains(query) ||
          fullName.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  String _clientName(Map<String, dynamic> client) {
    final customer = client['customer'];
    if (customer is Map) {
      final name = _cleanText(customer['name']);
      if (name.isNotEmpty) return name;
    }

    final name = [
      _cleanText(client['firstName']),
      _cleanText(client['lastName']),
    ].where((part) => part.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
    return _cleanText(client['name']).isEmpty
        ? context.t('Customer')
        : _cleanText(client['name']);
  }

  String _clientInitials(Map<String, dynamic> client) {
    final customer = client['customer'];
    if (customer is Map) {
      final initials = _cleanText(customer['initials']);
      if (initials.isNotEmpty) return initials;
    }
    final words = _clientName(client)
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'C';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  String _clientStatusLabel(Map<String, dynamic> client) {
    final status = client['status'];
    if (status is Map) {
      final label = _cleanText(status['label']);
      if (label.isNotEmpty) return label;
    }
    return client['active'] == false
        ? context.t('Inactive')
        : context.t('Active');
  }

  bool _isClientActive(Map<String, dynamic> client) {
    final status = client['status'];
    if (status is Map) {
      final value = _cleanText(status['value']).toLowerCase();
      if (value.isNotEmpty) return value != 'inactive';
    }
    return client['active'] != false;
  }

  String _clientTotalVisits(Map<String, dynamic> client) =>
      _cleanText(client['totalVisits']).isEmpty
          ? '0'
          : _cleanText(client['totalVisits']);

  String _clientTotalSpend(Map<String, dynamic> client) {
    final display = _cleanText(client['displayTotalSpend']);
    if (display.isNotEmpty) return display;
    return _formatAmount(client['totalSpend']);
  }

  String _clientLastVisit(Map<String, dynamic> client) {
    final display = _cleanText(client['displayLastVisit']);
    if (display.isNotEmpty) return display;
    return _formatDateValue(client['lastVisit']);
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _formatDateValue(dynamic value) {
    final raw = _cleanText(value);
    if (raw.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  String _formatAmount(dynamic value) {
    final text = _cleanText(value);
    if (text.isEmpty) return 'N/A';
    final parsed = value is num ? value : num.tryParse(text);
    if (parsed == null) {
      return _cleanText(value).isEmpty ? 'N/A' : _cleanText(value);
    }
    return formatMinorAmount(parsed, trimZeroDecimals: true);
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(_cleanText(value)) ?? 0;
  }

  String _formatMinorAmount(dynamic value, {String currency = 'INR'}) {
    final amount = value is num
        ? value.toDouble()
        : num.tryParse(_cleanText(value))?.toDouble();
    if (amount == null) return 'N/A';

    if (currency.toUpperCase() == 'INR') {
      return formatMinorAmount(amount);
    }
    final normalized = amount / 100;
    return '${currency.toUpperCase()} ${normalized.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _extractPurchases(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map.containsKey('packages') || map.containsKey('deals')) {
        return [
          ..._extractPurchases(map['packages']),
          ..._extractPurchases(map['deals']),
        ];
      }
      for (final key in const [
        'purchases',
        'items',
        'results',
        'data',
        'orders',
        'carts',
      ]) {
        final nested = map[key];
        final extracted = _extractPurchases(nested);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
      return map.isEmpty ? const [] : <Map<String, dynamic>>[map];
    }
    return const [];
  }

  int? _clientIdFromMap(Map<String, dynamic> client) {
    return _asInt(client['id']) ??
        _asInt(client['clientId']) ??
        _asInt(client['userId']);
  }

  String _purchaseTitle(Map<String, dynamic> purchase) {
    final candidates = [
      purchase['title'],
      purchase['name'],
      purchase['displayName'],
      purchase['packageName'],
      purchase['dealName'],
      purchase['serviceName'],
      purchase['cartName'],
      purchase['orderNumber'],
      purchase['invoiceNumber'],
      purchase['id'],
    ];
    for (final candidate in candidates) {
      final text = _cleanText(candidate);
      if (text.isNotEmpty) return text;
    }
    return 'Purchase';
  }

  String _purchaseSubtitle(Map<String, dynamic> purchase) {
    final parts = <String>[];
    final type = _cleanText(purchase['type']);
    final status = _cleanText(
      purchase['status'] ??
          purchase['paymentStatus'] ??
          purchase['orderStatus'],
    );
    final date = _formatDateValue(
      purchase['purchasedAt'] ??
          purchase['createdAt'] ??
          purchase['purchaseDate'] ??
          purchase['bookedAt'] ??
          purchase['updatedAt'],
    );
    if (type.isNotEmpty) parts.add(type);
    if (status.isNotEmpty) parts.add(status);
    if (date != 'N/A') parts.add(date);
    return parts.isEmpty ? 'No additional details' : parts.join(' • ');
  }

  String _purchaseAmountLabel(Map<String, dynamic> purchase) {
    if (purchase.containsKey('paidAmountMinor')) {
      final value = purchase['paidAmountMinor'];
      final text = _cleanText(value);
      if (text.isNotEmpty) {
        return _formatMinorAmount(
          value,
          currency: _cleanText(purchase['currency']).isEmpty
              ? 'INR'
              : _cleanText(purchase['currency']),
        );
      }
    }
    final keys = [
      'totalAmount',
      'amount',
      'price',
      'netAmount',
      'grandTotal',
      'total',
      'paidAmount',
      'amountMinor',
      'totalMinor',
    ];
    for (final key in keys) {
      final value = purchase[key];
      final text = _cleanText(value);
      if (text.isNotEmpty) {
        return _formatAmount(value);
      }
    }
    return 'N/A';
  }

  Widget _buildClientHeaderCell(
    String label,
    double width, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildClientBodyCell(
    Widget child,
    double width, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return SizedBox(
      width: width,
      child: Align(alignment: alignment, child: child),
    );
  }

  void _logPurchaseResponseShape(Map<String, dynamic> response) {
    debugPrint('[ClientPurchasesModal] responseType=${response.runtimeType}');
    debugPrint('[ClientPurchasesModal] topLevelKeys=${response.keys.toList()}');

    for (final entry in response.entries) {
      final value = entry.value;
      debugPrint(
        '[ClientPurchasesModal] key=${entry.key} valueType=${value.runtimeType}',
      );
      if (value is Map<String, dynamic>) {
        debugPrint(
          '[ClientPurchasesModal] ${entry.key} keys=${value.keys.toList()}',
        );
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        final first = Map<String, dynamic>.from(value.first as Map);
        debugPrint(
          '[ClientPurchasesModal] ${entry.key} firstItemKeys=${first.keys.toList()}',
        );
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    try {
      debugPrint(
          '[ClientPurchasesModal] fullResponse=\n${encoder.convert(response)}');
    } catch (_) {}
  }

  Future<void> _showClientPurchasesModal(Map<String, dynamic> client) async {
    final branchId = _selectedBranchId;
    final clientId = _clientIdFromMap(client);
    if (branchId == null || clientId == null) {
      _showSnack('Missing branch or client id');
      return;
    }
    _logClients(
      'open_client_purchases_modal',
      details: 'branchId=$branchId, clientId=$clientId',
    );

    final clientName = _clientName(client);
    final phone =
        _cleanText(client['phoneNumber'] ?? client['fullPhoneNumber']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _apiService.getClientPurchases(
                  branchId: branchId,
                  clientId: clientId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.starColor,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                clientName.isEmpty
                                    ? 'Client Purchases'
                                    : clientName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(snapshot.error.toString()),
                      ],
                    );
                  }

                  final response = snapshot.data ?? const <String, dynamic>{};
                  _logPurchaseResponseShape(response);
                  final purchases = _extractPurchases(response['data']);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clientName.isEmpty
                                      ? 'Client Purchases'
                                      : clientName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone.isEmpty
                                      ? 'Client ID: $clientId'
                                      : phone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (purchases.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No previous purchases found',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: purchases.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final purchase = purchases[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _purchaseTitle(purchase),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_purchaseSubtitle(purchase)),
                                ),
                                trailing: Text(
                                  _purchaseAmountLabel(purchase),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _downloadsFilePath(String fileName) async {
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory != null) {
      return '${downloadsDirectory.path}/$fileName';
    }

    final home = Platform.environment['HOME']?.trim();
    if (home != null && home.isNotEmpty) {
      return '$home/Downloads/$fileName';
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    return '${documentsDirectory.path}/$fileName';
  }

  Future<void> _exportClients() async {
    if (_clients.isEmpty) {
      _showSnack(translateText('No clients found'));
      return;
    }
    if (_isExporting) return;
    _logClients(
      'export_clients_started',
      details: 'branchId=$_selectedBranchId, count=${_clients.length}',
    );

    setState(() => _isExporting = true);
    try {
      final rows = <String>[
        [
          'Customer',
          'Total Visits',
          'Total Spend',
          'Last Visit',
          'Status',
        ].map(_csvCell).join(','),
      ];

      for (final client in _clients) {
        rows.add(
          [
            _clientName(client),
            _clientTotalVisits(client),
            _clientTotalSpend(client),
            _clientLastVisit(client),
            _clientStatusLabel(client),
          ].map(_csvCell).join(','),
        );
      }

      final csv = rows.join('\n');
      final branchName = _branchOptions
          .cast<_OwnerBranchOption?>()
          .firstWhere(
            (option) => option?.branchId == _selectedBranchId,
            orElse: () => null,
          )
          ?.branchName
          .trim();
      final safeName = (branchName == null || branchName.isEmpty
              ? 'branch_clients'
              : branchName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'))
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final fileName = '${safeName.isEmpty ? 'branch_clients' : safeName}.csv';

      var targetPath = await _downloadsFilePath(fileName);

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(csv);
      _logClients('export_clients_success', details: file.path);
      _showSnack('Exported to ${file.path}');
    } catch (error) {
      _logClients('export_clients_failed', details: error);
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ignore: unused_element
  Future<void> _showImportClientsModal() async {
    if (_selectedBranchId == null) {
      _showSnack(translateText('Please select a branch first.'));
      return;
    }
    _logClients(
      'open_import_clients_modal',
      details: 'branchId=$_selectedBranchId',
    );

    PlatformFile? selectedFile;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickFile() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['xlsx', 'xls', 'csv'],
                withData: false,
              );
              if (result == null || result.files.isEmpty) return;
              _logClients(
                'import_file_picked',
                details: result.files.single.path ?? result.files.single.name,
              );
              setDialogState(() {
                selectedFile = result.files.single;
              });
            }

            Future<void> downloadTemplate() async {
              final template =
                  'phoneNumber,countryCode,firstName,lastName,email\n';
              final targetPath =
                  await _downloadsFilePath('branch_clients_template.csv');
              final file = File(targetPath);
              await file.parent.create(recursive: true);
              await file.writeAsString(template);
              if (!mounted) return;
              _showSnack('Template saved to $targetPath');
            }

            Future<void> uploadFile() async {
              if (selectedFile?.path == null || selectedFile!.path!.isEmpty) {
                _showSnack('Please choose a file');
                return;
              }
              setDialogState(() => isUploading = true);
              try {
                _logClients(
                  'import_upload_started',
                  details: selectedFile!.path,
                );
                await _apiService.importClientsFile(
                  branchId: _selectedBranchId!,
                  file: File(selectedFile!.path!),
                );
                if (!mounted || !dialogContext.mounted) return;
                _logClients(
                  'import_upload_success',
                  details: 'branchId=$_selectedBranchId',
                );
                Navigator.of(dialogContext).pop();
                _showSnack('Clients imported successfully');
                await _loadClientsForBranch(_selectedBranchId!,
                    saveSelection: false);
              } catch (error) {
                _logClients('import_upload_failed', details: error);
                _showSnack(error.toString());
                if (dialogContext.mounted) {
                  setDialogState(() => isUploading = false);
                }
              }
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Import Branch Clients',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t(
                          'Download the template, fill in the client details, and upload the completed file.',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('Supported formats: .xlsx, .xls, or .csv.'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          color: const Color(0xFFFBFBFB),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('REQUIRED COLUMNS'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0xFF374151),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                                '• phoneNumber (also accepts phone / mobile / mobileNumber)'),
                            SizedBox(height: 4),
                            Text('• countryCode'),
                            SizedBox(height: 4),
                            Text('• firstName'),
                            SizedBox(height: 4),
                            Text('• lastName'),
                            SizedBox(height: 4),
                            Text('• email'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : downloadTemplate,
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(context.t('Download Template')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.starColor,
                          side: const BorderSide(color: AppColors.starColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.t('Upload completed file'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton(
                              onPressed: isUploading ? null : pickFile,
                              child: Text(context.t('Choose File')),
                            ),
                            Text(
                              selectedFile?.name ?? context.t('No file chosen'),
                              style: const TextStyle(color: Color(0xFF374151)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isUploading
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: Text(translateText('Cancel')),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: isUploading ? null : uploadFile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                            ),
                            child: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(context.t('Upload & Import')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateRangeDropdown() {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6D6C6)),
        ),
        child: DropdownButton<String>(
          value: _selectedDateRange,
          iconEnabledColor: AppColors.starColor,
          items: _dateRanges.map((range) {
            final label = _cleanText(range['label']);
            final value = _cleanText(range['value']);
            return DropdownMenuItem<String>(
              value: value.isEmpty ? 'this_month' : value,
              child: Text(label.isEmpty ? value : label),
            );
          }).toList(),
          onChanged: _isLoadingClients
              ? null
              : (value) async {
                  if (value == null || value == _selectedDateRange) return;
                  setState(() => _selectedDateRange = value);
                  await _reloadSelectedBranch();
                },
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _exportClients,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.starColor,
          disabledBackgroundColor: const Color(0xFFB8A06D),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                context.t('Export'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final cards = _summaryCards;
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: isWide ? 126 : 130,
          ),
          itemBuilder: (context, index) => _buildMetricCard(cards[index]),
        );
      },
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> card) {
    final title = _cleanText(card['title']);
    final value = _cleanText(card['displayValue']).isEmpty
        ? _cleanText(card['value'])
        : _cleanText(card['displayValue']);
    final change = card['change'];
    final changeText = change is Map ? _cleanText(change['displayValue']) : '';
    final iconSource = _cleanText(card['icon']).isEmpty
        ? (title.isEmpty ? 'C' : title)
        : _cleanText(card['icon']);
    final iconText = iconSource.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6F58),
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E8D1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  iconText,
                  style: const TextStyle(
                    color: Color(0xFF8B6500),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value.isEmpty ? '0' : value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    value: 0,
                    minHeight: 4,
                    backgroundColor: Color(0xFFF1EBE4),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF8B6500)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                changeText.isEmpty ? '0%' : changeText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A6F58),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTrendCard() {
    final trend = _dashboardData?['customerGrowthTrend'];
    if (trend is! Map) return const SizedBox.shrink();
    final data = trend['data'] is List
        ? (trend['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanText(trend['title']).isEmpty
                          ? 'Customer Growth Trend'
                          : _cleanText(trend['title']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cleanText(trend['subtitle']).isEmpty
                          ? 'Daily customer acquisition and retention over the selected date range.'
                          : _cleanText(trend['subtitle']),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B5B4D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _GrowthTrendLegend(),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth =
                  constraints.maxWidth < 720 ? 720.0 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: 260,
                  child: CustomPaint(
                    painter: _CustomerGrowthTrendPainter(
                      data: data,
                      asDouble: _asDouble,
                      cleanText: _cleanText,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerManagementTitle() {
    final title = _cleanText(
      (_dashboardData?['customerManagement'] is Map
          ? (_dashboardData!['customerManagement'] as Map)['title']
          : null),
    );
    return Text(
      title.isEmpty ? context.t('Customer Management') : title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildCustomerTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _customerTabs.map((tab) {
          final value = _cleanText(tab['value']);
          final label = _cleanText(tab['label']);
          final isSelected = value == _activeCustomerTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label.isEmpty ? value : label),
              selected: isSelected,
              selectedColor: AppColors.starColor,
              backgroundColor: const Color(0xFFF8F1E9),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B5B4D),
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide.none,
              onSelected: _isLoadingClients
                  ? null
                  : (_) async {
                      if (value.isEmpty || value == _activeCustomerTab) return;
                      setState(() => _activeCustomerTab = value);
                      await _reloadSelectedBranch();
                    },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption =
        _branchOptions.cast<_OwnerBranchOption?>().firstWhere(
              (option) => option?.branchId == _selectedBranchId,
              orElse: () => null,
            );
    final filteredClients = _filteredClients;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Clients')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ClientsBranchSelector(
              isLoading: _isLoadingBranches,
              branches: _branchOptions,
              selectedBranchId: _selectedBranchId,
              onBranchSelected: (branch) =>
                  _loadClientsForBranch(branch.branchId),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final pageTitle = _cleanText(
                  _dashboardData?['page'] is Map
                      ? (_dashboardData!['page'] as Map)['title']
                      : null,
                );

                final title = Text(
                  pageTitle.isEmpty ? context.t('Clients') : pageTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                );

                final isCompact = constraints.maxWidth < 520;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: _buildDateRangeDropdown(),
                            ),
                            _buildExportButton(),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: _buildDateRangeDropdown(),
                    ),
                    const SizedBox(width: 10),
                    _buildExportButton(),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSummaryCards(),
            const SizedBox(height: 14),
            _buildGrowthTrendCard(),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;

                final searchField = TextField(
                  controller: _searchController,
                  maxLength: 60,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.t("Search by user's name"),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                  ),
                );

                final exportButton = _buildExportButton();

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerManagementTitle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 96,
                            child: exportButton,
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildCustomerManagementTitle()),
                    SizedBox(
                      width: 220,
                      child: searchField,
                    ),
                    const SizedBox(width: 10),
                    exportButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _buildCustomerTabs(),
            const SizedBox(height: 14),
            if (selectedOption != null && selectedOption.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  selectedOption.address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_isLoadingClients) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (_errorMessage != null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!),
                    );
                  }
                  if (filteredClients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.t('No clients found')),
                    );
                  }

                  final baseFlexibleWidth = _nameColWidth +
                      _visitsColWidth +
                      _spendColWidth +
                      _lastVisitColWidth +
                      _statusColWidth +
                      _actionColWidth;
                  final minimumTableWidth =
                      baseFlexibleWidth + (_tableHorizontalPadding * 2);
                  final tableWidth = constraints.maxWidth < minimumTableWidth
                      ? minimumTableWidth
                      : constraints.maxWidth;
                  final rowContentWidth =
                      tableWidth - (_tableHorizontalPadding * 2);
                  final extraWidth = rowContentWidth > baseFlexibleWidth
                      ? rowContentWidth - baseFlexibleWidth
                      : 0.0;
                  final nameColumnWidth = _nameColWidth + (extraWidth * 0.5);
                  final visitsColumnWidth =
                      _visitsColWidth + (extraWidth * 0.1);
                  final spendColumnWidth = _spendColWidth + (extraWidth * 0.1);
                  final lastVisitColumnWidth =
                      _lastVisitColWidth + (extraWidth * 0.15);
                  final statusColumnWidth =
                      _statusColWidth + (extraWidth * 0.08);
                  final actionColumnWidth =
                      _actionColWidth + (extraWidth * 0.07);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _tableHorizontalPadding,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildClientHeaderCell(
                                  'CUSTOMER',
                                  nameColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'TOTAL VISITS',
                                  visitsColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'TOTAL SPEND',
                                  spendColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'LAST VISIT',
                                  lastVisitColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'STATUS',
                                  statusColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'ACTION',
                                  actionColumnWidth,
                                  alignment: Alignment.centerRight,
                                ),
                              ],
                            ),
                          ),
                          ...filteredClients.asMap().entries.map((entry) {
                            final client = entry.value;
                            final name = _clientName(client);
                            final isActive = _isClientActive(client);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _tableHorizontalPadding,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildClientBodyCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              const Color(0xFFF4E8D1),
                                          child: Text(
                                            _clientInitials(client),
                                            style: const TextStyle(
                                              color: Color(0xFF8B6500),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    nameColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(_clientTotalVisits(client)),
                                    visitsColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(_clientTotalSpend(client)),
                                    spendColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(_clientLastVisit(client)),
                                    lastVisitColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFFEFFAF3)
                                            : const Color(0xFFFFEEF3),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _clientStatusLabel(client),
                                        style: TextStyle(
                                          color: isActive
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFE11D48),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    statusColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    OutlinedButton(
                                      onPressed: () =>
                                          _showClientPurchasesModal(client),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.starColor,
                                        side: const BorderSide(
                                          color: AppColors.starColor,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'View',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    actionColumnWidth,
                                    alignment: Alignment.centerRight,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Showing ${_cleanText(_pagination['from']).isEmpty ? 0 : _pagination['from']} to ${_cleanText(_pagination['to']).isEmpty ? filteredClients.length : _pagination['to']} of ${_cleanText(_pagination['totalRecords']).isEmpty ? filteredClients.length : _pagination['totalRecords']} results',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthTrendLegend extends StatelessWidget {
  const _GrowthTrendLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _GrowthLegendItem(label: 'New', color: Color(0xFF7A5A10)),
        SizedBox(width: 14),
        _GrowthLegendItem(label: 'Returning', color: Color(0xFFB48A45)),
      ],
    );
  }
}

class _GrowthLegendItem extends StatelessWidget {
  const _GrowthLegendItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A6F58)),
        ),
      ],
    );
  }
}

class _CustomerGrowthTrendPainter extends CustomPainter {
  const _CustomerGrowthTrendPainter({
    required this.data,
    required this.asDouble,
    required this.cleanText,
  });

  final List<Map<String, dynamic>> data;
  final double Function(dynamic value) asDouble;
  final String Function(dynamic value) cleanText;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF1E4D7)
      ..strokeWidth = 1;
    final newPaint = Paint()
      ..color = const Color(0xFF7A5A10)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final returningPaint = Paint()
      ..color = const Color(0xFFB48A45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    const leftPadding = 34.0;
    const topPadding = 12.0;
    const rightPadding = 10.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final pointsData = data.isEmpty ? <Map<String, dynamic>>[const {}] : data;
    final maxObserved = pointsData.fold<double>(0, (maxValue, item) {
      return math.max(
        maxValue,
        math.max(_newValue(item), _returningValue(item)),
      );
    });
    final maxValue = math.max(4, maxObserved.ceil()).toDouble();

    for (var index = 0; index <= 4; index++) {
      final value = maxValue * index / 4;
      final y = topPadding + chartHeight - chartHeight * index / 4;
      _drawDashedLine(
        canvas,
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
      textPainter.text = TextSpan(
        text: value.round().toString(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF8A6F58)),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 8, y - 6),
      );
    }

    _drawDashedLine(
      canvas,
      Offset(leftPadding + chartWidth / 2, topPadding),
      Offset(leftPadding + chartWidth / 2, topPadding + chartHeight),
      gridPaint,
    );

    final newPoints = <Offset>[];
    final returningPoints = <Offset>[];
    final slotCount = pointsData.length <= 1 ? 1 : pointsData.length - 1;

    for (var index = 0; index < pointsData.length; index++) {
      final item = pointsData[index];
      final x = pointsData.length <= 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth * index / slotCount;
      newPoints.add(Offset(x, _valueY(_newValue(item), maxValue, chartHeight)));
      returningPoints.add(
        Offset(x, _valueY(_returningValue(item), maxValue, chartHeight)),
      );

      final label = _pointLabel(item, index);
      if (label.isNotEmpty) {
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A6F58)),
        );
        textPainter.layout(maxWidth: 80);
        textPainter.paint(
          canvas,
          Offset(
            x - textPainter.width / 2,
            topPadding + chartHeight + 9,
          ),
        );
      }
    }

    _drawPath(canvas, newPoints, newPaint);
    _drawPath(canvas, returningPoints, returningPaint);

    final newDotPaint = Paint()..color = const Color(0xFF7A5A10);
    final returningDotPaint = Paint()..color = const Color(0xFFB48A45);
    for (final point in newPoints) {
      canvas.drawCircle(point, 3, newDotPaint);
    }
    for (final point in returningPoints) {
      canvas.drawCircle(point, 3, returningDotPaint);
    }
  }

  double _valueY(double value, double maxValue, double chartHeight) {
    const topPadding = 12.0;
    return topPadding + chartHeight - (value / maxValue) * chartHeight;
  }

  double _newValue(Map<String, dynamic> item) {
    for (final key in const [
      'new',
      'newCustomers',
      'new_customers',
      'newCustomerCount',
      'new_count',
    ]) {
      final value = asDouble(item[key]);
      if (value != 0) return value;
    }
    return 0;
  }

  double _returningValue(Map<String, dynamic> item) {
    for (final key in const [
      'returning',
      'returningCustomers',
      'returning_customers',
      'returningCustomerCount',
      'returning_count',
    ]) {
      final value = asDouble(item[key]);
      if (value != 0) return value;
    }
    return 0;
  }

  String _pointLabel(Map<String, dynamic> item, int index) {
    for (final key in const ['label', 'displayDate', 'dateLabel', 'date']) {
      final text = cleanText(item[key]);
      if (text.isEmpty) continue;
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return DateFormat('d MMM').format(parsed.toLocal());
      return text;
    }
    return index == 0 ? '1 Jun' : '';
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final isVertical = (start.dx - end.dx).abs() < 0.01;
    var current = isVertical ? start.dy : start.dx;
    final endValue = isVertical ? end.dy : end.dx;
    while (current < endValue) {
      final next = math.min(current + dashWidth, endValue);
      canvas.drawLine(
        isVertical ? Offset(start.dx, current) : Offset(current, start.dy),
        isVertical ? Offset(end.dx, next) : Offset(next, end.dy),
        paint,
      );
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _CustomerGrowthTrendPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _OwnerBranchOption {
  const _OwnerBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get displayLabel => branchName.isEmpty ? salonName : branchName;
}

class _ClientsBranchSelector extends StatelessWidget {
  const _ClientsBranchSelector({
    required this.isLoading,
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  final bool isLoading;
  final List<_OwnerBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<_OwnerBranchOption> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    _OwnerBranchOption? selected;
    for (final branch in branches) {
      if (branch.branchId == selectedBranchId) {
        selected = branch;
        break;
      }
    }

    if (isLoading) {
      return const _SharedBranchSelectorShell(
        child: Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF8B6500),
          ),
        ),
      );
    }

    if (branches.isEmpty) {
      return _SharedBranchSelectorShell(
        child: Text(
          context.t('No branches available'),
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedBranch = selected ?? branches.first;
    return OwnerBranchHeaderSelector<int>(
      label: selectedBranch.displayLabel,
      options: branches
          .map(
            (branch) => OwnerBranchHeaderSelectorOption<int>(
              value: branch.branchId,
              label: branch.displayLabel,
              subtitle: branch.address,
            ),
          )
          .toList(),
      selectedValue: selectedBranch.branchId,
      placeholder: context.t('Select Branch'),
      isInteractive: branches.length > 1,
      onSelected: (branchId) {
        final branch = branches.firstWhere(
          (item) => item.branchId == branchId,
          orElse: () => selectedBranch,
        );
        onBranchSelected(branch);
      },
    );
  }
}

class _SharedBranchSelectorShell extends StatelessWidget {
  const _SharedBranchSelectorShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9CBBB)),
      ),
      child: child,
    );
  }
}
