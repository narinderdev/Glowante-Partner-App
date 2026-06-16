import 'package:flutter/material.dart';

import '../utils/api_service.dart';
import '../utils/localization_helper.dart';

const Color _clientGold = Color(0xFF8B6500);
const Color _clientInk = Color(0xFF1F1B18);
const Color _clientMuted = Color(0xFF6F665E);
const Color _clientBorder = Color(0xFFE8DED6);

class ViewAllClientOwnerScreen extends StatefulWidget {
  const ViewAllClientOwnerScreen({
    super.key,
    required this.branchId,
    this.initialCustomers = const [],
  });

  final int branchId;
  final List<Map<String, dynamic>> initialCustomers;

  @override
  State<ViewAllClientOwnerScreen> createState() =>
      _ViewAllClientOwnerScreenState();
}

class _ViewAllClientOwnerScreenState extends State<ViewAllClientOwnerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _customers = List<Map<String, dynamic>>.from(widget.initialCustomers);
    _searchController.addListener(() => setState(() {}));
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _apiService.getBranchCustomersList(widget.branchId);
      final customers = _extractCustomers(response['data']);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  List<Map<String, dynamic>> _extractCustomers(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => _normalizeCustomer(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (raw is Map) {
      for (final key in const ['data', 'customers', 'clients', 'items']) {
        final nested = raw[key];
        if (nested != null) {
          final extracted = _extractCustomers(nested);
          if (extracted.isNotEmpty) return extracted;
        }
      }
      return raw.isEmpty
          ? const []
          : [_normalizeCustomer(Map<String, dynamic>.from(raw))];
    }
    return const [];
  }

  Map<String, dynamic> _normalizeCustomer(Map<String, dynamic> customer) {
    final name = (customer['name'] ??
            customer['displayName'] ??
            customer['fullName'] ??
            customer['customerName'] ??
            '')
        .toString()
        .trim();
    if (name.isNotEmpty) {
      customer['displayName'] = name;
      final parts = name.split(RegExp(r'\s+'));
      customer.putIfAbsent('firstName', () => parts.first);
      customer.putIfAbsent(
        'lastName',
        () => parts.length > 1 ? parts.sublist(1).join(' ') : '',
      );
    }
    return customer;
  }

  String _cleanError(Object error) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    if (raw.contains('<html') || raw.contains('Bad Gateway')) {
      return translateText('Unable to load customers right now.');
    }
    return raw.isEmpty ? translateText('Unable to load customers.') : raw;
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _customerName(Map<String, dynamic> customer) {
    final explicitName = (customer['displayName'] ??
            customer['name'] ??
            customer['fullName'] ??
            customer['customerName'] ??
            '')
        .toString()
        .trim();
    if (explicitName.isNotEmpty) return explicitName;

    final firstName = (customer['firstName'] ?? '').toString().trim();
    final lastName = (customer['lastName'] ?? '').toString().trim();
    return '$firstName $lastName'.trim();
  }

  String _customerPhone(Map<String, dynamic> customer) {
    final fullPhone = (customer['fullPhoneNumber'] ?? '').toString().trim();
    if (fullPhone.isNotEmpty) return fullPhone;
    final phone = (customer['phoneNumber'] ?? '').toString().trim();
    if (phone.startsWith('+')) return phone;
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) return '';
    return digits.startsWith('91') && digits.length > 10
        ? '+$digits'
        : '+91$digits';
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    final query = _searchController.text.trim().toLowerCase();
    final queryDigits = _digitsOnly(query);
    if (query.isEmpty) return _customers;

    return _customers.where((customer) {
      final name = _customerName(customer).toLowerCase();
      final phone = _digitsOnly(_customerPhone(customer));
      return name.contains(query) ||
          (queryDigits.isNotEmpty && phone.contains(queryDigits));
    }).toList();
  }

  Widget _avatar(Map<String, dynamic> customer) {
    final name = _customerName(customer);
    final initial = name.isEmpty ? 'G' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFF5EAD2),
      child: Text(
        initial,
        style: const TextStyle(
          color: _clientGold,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filteredCustomers;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _clientGold,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          translateText('All Customers'),
          style: const TextStyle(
            color: _clientGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                // maxLength: 60,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: translateText('Search customer...'),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _clientGold,
                    size: 19,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _clientBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _clientBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _clientGold, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _clientGold,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _errorMessage != null
                        ? _ErrorState(
                            message: _errorMessage!,
                            onRetry: _loadCustomers,
                          )
                        : customers.isEmpty
                            ? Center(
                                child: Text(
                                  translateText('No customers found'),
                                  style: const TextStyle(
                                    color: _clientMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: customers.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final customer = customers[index];
                                  final name = _customerName(customer);
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          Navigator.pop(context, customer),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _clientBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _avatar(customer),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name.isEmpty
                                                        ? translateText(
                                                            'Unnamed customer',
                                                          )
                                                        : name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: _clientInk,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _customerPhone(customer),
                                                    style: const TextStyle(
                                                      color: _clientMuted,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: _clientGold,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(translateText('Retry')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _clientGold,
              side: const BorderSide(color: _clientGold),
            ),
          ),
        ],
      ),
    );
  }
}
