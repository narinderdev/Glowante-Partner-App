import 'package:flutter/material.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<_OwnerBranchOption> _branchOptions = const [];
  List<Map<String, dynamic>> _clients = const [];
  int? _selectedBranchId;
  bool _isLoadingBranches = true;
  bool _isLoadingClients = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

      if (selectedBranchId != null) {
        await _loadClientsForBranch(selectedBranchId, saveSelection: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingBranches = false;
        _errorMessage = error.toString();
      });
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingClients = false;
        _errorMessage = error.toString();
      });
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

  @override
  Widget build(BuildContext context) {
    final comingSoonText = translateText('Coming Soon');
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(comingSoonText)),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 18),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(comingSoonText)),
                    );
                  },
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
                  final isCompactTable = constraints.maxWidth < 720;

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

                  if (isCompactTable) {
                    return Column(
                      children: filteredClients.map((client) {
                        final name = [
                          _cleanText(client['firstName']),
                          _cleanText(client['lastName']),
                        ].where((part) => part.isNotEmpty).join(' ');
                        final email = _cleanText(client['email']);
                        final contact = _cleanText(
                          client['phoneNumber'] ?? client['fullPhoneNumber'],
                        );
                        final isActive = client['active'] != false;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? context.t('Customer') : name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              if (contact.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  contact,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
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
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'NAME',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'EMAIL',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'CONTACT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'STATUS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...filteredClients.map((client) {
                        final name = [
                          _cleanText(client['firstName']),
                          _cleanText(client['lastName']),
                        ].where((part) => part.isNotEmpty).join(' ');
                        final email = _cleanText(client['email']);
                        final contact = _cleanText(
                          client['phoneNumber'] ?? client['fullPhoneNumber'],
                        );
                        final isActive = client['active'] != false;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  name.isEmpty ? context.t('Customer') : name,
                                ),
                              ),
                              Expanded(flex: 4, child: Text(email)),
                              Expanded(flex: 3, child: Text(contact)),
                              Expanded(
                                flex: 2,
                                child: Text(
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
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
