import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_event.dart';
import 'package:bloc_onboarding/bloc/auth/auth_state.dart';
import 'package:bloc_onboarding/screens/otp_screen.dart';
import 'package:bloc_onboarding/services/push_notification_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isContinueEnabled = false;
  String _countryCode = '+91';
  String? _errorMessage;
  String? _lastSnackMessage;
  DateTime? _lastSnackTime;
  static const Duration _snackCooldown = Duration(seconds: 2);
  @override
  void initState() {
    super.initState();
    phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    phoneController.removeListener(_handlePhoneChanged);
    phoneController.dispose();
    super.dispose();
  }

  void _handlePhoneChanged() {
    final phone = phoneController.text.trim();
    final bool isValid = RegExp(r'^[6-9]\d{9}$').hasMatch(phone) &&
        !RegExp(r'^0+$').hasMatch(phone);
    if (isValid != _isContinueEnabled) {
      setState(() => _isContinueEnabled = isValid);
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final phoneNumber = phoneController.text.trim();

    // ✅ Validation checks
    if (phoneNumber.isEmpty ||
        phoneNumber.length != 10 ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phoneNumber) ||
        RegExp(r'^0+$').hasMatch(phoneNumber)) {
      setState(() {
        _errorMessage =
            translateText('Please enter a valid 10-digit mobile number');
      });
      return;
    }

    // ✅ clear error if valid
    setState(() {
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String? deviceToken;
    try {
      deviceToken = await PushNotificationService.instance.getToken();
      print('FCM Device Token: $deviceToken');
    } catch (error) {
      debugPrint('Unable to fetch FCM token: $error');
    }

    context.read<AuthBloc>().add(
          AuthLoginEvent(
            phoneNumber: phoneNumber,
            deviceToken: deviceToken,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 84, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Image.asset(
                'assets/images/finallogo.png',
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Image.asset('assets/images/logo.png', height: 80),
              ),
              const SizedBox(height: 24),

              // 🟡 Title
              Text(
                translateText('Sign in to your account'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // 🟡 Subtitle
              Text(
                translateText('Where beauty and convenience unite'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.starColor,
                ),
              ),

              const SizedBox(height: 20),

              // ✨ Tagline Row
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildDotText(translateText('Shine bright')),
                  _buildDotText(translateText('Feel radiant')),
                  _buildDotText(translateText('Choose Glowante!')),
                ],
              ),

              const SizedBox(height: 40),

              // 📱 Label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  translateText('Mobile Number'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 🌍 Phone field with country code picker
              // 📱 Country flag outside, code inside the input field
              Row(
                children: [
                  // 🌍 Flag (outside input)
// Container(
//   height: 48, // same as input
//   width: 90,  // ✅ slightly wider for proper flag + arrow space
//   padding: const EdgeInsets.symmetric(horizontal: 6), // add breathing space
//   decoration: BoxDecoration(
//     border: Border.all(color: Colors.grey.shade400),
//     borderRadius: BorderRadius.circular(8),
//     color: Colors.white, // ensure flag background matches screen
//   ),
//   child: Center(
//     child: CountryCodePicker(
//       onChanged: (code) {
//         setState(() {
//           _countryCode = code.dialCode ?? '+91';
//         });
//       },
//       initialSelection: 'IN', // 🇮🇳 default
//       favorite: const ['+91', 'IN'],
//       showFlag: true,
//       showFlagDialog: true,
//       showDropDownButton: true, // ✅ shows arrow next to flag
//       hideMainText: true, // hide "+91" (we show inside input)
//       alignLeft: false,
//       flagWidth: 28, // ✅ larger, crisp flag
//       padding: EdgeInsets.zero,
//       textStyle: const TextStyle(fontSize: 15, color: Colors.black),
//     ),
//   ),
// ),

                  const SizedBox(width: 8),

                  // 📞 TextField with code prefix inside
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Text(
                              _countryCode,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: translateText('Enter mobile number'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.starColor,
                                width: 1.3), // highlight border when focused
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          counterText: '',
                          errorText: phoneController.text.length > 10
                              ? 'Phone number cannot be more than 10 digits'
                              : null,
                        ),
                        maxLength: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
// 🔴 Inline error message above Continue button
              if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],

              // 🔘 Continue button
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthLoginSuccess) {
                    final dynamic rawPhone = state.response['phoneNumber'];
                    final String phoneNumber =
                        (rawPhone is String && rawPhone.isNotEmpty)
                            ? rawPhone
                            : phoneController.text.trim();
                    setState(() => _isLoading = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtpScreen(
                          phoneNumber: phoneNumber,
                        ),
                      ),
                    );
                  }
                  if (state is AuthError) {
                    setState(() => _isLoading = false);
                    final now = DateTime.now();
                    final bool shouldShow =
                        _lastSnackMessage != state.message ||
                            _lastSnackTime == null ||
                            now.difference(_lastSnackTime!) > _snackCooldown;
                    if (shouldShow) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(state.message)),
                        );
                      _lastSnackMessage = state.message;
                      _lastSnackTime = now;
                    }
                  }
                },
                child: ElevatedButton(
                  onPressed:
                      (_isContinueEnabled && !_isLoading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith(
                      (states) => states.contains(MaterialState.disabled)
                          ? AppColors.starColor.withOpacity(0.4)
                          : AppColors.starColor,
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          translateText('CONTINUE'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 🟡 Reusable bullet text for tagline
  Widget _buildDotText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle,
            size: 8, color: AppColors.starColor.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
