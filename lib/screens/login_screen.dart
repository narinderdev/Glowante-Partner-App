import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_event.dart';
import 'package:bloc_onboarding/bloc/auth/auth_state.dart';
import 'package:bloc_onboarding/screens/otp_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;  // Loading state flag
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
            SizedBox(height: 20),
            // App Logo
            Image.asset(
              'assets/images/splash_logo.png',
              height: 100,
            ),
            SizedBox(height: 20),
            // Tagline
            Text(
              "Where beauty and convenience unite",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            // Bullet points tagline
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("● Shine bright  "),
                Text("● Feel radiant  "),
                Text("● Choose Glowante!"),
              ],
            ),
            SizedBox(height: 30),
            // Mobile number input
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter mobile number',
                border: OutlineInputBorder(),
                errorText: phoneController.text.length > 10
                    ? 'Phone number cannot be more than 10 digits'
                    : null,
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            SizedBox(height: 20),
            // Login Button with BlocListener
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthLoginSuccess) {
                  final phoneNumber = state.response['phoneNumber'];
                  final otp = state.response['otp'];
                  setState(() {
                    _isLoading = false;
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpScreen(phoneNumber: phoneNumber, otp: otp ?? ''),
                    ),
                  );
                }
                if (state is AuthError) {
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
              child: ElevatedButton(
                onPressed: () {
                  final phoneNumber = phoneController.text;
                  if (phoneNumber.length == 10) {
                    setState(() {
                      _isLoading = true;
                    });
                    BlocProvider.of<AuthBloc>(context)
                        .add(AuthLoginEvent(phoneNumber: phoneNumber));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Continue"),
              ),
            ),
            SizedBox(height: 20),
            // Footer text
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthLoginSuccess) {
                  return Text(
                    'Login Success: ${state.response['message']}',
                    style: TextStyle(color: Colors.green),
                  );
                }
                if (state is AuthError) {
                  return Text(
                    'Error: ${state.message}',
                    style: TextStyle(color: Colors.red),
                  );
                }
                return SizedBox.shrink();
              },
            ),
            SizedBox(height: 20), // Extra spacing at the bottom
          ],
        ),
      ),
    ),
  );
}
}
