import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/input_validation.dart';
import '../utils/localization_helper.dart';
import '../widgets/app_loader.dart';
import '../widgets/dialog_scoped_resources.dart';

final RegExp _clientNamePattern = RegExp(r'^[A-Za-z ]+$');
final RegExp _clientPhonePattern = RegExp(r'^[6-9][0-9]{9}$');

// Raw client directory for a salon — unlike OwnerBranchClientsScreen's
// engagement dashboard (which only lists clients with booking activity in
// the selected date range), this shows every customer of the salon via
// `salons/{id}/customers`, including ones added by import who haven't
// booked yet. Customers are salon-scoped, so this list is the same for
// every branch of the salon.
class OwnerBranchAllClientsScreen extends StatefulWidget {
  const OwnerBranchAllClientsScreen({super.key, required this.salonId});

  final int salonId;

  @override
  State<OwnerBranchAllClientsScreen> createState() =>
      _OwnerBranchAllClientsScreenState();
}

class _OwnerBranchAllClientsScreenState
    extends State<OwnerBranchAllClientsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiService.getSalonCustomers(widget.salonId);
      final clients = _extractClients(response['data']);
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  List<Map<String, dynamic>> _extractClients(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => _normalizeClient(item))
          .toList();
    }

    if (raw is Map) {
      for (final key in const [
        'data',
        'customers',
        'clients',
        'items',
        'results'
      ]) {
        final nested = raw[key];
        if (nested != null) {
          final extracted = _extractClients(nested);
          if (extracted.isNotEmpty) return extracted;
        }
      }
      return raw.isEmpty ? const [] : [_normalizeClient(raw)];
    }

    return const [];
  }

  Map<String, dynamic> _normalizeClient(Map<dynamic, dynamic> raw) {
    final client = Map<String, dynamic>.from(raw);
    for (final nestedKey in const ['customer', 'user', 'client']) {
      final nested = client[nestedKey];
      if (nested is Map) {
        final nestedClient = Map<String, dynamic>.from(nested);
        for (final entry in client.entries) {
          if (entry.key == 'customer' ||
              entry.key == 'user' ||
              entry.key == 'client') {
            continue;
          }
          nestedClient.putIfAbsent(entry.key, () => entry.value);
        }
        return _normalizeClient(nestedClient);
      }
    }

    final name = _clientName(client);
    if (name.isNotEmpty) {
      client['displayName'] = name;
      client['name'] = name;
    }
    return client;
  }

  String _clientName(Map<String, dynamic> client) {
    final explicitName = (client['displayName'] ??
            client['name'] ??
            client['fullName'] ??
            client['customerName'] ??
            '')
        .toString()
        .trim();
    if (explicitName.isNotEmpty) return explicitName;

    final firstName = (client['firstName'] ?? '').toString().trim();
    final lastName = (client['lastName'] ?? '').toString().trim();
    return '$firstName $lastName'.trim();
  }

  String _clientPhone(Map<String, dynamic> client) {
    final fullPhone = (client['fullPhoneNumber'] ?? '').toString().trim();
    if (fullPhone.isNotEmpty) return fullPhone;
    return (client['phoneNumber'] ?? '').toString().trim();
  }

  String _clientEmail(Map<String, dynamic> client) {
    return (client['email'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();
    final queryDigits = _digitsOnly(query);
    if (query.isEmpty) return _clients;
    return _clients.where((client) {
      final name = _clientName(client).toLowerCase();
      final phone = _clientPhone(client).toLowerCase();
      final phoneDigits = _digitsOnly(phone);
      final email = _clientEmail(client).toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          (queryDigits.isNotEmpty && phoneDigits.contains(queryDigits)) ||
          email.contains(query);
    }).toList();
  }

  String? _validateClientName(String value) {
    if (value.isEmpty) {
      return translateText(
        '{label} is required',
        params: {'label': translateText('Name')},
      );
    }
    if (!_clientNamePattern.hasMatch(value)) {
      return translateText(
        '{label} should contain alphabets only',
        params: {'label': translateText('Name')},
      );
    }
    return null;
  }

  String? _validateClientPhone(String value) {
    if (value.isEmpty) return translateText('Phone number is required');
    if (!_clientPhonePattern.hasMatch(value)) {
      return translateText(
        'Enter a valid 10-digit phone number starting with 6, 7, 8, or 9',
      );
    }
    return null;
  }

  String _extractApiErrorMessage(Object error) {
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is List && message.isNotEmpty) {
        return message.first.toString().trim();
      }
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final errorValue = error['error'];
      if (errorValue is String && errorValue.trim().isNotEmpty) {
        return errorValue.trim();
      }
    }

    var text = error.toString().trim();
    const exceptionPrefix = 'Exception:';
    if (text.startsWith(exceptionPrefix)) {
      text = text.substring(exceptionPrefix.length).trim();
    }
    if (text.contains('<html') ||
        text.contains('Bad Gateway') ||
        text.contains('nginx')) {
      return translateText('Something went wrong. Please try again.');
    }
    return text.isEmpty
        ? translateText('Something went wrong. Please try again.')
        : text;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;
    String? nameError;
    String? phoneError;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => DialogScopedResources(
          resources: [nameController, phoneController],
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final maxDialogHeight = MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom -
                  48;

              Future<void> submit() async {
                final name =
                    nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                final phone = _digitsOnly(phoneController.text);

                setDialogState(() {
                  nameError = _validateClientName(name);
                  phoneError = _validateClientPhone(phone);
                });

                if (nameError != null || phoneError != null) return;

                setDialogState(() => isSubmitting = true);
                try {
                  final response = await _apiService.addSalonCustomer(
                    salonId: widget.salonId,
                    name: name,
                    phoneNumber: phone,
                  );

                  if (response['success'] == false) {
                    throw response;
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _showSnack(translateText('Customer added successfully'));
                  await _load();
                } catch (error) {
                  _showSnack(_extractApiErrorMessage(error));
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => isSubmitting = false);
                  }
                }
              }

              return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                backgroundColor: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxDialogHeight),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translateText('Add New Customer'),
                          style: const TextStyle(
                            color: Color(0xFF1C1917),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _DialogRequiredLabel(label: translateText('Name')),
                        _DialogTextField(
                          controller: nameController,
                          hint: "Enter guest's name",
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 60,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              AppInputRules.namePattern,
                            ),
                            LengthLimitingTextInputFormatter(60),
                          ],
                          onChanged: (_) {
                            if (nameError != null) {
                              setDialogState(() => nameError = null);
                            }
                          },
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        if (nameError != null) _DialogErrorText(nameError!),
                        const SizedBox(height: 14),
                        _DialogRequiredLabel(
                          label: translateText('Phone Number'),
                        ),
                        _DialogTextField(
                          controller: phoneController,
                          hint: translateText('Enter phone no'),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          maxLength: 10,
                          prefixText: '+91  ',
                          inputFormatters: AppInputRules.phoneFormatters,
                          onChanged: (_) {
                            if (phoneError != null) {
                              setDialogState(() => phoneError = null);
                            }
                          },
                          onSubmitted: (_) => submit(),
                        ),
                        if (phoneError != null) _DialogErrorText(phoneError!),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: const Color(0x338B6500),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: isSubmitting
                                ? AppLoader.inline(
                                    size: 18,
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  )
                                : Text(
                                    translateText('Add Customer').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('All Clients')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    cursorColor: AppColors.starColor,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.t('Search by name, phone or email'),
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF78716C),
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF78716C),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(
                          color: AppColors.starColor,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: translateText('Add Client'),
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _showAddClientDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(context.t('Add Client')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE7E5E4),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: AppLoader.page()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (clients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    context.t('No clients found'),
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              ...clients.map((client) => _ClientTile(client: client)),
          ],
        ),
      ),
    );
  }
}

class _DialogRequiredLabel extends StatelessWidget {
  const _DialogRequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF1C1917),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.prefixText,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: AppColors.starColor,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB9A999), fontSize: 13),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: Color(0xFF1C1917),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFFBFAF8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.starColor, width: 1.4),
        ),
      ),
    );
  }
}

class _DialogErrorText extends StatelessWidget {
  const _DialogErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client});

  final Map<String, dynamic> client;

  @override
  Widget build(BuildContext context) {
    final name =
        (client['displayName'] ?? client['name'] ?? '').toString().trim();
    final phone = (client['fullPhoneNumber'] ?? client['phoneNumber'] ?? '')
        .toString()
        .trim();
    final email = (client['email'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.starColor.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: AppColors.starColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.t('Unnamed') : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
