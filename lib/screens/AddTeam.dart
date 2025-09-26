import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/AddTeamSelectServices.dart';
import '../utils/api_service.dart';

class AddTeamScreen extends StatefulWidget {
  final int branchId;
  final int salonId;
  final String branchName;

  const AddTeamScreen({
    super.key,
    required this.branchId,
    required this.salonId,
    required this.branchName,
  });

  @override
  State<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  // Show inline validations only after user taps "Add Team Member"
  bool _showGlobalErrors = false;

  // Inline-error suppression flags (hide error while user is interacting)
  bool _suppressPhoneError = false;
  bool _suppressVerifyError = false;

  bool _suppressFirstNameError = false;
  bool _suppressLastNameError  = false;
  bool _suppressEmailError     = false;
  bool _suppressOtpError       = false;

  bool _suppressGenderError = false;
  bool _suppressRolesError  = false;
  bool _suppressSpecsError  = false;
  bool _suppressDateError   = false;

  // Colors for statuses
  final Color _errorColor      = Colors.red;      // invalid inputs
  final Color _verifyWarnColor = Colors.orange;   // "please verify" prompt
  final Color _successColor    = Colors.green;    // verified success

  // --- Shared validators (return null when valid, error string when invalid) ---
  String? _vPhone(String? v) {
    if (_suppressPhoneError) return null;
    final phone = (v ?? '').trim();
    if (phone.isEmpty) return 'Phone number is required.';
    if (phone.length != 10) return 'Phone number must be 10 digits.';
    return null;
  }

  // exact string requested
  String? _vPhoneVerified() {
    if (_suppressVerifyError) return null;
    return _phoneVerified ? null : 'Please verify phone number';
  }

  String? _vFirstName(String? v) {
    if (_suppressFirstNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return 'First name is required.';
    if (!RegExp(r'^[A-Z]').hasMatch(x)) {
      return 'First name must start with a capital letter.';
    }
    return null;
  }

  String? _vLastName(String? v) {
    if (_suppressLastNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return 'Last name is required.';
    if (!RegExp(r'^[A-Z]').hasMatch(x)) {
      return 'Last name must start with a capital letter.';
    }
    return null;
  }

  String? _vEmail(String? v) {
    if (_suppressEmailError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return 'Email is required.';
    if (!_emailRegExp.hasMatch(x)) return 'Enter a valid email address.';
    return null;
  }

  // exact strings requested
  String? _vGender() {
    if (_suppressGenderError) return null;
    return _gender.isEmpty ? 'Select gender' : null;
  }

  String? _vJoiningDate() {
    if (_suppressDateError) return null;
    return _joiningDate == null ? 'select a joining date' : null;
  }

  String? _vRoles() {
    if (_suppressRolesError) return null;
    return _selectedRoles.isEmpty ? 'Select role' : null;
  }

  String? _vSpecs() {
    if (_suppressSpecsError) return null;
    return _selectedSpecs.isEmpty ? 'Select specialization' : null;
  }

  String? _vOtp(String? v) {
    if (_suppressOtpError) return null;
    final x = (v ?? '').trim();
    return x.isEmpty ? 'OTP is required.' : null;
  }

  // Data for roles/specializations
  List<Map<String, dynamic>> _allRoles = [];
  List<Map<String, dynamic>> _allSpecs = [];

  // Controllers
  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _briefCtrl = TextEditingController();

  // State
  DateTime? _joiningDate;
  String _gender = '';
  final List<String> _selectedRoles = [];
  final List<String> _selectedSpecs = [];
  bool _phoneVerified = false;

  // Verify button loader
  bool _isVerifying = false;

  // Theme (black & white)
  final Color _bg = Colors.white;
  final Color _fieldFill = Colors.grey.shade100;
  final BorderRadius _radius = BorderRadius.circular(12);
  final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Image
  File? _cameraImage;
  String? imageUrl;

  // Button submit loader
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchRolesAndSpecializations();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _briefCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRolesAndSpecializations() async {
    try {
      final data = await ApiService().getRolesAndSpecializations();
      setState(() {
        _allRoles = List<Map<String, dynamic>>.from(data['roles'] ?? const []);
        _allSpecs =
            List<Map<String, dynamic>>.from(data['specialities'] ?? const []);
      });
    } catch (e) {
      debugPrint('Error fetching roles/specs: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _cameraImage = File(picked.path);
    });

    imageUrl = await _uploadImageToS3(_cameraImage!);
  }

  Future<String?> _uploadImageToS3(File image) async {
    try {
      return await ApiService().uploadImage(image);
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  InputDecoration _decor({
    String? hint,
    Widget? prefix,
    Widget? suffix,
    EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }

  Widget _reqLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleVerifyPhoneNumber() async {
    final phoneNumber = _phoneCtrl.text.trim();

    // Local guards (toast only, don't show inline here)
    if (phoneNumber.isEmpty) {
      _toast('Please enter phone number');
      return;
    }
    if (phoneNumber.length != 10) {
      _toast('Enter a valid 10-digit phone number');
      return;
    }

    // Hide the "please verify..." inline error while verifying
    if (!_suppressVerifyError) {
      setState(() => _suppressVerifyError = true);
    }

    setState(() => _isVerifying = true);
    try {
      final response = await ApiService.checkUserAndSendOtp(phoneNumber);
      final success = response['success'] == true;

      if (success) {
        final data = response['data'] ?? {};
        final user = data['user'];
        final exists = (data['exists'] == true);

        if (exists && user != null) {
          _firstNameCtrl.text = (user['firstName'] ?? '').toString();
          _lastNameCtrl.text = (user['lastName'] ?? '').toString();
          _emailCtrl.text = (user['email'] ?? '').toString();
        }

        _otpCtrl.text = (data['otp'] ?? '').toString();

        setState(() {
          _phoneVerified = true;
          _suppressVerifyError = true; // keep hidden after success
          _suppressOtpError = true;    // hide OTP inline error once filled
        });

        // Re-validate after OTP auto-fill so "OTP is required" clears immediately
        _formKey.currentState?.validate();

        _toast('Phone verified successfully');
      } else {
        final msg = response['message'];
        final errorText = (msg is List)
            ? msg.join('\n')
            : (msg is String ? msg : 'Verification failed. Please try again.');
        _toast(errorText);
      }
    } catch (e) {
      _toast('An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _pickJoiningDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _joiningDate ?? now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (res != null) {
      setState(() {
        _joiningDate = res;
        _suppressDateError = true; // hide inline error after selection
      });
      _formKey.currentState?.validate(); // reflect removal instantly
    }
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<Map<String, dynamic>> source,
    required List<String> target,
  }) async {
    final temp = [...target];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: source.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = source[i];
                        final itemName =
                            (item['label'] ?? item['name'] ?? '').toString();
                        final checked = temp.contains(itemName);

                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            if (v == true && !temp.contains(itemName)) {
                              temp.add(itemName);
                            } else if (v == false) {
                              temp.remove(itemName);
                            }
                            setModalState(() {});
                          },
                          title: Text(itemName),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    text: 'Done',
                    onPressed: () {
                      setState(() {
                        target
                          ..clear()
                          ..addAll(temp);

                        // Hide inline error after user selection interaction
                        if (identical(target, _selectedRoles)) {
                          _suppressRolesError = true;
                        } else if (identical(target, _selectedSpecs)) {
                          _suppressSpecsError = true;
                        }
                      });
                      // reflect removal instantly
                      _formKey.currentState?.validate();
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Please fix the following'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors
              .map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $m'),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper to run something after rebuild completes
  Future<void> _afterRebuild() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  Future<bool> _validateFormAndShowAlert() async {
    // Turn ON global inline errors before validating (so everything shows)
    setState(() {
      _showGlobalErrors     = true;

      _suppressPhoneError    = false;
      _suppressVerifyError   = false;
      _suppressFirstNameError = false;
      _suppressLastNameError  = false;
      _suppressEmailError     = false;
      _suppressOtpError       = false;
      _suppressGenderError    = false;
      _suppressRolesError     = false;
      _suppressSpecsError     = false;
      _suppressDateError      = false;
    });

    // ✅ Wait for the UI to rebuild, THEN validate so errors appear on first tap
    await _afterRebuild();
    _formKey.currentState?.validate();

    final errors = <String>[];
    void push(String? e) {
      if (e != null && e.trim().isNotEmpty) errors.add(e);
    }

    // Collect same messages for Alert using shared helpers
    push(_vPhone(_phoneCtrl.text));
    push(_vPhoneVerified()); // verify state
    push(_vFirstName(_firstNameCtrl.text));
    push(_vLastName(_lastNameCtrl.text));
    push(_vEmail(_emailCtrl.text));
    push(_vGender());
    push(_vRoles());
    push(_vSpecs());
    push(_vJoiningDate());
    push(_vOtp(_otpCtrl.text));
    // Brief excluded by requirement

    if (errors.isNotEmpty) {
      await _showValidationDialog(errors);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Add Team Member',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          child: _cameraImage == null
                              ? const Icon(Icons.camera_alt, size: 30)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.file(
                                    _cameraImage!,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _reqLabel('Verify Phone Number'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            // Only validate on typing AFTER first submit
                            autovalidateMode: _showGlobalErrors
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            textCapitalization: TextCapitalization.none,
                            decoration: _decor(
                              hint: 'Verify phone number',
                              prefix: const Icon(Icons.search),
                            ),
                            validator: _vPhone, // RED errors for "invalid phone"
                            onChanged: (_) {
                              // Hide phone+verify inline errors while typing
                              if (!_suppressPhoneError || !_suppressVerifyError) {
                                setState(() {
                                  _suppressPhoneError  = true;
                                  _suppressVerifyError = true;
                                });
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          height: 48,
                          child: _PrimaryButton(
                            text: _isVerifying
                                ? 'Verifying...'
                                : (_phoneVerified ? 'Verified' : 'Verify'),
                            enabled: !_phoneVerified && !_isVerifying,
                            isLoading: _isVerifying, // loader in button
                            onPressed: (_phoneVerified || _isVerifying)
                                ? null
                                : () async {
                                    // Hide the "please verify" prompt when tapping
                                    if (!_suppressVerifyError) {
                                      setState(() => _suppressVerifyError = true);
                                    }
                                    await _handleVerifyPhoneNumber();
                                  },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Under the row:
                    // - If verified: show green success immediately
                    // - Else: show orange "please verify phone number" only AFTER first submit
                    if (_phoneVerified)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Phone verified',
                          style: TextStyle(
                            color: _successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (_showGlobalErrors)
                      FormField<bool>(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (_) => _vPhoneVerified(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                      color: _verifyWarnColor, fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reqLabel('First Name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _firstNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                autovalidateMode: _showGlobalErrors
                                    ? AutovalidateMode.onUserInteraction
                                    : AutovalidateMode.disabled,
                                decoration: _decor(hint: 'Enter first name'),
                                validator: _vFirstName,
                                onChanged: (_) {
                                  if (!_suppressFirstNameError) {
                                    setState(() => _suppressFirstNameError = true);
                                  }
                                },
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'^\s')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reqLabel('Last Name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _lastNameCtrl,
                                autovalidateMode: _showGlobalErrors
                                    ? AutovalidateMode.onUserInteraction
                                    : AutovalidateMode.disabled,
                                textCapitalization: TextCapitalization.words,
                                decoration: _decor(hint: 'Enter last name'),
                                validator: _vLastName,
                                onChanged: (_) {
                                  if (!_suppressLastNameError) {
                                    setState(() => _suppressLastNameError = true);
                                  }
                                },
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'^\s')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _reqLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autovalidateMode: _showGlobalErrors
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      decoration: _decor(hint: 'Enter email address'),
                      validator: _vEmail,
                      onChanged: (_) {
                        if (!_suppressEmailError) {
                          setState(() => _suppressEmailError = true);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Otp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      enabled: false,
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      autovalidateMode: _showGlobalErrors
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      decoration: _decor(hint: 'Enter otp'),
                      validator: _vOtp,
                      onChanged: (_) {
                        if (!_suppressOtpError) {
                          setState(() => _suppressOtpError = true);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Male',
                          groupValue: _gender,
                          onChanged: (v) => setState(() {
                            _gender = v ?? '';
                            _suppressGenderError = true;
                          }),
                        ),
                        const Text('Male'),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: 'Female',
                          groupValue: _gender,
                          onChanged: (v) => setState(() {
                            _gender = v ?? '';
                            _suppressGenderError = true;
                          }),
                        ),
                        const Text('Female'),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: 'Other',
                          groupValue: _gender,
                          onChanged: (v) => setState(() {
                            _gender = v ?? '';
                            _suppressGenderError = true;
                          }),
                        ),
                        const Text('Other'),
                      ],
                    ),
                    if (_showGlobalErrors)
                      FormField<String>(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (_) => _vGender(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: _errorColor, fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 8),

                    _reqLabel('Roles'),
                    const SizedBox(height: 8),
                    _PickField(
                      hint: 'Select Roles',
                      values: _selectedRoles,
                      onTap: () => _openMultiSelect(
                        title: 'Select Roles',
                        source: _allRoles,
                        target: _selectedRoles,
                      ),
                    ),
                    if (_showGlobalErrors)
                      FormField<List<String>>(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (_) => _vRoles(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: _errorColor, fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 16),

                    _reqLabel('Specializations'),
                    const SizedBox(height: 8),
                    _PickField(
                      hint: 'Select Specializations',
                      values: _selectedSpecs,
                      onTap: () => _openMultiSelect(
                        title: 'Select Specializations',
                        source: _allSpecs,
                        target: _selectedSpecs,
                      ),
                    ),
                    if (_showGlobalErrors)
                      FormField<List<String>>(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (_) => _vSpecs(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: _errorColor, fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 16),

                    _reqLabel('Joining Date'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickJoiningDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          decoration: _decor(
                            hint: _joiningDate == null
                                ? 'Select joining date'
                                : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                            prefix: const Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (_) => null,
                        ),
                      ),
                    ),
                    if (_showGlobalErrors)
                      FormField<DateTime>(
                        autovalidateMode: AutovalidateMode.always,
                        validator: (_) => _vJoiningDate(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: _errorColor, fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 16),

                    const Text(
                      'Brief About Member',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _briefCtrl,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decor(
                        hint: 'Enter a brief about this member',
                      ).copyWith(contentPadding: const EdgeInsets.all(14)),
                      validator: (_) => null, // Brief excluded
                    ),

                    const SizedBox(height: 20),

                    // _PrimaryButton(
                    //   text: _isSubmitting ? 'Adding...' : 'Add Team Member',
                    //   isLoading: _isSubmitting,
                    //   onPressed: _isSubmitting
                    //       ? null
                    //       : () async {
                    //           if (!await _validateFormAndShowAlert()) return;

                    //           setState(() => _isSubmitting = true);
                    //           try {
                    //             final payload = {
                    //               "countryCode": "+91",
                    //               "phoneNumber": _phoneCtrl.text.trim(),
                    //               "firstName": _firstNameCtrl.text.trim(),
                    //               "lastName": _lastNameCtrl.text.trim(),
                    //               "email": _emailCtrl.text.trim(),
                    //               "joinedAt": _joiningDate == null
                    //                   ? null
                    //                   : "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}",
                    //               "roles": _selectedRoles,
                    //               "specialities": _selectedSpecs,
                    //               // "profileImage": imageUrl, // if needed
                    //               // "gender": _gender,        // if needed
                    //               // "brief": _briefCtrl.text, // if needed
                    //             };

                    //             final result = await ApiService()
                    //                 .addSalonTeamMember(widget.salonId, payload);

                    //             if (!mounted) return;
                    //             if (result['success'] == true) {
                    //               ScaffoldMessenger.of(context).showSnackBar(
                    //                 const SnackBar(
                    //                   content: Text("Team Member added successfully"),
                    //                 ),
                    //               );
                    //               Navigator.pop(context, true);
                    //             } else {
                    //               ScaffoldMessenger.of(context).showSnackBar(
                    //                 SnackBar(
                    //                   content: Text(
                    //                     "Failed: ${result['message'] ?? 'Unknown error'}",
                    //                   ),
                    //                 ),
                    //               );
                    //             }
                    //           } finally {
                    //             if (mounted) {
                    //               setState(() => _isSubmitting = false);
                    //             }
                    //           }
                    //         },
                    // ),

                    // const SizedBox(height: 24),
const SizedBox(height: 12),

// ✅ New Next Button
_PrimaryButton(
  text: 'Next',
  onPressed: () async {
    if (!await _validateFormAndShowAlert()) return;

    final payload = {
      "countryCode": "+91",
      "phoneNumber": _phoneCtrl.text.trim(),
      "firstName": _firstNameCtrl.text.trim(),
      "lastName": _lastNameCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "joinedAt": _joiningDate == null
          ? null
          : "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}",
      "roles": _selectedRoles,
      "specialities": _selectedSpecs,
      "profileImage": imageUrl,
      "gender": _gender,
      "brief": _briefCtrl.text,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTeamSelectServices(
          salonId: widget.salonId,
          teamPayload: payload,
        ),
      ),
    );
  },
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
}

class _PickField extends StatelessWidget {
  const _PickField({
    required this.hint,
    required this.values,
    required this.onTap,
  });

  final String hint;
  final List<String> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = values.isEmpty ? hint : values.join(', ');
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: text,
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
          // No validator here — inline errors are handled via FormField wrappers above.
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 50,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled && !isLoading ? onPressed : null;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}
