// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../screens/add_salon_screen.dart'; // Import AddSalonScreen
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart'; // Import AddSalonCubit
import 'package:bloc_onboarding/repositories/salon_repository.dart'; // Import SalonRepository
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'login_screen.dart';
import 'stylist_bottom_nav.dart';

const Color _profileGold = Color(0xFF8B6500);
const Color _profileGoldLight = Color(0xFFD0A244);
const Color _profileInk = Color(0xFF1F1B18);
const Color _profileMuted = Color(0xFF6F665E);
const Color _profileBorder = Color(0xFFE8DED6);
const Color _profileFieldFill = Color(0xFFF7F4F3);

class UpdateUserProfileScreen extends StatefulWidget {
  final String token; // Token passed from OTP verification screen
  final bool isStylist;

  // Constructor to accept the token
  const UpdateUserProfileScreen({
    super.key,
    required this.token,
    this.isStylist = false,
  });

  @override
  State<UpdateUserProfileScreen> createState() =>
      _UpdateUserProfileScreenState();
}

class _UpdateUserProfileScreenState extends State<UpdateUserProfileScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final FocusNode firstNameFocusNode = FocusNode();
  final FocusNode lastNameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();

  String firstNameError = '';
  String lastNameError = '';
  String emailError = '';

  bool isLoading = false; // Flag to show loader while updating profile

  // API service instance
  final ApiService apiService = ApiService();
  static final RegExp _namePattern = RegExp(r"^[A-Za-z][A-Za-z .'-]*$");

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    firstNameFocusNode.dispose();
    lastNameFocusNode.dispose();
    emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    String firstName = _capitalizeFirstLetter(firstNameController.text.trim());
    String lastName = _capitalizeFirstLetter(lastNameController.text.trim());
    String email = emailController.text.trim().toLowerCase();
    if (emailController.text != email) {
      emailController.value = TextEditingValue(
        text: email,
        selection: TextSelection.collapsed(offset: email.length),
      );
    }

    // Reset errors
    setState(() {
      firstNameError = '';
      lastNameError = '';
      emailError = '';
    });

    // Validate input
    bool isValid = true;

    // ✅ First name validation
    if (firstName.isEmpty) {
      setState(() => firstNameError = translateText('First Name is required'));
      isValid = false;
    } else if (firstName.length < 2) {
      setState(() => firstNameError =
          translateText('First Name must be at least 2 characters'));
      isValid = false;
    } else if (!_namePattern.hasMatch(firstName)) {
      setState(() => firstNameError = translateText(
          'Use only letters, spaces, hyphens, apostrophes, or periods'));
      isValid = false;
    }

    // ✅ Last name validation
    if (lastName.isEmpty) {
      setState(() => lastNameError = translateText('Last Name is required'));
      isValid = false;
    } else if (lastName.length < 2) {
      setState(() => lastNameError =
          translateText('Last Name must be at least 2 characters'));
      isValid = false;
    } else if (!_namePattern.hasMatch(lastName)) {
      setState(() => lastNameError = translateText(
          'Use only letters, spaces, hyphens, apostrophes, or periods'));
      isValid = false;
    }

    // ✅ Email validation
    if (email.isEmpty) {
      setState(() => emailError = translateText('Email is required'));
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => emailError = translateText('Enter a valid email'));
      isValid = false;
    }

    if (!isValid) return;

    setState(() => isLoading = true);

    try {
      final response = await apiService.updateUserProfileDetails(
        firstName,
        lastName,
        email,
        widget.token,
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('firstName', firstName);
      await prefs.setString('lastName', lastName);
      await prefs.setString('email', email);
      await prefs.setString('emailAddress', email);
      await prefs.setString('first_name', firstName);
      await prefs.setString('last_name', lastName);
      await prefs.setBool('profile_complete', true);
      await prefs.setBool('profile_pending', false);

      if (response['success'] == true) {
        var userData = response['data'];
        double? latitude = userData['latitude'] ?? 0.0;
        double? longitude = userData['longitude'] ?? 0.0;
        if (!mounted) return;

        if (widget.isStylist) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const StylistBottomNav(tabIndex: 0),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (context) =>
                    AddSalonCubit(context.read<SalonRepository>()),
                child: AddSalonScreen(
                  id: userData['id'].toString(),
                  phoneNumber: userData['phoneNumber'],
                  fullPhoneNumber: userData['fullPhoneNumber'],
                  firstName: userData['firstName'] ?? '',
                  lastName: userData['lastName'] ?? '',
                  email: email,
                  isProceedFrom: "onboarding",
                  buildingName: userData['buildingName'] ?? '',
                  city: userData['city'] ?? '',
                  pincode: userData['pincode'] ?? '',
                  state: userData['state'] ?? '',
                  completeAddress: userData['completeAddress'] ??
                      userData['address'] ??
                      userData['fullAddress'] ??
                      '',
                  latitude: latitude,
                  longitude: longitude,
                  showCancelButton: true,
                ),
              ),
            ),
          );
        }
      } else {
        List<String> errorMessages = List<String>.from(
          response['message'] ?? [],
        ).map(_friendlyProfileMessage).toList();
        _showErrorDialog(errorMessages);
      }
    } catch (e) {
      final message = _friendlyProfileError(e);
      setState(() => emailError = message);
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _friendlyProfileError(Object error) {
    final message = extractErrorMessage(
      error,
      fallback: 'Unable to update profile. Please try again.',
    );
    return _friendlyProfileMessage(message);
  }

  String _friendlyProfileMessage(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('email must be an email') ||
        lowerMessage.contains('must be an email')) {
      return translateText('Enter a valid email');
    }
    if (lowerMessage.contains('socketexception') ||
        lowerMessage.contains('failed host lookup') ||
        lowerMessage.contains('no address associated with hostname') ||
        lowerMessage.contains('network is unreachable') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection reset') ||
        lowerMessage.contains('clientexception')) {
      return translateText(
        'No internet connection. Please check your network and try again.',
      );
    }
    if (lowerMessage.contains('bad gateway') ||
        lowerMessage.contains('gateway') ||
        lowerMessage.contains('502') ||
        lowerMessage.contains('503') ||
        lowerMessage.contains('504') ||
        lowerMessage.contains('service unavailable')) {
      return translateText(
        'Profile service is temporarily unavailable. Please try again in a few minutes.',
      );
    }
    return message;
  }

  String _capitalizeFirstLetter(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  void _goBackToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // Function to show the error messages in an alert dialog
  void _showErrorDialog(List<String> errorMessages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translateText("Profile Update Failed")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: errorMessages
                .map(
                    (error) => Text(error, style: TextStyle(color: Colors.red)))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(translateText("OK")),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      appBar: AppBar(
        backgroundColor: _profileGold,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _profileGold,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFFBF7F2),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        title: Text(
          translateText('Create Profile'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _profileGold,
                ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: _profileGold,
              selectionColor: Color(0x33D0A244),
              selectionHandleColor: _profileGold,
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _profileBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 22,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5EAD2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: _profileGold,
                            size: 29,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          translateText('Create Profile'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _profileInk,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Center(
                        child: Text(
                          translateText(
                            'Complete your profile details to continue onboarding.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _profileMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AutofillGroup(
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: firstNameController,
                              focusNode: firstNameFocusNode,
                              nextFocusNode: lastNameFocusNode,
                              label: 'First Name',
                              hint: 'Enter your first name',
                              fieldType: 'firstName',
                              fieldError: firstNameError,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: lastNameController,
                              focusNode: lastNameFocusNode,
                              nextFocusNode: emailFocusNode,
                              label: 'Last Name',
                              hint: 'Enter your last name',
                              fieldType: 'lastName',
                              fieldError: lastNameError,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: emailController,
                              focusNode: emailFocusNode,
                              label: 'Email',
                              hint: 'Enter your email',
                              fieldType: 'email',
                              fieldError: emailError,
                              autofillHints: const [AutofillHints.email],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _profileGold,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _profileGold.withValues(alpha: 0.55),
                          elevation: 8,
                          shadowColor: const Color(0x338B6500),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                translateText('Continue').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: isLoading ? null : _goBackToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _profileGold,
                          disabledForegroundColor:
                              _profileGold.withValues(alpha: 0.45),
                          side: const BorderSide(color: _profileGoldLight),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: Text(
                          translateText('Go back to login').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  translateText(
                    '"Excellence begins with understanding our guests."',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB9A999),
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          text: translateText(label).toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF4B4038),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.redAccent,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required String hint,
    required String fieldType,
    required String fieldError,
    List<String>? autofillHints,
  }) {
    final bool isNameField =
        fieldType == 'firstName' || fieldType == 'lastName';
    final maxLength = fieldType == 'email' ? 100 : 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextField(
          key: ValueKey('create_profile_$fieldType'),
          controller: controller,
          focusNode: focusNode,
          cursorColor: _profileGold,
          textInputAction: fieldType == 'email'
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: (_) {
            if (fieldType == 'email') {
              _updateProfile();
            } else {
              FocusScope.of(context).requestFocus(
                nextFocusNode ?? emailFocusNode,
              );
            }
          },
          onChanged: (value) {
            if (fieldType == 'firstName' && firstNameError.isNotEmpty) {
              setState(() => firstNameError = '');
            } else if (fieldType == 'lastName' && lastNameError.isNotEmpty) {
              setState(() => lastNameError = '');
            } else if (fieldType == 'email' && emailError.isNotEmpty) {
              setState(() => emailError = '');
            }
          },
          keyboardType: fieldType == 'email'
              ? TextInputType.emailAddress
              : TextInputType.text,
          autofillHints: autofillHints,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: [
            if (isNameField) const _ProfileNameInputFormatter(),
            if (fieldType == 'email')
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            if (fieldType == 'email') const _LowerCaseTextInputFormatter(),
          ],
          textCapitalization:
              isNameField ? TextCapitalization.words : TextCapitalization.none,
          style: const TextStyle(
            color: _profileInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: translateText(hint),
            counterText: '',
            filled: true,
            fillColor: _profileFieldFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: _profileBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: _profileBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide:
                  const BorderSide(color: _profileGoldLight, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
            ),
            hintStyle: const TextStyle(
              color: Color(0xFFAAA19A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    fieldError,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${value.text.length}/$maxLength',
                  style: TextStyle(
                    color: value.text.length >= maxLength
                        ? Colors.redAccent
                        : _profileMuted,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfileNameInputFormatter extends TextInputFormatter {
  const _ProfileNameInputFormatter();

  static final RegExp _validCharacters = RegExp(r"[A-Za-z .'-]");
  static final RegExp _spaceLikeCharacters = RegExp(r'[\s\u00A0]+');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalizedText = newValue.text.replaceAll(_spaceLikeCharacters, ' ');
    final buffer = StringBuffer();

    for (final rune in normalizedText.runes) {
      final character = String.fromCharCode(rune);
      if (_validCharacters.hasMatch(character)) {
        buffer.write(character);
      }
    }

    final filteredText = buffer.toString();
    final selectionOffset =
        newValue.selection.end.clamp(0, filteredText.length);

    return TextEditingValue(
      text: filteredText,
      selection: TextSelection.collapsed(offset: selectionOffset),
      composing: TextRange.empty,
    );
  }
}

class _LowerCaseTextInputFormatter extends TextInputFormatter {
  const _LowerCaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toLowerCase(),
      composing: TextRange.empty,
    );
  }
}
