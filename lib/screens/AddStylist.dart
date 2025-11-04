import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/screens/ChooseTimeSlot.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:bloc_onboarding/utils/localization_helper.dart';


class AddStylistScreen extends StatefulWidget {
  final int branchId;
  const AddStylistScreen({super.key, required this.branchId});

  @override
  State<AddStylistScreen> createState() => _AddStylistScreenState();
}

class _AddStylistScreenState extends State<AddStylistScreen> {
  final _formKey = GlobalKey<FormState>();
  String? imageUrl;
  // All roles and specializations data
  List<Map<String, dynamic>> _allRoles = [];
  List<Map<String, dynamic>> _allSpecs = [];

  // Controllers
  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _briefCtrl = TextEditingController();
  DateTime? _joiningDate;

  // Gender
  String _gender = '';

  final List<String> _selectedRoles = [];
  final List<String> _selectedSpecs = [];

  bool _phoneVerified = false;
  bool _otpFilled = false;

  // Colors
  final Color _bg = const Color(0xFFFFF8F0); // warm cream
  final Color _fieldFill = const Color(0xFFF7EFE6);
  final BorderRadius _radius = BorderRadius.circular(12);
  final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  File? _cameraImage;
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();

    // Pick an image from the gallery
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _cameraImage = File(pickedFile.path); // Set the selected image
      });

      // Upload the image and get the URL
      imageUrl = await _uploadImageToS3(
        _cameraImage!,
      ); // Store the image URL after uploading
      print("Uploaded Image URL: $imageUrl"); // Print the URL to debug
    }
  }

  Future<String?> _uploadImageToS3(File image) async {
    try {
      String? uploadedUrl = await ApiService().uploadImage(image);
      if (uploadedUrl != null) {
        print('Image uploaded successfully: $uploadedUrl');
        return uploadedUrl; // Return the uploaded image URL
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  InputDecoration _decor({
    String? hint,
    Widget? prefix,
    Widget? suffix,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
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
        borderSide: const BorderSide(color: Color(0xFFE0D6CC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFE0D6CC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFDBA35B), width: 1.5),
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
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRolesAndSpecializations() async {
    try {
      // Fetch data from the API
      Map<String, dynamic> data = await ApiService()
          .getRolesAndSpecializations();

      // Log the data to check the response
      print('Fetched roles and specializations: $data');

      // Assuming the data has a 'roles' and 'specialities' field
      setState(() {
        _allRoles = List<Map<String, dynamic>>.from(data['roles']);
        _allSpecs = List<Map<String, dynamic>>.from(data['specialities']);
        print('Roles: $_allRoles');
        print('Specializations: $_allSpecs');
      });
    } catch (e) {
      print('Error fetching data: $e');
      // Handle the error appropriately, e.g., show a message to the user
    }
  }

  Future<void> _handleVerifyPhoneNumber() async {
    // Get phone number entered by the user
    String phoneNumber = _phoneCtrl.text;

    try {
      // Make the API call to verify phone number and fetch user data
      var response = await ApiService.checkUserAndSendOtp(phoneNumber);

      // Check if the API response is successful
      if (response['success']) {
        var userData = response['data']['user']; // Get the user data
        bool userExists =
            response['data']['exists']; // Check if the user exists

        // If user exists, auto-fill the fields
        if (userExists) {
          if (userData != null) {
            print('User Data: $userData'); // Print user data to debug
            _firstNameCtrl.text =
                userData['firstName'] ?? ''; // Default to empty string if null
            _lastNameCtrl.text =
                userData['lastName'] ?? ''; // Default to empty string if null
            _emailCtrl.text =
                userData['email'] ?? ''; // Default to empty string if null
          }
        } else {
          print('No user data found. User might not exist.');
          // Optionally, you can show a message indicating the user doesn't exist
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(translateText('No user found.'))));
        }

        // Set the OTP in the OTP field
        _otpCtrl.text =
            response['data']['otp']; // Set the OTP received from the API

        // Update the phone verification status
        setState(() {
          _phoneVerified = true;
        });

        // Optionally, you can display a success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(translateText('Phone Verified Successfully'))));
      } else {
        // Handle failure (e.g., OTP error, invalid phone)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${translateText('Error')}: ${response['message']}")),
        );
      }
    } catch (e) {
      // Handle network or other errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(translateText('An error occurred: {error}', params: {'error': e.toString()}))));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRolesAndSpecializations();
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
              primary: Color(0xFFEEA044),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (res != null) setState(() => _joiningDate = res);
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<Map<String, dynamic>> source, // List of Maps
    required List<String> target,
  }) async {
    final temp = [...target]; // Create a temporary list to track selections

    // Show bottom sheet for multi-select
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
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
              // Title of the sheet
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              // List of items with checkboxes
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: source
                      .length, // This should match the length of your roles or specialities
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = source[i];
                    final itemName =
                        item['label'] ??
                        item['name'] ??
                        ''; // Extract label or name
                    final itemId = item['id']; // Extract id
                    final itemCode = item['code']; // Extract code
                    final checked = temp.contains(
                      itemName,
                    ); // Check if the item is selected

                    // Log the data for each item (id, code, label)
                    print(
                      'Item ${itemName}: id = $itemId, code = $itemCode, selected = $checked',
                    );

                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        // Update temporary list based on selection
                        if (v == true && !temp.contains(itemName)) {
                          temp.add(itemName);
                          // Log the selected item
                          print(
                            'Selected ${itemName}: id = $itemId, code = $itemCode',
                          );
                        } else if (v == false) {
                          temp.remove(itemName);
                          // Log the deselected item
                          print(
                            'Deselected ${itemName}: id = $itemId, code = $itemCode',
                          );
                        }
                        setState(() {}); // Refresh the sheet
                      },
                      title: Text(itemName),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              SizedBox(height: 12),
              _GradientButton(
                text: 'Done',
                onPressed: () {
                  setState(() {
                    target
                      ..clear()
                      ..addAll(
                        temp,
                      ); // Update the target list with selected items
                  });
                  Navigator.pop(ctx); // Close the bottom sheet
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translateText('Please fix the following')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors
              .map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ' + message),
                ),
              )
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

  Future<bool> _validateFormAndShowAlert() async {
    final errors = <String>[];

    _formKey.currentState?.validate();

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      errors.add(translateText('Phone number is required'));
    } else if (phone.length < 10) {
      errors.add(translateText('Phone number must be 10 digits.'));
    }

    if (!_phoneVerified) {
      errors.add(translateText('Please verify phone number'));
    }

    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) {
      errors.add(translateText('First Name is required & Must start with a capital letter.'));
    }

    final lastName = _lastNameCtrl.text.trim();
    if (lastName.isEmpty) {
      errors.add(translateText('Last Name is required & Must start with a capital letter.'));
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      errors.add(translateText('Email is required.'));
    } else if (!_emailRegExp.hasMatch(email)) {
      errors.add(translateText('Enter a valid email address.'));
    }

    if (_gender.isEmpty) {
      errors.add(translateText('Please select a gender.'));
    }

    if (_selectedRoles.isEmpty) {
      errors.add(translateText('Select at least one role.'));
    }

    if (_selectedSpecs.isEmpty) {
      errors.add(translateText('Select at least one specialization.'));
    }

    if (_joiningDate == null) {
      errors.add(translateText('Select a joining date.'));
    }

    if (_otpCtrl.text.trim().isEmpty) {
      errors.add(translateText('OTP is required.'));
    }

    if (errors.isNotEmpty) {
      await _showValidationDialog(errors);
      return false;
    }

    return true;
  }

  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(translateText('Become Stylish')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //  Text('Branch ID: ${widget.branchId}',
                    //                     style: const TextStyle(
                    //                         fontSize: 16, fontWeight: FontWeight.w600)),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 40, // Size of the avatar
                          backgroundColor: Colors.grey[300],
                          child: _cameraImage == null
                              ? Icon(
                                  Icons.camera_alt,
                                  size: 30,
                                ) // Default camera icon
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

                    SizedBox(height: 8),

                    // Phone Number Verification Field
                    _reqLabel('Verify Phone Number'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,

                            keyboardType: TextInputType.phone,
                            decoration: _decor(
                              hint: 'Verify phone number',
                              prefix: Icon(Icons.search),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? translateText('Phone is required')
                                : null,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // Allow only digits
                              LengthLimitingTextInputFormatter(
                                10,
                              ), // Limit input to 10 digits
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          height: 48,
                          child: _GradientButton(
                            text: _phoneVerified ? translateText('Verified') : translateText('Verify'),
                            onPressed: _phoneVerified
                                ? () {} // Provide an empty function when disabled
                                : () async {
                                    await _handleVerifyPhoneNumber(); // Wrap async function in an anonymous function
                                  },
                            enabled: !_phoneVerified,
                            fullWidth: false,
                            height: 48,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // First Name and Last Name Fields
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reqLabel('First Name'),
                              SizedBox(height: 8),
                              TextFormField(
  controller: _firstNameCtrl,
keyboardType: TextInputType.text,
  textCapitalization: TextCapitalization.sentences, // helps user type caps
  decoration: _decor(hint: 'Enter first name'),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return translateText('First Name is required');
    if (!RegExp(r'^[A-Z]').hasMatch(s)) {
      return translateText('Must start with a capital letter');
    }
    return null;
  },
),

                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reqLabel('Last Name'),
                              SizedBox(height: 8),
                              TextFormField(
  controller: _lastNameCtrl,
keyboardType: TextInputType.text,
  textCapitalization: TextCapitalization.sentences, 
  decoration: _decor(hint: 'Enter last name'),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return translateText('Last Name is required');
    if (!RegExp(r'^[A-Z]').hasMatch(s)) {
      return translateText('Must start with a capital letter');
    }
    return null;
  },
),

                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Email Field
                    _reqLabel('Email'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decor(hint: 'Enter email address'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? translateText('Email is required')
                          : null,
                    ),

                    SizedBox(height: 16),

                    // OTP Field
                    Text(translateText('Otp'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      enabled: false,
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _decor(hint: 'Enter otp'),
                    ),

                    SizedBox(height: 16),

                    // Gender Radio Buttons
                    Text(translateText('Gender'),
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
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        Text(translateText('Male')),
                        SizedBox(width: 16),
                        Radio<String>(
                          value: 'Female',
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        Text(translateText('Female')),
                        SizedBox(width: 16),
                        Radio<String>(
                          value: 'Other',
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        Text(translateText('Other')),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Roles Selection
                    _reqLabel('Roles'),
                    SizedBox(height: 8),
                    _PickField(
                      hint: 'Select Roles',
                      values: _selectedRoles,
                      onTap: () => _openMultiSelect(
                        title: 'Select Roles',
                        source: _allRoles,
                        target: _selectedRoles,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Specializations Selection
                    _reqLabel('Specializations'),
                    SizedBox(height: 8),
                    _PickField(
                      hint: 'Select Specializations',
                      values: _selectedSpecs,
                      onTap: () => _openMultiSelect(
                        title: 'Select Specializations',
                        source: _allSpecs,
                        target: _selectedSpecs,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Joining Date Field
                    _reqLabel('Joining Date'),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickJoiningDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          decoration:
                              _decor(
                                hint: 'Select joining date',
                                prefix: Icon(
                                  Icons.calendar_today_outlined,
                                ),
                              ).copyWith(
                                hintText: _joiningDate == null
                                    ? translateText('Select joining date')
                                    : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                              ),
                          validator: (_) => _joiningDate == null
                              ? translateText('Joining date is required')
                              : null,
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Brief About Member Field
                    Text(translateText('Brief About Member'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _briefCtrl,
                      maxLines: 4,
                      decoration: _decor(
                        hint: 'Enter a brief about this member',
                      ).copyWith(contentPadding: const EdgeInsets.all(14)),
                    ),

                    SizedBox(height: 20),

                    // Timeslot Selection Button
                    // _GradientButton(
                    //   text: 'Choose Timeslot',
                    //   onPressed: () async {
                    //     if (!await _validateFormAndShowAlert()) {
                    //       return;
                    //     }

                    //     // Prepare data to be passed
                    //     final formData = {
                    //       'phoneNumber': _phoneCtrl.text,
                    //       'firstName': _firstNameCtrl.text,
                    //       'lastName': _lastNameCtrl.text,
                    //       'email': _emailCtrl.text,
                    //       'otp': _otpCtrl.text,
                    //       'gender': _gender,
                    //       'roles': _selectedRoles,
                    //       'specializations': _selectedSpecs,
                    //       'joiningDate': _joiningDate,
                    //       'brief': _briefCtrl.text,
                    //       'profileImage': imageUrl,
                    //       'branchId': widget.branchId,
                    //     };
                    //     print('Form Data: $formData'); // Log the form data
                    //     // Navigate to ChooseTimeSlot.dart and pass the form data
                    //     Navigator.pushReplacement(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => ChooseTimeSlot(
                    //           formData: formData,
                    //         ), // Pass data directly to the new screen
                    //       ),
                    //     );
                    //   },
                    // ),

                    SizedBox(height: 24),
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
            fillColor: const Color(0xFFF7EFE6),
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0D6CC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0D6CC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDBA35B),
                width: 1.5,
              ),
            ),
          ),
          validator: (_) =>
              values.isEmpty ? translateText('Please select at least one') : null,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.fullWidth = true, // <-- new
    this.height = 50, // <-- optional
    super.key,
  });

  final String text;
  final VoidCallback onPressed;
  final bool enabled;
  final bool fullWidth; // <-- new
  final double height; // <-- new

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF2A245), Color(0xFFF4C058)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          // Only take all available width when asked to.
          width: fullWidth ? double.infinity : null, // <-- changed
          height: height, // <-- changed
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: enabled ? onPressed : null,
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
