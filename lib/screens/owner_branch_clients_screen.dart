import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

class OwnerBranchClientsScreen extends StatefulWidget {
  const OwnerBranchClientsScreen({super.key});

  @override
  State<OwnerBranchClientsScreen> createState() =>
      _OwnerBranchClientsScreenState();
}

class _OwnerBranchClientsScreenState extends State<OwnerBranchClientsScreen> {
  static const double _serialColWidth = 72;
  static const double _nameColWidth = 220;
  static const double _mobileColWidth = 180;
  static const double _statusColWidth = 120;
  static const double _actionColWidth = 140;
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
  int? _selectedBranchId;
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
      final response = await _apiService.getBranchClients(branchId);
      final clients = _extractClients(response['data']);
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

  List<Map<String, dynamic>> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;
    return _clients.where((client) {
      final first = _cleanText(client['firstName']).toLowerCase();
      final last = _cleanText(client['lastName']).toLowerCase();
      final email = _cleanText(client['email']).toLowerCase();
      final phone = _cleanText(
        client['phoneNumber'] ?? client['fullPhoneNumber'],
      ).toLowerCase();
      final fullName = '$first $last'.trim();
      return fullName.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _formatCreatedAt(dynamic value) {
    final raw = _cleanText(value);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }

  String _formatDateValue(dynamic value) {
    final raw = _cleanText(value);
    if (raw.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  String _formatAmount(dynamic value) {
    if (value is num) {
      return '₹${value.toStringAsFixed(0)}';
    }
    final parsed = num.tryParse(_cleanText(value));
    if (parsed == null) {
      return _cleanText(value).isEmpty ? 'N/A' : _cleanText(value);
    }
    return '₹${parsed.toStringAsFixed(0)}';
  }

  String _formatMinorAmount(dynamic value, {String currency = 'INR'}) {
    final amount = value is num
        ? value.toDouble()
        : num.tryParse(_cleanText(value))?.toDouble();
    if (amount == null) return 'N/A';

    final normalized = amount / 100;
    if (currency.toUpperCase() == 'INR') {
      return '₹${normalized.toStringAsFixed(2)}';
    }
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

    final clientName = [
      _cleanText(client['firstName']),
      _cleanText(client['lastName']),
    ].where((part) => part.isNotEmpty).join(' ');
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
          'ID',
          'First Name',
          'Last Name',
          'Email',
          'Phone Number',
          'Status',
          'Role',
          'Created At',
        ].map(_csvCell).join(','),
      ];

      for (final client in _clients) {
        rows.add(
          [
            _cleanText(client['id']),
            _cleanText(client['firstName']),
            _cleanText(client['lastName']),
            _cleanText(client['email']),
            _cleanText(client['phoneNumber'] ?? client['fullPhoneNumber']),
            client['active'] == false
                ? translateText('Inactive')
                : translateText('Active'),
            _cleanText(client['role'] ?? client['userType'] ?? 'App User'),
            _formatCreatedAt(
              client['createdAt'] ??
                  client['created_at'] ??
                  client['updatedAt'],
            ),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7E5E4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Branches').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingBranches)
                    const Center(child: CircularProgressIndicator())
                  else if (_branchOptions.isEmpty)
                    Text(context.t('No branches available'))
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _branchOptions.map((option) {
                        final isSelected = option.branchId == _selectedBranchId;
                        return InkWell(
                          onTap: () => _loadClientsForBranch(option.branchId),
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected
                                      ? AppColors.starColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              option.branchName.isEmpty
                                  ? option.salonName
                                  : option.branchName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.starColor
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;

                final searchField = SizedBox(
                  width: isCompact ? double.infinity : 220,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.t("Search by user's name"),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  ),
                );

                final exportButton = OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportClients,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(context.t('Export')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF22C55E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );

                final importButton = ElevatedButton(
                  onPressed: _showImportClientsModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(context.t('Import Clients')),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.t('Branch Clients')}: ${filteredClients.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      searchField,
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          exportButton,
                          importButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '${context.t('Branch Clients')}: ${filteredClients.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    searchField,
                    const SizedBox(width: 10),
                    exportButton,
                    const SizedBox(width: 10),
                    importButton,
                  ],
                );
              },
            ),
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

                  final tableWidth =
                      constraints.maxWidth < 820 ? 820.0 : constraints.maxWidth;
                  final rowContentWidth =
                      tableWidth - (_tableHorizontalPadding * 2);
                  final baseFlexibleWidth = _nameColWidth +
                      _mobileColWidth +
                      _statusColWidth +
                      _actionColWidth;
                  final extraWidth = rowContentWidth >
                          (_serialColWidth + baseFlexibleWidth)
                      ? rowContentWidth - (_serialColWidth + baseFlexibleWidth)
                      : 0.0;
                  final nameColumnWidth = _nameColWidth + (extraWidth * 0.45);
                  final mobileColumnWidth =
                      _mobileColWidth + (extraWidth * 0.25);
                  final statusColumnWidth =
                      _statusColWidth + (extraWidth * 0.15);
                  final actionColumnWidth =
                      _actionColWidth + (extraWidth * 0.15);

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
                                _buildClientHeaderCell('S.NO', _serialColWidth),
                                _buildClientHeaderCell(
                                  'NAME',
                                  nameColumnWidth,
                                ),
                                _buildClientHeaderCell(
                                  'MOBILE',
                                  mobileColumnWidth,
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
                            final index = entry.key;
                            final client = entry.value;
                            final name = [
                              _cleanText(client['firstName']),
                              _cleanText(client['lastName']),
                            ].where((part) => part.isNotEmpty).join(' ');
                            final contact = _cleanText(
                              client['phoneNumber'] ??
                                  client['fullPhoneNumber'],
                            );
                            final isActive = client['active'] != false;
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
                                    Text('${index + 1}'),
                                    _serialColWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(
                                      name.isEmpty
                                          ? context.t('Customer')
                                          : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    nameColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(
                                      contact.isEmpty ? 'N/A' : contact,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    mobileColumnWidth,
                                  ),
                                  _buildClientBodyCell(
                                    Text(
                                      isActive
                                          ? context.t('Active')
                                          : context.t('Inactive'),
                                      style: TextStyle(
                                        color: isActive
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFEF4444),
                                        fontWeight: FontWeight.w600,
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
            const Text(
              'Page 1 of 1',
              style: TextStyle(
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
}
