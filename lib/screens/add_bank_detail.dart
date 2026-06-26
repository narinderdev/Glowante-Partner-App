import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class AddBankDetailScreen extends StatefulWidget {
  const AddBankDetailScreen({super.key});

  @override
  State<AddBankDetailScreen> createState() => _AddBankDetailScreenState();
}

class _AddBankDetailScreenState extends State<AddBankDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _upiIdController = TextEditingController();

  bool _submitted = false;

  @override
  void dispose() {
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscController.dispose();
    _branchNameController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translateText('Bank details saved locally. API integration pending.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar:
          buildProfileSubpageAppBar(title: translateText('Add Bank Details')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translateText('Settlement Account'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF161616),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          translateText(
                            'Payments collected from customers will be settled to this bank account.',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF6F665E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _bankField(
                          controller: _accountHolderController,
                          label: 'Account Holder Name *',
                          hint: 'Enter account holder name',
                          textCapitalization: TextCapitalization.words,
                        ),
                        _bankField(
                          controller: _bankNameController,
                          label: 'Bank Name *',
                          hint: 'Enter bank name',
                          textCapitalization: TextCapitalization.words,
                        ),
                        _bankField(
                          controller: _accountNumberController,
                          label: 'Account Number *',
                          hint: 'Enter account number',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(18),
                          ],
                        ),
                        _bankField(
                          controller: _confirmAccountNumberController,
                          label: 'Confirm Account Number *',
                          hint: 'Re-enter account number',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(18),
                          ],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return translateText(
                                '{field} is required',
                              ).replaceAll(
                                '{field}',
                                translateText('Confirm Account Number'),
                              );
                            }
                            if (text != _accountNumberController.text.trim()) {
                              return translateText(
                                'Account numbers do not match',
                              );
                            }
                            return null;
                          },
                        ),
                        _bankField(
                          controller: _ifscController,
                          label: 'IFSC Code *',
                          hint: 'Enter IFSC code',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: (value) {
                            final text = value?.trim().toUpperCase() ?? '';
                            if (text.isEmpty) {
                              return translateText(
                                '{field} is required',
                              ).replaceAll(
                                '{field}',
                                translateText('IFSC Code'),
                              );
                            }
                            if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                .hasMatch(text)) {
                              return translateText('Enter a valid IFSC code');
                            }
                            return null;
                          },
                        ),
                        _bankField(
                          controller: _branchNameController,
                          label: 'Branch Name *',
                          hint: 'Enter branch name',
                          textCapitalization: TextCapitalization.words,
                        ),
                        _bankField(
                          controller: _upiIdController,
                          label: 'UPI ID',
                          hint: 'Enter UPI ID (optional)',
                          keyboardType: TextInputType.emailAddress,
                          bottomSpacing: 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.starColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            translateText(
                              'This screen prepares the payout destination for salon earnings. Live verification and save API will be added later.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF6F665E),
                              fontSize: 12,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        translateText('Save Bank Details'),
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
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldLabel(String label) {
    final normalized = label.replaceAll('*', '').trim();
    final localized = translateText(normalized);
    final isRequired = label.contains('*');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: localized.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF463E37),
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.red),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _bankField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    double bottomSpacing = 18,
  }) {
    final localizedLabel = translateText(label.replaceAll('*', '').trim());
    final isRequired = label.contains('*');

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            validator: validator ??
                (value) {
                  final text = value?.trim() ?? '';
                  if (isRequired && text.isEmpty) {
                    return translateText(
                      '{field} is required',
                    ).replaceAll('{field}', localizedLabel);
                  }
                  return null;
                },
            decoration: InputDecoration(
              hintText: translateText(hint),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD1A24A),
                  width: 1.2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
