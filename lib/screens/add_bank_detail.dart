import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/input_validation.dart';

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

String _maskAccountNumberForDisplay(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  if (text.contains('*') || text.contains('x') || text.contains('X')) {
    return text;
  }

  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) {
    return text;
  }

  return '${'*' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
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
      barrierDismissible: false,
      builder: (ctx) {
        var isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleDelete() async {
              if (isDeleting) return;

              setDialogState(() => isDeleting = true);

              final response = await _apiService.deleteSalonPayoutAccount(
                salonId: _salonId!,
                payoutAccountId: payoutAccountId,
              );

              if (!mounted || !context.mounted) {
                return;
              }

              setDialogState(() => isDeleting = false);

              if (response['success'] == true) {
                Navigator.pop(context, true);
                Fluttertoast.showToast(
                  msg: response['message']?.toString() ??
                      translateText('Bank account deleted successfully'),
                );
                await _loadAccounts(silent: true);
              } else {
                Fluttertoast.showToast(
                  msg: response['message']?.toString() ??
                      translateText('Failed to delete bank details'),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                translateText('Delete Account'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.starColor,
                ),
              ),
              content: Text(
                translateText(
                  'Are you sure you want to delete this payout account?',
                ),
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.pop(context, false),
                  child: Text(translateText('Cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isDeleting ? null : handleDelete,
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(translateText('Delete')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
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
    final holder = _firstText(account, const [
      'accountHolderName',
      'holderName',
      'beneficiaryName',
    ]);
    final maskedAccountNumber = _maskAccountNumberForDisplay(
      _firstText(account, const [
        'maskedAccountNumber',
        'accountNumber',
        'maskedAccountNo',
      ]),
    );
    final bankName = _firstText(account, const ['bankName', 'bank']);
    final ifsc = _firstText(account, const ['ifsc', 'ifscCode']).toUpperCase();
    final branchName = _firstText(account, const ['branchName']);
    final upiId = _firstText(account, const ['upiId']);
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
                            holder.isEmpty
                                ? translateText('Bank Details')
                                : holder,
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
                      bankName.isEmpty
                          ? translateText('Payout Account')
                          : bankName,
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
          if (branchName.isNotEmpty)
            _AccountRow(
              label: translateText('Branch Name'),
              value: branchName,
            ),
          if (upiId.isNotEmpty)
            _AccountRow(
              label: translateText('UPI ID'),
              value: upiId,
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
  final _accountHolderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ifscController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _upiIdController = TextEditingController();

  final ApiService _apiService = ApiService();

  bool _isSaving = false;
  bool _isDefault = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final account = widget.existingAccount;
    if (account != null) {
      _accountHolderNameController.text = _firstText(account, const [
        'accountHolderName',
        'holderName',
        'beneficiaryName',
      ]);
      _bankNameController.text =
          _firstText(account, const ['bankName', 'bank']);
      _ifscController.text = _firstText(account, const ['ifsc', 'ifscCode']);
      _branchNameController.text = _firstText(account, const ['branchName']);
      _upiIdController.text = _firstText(account, const ['upiId']);
      _isDefault = _readBool(account['isDefault'] ?? account['default']);
    }
  }

  @override
  void dispose() {
    _accountHolderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _bankNameController.dispose();
    _ifscController.dispose();
    _branchNameController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) {
    final text = _cleanText(value);
    if (text.isEmpty) {
      return translateText('{field} is required').replaceAll('{field}', field);
    }
    return null;
  }

  String? _requiredAfterSubmit(String? value, String field) {
    if (!_submitted) return null;
    return _required(value, field);
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

  String? _validateAccountNumber(String? value) {
    final text = _cleanText(value);
    if (text.isEmpty) {
      return translateText('Account Number is required');
    }
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return translateText('Account number must contain only digits');
    }
    return null;
  }

  String? _validateConfirmAccountNumber(String? value) {
    final text = _cleanText(value);
    if (text.isEmpty) {
      return translateText('Confirm Account Number is required');
    }
    if (text != _accountNumberController.text.trim()) {
      return translateText('Account numbers do not match');
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
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
        'accountHolderName': _accountHolderNameController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'confirmAccountNumber': _confirmAccountNumberController.text.trim(),
        'ifscCode': _ifscController.text.trim().toUpperCase(),
        if (_branchNameController.text.trim().isNotEmpty)
          'branchName': _branchNameController.text.trim(),
        if (_upiIdController.text.trim().isNotEmpty)
          'upiId': _upiIdController.text.trim(),
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
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.starColor,
              ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppColors.starColor,
            selectionColor: Color(0x33D3A94C),
            selectionHandleColor: AppColors.starColor,
          ),
        ),
        child: SafeArea(
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
                      if (isEditing) ...[
                        const SizedBox(height: 10),
                        Text(
                          translateText(
                            'The backend returns only the masked account number. Re-enter the full account number to update bank details.',
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xFF8A7C6A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _field(
                        controller: _accountHolderNameController,
                        label: 'Account Holder Name *',
                        hint: 'Enter account holder name',
                        textCapitalization: TextCapitalization.words,
                        maxLength: AppInputRules.nameMaxLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z ]')),
                          LengthLimitingTextInputFormatter(
                            AppInputRules.nameMaxLength,
                          ),
                        ],
                        validator: (value) => _requiredAfterSubmit(
                          value,
                          translateText('Account Holder Name'),
                        ),
                      ),
                      _field(
                        controller: _bankNameController,
                        label: 'Bank Name *',
                        hint: 'Enter bank name',
                        textCapitalization: TextCapitalization.words,
                        maxLength: AppInputRules.nameMaxLength,
                        validator: (value) => _requiredAfterSubmit(
                          value,
                          translateText('Bank Name'),
                        ),
                      ),
                      _field(
                        controller: _accountNumberController,
                        label: 'Account Number *',
                        hint: 'Enter full account number',
                        keyboardType: TextInputType.number,
                        maxLength: 20,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(20),
                        ],
                        validator: (value) =>
                            _submitted ? _validateAccountNumber(value) : null,
                      ),
                      _field(
                        controller: _confirmAccountNumberController,
                        label: 'Confirm Account Number *',
                        hint: 'Re-enter account number',
                        keyboardType: TextInputType.number,
                        maxLength: 20,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(20),
                        ],
                        validator: (value) => _submitted
                            ? _validateConfirmAccountNumber(value)
                            : null,
                      ),
                      _field(
                        controller: _ifscController,
                        label: 'IFSC Code *',
                        hint: 'Enter IFSC code',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (value) =>
                            _submitted ? _validateIfsc(value) : null,
                      ),
                      _field(
                        controller: _branchNameController,
                        label: 'Branch Name',
                        hint: 'Enter branch name',
                        textCapitalization: TextCapitalization.words,
                        maxLength: AppInputRules.nameMaxLength,
                        validator: (_) => null,
                      ),
                      _field(
                        controller: _upiIdController,
                        label: 'UPI ID',
                        hint: 'Enter UPI ID',
                        maxLength: AppInputRules.emailMaxLength,
                        validator: (_) => null,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isDefault,
                        onChanged: (value) =>
                            setState(() => _isDefault = value),
                        activeTrackColor:
                            AppColors.starColor.withValues(alpha: 0.32),
                        activeThumbColor: AppColors.starColor,
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.starColor
                              : const Color(0xFFBDB4AA),
                        ),
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
    void Function(String)? onChanged,
    int maxLines = 1,
    int? maxLength,
    double bottomSpacing = 14,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: TextFormField(
        controller: controller,
        cursorColor: AppColors.starColor,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: (value) {
          onChanged?.call(value);
          if (_submitted) {
            _formKey.currentState?.validate();
          }
        },
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
            (value) => _requiredAfterSubmit(
                  value,
                  translateText(label.replaceAll('*', '').trim()),
                ),
      ),
    );
  }
}
