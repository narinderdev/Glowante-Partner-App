import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_event.dart';
import 'package:bloc_onboarding/bloc/auth/auth_state.dart';
import 'package:bloc_onboarding/screens/otp_screen.dart';
import 'package:bloc_onboarding/services/push_notification_service.dart';

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/splash_logo.png',
                height: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'Where beauty and convenience unite',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('- Shine bright  '),
                  Text('- Feel radiant  '),
                  Text('- Choose Glowante!'),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter mobile number',
                  border: const OutlineInputBorder(),
                  errorText: phoneController.text.length > 10
                      ? 'Phone number cannot be more than 10 digits'
                      : null,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 20),
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthLoginSuccess) {
                    final phoneNumber = state.response['phoneNumber'];
                    final otp = state.response['otp'];
                    setState(() => _isLoading = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtpScreen(
                          phoneNumber: phoneNumber,
                          otp: otp ?? '',
                        ),
                      ),
                    );
                  }
                  if (state is AuthError) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message)),
                    );
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
                        deviceToken = await PushNotificationService.instance.getToken();
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
                        const SnackBar(
                          content: Text('Please enter a valid 10-digit mobile number'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthLoginSuccess) {
                    return Text(
                      'Login Success: ${state.response['message']}',
                      style: const TextStyle(color: Colors.green),
                    );
                  }
                  if (state is AuthError) {
                    return Text(
                      'Error: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
