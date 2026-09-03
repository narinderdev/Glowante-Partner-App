import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../utils/localization_helper.dart';
import '../widgets/app_loader.dart';

/// Owner/super-admin "send a salon invitation" screen (see
/// invitation_plan.md Phase 1A). Replaces the old direct
/// `branches/:id/add-user` add-member flow for brand new team members —
/// the invitee accepts the emailed invitation link on their own before any
/// salon membership is created.
class InviteTeamMemberScreen extends StatefulWidget {
  const InviteTeamMemberScreen({
    super.key,
    required this.salonId,
    this.salonName,
  });

  final int salonId;
  final String? salonName;

  @override
  State<InviteTeamMemberScreen> createState() => _InviteTeamMemberScreenState();
}

const _inviteGold = Color(0xFF8B6500);
const _inviteInk = Color(0xFF1F1A16);
const _inviteMuted = Color(0xFF776D64);
const _inviteBorder = Color(0xFFE8DDD2);
const _inviteFieldFill = Color(0xFFFAF9F8);

class _InviteTeamMemberScreenState extends State<InviteTeamMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  final RegExp _nameRegExp = RegExp(r'^[A-Za-z0-9 ]+$');
  final List<TextInputFormatter> _nameInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
  ];
  final RegExp _emailRegExp =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  bool _isSubmitting = false;

  // Validation only appears after a submit attempt (_showGlobalErrors), and
  // clears per-field the moment the user edits that field again — same
  // pattern as AddTeam.dart's suppress flags, so it doesn't nag while typing.
  bool _showGlobalErrors = false;
  bool _suppressFirstNameError = false;
  bool _suppressLastNameError = false;
  bool _suppressPhoneError = false;
  bool _suppressEmailError = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _refreshValidationIfNeeded() {
    if (!mounted || !_showGlobalErrors) return;
    _formKey.currentState?.validate();
  }

  String? _validateName(
    String? value,
    String fieldLabel, {
    required bool suppressed,
  }) {
    if (suppressed) return null;
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return translateText('{field} is required', params: {
        'field': fieldLabel,
      });
    }
    if (!_nameRegExp.hasMatch(v)) {
      return translateText('Only letters, numbers and spaces are allowed.');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (_suppressPhoneError) return null;
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return translateText('Phone number is required');
    if (phone.length != 10) {
      return translateText('Phone number must be 10 digits.');
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return translateText('Enter a valid mobile number.');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (_suppressEmailError) return null;
    final email = (value ?? '').trim();
    if (email.isEmpty) return translateText('Email is required.');
    if (!_emailRegExp.hasMatch(email)) {
      return translateText('Enter a valid email address.');
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;

    setState(() {
      _showGlobalErrors = true;
      _suppressFirstNameError = false;
      _suppressLastNameError = false;
      _suppressPhoneError = false;
      _suppressEmailError = false;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService().sendTeamInvitation(
        salonId: widget.salonId,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        nationalNumber: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        message: _messageCtrl.text,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Fluttertoast.showToast(
          msg: translateText('Invitation sent'),
        );
        Navigator.of(context).pop(true);
        return;
      }

      Fluttertoast.showToast(
        msg: extractMessage(
          response,
          fallback: 'Unable to send this invitation',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: extractErrorMessage(
          e,
          fallback: 'Unable to send this invitation',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String hint) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _inviteFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _inviteBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _inviteBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _inviteGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
    );
  }

  Widget _requiredLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _inviteInk,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          '*',
          style: TextStyle(
            color: AppColors.red,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _inviteInk,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  AutovalidateMode get _autovalidateMode => _showGlobalErrors
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _inviteGold,
        centerTitle: true,
        title: Text(
          translateText('Invite Team Member'),
          style: const TextStyle(
            color: _inviteGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _inviteBorder),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                translateText(
                  "We'll email them a link to join your salon on Glowante.",
                ),
                style: const TextStyle(
                  color: _inviteMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _requiredLabel(translateText('First Name')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _firstNameCtrl,
                decoration: _decoration(translateText('First name')),
                autovalidateMode: _autovalidateMode,
                maxLength: 50,
                inputFormatters: _nameInputFormatters,
                validator: (v) => _validateName(
                  v,
                  translateText('First Name'),
                  suppressed: _suppressFirstNameError,
                ),
                onChanged: (_) {
                  setState(() => _suppressFirstNameError = true);
                  _refreshValidationIfNeeded();
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _requiredLabel(translateText('Last Name')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _lastNameCtrl,
                decoration: _decoration(translateText('Last name')),
                autovalidateMode: _autovalidateMode,
                maxLength: 50,
                inputFormatters: _nameInputFormatters,
                validator: (v) => _validateName(
                  v,
                  translateText('Last Name'),
                  suppressed: _suppressLastNameError,
                ),
                onChanged: (_) {
                  setState(() => _suppressLastNameError = true);
                  _refreshValidationIfNeeded();
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _requiredLabel(translateText('Phone Number')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autovalidateMode: _autovalidateMode,
                decoration: _decoration('9876543210').copyWith(
                  prefixIcon: Container(
                    alignment: Alignment.center,
                    width: 52,
                    child: const Text(
                      '+91',
                      style: TextStyle(
                        color: _inviteInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                validator: _validatePhone,
                onChanged: (_) {
                  setState(() => _suppressPhoneError = true);
                  _refreshValidationIfNeeded();
                },
              ),
              const SizedBox(height: 16),
              _requiredLabel(translateText('Email')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: _autovalidateMode,
                maxLength: 50,
                decoration: _decoration('name@example.com'),
                validator: _validateEmail,
                onChanged: (_) {
                  setState(() => _suppressEmailError = true);
                  _refreshValidationIfNeeded();
                },
              ),
              const SizedBox(height: 16),
              _label(translateText('Message (optional)')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: _decoration(
                  translateText('Join our team at {salon}.', params: {
                    'salon': widget.salonName ?? '',
                  }),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inviteGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD8CEC5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? AppLoader.inline(
                          size: 20, strokeWidth: 2, color: Colors.white)
                      : Text(
                          translateText('Send Invitation'),
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
    );
  }
}
