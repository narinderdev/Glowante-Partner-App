import 'package:flutter/material.dart';
import '../utils/api_service.dart';
// import 'package:bloc_onboarding/screens/ChooseTimeSlot.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddTeamScreen extends StatefulWidget {
  final int branchId;
   final int salonId;
  final String branchName;
  const AddTeamScreen({super.key, required this.branchId,required this.salonId,
    required this.branchName,});

  @override
  State<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
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
        children: const [
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
          ).showSnackBar(SnackBar(content: Text('No user found.')));
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
        ).showSnackBar(SnackBar(content: Text('Phone Verified Successfully')));
      } else {
        // Handle failure (e.g., OTP error, invalid phone)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response['message']}')),
        );
      }
    } catch (e) {
      // Handle network or other errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
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
        title: const Text('Please fix the following'),
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
            child: const Text('OK'),
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
      errors.add('Phone number is required.');
    } else if (phone.length < 10) {
      errors.add('Phone number must be 10 digits.');
    }

    if (!_phoneVerified) {
      errors.add('Please verify the phone number.');
    }

    final firstName = _firstNameCtrl.text.trim();
  if (firstName.isEmpty) {
    errors.add('First name is required.');
  } else if (!RegExp(r'^[A-Z]').hasMatch(firstName)) {
    errors.add('Must start with a capital letter.');
  }

  final lastName = _lastNameCtrl.text.trim();
  if (lastName.isEmpty) {
    errors.add('Last name is required.');
  } else if (!RegExp(r'^[A-Z]').hasMatch(lastName)) {
    errors.add('Must start with a capital letter.');
  }
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      errors.add('Email is required.');
    } else if (!_emailRegExp.hasMatch(email)) {
      errors.add('Enter a valid email address.');
    }

    if (_gender.isEmpty) {
      errors.add('Please select a gender.');
    }

    if (_selectedRoles.isEmpty) {
      errors.add('Select at least one role.');
    }

    if (_selectedSpecs.isEmpty) {
      errors.add('Select at least one specialization.');
    }

    if (_joiningDate == null) {
      errors.add('Select a joining date.');
    }

    if (_otpCtrl.text.trim().isEmpty) {
      errors.add('OTP is required.');
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Add Team Member'),
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
                 Text(
  'Salon ID: ${widget.salonId}',
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
),
Text(
  'Branch ID: ${widget.branchId}',
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
),
Text(
  'Branch Name: ${widget.branchName}',
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 40, // Size of the avatar
                          backgroundColor: Colors.grey[300],
                          child: _cameraImage == null
                              ? const Icon(
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

                    const SizedBox(height: 8),

                    // Phone Number Verification Field
                    _reqLabel('Verify Phone Number'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,

                            keyboardType: TextInputType.phone,
                            decoration: _decor(
                              hint: 'Verify phone number',
                              prefix: const Icon(Icons.search),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Phone is required'
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
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          height: 48,
                          child: _GradientButton(
                            text: _phoneVerified ? 'Verified' : 'Verify',
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

                    const SizedBox(height: 16),

                    // First Name and Last Name Fields
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reqLabel('First Name'),
                              const SizedBox(height: 8),
                              // TextFormField(
                              //   controller: _firstNameCtrl,

                              //   decoration: _decor(hint: 'Enter first name'),
                              //   validator: (v) =>
                              //       (v == null || v.trim().isEmpty)
                              //       ? 'Required'
                              //       : null,
                              // ),
                                                 TextFormField(
  controller: _firstNameCtrl,
  textCapitalization: TextCapitalization.words, // helps user type caps
  decoration: _decor(hint: 'Enter first name'),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'First name is required';
    if (!RegExp(r'^[A-Z]').hasMatch(s)) {
      return 'Must start with a capital letter';
    }
    return null;
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
                              _reqLabel('Last Name'),
                              const SizedBox(height: 8),
                              // TextFormField(
                              //   controller: _lastNameCtrl,
                              //   decoration: _decor(hint: 'Enter last name'),
                              //   validator: (v) =>
                              //       (v == null || v.trim().isEmpty)
                              //       ? 'Required'
                              //       : null,
                              // ),
                                   TextFormField(
  controller: _lastNameCtrl,
  textCapitalization: TextCapitalization.words,
  decoration: _decor(hint: 'Enter last name'),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Last name is required';
    if (!RegExp(r'^[A-Z]').hasMatch(s)) {
      return 'Must start with a capital letter';
    }
    return null;
  },
),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Email Field
                    _reqLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decor(hint: 'Enter email address'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Email is required'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // OTP Field
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
                      decoration: _decor(hint: 'Enter otp'),
                    ),

                    const SizedBox(height: 16),

                    // Gender Radio Buttons
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
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        const Text('Male'),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: 'Female',
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        const Text('Female'),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: 'Other',
                          groupValue: _gender,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        const Text('Other'),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Roles Selection
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

                    const SizedBox(height: 16),

                    // Specializations Selection
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

                    const SizedBox(height: 16),

                    // Joining Date Field
                    _reqLabel('Joining Date'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickJoiningDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          decoration:
                              _decor(
                                hint: 'Select joining date',
                                prefix: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                              ).copyWith(
                                hintText: _joiningDate == null
                                    ? 'Select joining date'
                                    : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                              ),
                          validator: (_) => _joiningDate == null
                              ? 'Joining date is required'
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Brief About Member Field
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
                      decoration: _decor(
                        hint: 'Enter a brief about this member',
                      ).copyWith(contentPadding: const EdgeInsets.all(14)),
                    ),

                    const SizedBox(height: 20),

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
_GradientButton(
  text: 'Add Team Member',
  onPressed: () async {
    if (!await _validateFormAndShowAlert()) {
      return;
    }

    final payload = {
      "countryCode": "+91",
      "phoneNumber": _phoneCtrl.text.trim(),
      "firstName": _firstNameCtrl.text.trim(),
      "lastName": _lastNameCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),"joinedAt": _joiningDate != null
          ? "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}"
          : null,
      "roles": _selectedRoles,
      "specialities": _selectedSpecs,
    };

    print("📌 Final Team Member Payload: $payload");

    final result = await ApiService().addSalonTeamMember(widget.salonId, payload);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team Member added successfully")),
      );
      Navigator.pop(context,true); // go back to TeamScreen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed: ${result['message']}")),
      );
    }
  },
),

                    const SizedBox(height: 24),
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
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
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
              values.isEmpty ? 'Please select at least one' : null,
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
