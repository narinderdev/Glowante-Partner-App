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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Image.asset('assets/images/splash_logo.png', height: 100),
              SizedBox(height: 20),
              Text(translateText('Where beauty and convenience unite'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(translateText('- Shine bright  ')),
                  Text(translateText('- Feel radiant  ')),
                  Text(translateText('- Choose Glowante!')),
                ],
              ),
              SizedBox(height: 30),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: translateText('Mobile Number'),
                  hintText: translateText('Enter mobile number'),
                  border: const OutlineInputBorder(),
                  errorText: phoneController.text.length > 10
                      ? 'Phone number cannot be more than 10 digits'
                      : null,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              SizedBox(height: 20),
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthLoginSuccess) {
                    final phoneNumber = state.response['phoneNumber'];
                    final otp = state.response['otp'];
                    setState(() => _isLoading = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OtpScreen(phoneNumber: phoneNumber, otp: otp ?? ''),
                      ),
                    );
                  }
                  if (state is AuthError) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message)));
                  }
                },
                child: ElevatedButton(
                  onPressed: () async {
                    final phoneNumber = phoneController.text.trim();
                    if (phoneNumber.length == 10) {
                      FocusScope.of(context).unfocus();
                      setState(() => _isLoading = true);

                      String? deviceToken;
                      try {
                        deviceToken = await PushNotificationService.instance
                            .getToken();
                        print('FCM Device Token: $deviceToken');
                      } catch (error) {
                        debugPrint('Unable to fetch FCM token: ${error}');
                      }

                      context.read<AuthBloc>().add(
                        AuthLoginEvent(
                          phoneNumber: phoneNumber,
                          deviceToken: deviceToken,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(translateText('Please enter a valid 10-digit mobile number'),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.starColor,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(translateText('Continue')),
                ),
              ),
              SizedBox(height: 20),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthLoginSuccess) {
                    // return Text(
                    //   'Login Success: ${state.response['message']}',
                    //   style: const TextStyle(color: Colors.green),
                    // );
                  }
                  if (state is AuthError) {
                    return Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
