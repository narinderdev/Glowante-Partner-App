import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';

String _cleanText(dynamic value) => value?.toString().trim() ?? '';

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_cleanText(value));
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = _cleanText(value).toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _cleanText(map[key]);
    if (value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return fallback;
}

String _friendlyError(Object error) {
  final text = error.toString().trim();
  if (text.startsWith('Exception: ')) {
    return text.substring(11).trim();
  }
  return text;
}

List<Map<String, dynamic>> _extractAccounts(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  if (raw is Map<String, dynamic>) {
    for (final key in const [
      'data',
      'accounts',
      'payoutAccounts',
      'payout_accounts',
      'items',
      'rows',
      'results',
    ]) {
      final nested = _extractAccounts(raw[key]);
      if (nested.isNotEmpty) return nested;
    }
  }

  if (raw is Map) {
    return _extractAccounts(Map<String, dynamic>.from(raw));
  }

  return const <Map<String, dynamic>>[];
}

class AddBankDetailScreen extends StatefulWidget {
  const AddBankDetailScreen({super.key, this.salonId});

  final int? salonId;

  @override
  State<AddBankDetailScreen> createState() => _AddBankDetailScreenState();
}

class _AddBankDetailScreenState extends State<AddBankDetailScreen> {
  final ApiService _apiService = ApiService();

  int? _salonId;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _accounts = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _salonId = widget.salonId ?? prefs.getInt('selected_salon_id');

    if (!mounted) return;

    if (_salonId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = translateText(
          'Select a salon first to manage bank details.',
        );
      });
      return;
    }

    await _loadAccounts();
  }

  Future<void> _loadAccounts({bool silent = false}) async {
    if (_salonId == null) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _apiService.getSalonPayoutAccounts(_salonId!);
      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ??
              translateText('Failed to load bank details'),
        );
      }

      final accounts = _extractAccounts(response['data']);

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? account}) async {
    if (_salonId == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SalonPayoutAccountFormScreen(
          salonId: _salonId!,
          existingAccount: account,
        ),
      ),
    );

    if (result == true) {
      await _loadAccounts(silent: true);
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    if (_salonId == null) return;

    final payoutAccountId =
        _readInt(account['id'] ?? account['payoutAccountId']);
    if (payoutAccountId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(translateText('Delete bank account?')),
        content: Text(
          translateText(
            'Are you sure you want to delete this payout account?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(translateText('Cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(translateText('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.deleteSalonPayoutAccount(
        salonId: _salonId!,
        payoutAccountId: payoutAccountId,
      );

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ??
              translateText('Failed to delete bank details'),
        );
      }

      Fluttertoast.showToast(
        msg: response['message']?.toString() ??
            translateText('Bank account deleted successfully'),
      );
      await _loadAccounts(silent: true);
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Bank Details'),
      ),
      floatingActionButton: _salonId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(translateText('Add Bank Details')),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadAccounts(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
            children: [
              _SummaryCard(
                salonId: _salonId,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 14),
              if (_errorMessage != null) ...[
                _ErrorCard(message: _errorMessage!),
                const SizedBox(height: 14),
              ],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_accounts.isEmpty)
                const _EmptyAccountsState()
              else
                ..._accounts.expand(
                  (account) => [
                    _PayoutAccountCard(
                      account: account,
                      onEdit: () => _openForm(account: account),
                      onDelete: () => _deleteAccount(account),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.salonId,
    required this.isLoading,
  });

  final int? salonId;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_balance_outlined,
            color: AppColors.starColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Salon Payout Accounts'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF201B17),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  salonId == null
                      ? translateText(
                          'Select a salon to manage payout accounts.')
                      : translateText(
                          'Manage the bank account used for salon settlements.',
                        ),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF6F665E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C2C2)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF9C2E2E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 34,
            color: Color(0xFFB58A2D),
          ),
          const SizedBox(height: 10),
          Text(
            translateText('No bank details added yet'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF201B17),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translateText(
              'Add a payout account to receive salon settlements.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF6F665E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutAccountCard extends StatelessWidget {
  const _PayoutAccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final displayName = _firstText(account, const [
      'displayName',
      'name',
      'accountName',
      'label',
    ]);
    final provider =
        _firstText(account, const ['provider'], fallback: 'RAZORPAY');
    final holder = _firstText(account, const [
      'accountHolderName',
      'holderName',
      'beneficiaryName',
    ]);
    final maskedAccountNumber = _firstText(account, const [
      'maskedAccountNumber',
      'accountNumber',
      'maskedAccountNo',
    ]);
    final bankName = _firstText(account, const ['bankName', 'bank']);
    final ifsc = _firstText(account, const ['ifsc', 'ifscCode']).toUpperCase();
    final notes = _firstText(account, const ['notes', 'remark']);
    final isDefault = _readBool(account['isDefault'] ?? account['default']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DED6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 6),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.starColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName.isEmpty
                                ? translateText('Payout Account')
                                : displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF201B17),
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.starColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A7C6A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: translateText('Edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: translateText('Delete'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AccountRow(
            label: translateText('Account Holder'),
            value: holder.isEmpty ? 'N/A' : holder,
          ),
          _AccountRow(
            label: translateText('Account Number'),
            value: maskedAccountNumber.isEmpty ? 'N/A' : maskedAccountNumber,
          ),
          _AccountRow(
            label: translateText('Bank Name'),
            value: bankName.isEmpty ? 'N/A' : bankName,
          ),
          _AccountRow(
            label: translateText('IFSC'),
            value: ifsc.isEmpty ? 'N/A' : ifsc,
          ),
          if (notes.isNotEmpty)
            _AccountRow(
              label: translateText('Notes'),
              value: notes,
            ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A7C6A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF201B17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonPayoutAccountFormScreen extends StatefulWidget {
  const _SalonPayoutAccountFormScreen({
    required this.salonId,
    this.existingAccount,
  });

  final int salonId;
  final Map<String, dynamic>? existingAccount;

  @override
  State<_SalonPayoutAccountFormScreen> createState() =>
      _SalonPayoutAccountFormScreenState();
}

class _SalonPayoutAccountFormScreenState
    extends State<_SalonPayoutAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _maskedAccountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ifscController = TextEditingController();
  final _razorpayContactIdController = TextEditingController();
  final _razorpayFundAccountIdController = TextEditingController();
  final _notesController = TextEditingController();

  final ApiService _apiService = ApiService();

  bool _isSaving = false;
  bool _isDefault = false;
  String _provider = 'RAZORPAY';

  static const List<String> _providers = <String>['RAZORPAY'];

  @override
  void initState() {
    super.initState();
    final account = widget.existingAccount;
    if (account != null) {
      _displayNameController.text =
          _firstText(account, const ['displayName', 'name', 'label']);
      _accountHolderNameController.text = _firstText(account, const [
        'accountHolderName',
        'holderName',
        'beneficiaryName',
      ]);
      _maskedAccountNumberController.text = _firstText(account, const [
        'maskedAccountNumber',
        'accountNumber',
        'maskedAccountNo',
      ]);
      _bankNameController.text =
          _firstText(account, const ['bankName', 'bank']);
      _ifscController.text = _firstText(account, const ['ifsc', 'ifscCode']);
      _razorpayContactIdController.text = _firstText(account, const [
        'razorpayContactId',
        'contactId',
      ]);
      _razorpayFundAccountIdController.text = _firstText(account, const [
        'razorpayFundAccountId',
        'fundAccountId',
      ]);
      _notesController.text = _firstText(account, const ['notes', 'remark']);
      _isDefault = _readBool(account['isDefault'] ?? account['default']);
      final provider = _firstText(account, const ['provider']);
      if (provider.isNotEmpty) {
        _provider = provider;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _accountHolderNameController.dispose();
    _maskedAccountNumberController.dispose();
    _bankNameController.dispose();
    _ifscController.dispose();
    _razorpayContactIdController.dispose();
    _razorpayFundAccountIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) {
    final text = _cleanText(value);
    if (text.isEmpty) {
      return translateText('{field} is required').replaceAll('{field}', field);
    }
    return null;
  }

  String? _validateIfsc(String? value) {
    final text = _cleanText(value).toUpperCase();
    if (text.isEmpty) {
      return translateText('IFSC code is required');
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(text)) {
      return translateText('Enter a valid IFSC code');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final existingAccountId = _readInt(
        widget.existingAccount?['id'] ??
            widget.existingAccount?['payoutAccountId'],
      );

      if (widget.existingAccount != null && existingAccountId == null) {
        throw Exception(
          translateText('Missing payout account id'),
        );
      }

      final payload = <String, dynamic>{
        'provider': _provider,
        'displayName': _displayNameController.text.trim(),
        'accountHolderName': _accountHolderNameController.text.trim(),
        'maskedAccountNumber': _maskedAccountNumberController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'ifsc': _ifscController.text.trim().toUpperCase(),
        if (_razorpayContactIdController.text.trim().isNotEmpty)
          'razorpayContactId': _razorpayContactIdController.text.trim(),
        if (_razorpayFundAccountIdController.text.trim().isNotEmpty)
          'razorpayFundAccountId': _razorpayFundAccountIdController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        'isDefault': _isDefault,
      };

      final response = widget.existingAccount == null
          ? await _apiService.createSalonPayoutAccount(
              salonId: widget.salonId,
              payload: payload,
            )
          : await _apiService.updateSalonPayoutAccount(
              salonId: widget.salonId,
              payoutAccountId: existingAccountId!,
              payload: payload,
            );

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ??
              translateText('Failed to save bank details'),
        );
      }

      if (!mounted) return;
      Fluttertoast.showToast(
        msg: response['message']?.toString() ??
            translateText('Bank details saved successfully'),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingAccount != null;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title:
            translateText(isEditing ? 'Edit Bank Details' : 'Add Bank Details'),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Form(
              key: _formKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8DED6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText(
                        'Create a salon payout account reference',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF201B17),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translateText(
                        'This account will be used for salon settlement payouts.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF6F665E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      controller: _displayNameController,
                      label: 'Display Name *',
                      hint: 'Enter display name',
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          _required(value, translateText('Display Name')),
                    ),
                    _field(
                      controller: _accountHolderNameController,
                      label: 'Account Holder Name *',
                      hint: 'Enter account holder name',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                        LengthLimitingTextInputFormatter(60),
                      ],
                      validator: (value) => _required(
                          value, translateText('Account Holder Name')),
                    ),
                    _field(
                      controller: _maskedAccountNumberController,
                      label: 'Masked Account Number *',
                      hint: 'Enter masked account number',
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9Xx* -]'),
                        ),
                        LengthLimitingTextInputFormatter(24),
                      ],
                      validator: (value) => _required(
                          value, translateText('Masked Account Number')),
                    ),
                    _field(
                      controller: _bankNameController,
                      label: 'Bank Name *',
                      hint: 'Enter bank name',
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          _required(value, translateText('Bank Name')),
                    ),
                    _field(
                      controller: _ifscController,
                      label: 'IFSC *',
                      hint: 'Enter IFSC code',
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: _validateIfsc,
                    ),
                    DropdownButtonFormField<String>(
                      value: _providers.contains(_provider)
                          ? _provider
                          : _providers.first,
                      decoration: InputDecoration(
                        labelText: translateText('Provider'),
                        filled: true,
                        fillColor: const Color(0xFFFAF8F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2D3BF)),
                        ),
                      ),
                      items: _providers
                          .map(
                            (provider) => DropdownMenuItem<String>(
                              value: provider,
                              child: Text(provider),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _provider = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _razorpayContactIdController,
                      label: 'Razorpay Contact ID',
                      hint: 'Enter Razorpay contact id',
                    ),
                    _field(
                      controller: _razorpayFundAccountIdController,
                      label: 'Razorpay Fund Account ID',
                      hint: 'Enter Razorpay fund account id',
                    ),
                    _field(
                      controller: _notesController,
                      label: 'Notes',
                      hint: 'Enter notes',
                      maxLines: 3,
                      bottomSpacing: 14,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      onChanged: (value) => setState(() => _isDefault = value),
                      title: Text(translateText('Set as default')),
                      subtitle: Text(
                        translateText('Use this payout account by default.'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                translateText(
                                  isEditing
                                      ? 'Update Bank Details'
                                      : 'Save Bank Details',
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    double bottomSpacing = 14,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: translateText(label.replaceAll('*', '').trim()),
          hintText: translateText(hint),
          filled: true,
          fillColor: const Color(0xFFFAF8F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFFD8C7B3),
              width: 1.2,
            ),
          ),
        ),
        validator: validator ??
            (value) => _required(
                value, translateText(label.replaceAll('*', '').trim())),
      ),
    );
  }
}
