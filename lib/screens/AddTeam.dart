import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import '../screens/AddTeamSelectServices.dart';
import '../screens/AddTeamChooseTimeSlots.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/aws_s3_uploader.dart'; // ✅ make sure this import is present
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';

class AddTeamScreen extends StatefulWidget {
  final int branchId;
  final int salonId;
  final String? salonName;
  final bool isEdit;
  final Map<String, dynamic>? initialMember;

  const AddTeamScreen({
    super.key,
    required this.branchId,
    required this.salonId,
    required this.salonName,
    this.isEdit = false,
    this.initialMember,
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

  String? _vFirstName(String? v) {
    if (_suppressFirstNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('First Name is required');
    return null;
  }

  String? _vLastName(String? v) {
    if (_suppressLastNameError) return null;
    final x = (v ?? '').trim();
    if (x.isEmpty) return translateText('Last Name is required');
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

  String? _vJoiningDate() => null;

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

  List<Map<String, dynamic>> _allRoles = [];
  List<Map<String, dynamic>> _allSpecs = [];
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
  bool _isVerifying = false;
  final Color _bg = Colors.white;
  final Color _fieldFill = const Color(0xFFFAF9F8);
  final BorderRadius _radius = BorderRadius.circular(12);
  final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  File? _cameraImage;
  String? imageUrl;
  String? _existingImageUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchRolesAndSpecializations();
    _prefillFromInitialMember();
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

  void _prefillFromInitialMember() {
    final member = widget.initialMember;
    if (member == null) return;
    final branchAssignment = _branchAssignment(member);

    _phoneCtrl.text =
        (member['phoneNumber'] ?? member['phone'] ?? '').toString().trim();
    _firstNameCtrl.text = (member['firstName'] ?? '').toString().trim();
    _lastNameCtrl.text = (member['lastName'] ?? '').toString().trim();
    _emailCtrl.text = (member['email'] ?? '').toString().trim();
    _gender = _normalizeGender((member['gender'] ?? '').toString().trim());
    _briefCtrl.text =
        (member['info'] ?? member['brief'] ?? '').toString().trim();
    _existingImageUrl =
        (member['profilePictureUrl'] ?? '').toString().trim().isEmpty
            ? null
            : (member['profilePictureUrl'] ?? '').toString().trim();
    _phoneVerified = widget.isEdit;

    final joiningDateRaw =
        branchAssignment?['joiningDate'] ?? member['joiningDate'];
    if (joiningDateRaw is String && joiningDateRaw.trim().isNotEmpty) {
      _joiningDate = DateTime.tryParse(joiningDateRaw.trim());
    }

    _selectedRoles
      ..clear()
      ..addAll(_extractLabels(member['roles']));
    _selectedSpecs
      ..clear()
      ..addAll(
        _extractLabels(
          member['specialities'] ?? member['specializations'],
        ),
      );
  }

  Map<String, dynamic>? _branchAssignment(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    if (rawAssignments is! List) {
      return null;
    }

    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final branchId = branch is Map ? branch['id'] : assignment['branchId'];
      if (branchId?.toString() == widget.branchId.toString()) {
        return Map<String, dynamic>.from(assignment);
      }
    }

    if (rawAssignments.isNotEmpty && rawAssignments.first is Map) {
      return Map<String, dynamic>.from(rawAssignments.first as Map);
    }
    return null;
  }

  List<int> _branchServiceIdsFromAssignment(Map<String, dynamic>? assignment) {
    final ids = <int>{};

    void addId(dynamic value) {
      if (value is int) {
        ids.add(value);
      } else if (value is num) {
        ids.add(value.toInt());
      } else if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) ids.add(parsed);
      }
    }

    final directIds = assignment?['branchServiceIds'];
    if (directIds is List) {
      for (final id in directIds) {
        addId(id);
      }
    }

    final userBranchServices = assignment?['userBranchServices'];
    if (userBranchServices is List) {
      for (final item in userBranchServices) {
        if (item is! Map) continue;
        addId(item['branchServiceId']);
        final branchService = item['branchService'];
        if (branchService is Map) {
          addId(branchService['id']);
        }
      }
    }

    return ids.toList();
  }

  List<String> _extractLabels(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((entry) {
          if (entry is Map) {
            return (entry['label'] ?? entry['name'] ?? entry['code'] ?? '')
                .toString()
                .trim();
          }
          return entry.toString().trim();
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> _resolveCodes(
    List<String> selectedValues,
    List<Map<String, dynamic>> source,
  ) {
    return selectedValues.map((selected) {
      final normalizedSelected = selected.trim().toLowerCase();
      for (final option in source) {
        final candidates = [
          option['label'],
          option['name'],
          option['code'],
        ]
            .map((value) => (value ?? '').toString().trim())
            .where((v) => v.isNotEmpty);
        for (final candidate in candidates) {
          if (candidate.toLowerCase() == normalizedSelected) {
            final code = (option['code'] ?? candidate).toString().trim();
            return code.isEmpty ? candidate : code;
          }
        }
      }
      return normalizedSelected.replaceAll(' ', '_');
    }).toList();
  }

  Map<String, dynamic>? _normalizedAddress(dynamic rawAddress) {
    if (rawAddress is! Map) {
      return null;
    }

    final normalized = <String, dynamic>{};
    for (final entry in rawAddress.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      normalized[key] = value;
    }
    return normalized.isEmpty ? null : normalized;
  }

  String _normalizeGender(String value) {
    switch (value.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return value;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _cameraImage = File(picked.path);
    });
    _toast('Uploading image...');

    final uploaded =
        await AwsS3Uploader().uploadImageResult(picked, folder: 'uploads/team');
    if (uploaded != null) {
      setState(() {
        imageUrl = uploaded.cdnUrl ?? uploaded.publicUrl;
      });
      _toast('Image uploaded successfully');
    } else {
      _toast('❌ Failed to upload image');
    }
  }

  Future<String?> _uploadImageToS3(File image) async {
    try {
      final xFile = XFile(image.path);
      final result = await AwsS3Uploader().uploadImageResult(
        xFile,
        folder: 'uploads/team', // optional subfolder for team avatars
      );

      if (result == null) {
        debugPrint('❌ Upload failed');
        return null;
      }

      // prefer cdnUrl if available
      final url = result.cdnUrl ?? result.publicUrl;
      debugPrint('✅ Uploaded profile image URL: $url');
      return url;
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
      hintStyle: const TextStyle(color: Color(0xFF8D867F), fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: AppColors.starColor, width: 1.5),
      ),
    );
  }

  Widget _reqLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF5E564F),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
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
          : today,
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

  Future<void> _submitEditMember() async {
    if (!await _validateFormAndShowAlert()) return;

    final userId = (widget.initialMember?['id'] as num?)?.toInt();
    if (userId == null) {
      _toast('Missing member id');
      return;
    }

    String capitalizeFirst(String value) =>
        value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value;

    setState(() => _isSubmitting = true);
    try {
      final branchAssignment =
          _branchAssignment(widget.initialMember ?? const {});
      final branchServiceIds = _branchServiceIdsFromAssignment(
        branchAssignment ?? widget.initialMember,
      );
      final payload = <String, dynamic>{
        "countryCode": "+91",
        "phoneNumber": _phoneCtrl.text.trim(),
        "firstName": capitalizeFirst(_firstNameCtrl.text.trim()),
        "lastName": capitalizeFirst(_lastNameCtrl.text.trim()),
        "email": _emailCtrl.text.trim(),
        "gender": _gender.toLowerCase(),
        if (_joiningDate != null)
          "joiningDate":
              '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
        "info": capitalizeFirst(_briefCtrl.text.trim()),
        "roles": _resolveCodes(_selectedRoles, _allRoles),
        "specialities": _resolveCodes(_selectedSpecs, _allSpecs),
        "profilePictureUrl": imageUrl ?? _existingImageUrl,
        "schedules": branchAssignment?['schedules'] ??
            widget.initialMember?['schedules'] ??
            const [],
        "branchServiceIds": branchServiceIds,
        "userBranchServices": branchAssignment?['userBranchServices'] ??
            widget.initialMember?['userBranchServices'] ??
            const [],
        "allowOnlineBooking": branchAssignment?['allowOnlineBooking'] ??
            widget.initialMember?['allowOnlineBooking'] ??
            true,
        if (_normalizedAddress(widget.initialMember?['address']) != null)
          "address": _normalizedAddress(widget.initialMember?['address']),
      }..removeWhere((key, value) => value == null);

      await ApiService().updateTeamMember(
        branchId: widget.branchId,
        userId: userId,
        payload: payload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(translateText('Team member updated successfully'))),
      );
      Navigator.pop(context, true);
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    await _afterRebuild();
    _formKey.currentState?.validate();

    final errors = <String>[];
    void push(String? e) {
      if (e != null && e.trim().isNotEmpty) errors.add(e);
    }

    push(_vPhone(_phoneCtrl.text));
    push(_vFirstName(_firstNameCtrl.text));
    push(_vLastName(_lastNameCtrl.text));
    push(_vEmail(_emailCtrl.text));
    push(_vGender());
    push(_vRoles());
    push(_vSpecs());
    push(_vJoiningDate());
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
      appBar: buildProfileSubpageAppBar(
        title: translateText(
            widget.isEdit ? 'Edit Team Member' : 'Add Team Member'),
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
                    if (!widget.isEdit) ...[
                      MultiStepFlowHeader(
                        currentStep: 1,
                        steps: const [
                          FlowStepItem(
                            stepNumber: 1,
                            label: 'Personal Details',
                          ),
                          FlowStepItem(
                            stepNumber: 2,
                            label: 'Schedule',
                          ),
                          FlowStepItem(
                            stepNumber: 3,
                            label: 'Services',
                          ),
                          FlowStepItem(
                            stepNumber: 4,
                            label: 'Online Availability',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFD8C7B3),
                                  width: 1.4,
                                ),
                              ),
                              child: ClipOval(
                                child: _cameraImage == null
                                    ? (_existingImageUrl != null
                                        ? Image.network(
                                            _existingImageUrl!,
                                            fit: BoxFit.cover,
                                            width: 104,
                                            height: 104,
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.camera_alt_outlined,
                                                color: Color(0xFF8D867F),
                                                size: 28,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                translateText('Upload\nPhoto'),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Color(0xFF8D867F),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ],
                                          ))
                                    : Image.file(
                                        _cameraImage!,
                                        fit: BoxFit.cover,
                                        width: 104,
                                        height: 104,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: -4,
                              bottom: 8,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.starColor,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x26000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    _reqLabel(translateText('Phone Number')),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            enabled: widget.isEdit || !_phoneVerified,
                            keyboardType: TextInputType.phone,
                            // Only validate on typing AFTER first submit
                            autovalidateMode: _showGlobalErrors
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            textCapitalization: TextCapitalization.none,
                            decoration: _decor(
                              hint: translateText('Enter phone number'),
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    '+91',
                                    style: TextStyle(
                                      color: Color(0xFF2D2926),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
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
                    if (_phoneVerified && !widget.isEdit)
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
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // keep tops aligned
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
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  autovalidateMode: _showGlobalErrors
                                      ? AutovalidateMode.onUserInteraction
                                      : AutovalidateMode.disabled,
                                  decoration: _decor(
                                      hint: translateText('Enter first name')),
                                  validator: _vFirstName,
                                  onChanged: (_) {
                                    if (!_suppressFirstNameError) {
                                      setState(
                                          () => _suppressFirstNameError = true);
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
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  autovalidateMode: _showGlobalErrors
                                      ? AutovalidateMode.onUserInteraction
                                      : AutovalidateMode.disabled,
                                  decoration: _decor(
                                      hint: translateText('Enter last name')),
                                  validator: _vLastName,
                                  onChanged: (_) {
                                    if (!_suppressLastNameError) {
                                      setState(
                                          () => _suppressLastNameError = true);
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

                    Text(
                      translateText('Joining Date'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                        hint: translateText('Enter a brief about this member'),
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
                      flowStyle: true,
                      onPressed: () async {
                        if (!await _validateFormAndShowAlert()) return;
                        String capitalizeFirst(String value) => value.isNotEmpty
                            ? value[0].toUpperCase() + value.substring(1)
                            : value;

                        final branchAssignment =
                            _branchAssignment(widget.initialMember ?? const {});
                        final branchServiceIds =
                            _branchServiceIdsFromAssignment(
                          branchAssignment ?? widget.initialMember,
                        );
                        final payload = <String, dynamic>{
                          if (widget.isEdit)
                            "userId":
                                (widget.initialMember?['id'] as num?)?.toInt(),
                          "isEdit": widget.isEdit,
                          "countryCode": "+91",
                          "phoneNumber": _phoneCtrl.text.trim(),
                          "firstName":
                              capitalizeFirst(_firstNameCtrl.text.trim()),
                          "lastName":
                              capitalizeFirst(_lastNameCtrl.text.trim()),
                          "email": _emailCtrl.text.trim(),
                          "gender": _gender.toLowerCase(),
                          if (_joiningDate != null)
                            "joiningDate":
                                '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                          "brief": capitalizeFirst(_briefCtrl.text.trim()),
                          "roles": _resolveCodes(_selectedRoles, _allRoles),
                          "specializations":
                              _resolveCodes(_selectedSpecs, _allSpecs),
                          "specialities":
                              _resolveCodes(_selectedSpecs, _allSpecs),
                          "profilePictureUrl": imageUrl ?? _existingImageUrl,
                          "allowOnlineBooking":
                              branchAssignment?['allowOnlineBooking'] ??
                                  widget.initialMember?['allowOnlineBooking'] ??
                                  true,
                          "branchServiceIds": branchServiceIds,
                          "userBranchServices":
                              branchAssignment?['userBranchServices'] ??
                                  widget.initialMember?['userBranchServices'] ??
                                  const [],
                          "schedules": branchAssignment?['schedules'] ??
                              widget.initialMember?['schedules'] ??
                              const [],
                          if (_normalizedAddress(
                                  widget.initialMember?['address']) !=
                              null)
                            "address": _normalizedAddress(
                              widget.initialMember?['address'],
                            ),
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
    this.flowStyle = false,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final bool flowStyle;

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
          elevation: flowStyle ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(flowStyle ? 6 : 14),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: flowStyle ? 22 : 20,
                height: flowStyle ? 22 : 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: flowStyle ? 2.5 : 2,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontWeight: flowStyle ? FontWeight.w600 : FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
