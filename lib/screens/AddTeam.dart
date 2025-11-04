import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import '../screens/AddTeamSelectServices.dart';
import '../screens/AddTeamChooseTimeSlots.dart';
import '../utils/api_service.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class AddTeamScreen extends StatefulWidget {
  final int branchId;
  final int salonId;
  final String? salonName;

  const AddTeamScreen({
    super.key,
    required this.branchId,
    required this.salonId,
    required this.salonName,
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
  bool _suppressLastNameError = false;
  bool _suppressEmailError = false;
  bool _suppressOtpError = false;

  bool _suppressGenderError = false;
  bool _suppressRolesError = false;
  bool _suppressSpecsError = false;
  bool _suppressDateError = false;

  // Colors for statuses
  final Color _errorColor = Colors.red; // invalid inputs
  final Color _verifyWarnColor = Colors.red; // "please verify" prompt
  final Color _successColor = Colors.green; // verified success

  // --- Shared validators (return null when valid, error string when invalid) ---
  String? _vPhone(String? v) {
    if (_suppressPhoneError) return null;
    final phone = (v ?? '').trim();
    if (phone.isEmpty) return translateText('Phone number is required');
    if (phone.length != 10)
      return translateText('Phone number must be 10 digits.');
    return null;
  }

  // exact string requested
  // String? _vPhoneVerified() {
  //   if (_suppressVerifyError) return null;
  //   return _phoneVerified ? null : translateText('Please verify phone number');
  // }

  String? _vFirstName(String? v) {
    if (_suppressFirstNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('First Name is required');
    // if (!RegExp(r'^[A-Z]').hasMatch(x)) {
    //   return translateText('First name must start with a capital letter.');
    // }
    return null;
  }

  String? _vLastName(String? v) {
    if (_suppressLastNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('Last Name is required');
    // if (!RegExp(r'^[A-Z]').hasMatch(x)) {
    //   return translateText('Last name must start with a capital letter.');
    // }
    return null;
  }

  String? _vEmail(String? v) {
    if (_suppressEmailError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('Email is required.');
    if (!_emailRegExp.hasMatch(x))
      return translateText('Enter a valid email address.');
    return null;
  }

  // exact strings requested
  String? _vGender() {
    if (_suppressGenderError) return null;
    return _gender.isEmpty ? translateText('Select gender') : null;
  }

  String? _vJoiningDate() {
    if (_suppressDateError) return null;
    return _joiningDate == null ? translateText('Select a joining date') : null;
  }

  String? _vRoles() {
    if (_suppressRolesError) return null;
    return _selectedRoles.isEmpty ? translateText('Select role') : null;
  }

  String? _vSpecs() {
    if (_suppressSpecsError) return null;
    return _selectedSpecs.isEmpty
        ? translateText('Select specialization')
        : null;
  }

  // String? _vOtp(String? v) {
  //   if (_suppressOtpError) return null;
  //   final x = (v ?? '').trim();
  //   return x.isEmpty ? translateText('OTP is required.') : null;
  // }

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

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _brieftFocus = FocusNode();

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
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _brieftFocus.dispose();
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
        children: [
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
          _suppressOtpError = true; // hide OTP inline error once filled
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    _firstNameFocus.unfocus();
    _lastNameFocus.unfocus();
    _emailFocus.unfocus();
    _brieftFocus.unfocus();
  }
  // Future<void> _pickJoiningDate() async {
  //   _dismissKeyboard();
  //   final now = DateTime.now();
  //   final res = await showDatePicker(
  //     context: context,
  //     firstDate: DateTime(now.year - 5),
  //     lastDate: DateTime(now.year + 5),
  //     initialDate: _joiningDate ?? now,
  //     builder: (ctx, child) {
  //       return Theme(
  //         data: Theme.of(ctx).copyWith(
  //           colorScheme: const ColorScheme.light(
  //             primary: Colors.black,
  //             onPrimary: Colors.white,
  //             onSurface: Colors.black87,
  //           ),
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //   _dismissKeyboard();
  //   if (res != null) {
  //     setState(() {
  //       _joiningDate = res;
  //       _suppressDateError = true; // hide inline error after selection
  //     });
  //   }
  // }
Future<void> _pickJoiningDate() async {
  _dismissKeyboard();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day); // strip time

  final res = await showDatePicker(
    context: context,
    firstDate: today, // ✅ cannot pick any date before today
    lastDate: DateTime(now.year + 5),
    initialDate: _joiningDate != null && _joiningDate!.isAfter(today)
        ? _joiningDate!
        : today, // ✅ default to today if past or null
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

  _dismissKeyboard();
  if (res != null) {
    setState(() {
      _joiningDate = res;
      _suppressDateError = true; // hide inline error after selection
    });
  }
}

  Future<void> _openMultiSelect({
    required String title,
    required List<Map<String, dynamic>> source,
    required List<String> target,
  }) async {
    _dismissKeyboard();
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
                  SizedBox(height: 8),
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
                  SizedBox(height: 12),
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
                      Navigator.pop(ctx);
                    },
                  ),
                  SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
    _dismissKeyboard();
  }

  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translateText('Please fix the following')),
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
            child: Text(translateText('OK')),
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
      _showGlobalErrors = true;

      _suppressPhoneError = false;
      _suppressVerifyError = false;
      _suppressFirstNameError = false;
      _suppressLastNameError = false;
      _suppressEmailError = false;
      _suppressOtpError = false;
      _suppressGenderError = false;
      _suppressRolesError = false;
      _suppressSpecsError = false;
      _suppressDateError = false;
    });

    // âœ… Wait for the UI to rebuild, THEN validate so errors appear on first tap
    await _afterRebuild();
    _formKey.currentState?.validate();

    final errors = <String>[];
    void push(String? e) {
      if (e != null && e.trim().isNotEmpty) errors.add(e);
    }

    // Collect same messages for Alert using shared helpers
    push(_vPhone(_phoneCtrl.text));
    // push(_vPhoneVerified()); // verify state
    push(_vFirstName(_firstNameCtrl.text));
    push(_vLastName(_lastNameCtrl.text));
    push(_vEmail(_emailCtrl.text));
    push(_vGender());
    push(_vRoles());
    push(_vSpecs());
    push(_vJoiningDate());
    // push(_vOtp(_otpCtrl.text));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Let the gradient show through:
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Ensure status bar + icons look good on the gradient:
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: Colors.white, // back button color
        ),
        title: Text(
          translateText('Add Team Member'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Paint the gradient here:
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.starColor, // your start color
                AppColors.getStartedButton, // your end color
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                              ? Icon(Icons.camera_alt, size: 30)
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

                    SizedBox(height: 12),

                    _reqLabel('Phone Number'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            enabled: !_phoneVerified,
                            keyboardType: TextInputType.phone,
                            // Only validate on typing AFTER first submit
                            autovalidateMode: _showGlobalErrors
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            textCapitalization: TextCapitalization.none,
                            decoration: _decor(
                              hint: 'Phone number',
                              prefix: Icon(Icons.search),
                            ),
                            validator:
                                _vPhone, // RED errors for "invalid phone"
                            onChanged: (_) {
                              // Hide phone+verify inline errors while typing
                              if (!_suppressPhoneError ||
                                  !_suppressVerifyError) {
                                setState(() {
                                  _suppressPhoneError = true;
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
                        SizedBox(width: 10),
                        // SizedBox(
                        //   width: 110,
                        //   height: 48,
                        //   child: _PrimaryButton(
                        //     text: _isVerifying
                        //         ? 'Verifying...'
                        //         : (_phoneVerified ? 'Verified' : 'Verify'),
                        //     enabled: !_phoneVerified && !_isVerifying,
                        //     isLoading: _isVerifying, // loader in button
                        //     onPressed: (_phoneVerified || _isVerifying)
                        //         ? null
                        //         : () async {
                        //             // Suppress all inline errors after verify tap
                        //             setState(() {
                        //               _suppressPhoneError = true;
                        //               _suppressVerifyError = true;
                        //               _suppressFirstNameError = true;
                        //               _suppressLastNameError = true;
                        //               _suppressEmailError = true;
                        //               _suppressOtpError = true;
                        //               _suppressGenderError = true;
                        //               _suppressRolesError = true;
                        //               _suppressSpecsError = true;
                        //               _suppressDateError = true;
                        //             });
                        //             await _handleVerifyPhoneNumber();
                        //           },
                        //   ),
                        // ),
                      ],
                    ),

                    SizedBox(height: 16),
                    if (_phoneVerified)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          translateText('Phone verified'),
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
                        // validator: (_) => _vPhoneVerified(),
                        builder: (state) => state.hasError
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                      color: _verifyWarnColor, fontSize: 12),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                    SizedBox(height: 16),

                    IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start, // keep tops aligned
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reqLabel(translateText('First Name')),
            const SizedBox(height: 8),
            TextFormField(
              focusNode: _firstNameFocus,
              controller: _firstNameCtrl,
             keyboardType: TextInputType.text,
  textCapitalization: TextCapitalization.sentences, 
              autovalidateMode: _showGlobalErrors
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: _decor(hint: translateText('Enter first name')),
              validator: _vFirstName,
              onChanged: (_) {
                if (!_suppressFirstNameError) {
                  setState(() => _suppressFirstNameError = true);
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reqLabel(translateText('Last Name')),
            const SizedBox(height: 8),
            TextFormField(
              focusNode: _lastNameFocus,
              controller: _lastNameCtrl,
          keyboardType: TextInputType.text,
  textCapitalization: TextCapitalization.sentences, 
              autovalidateMode: _showGlobalErrors
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: _decor(hint: translateText('Enter last name')),
              validator: _vLastName,
              onChanged: (_) {
                if (!_suppressLastNameError) {
                  setState(() => _suppressLastNameError = true);
                }
              },
            ),
          ],
        ),
      ),
    ],
  ),
),


                    SizedBox(height: 16),

                    _reqLabel(translateText('Email')),
                    SizedBox(height: 8),
                    TextFormField(
                      focusNode: _emailFocus,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autovalidateMode: _showGlobalErrors
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      decoration:
                          _decor(hint: translateText('Enter email address')),
                      validator: _vEmail,
                      onChanged: (_) {
                        if (!_suppressEmailError) {
                          setState(() => _suppressEmailError = true);
                        }
                      },
                    ),

                    SizedBox(height: 16),

                    // Text(
                    //   translateText('OTP'),
                    //   style: TextStyle(
                    //     fontSize: 14,
                    //     fontWeight: FontWeight.w600,
                    //   ),
                    // ),
                    // SizedBox(height: 8),
                    // TextFormField(
                    //   enabled: false,
                    //   controller: _otpCtrl,
                    //   keyboardType: TextInputType.number,
                    //   autovalidateMode: _showGlobalErrors
                    //       ? AutovalidateMode.onUserInteraction
                    //       : AutovalidateMode.disabled,
                    //   decoration: _decor(hint: translateText('Enter otp')),
                    //   validator: _vOtp,
                    //   onChanged: (_) {
                    //     if (!_suppressOtpError) {
                    //       setState(() => _suppressOtpError = true);
                    //     }
                    //   },
                    // ),

                    // SizedBox(height: 16),

                    Text(
                      translateText('Gender'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
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
                        Text(translateText('Male')),
                        SizedBox(width: 16),
                        Radio<String>(
                          value: 'Female',
                          groupValue: _gender,
                          onChanged: (v) => setState(() {
                            _gender = v ?? '';
                            _suppressGenderError = true;
                          }),
                        ),
                        Text(translateText('Female')),
                        SizedBox(width: 16),
                        Radio<String>(
                          value: 'Other',
                          groupValue: _gender,
                          onChanged: (v) => setState(() {
                            _gender = v ?? '';
                            _suppressGenderError = true;
                          }),
                        ),
                        Text(translateText('Other')),
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
                                  style: TextStyle(
                                      color: _errorColor, fontSize: 12),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                    SizedBox(height: 8),

                    _reqLabel(translateText('Roles')),
                    SizedBox(height: 8),
                    _PickField(
                      hint: translateText('Select Roles'),
                      values: _selectedRoles,
                      onTap: () => _openMultiSelect(
                        title: translateText('Select Roles'),
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
                                  style: TextStyle(
                                      color: _errorColor, fontSize: 12),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                    SizedBox(height: 16),

                    _reqLabel(translateText('Specializations')),
                    SizedBox(height: 8),
                    _PickField(
                      hint: translateText('Select Specializations'),
                      values: _selectedSpecs,
                      onTap: () => _openMultiSelect(
                        title: translateText('Select Specializations'),
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
                                  style: TextStyle(
                                      color: _errorColor, fontSize: 12),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                    SizedBox(height: 16),

                    _reqLabel(translateText('Joining Date')),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickJoiningDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          decoration: _decor(
                            hint: _joiningDate == null
                                ? translateText('Select joining date')
                                : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                            prefix: Icon(Icons.calendar_today_outlined),
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
                                  style: TextStyle(
                                      color: _errorColor, fontSize: 12),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                    SizedBox(height: 16),

                    Text(
                      translateText('Brief About Member'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      focusNode: _brieftFocus,
                      controller: _briefCtrl,
                      maxLines: 4,
                      maxLength: 100,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                     keyboardType: TextInputType.text,
  textCapitalization: TextCapitalization.sentences, 
                      decoration: _decor(
                        hint: 'Enter a brief about this member',
                      ).copyWith(
                        contentPadding: const EdgeInsets.all(14),
                        counterText: '',
                      ),
                      validator: (_) => null, // Brief excluded
                    ),

                    SizedBox(height: 20),

                    SizedBox(height: 12),

// âœ… New Next Button
                    _PrimaryButton(
                      text: 'Next',
                      onPressed: () async {
                        if (!await _validateFormAndShowAlert()) return;
                        String capitalizeFirst(String value) => value.isNotEmpty
                            ? value[0].toUpperCase() + value.substring(1)
                            : value;

                        final payload = <String, dynamic>{
                          "countryCode": "+91",
                          "phoneNumber": _phoneCtrl.text.trim(),
                          "firstName":
                              capitalizeFirst(_firstNameCtrl.text.trim()),
                          "lastName":
                              capitalizeFirst(_lastNameCtrl.text.trim()),
                          "email": _emailCtrl.text.trim(),
                          "gender": _gender,
                          "joiningDate": _joiningDate,
                          "brief": capitalizeFirst(_briefCtrl.text.trim()),
                          "roles": List<String>.from(_selectedRoles),
                          "specializations": List<String>.from(_selectedSpecs),
                          "specialities": List<String>.from(_selectedSpecs),
                          "profileImage": imageUrl,
                          // "otp": _otpCtrl.text.trim(),
                        };

                        print('Sending to Choose time slots: $payload');
                        final refresh = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTeamChooseTimeSlot(
                              formData: {
                                "salonId": widget.salonId,
                                "branchId": widget.branchId,
                                "salonName": widget.salonName,
                                ...payload,
                              },
                            ),
                          ),
                        );
                        if (refresh == true && mounted) {
                          Navigator.pop(context, true);
                        }
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
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
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
          // No validator here â€” inline errors are handled via FormField wrappers above.
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
          backgroundColor: AppColors.starColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? SizedBox(
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
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import '../screens/AddTeamSelectServices.dart';
// import '../utils/api_service.dart';
// import '../utils/colors.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';

// class AddTeamScreen extends StatefulWidget {
//   final int salonId;
//   final String? salonName;
//   final int? branchId;
//   const AddTeamScreen({
//     super.key,
//     required this.salonId,
//     this.salonName,
//     this.branchId,
//   });

//   @override
//   State<AddTeamScreen> createState() => _AddTeamScreenState();
// }

// class _AddTeamScreenState extends State<AddTeamScreen> {
//   final _formKey = GlobalKey<FormState>();

//   final _phoneCtrl = TextEditingController();
//   final _firstNameCtrl = TextEditingController();
//   final _lastNameCtrl = TextEditingController();
//   final _emailCtrl = TextEditingController();
//   final _addressCtrl = TextEditingController();
//   final _briefCtrl = TextEditingController();
//   final _firstNameKey = GlobalKey<FormFieldState>();
//   final _lastNameKey = GlobalKey<FormFieldState>();
//   final _phoneKey = GlobalKey<FormFieldState>();
//   final _emailKey = GlobalKey<FormFieldState>();
//   final _addressKey = GlobalKey<FormFieldState>();

//   List<Map<String, dynamic>> _allRoles = [];
//   List<Map<String, dynamic>> _allSpecs = [];

//   DateTime? _joiningDate;
//   String _gender = '';
//   final List<String> _selectedRoles = [];
//   final List<String> _selectedSpecs = [];
//   File? _cameraImage;
//   String? imageUrl;

//   bool _isSubmitting = false;
//   bool _validateNow = false;

//   final Color _fieldFill = Colors.grey.shade100;
//   final BorderRadius _radius = BorderRadius.circular(12);
//   final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

//   @override
//   void initState() {
//     super.initState();
//     _fetchRolesAndSpecializations();
//   }

//   @override
//   void dispose() {
//     _phoneCtrl.dispose();
//     _firstNameCtrl.dispose();
//     _lastNameCtrl.dispose();
//     _emailCtrl.dispose();
//     _addressCtrl.dispose();
//     _briefCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _fetchRolesAndSpecializations() async {
//     try {
//       final data = await ApiService().getRolesAndSpecializations();
//       setState(() {
//         _allRoles = List<Map<String, dynamic>>.from(data['roles'] ?? const []);
//         _allSpecs =
//             List<Map<String, dynamic>>.from(data['specialities'] ?? const []);
//       });
//     } catch (e) {
//       debugPrint('Error fetching roles/specs: $e');
//     }
//   }

//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
//     if (picked == null) return;
//     setState(() => _cameraImage = File(picked.path));
//     imageUrl = await _uploadImageToS3(_cameraImage!);
//   }

//   Future<String?> _uploadImageToS3(File image) async {
//     try {
//       return await ApiService().uploadImage(image);
//     } catch (e) {
//       debugPrint('Image upload error: $e');
//       return null;
//     }
//   }

//   InputDecoration _decor({String? hint, Widget? prefix, Widget? suffix}) {
//     return InputDecoration(
//       hintText: hint,
//       filled: true,
//       fillColor: _fieldFill,
//       prefixIcon: prefix,
//       suffixIcon: suffix,
//       helperText: ' ',
//       helperStyle: const TextStyle(height: 1),
//       errorStyle: const TextStyle(height: 1.1),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//       border: OutlineInputBorder(
//         borderRadius: _radius,
//         borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: _radius,
//         borderSide: const BorderSide(color: Colors.black, width: 1.5),
//       ),
//     );
//   }

//   Widget _reqLabel(String text) => RichText(
//         text: TextSpan(
//           text: text,
//           style: const TextStyle(
//               fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
//           children: const [
//             TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
//           ],
//         ),
//       );

//   void _capitalizeFirst(TextEditingController controller) {
//     final text = controller.text;
//     if (text.isNotEmpty) {
//       final newText =
//           text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : '');
//       if (newText != text) {
//         final pos = controller.selection;
//         controller.value = controller.value.copyWith(
//           text: newText,
//           selection: pos,
//         );
//       }
//     }
//   }

//   String? _validateNotEmpty(String? value, String fieldName) {
//     if (!_validateNow) return null;
//     if (value == null || value.trim().isEmpty)
//       return translateText('$fieldName is required');
//     return null;
//   }

//   Future<void> _openMultiSelect({
//     required String title,
//     required List<Map<String, dynamic>> source,
//     required List<String> target,
//   }) async {
//     final temp = [...target];
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
//       ),
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setModalState) {
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 16,
//                 right: 16,
//                 top: 10,
//                 bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     width: 44,
//                     height: 4,
//                     margin: const EdgeInsets.only(bottom: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black12,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                   Text(title,
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.w700)),
//                   const SizedBox(height: 8),
//                   Flexible(
//                     child: ListView.separated(
//                       shrinkWrap: true,
//                       itemCount: source.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (_, i) {
//                         final item = source[i];
//                         final name =
//                             (item['label'] ?? item['name'] ?? '').toString();
//                         final checked = temp.contains(name);
//                         return CheckboxListTile(
//                           value: checked,
//                           onChanged: (v) {
//                             if (v == true && !temp.contains(name)) {
//                               temp.add(name);
//                             } else if (v == false) {
//                               temp.remove(name);
//                             }
//                             setModalState(() {});
//                           },
//                           title: Text(name),
//                           controlAffinity: ListTileControlAffinity.leading,
//                           dense: true,
//                         );
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         target
//                           ..clear()
//                           ..addAll(temp);
//                       });
//                       Navigator.pop(ctx);
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: const Text('Done'),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Future<void> _submit() async {
//     setState(() => _validateNow = true);
//     if (!_formKey.currentState!.validate()) return;

//     final payload = {
//       // "countryCode": "+91",
//       "salonId": widget.salonId,
//       "branchId": widget.branchId,
//       "firstName": _firstNameCtrl.text.trim(),
//       "lastName": _lastNameCtrl.text.trim(),
//       "phoneNumber": _phoneCtrl.text.trim(),
//       "email": _emailCtrl.text.trim(),
//       "address": _addressCtrl.text.trim(),
//       // "joinedAt": _joiningDate == null
//       //     ? null
//       //     : "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}",
//       // "roles": _selectedRoles,
//       // "specialities": _selectedSpecs,
//       // "profileImage": imageUrl,
//       // "gender": _gender,
//       // "brief": _briefCtrl.text.trim(),
//     };

//     print('ðŸš€ Sending to next screen:');
//     print(payload);

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddTeamSelectServices(
//           salonId: widget.salonId,
//           teamPayload: payload,
//         ),
//       ),
//     );
//   }

//   Future<void> _pickJoiningDate() async {
//     final now = DateTime.now();
//     final res = await showDatePicker(
//       context: context,
//       firstDate: DateTime(now.year - 5),
//       lastDate: DateTime(now.year + 5),
//       initialDate: _joiningDate ?? now,
//     );
//     if (res != null) setState(() => _joiningDate = res);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text(translateText('Add Team Member'),
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(color: Colors.white),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [AppColors.starColor, AppColors.getStartedButton],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: SafeArea(
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Avatar
//                 // Center(
//                 //   child: GestureDetector(
//                 //     onTap: _pickImage,
//                 //     child: CircleAvatar(
//                 //       radius: 40,
//                 //       backgroundColor: Colors.grey[300],
//                 //       child: _cameraImage == null
//                 //           ? const Icon(Icons.camera_alt, size: 30)
//                 //           : ClipRRect(
//                 //               borderRadius: BorderRadius.circular(40),
//                 //               child: Image.file(_cameraImage!,
//                 //                   fit: BoxFit.cover, width: 80, height: 80),
//                 //             ),
//                 //     ),
//                 //   ),
//                 // ),
//                 // const SizedBox(height: 16),

//                 // Branch info
//                 // Text(
//                 //   'Branch ID: ${widget.salonId}',
//                 //   style: const TextStyle(
//                 //       fontSize: 14,
//                 //       fontWeight: FontWeight.w600,
//                 //       color: Colors.grey),
//                 // ),
//                 // const SizedBox(height: 16),

//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _reqLabel(translateText('First Name')),
//                           const SizedBox(height: 6),
//                           TextFormField(
//                             key: _firstNameKey,
//                             controller: _firstNameCtrl,
//                             decoration:
//                                 _decor(hint: translateText('Enter first name')),
//                             validator: (v) =>
//                                 _validateNotEmpty(v, 'First Name'),
//                             onChanged: (_) {
//                               _capitalizeFirst(_firstNameCtrl);
//                               setState(() => _validateNow = false);
//                               _firstNameKey.currentState?.validate();
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _reqLabel(translateText('Last Name')),
//                           const SizedBox(height: 6),
//                           TextFormField(
//                             key: _lastNameKey,
//                             controller: _lastNameCtrl,
//                             decoration:
//                                 _decor(hint: translateText('Enter last name')),
//                             validator: (v) => _validateNotEmpty(v, 'Last Name'),
//                             onChanged: (_) {
//                               _capitalizeFirst(_lastNameCtrl);
//                               setState(() => _validateNow = false);
//                               _lastNameKey.currentState?.validate();
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 16),

//                 _reqLabel(translateText('Phone Number')),
//                 TextFormField(
//                   key: _phoneKey,
//                   controller: _phoneCtrl,
//                   keyboardType: TextInputType.phone,
//                   decoration: _decor(hint: translateText('Enter phone number')),
//                   validator: (v) => _validateNotEmpty(v, 'Phone number'),
//                   onChanged: (_) {
//                     setState(() => _validateNow = false);
//                     _phoneKey.currentState?.validate();
//                   },
//                   inputFormatters: [
//                     FilteringTextInputFormatter.digitsOnly,
//                     LengthLimitingTextInputFormatter(10),
//                   ],
//                 ),
//                 const SizedBox(height: 16),

//                 _reqLabel(translateText('Email')),
//                 TextFormField(
//                   key: _emailKey,
//                   controller: _emailCtrl,
//                   keyboardType: TextInputType.emailAddress,
//                   decoration: _decor(hint: translateText('Email')),
//                   validator: (v) {
//                     if (!_validateNow) return null;
//                     if (v == null || v.trim().isEmpty)
//                       return translateText('Email is required');
//                     if (!_emailRegExp.hasMatch(v))
//                       return translateText('Enter a valid email');
//                     return null;
//                   },
//                   onChanged: (_) {
//                     setState(() => _validateNow = false);
//                     _emailKey.currentState?.validate();
//                   },
//                 ),
//                 const SizedBox(height: 16),

//                 _reqLabel(translateText('Address')),
//                 TextFormField(
//                   key: _addressKey,
//                   controller: _addressCtrl,
//                   maxLines: 3,
//                   decoration: _decor(hint: translateText('Address')),
//                   validator: (v) => _validateNotEmpty(v, 'Address'),
//                   onChanged: (_) {
//                     _capitalizeFirst(
//                         _addressCtrl); // ðŸ‘ˆ Auto-capitalize first letter
//                     setState(() => _validateNow = false);
//                     _addressKey.currentState
//                         ?.validate(); // ðŸ‘ˆ Revalidate only this field
//                   },
//                 ),

//                 const SizedBox(height: 16),

//                 // Text('Gender', style: const TextStyle(fontWeight: FontWeight.w600)),
//                 // Row(
//                 //   children: [
//                 //     Radio<String>(
//                 //         value: 'Male',
//                 //         groupValue: _gender,
//                 //         onChanged: (v) => setState(() => _gender = v ?? '')),
//                 //     const Text('Male'),
//                 //     Radio<String>(
//                 //         value: 'Female',
//                 //         groupValue: _gender,
//                 //         onChanged: (v) => setState(() => _gender = v ?? '')),
//                 //     const Text('Female'),
//                 //     Radio<String>(
//                 //         value: 'Other',
//                 //         groupValue: _gender,
//                 //         onChanged: (v) => setState(() => _gender = v ?? '')),
//                 //     const Text('Other'),
//                 //   ],
//                 // ),
//                 // const SizedBox(height: 16),

//                 // _reqLabel('Roles'),
//                 // _PickField(
//                 //   hint: 'Select Roles',
//                 //   values: _selectedRoles,
//                 //   onTap: () => _openMultiSelect(
//                 //     title: 'Select Roles',
//                 //     source: _allRoles,
//                 //     target: _selectedRoles,
//                 //   ),
//                 // ),
//                 // const SizedBox(height: 16),

//                 // _reqLabel('Specializations'),
//                 // _PickField(
//                 //   hint: 'Select Specializations',
//                 //   values: _selectedSpecs,
//                 //   onTap: () => _openMultiSelect(
//                 //     title: 'Select Specializations',
//                 //     source: _allSpecs,
//                 //     target: _selectedSpecs,
//                 //   ),
//                 // ),
//                 // const SizedBox(height: 16),

//                 // _reqLabel('Joining Date'),
//                 // GestureDetector(
//                 //   onTap: _pickJoiningDate,
//                 //   child: AbsorbPointer(
//                 //     child: TextFormField(
//                 //       readOnly: true,
//                 //       decoration: _decor(
//                 //         hint: _joiningDate == null
//                 //             ? 'Select joining date'
//                 //             : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
//                 //         prefix: const Icon(Icons.calendar_today_outlined),
//                 //       ),
//                 //       validator: (_) {
//                 //         if (!_validateNow) return null;
//                 //         if (_joiningDate == null) return 'Joining date is required';
//                 //         return null;
//                 //       },
//                 //     ),
//                 //   ),
//                 // ),
//                 // const SizedBox(height: 16),

//                 // TextFormField(
//                 //   controller: _briefCtrl,
//                 //   maxLines: 4,
//                 //   decoration: _decor(hint: 'Brief About Member'),
//                 //   onChanged: (_) {
//                 //     _capitalizeFirst(_briefCtrl);
//                 //     setState(() => _validateNow = false);
//                 //   },
//                 // ),
//                 // const SizedBox(height: 24),

//                 _PrimaryButton(
//                   text: translateText('Next'),
//                   onPressed: _isSubmitting ? null : _submit,
//                   isLoading: _isSubmitting,
//                 ),
//                 const SizedBox(height: 24),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _PickField extends StatelessWidget {
//   final String hint;
//   final List<String> values;
//   final VoidCallback onTap;

//   const _PickField({
//     required this.hint,
//     required this.values,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final text = values.isEmpty ? hint : values.join(', ');
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: TextFormField(
//           readOnly: true,
//           decoration: InputDecoration(
//             hintText: text,
//             filled: true,
//             fillColor: Colors.grey.shade100,
//             suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _PrimaryButton extends StatelessWidget {
//   final String text;
//   final VoidCallback? onPressed;
//   final bool isLoading;

//   const _PrimaryButton({
//     required this.text,
//     required this.onPressed,
//     this.isLoading = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       height: 50,
//       child: ElevatedButton(
//         onPressed: isLoading ? null : onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.starColor,
//           foregroundColor: Colors.white,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         ),
//         child: isLoading
//             ? const CircularProgressIndicator(
//                 color: Colors.white, strokeWidth: 2)
//             : Text(text,
//                 style:
//                     const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
//       ),
//     );
//   }
// }




