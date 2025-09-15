import 'dart:async';  // Import for Timer
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/api_service.dart';  // Import ApiService for OTP verification
import 'bottom_nav.dart'; // Import BottomNav (for your 4-tab navigation)
import 'login_screen.dart'; // Import the LoginScreen
import '../screens/UpdateProfileScreen.dart'; // Import UpdateUserProfileScreen
import 'package:shared_preferences/shared_preferences.dart'; 

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String otp; // Added OTP field

  OtpScreen({required this.phoneNumber, required this.otp});

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());  // Create a focus node for each field
  String errorMessage = ''; // To store error message
  bool isResendingOtp = false;  // Track whether OTP is being resent
  int remainingTime = 30;  // Set initial time to 30 seconds
  Timer? _timer;  // Timer instance to handle countdown
  bool isContinueButtonEnabled = false;  // Track if the Continue button should be enabled
  bool isLoading = false;  // Track loading state for button

  // API service instance
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Start the countdown timer immediately when the screen is initialized
    _startCountdown();
  }

Future<void> _verifyOtp() async {
  String otp = otpControllers.map((controller) => controller.text).join();
  if (otp.length < 6) {
    setState(() {
      errorMessage = 'Please enter a valid 6-digit OTP';
    });
    return;
  }

  setState(() {
    isLoading = true; // Set loading state
  });

  try {
    final response = await apiService.verifyOTP(widget.phoneNumber, otp);

    if (response['success'] == true) {
      print("OTP Verified successfully");

      String? token = response['data']?['token'];
      Map<String, dynamic>? user = response['data']?['user'];

      if (token != null && user != null) {
        String? firstName = user['firstName'];
        String? lastName = user['lastName'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token);
        await prefs.setString('phone_number', widget.phoneNumber);
        if (firstName != null) await prefs.setString('first_name', firstName);
        if (lastName != null) await prefs.setString('last_name', lastName);

        print("Token saved: $token");
        print("Phone saved: ${widget.phoneNumber}");
        print("First Name saved: $firstName");
        print("Last Name saved: $lastName");

        // Navigate
        if (firstName != null && firstName.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 0)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => UpdateUserProfileScreen(token: token)),
          );
        }
      } else {
        setState(() {
          errorMessage = 'User data or token is missing';
        });
      }
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'OTP verification failed';
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Error verifying OTP: $e';
    });
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  // Function to handle OTP input focus and auto-switch to next field
  void _handleOtpInput(String value, int index) {
    if (value.isNotEmpty) {
      // Move focus to next field
      if (index < 5) {
        FocusScope.of(context).requestFocus(focusNodes[index + 1]);
      }
    } else if (index > 0) {
      // Move focus to previous field if value is empty (deletion)
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
    }

    // Check if all OTP fields are filled
    bool allFilled = otpControllers.every((controller) => controller.text.isNotEmpty);
    setState(() {
      isContinueButtonEnabled = allFilled;  // Enable button when all fields are filled
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      isResendingOtp = true;  // Set loading state
    });
    try {
      final response = await apiService.resendOtp(widget.phoneNumber);
      if (response['success'] == true) {
        setState(() {
          errorMessage = 'OTP has been resent successfully';
        });
        // Start the countdown timer after OTP is resent
        _startCountdown();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to resend OTP';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error during OTP resend: $e';
      });
    } finally {
      setState(() {
        isResendingOtp = false;  // Reset loading state
      });
    }
  }

  void _startCountdown() {
    // Log to check if the function is being called
    print("Starting countdown...");

    // Cancel the previous timer if it exists
    _timer?.cancel();

    // Reset the remaining time to 30 seconds
    setState(() {
      remainingTime = 30;
    });
    print("Remaining time set to: $remainingTime"); // Log initial time set

    // Start a new periodic timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;  // Decrease the remaining time by 1 every second
        });
        // print('Remaining time: $remainingTime');  // Log to check timer progression
      } else {
        _timer?.cancel();  // Stop the timer when countdown reaches 0
        // print('Timer finished');  // Log when timer finishes
      }
    });
  }

  // Function to reset the countdown and go back to the LoginScreen when back is pressed
  void _onBackPressed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),  // Navigate back to LoginScreen
    );
  }

  @override
  void dispose() {
    // Dispose all the focus nodes to avoid memory leaks
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();  // Cancel the timer when disposing
    super.dispose();
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: _onBackPressed,
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Text(
              "OTP Verification",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Enter the OTP sent to *****${widget.phoneNumber.substring(6)}",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            // OTP Input Fields (6 separate text fields)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 40,
                  height: 50,
                  margin: EdgeInsets.symmetric(horizontal: 5),
                  child: TextField(
                    controller: otpControllers[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    focusNode: focusNodes[index],
                    decoration: InputDecoration(
                      counterText: "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      _handleOtpInput(value, index);
                    },
                  ),
                );
              }),
            ),
            if (errorMessage.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            SizedBox(height: 20),
            // Continue Button
            ElevatedButton(
              onPressed: isContinueButtonEnabled && !isLoading ? _verifyOtp : null,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: isContinueButtonEnabled && !isLoading ? Colors.orange : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Continue", style: TextStyle(color: Colors.black)),
            ),
            SizedBox(height: 20),
            // Resend OTP
            GestureDetector(
              onTap: isResendingOtp || remainingTime > 0 ? null : _resendOtp,
              child: Text(
                isResendingOtp
                    ? "Resending..."
                    : (remainingTime > 0 ? "Resend OTP in $remainingTime sec" : "Resend OTP"),
                style: TextStyle(
                  color: remainingTime > 0 ? Colors.grey : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       elevation: 0, // Remove the default app bar shadow
  //       backgroundColor: Colors.transparent, // Make the app bar transparent
  //       leading: IconButton(
  //         icon: Icon(Icons.arrow_back),
  //         onPressed: _onBackPressed,  // Navigate to LoginScreen on back button press
  //       ),
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           Text(
  //             "OTP Verification",
  //             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  //           ),
  //           SizedBox(height: 10),
  //                      Text(
  //             "Enter the OTP sent to *****${widget.phoneNumber.substring(6)}",
  //             style: TextStyle(fontSize: 16),
  //           ),
  //           SizedBox(height: 30),
  //           // OTP Input Fields (6 separate text fields)
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: List.generate(6, (index) {
  //               return Container(
  //                 width: 40,
  //                 height: 50,
  //                 margin: EdgeInsets.symmetric(horizontal: 5),
  //                 child: TextField(
  //                   controller: otpControllers[index],
  //                   keyboardType: TextInputType.number,
  //                   textAlign: TextAlign.center,
  //                   maxLength: 1,
  //                   focusNode: focusNodes[index],  // Use corresponding FocusNode
  //                   decoration: InputDecoration(
  //                     counterText: "",
  //                     border: OutlineInputBorder(
  //                       borderRadius: BorderRadius.circular(8),
  //                     ),
  //                   ),
  //                   onChanged: (value) {
  //                     // Move focus on input
  //                     _handleOtpInput(value, index);
  //                   },
  //                 ),
  //               );
  //             }),
  //           ),
  //           if (errorMessage.isNotEmpty) ...[
  //             SizedBox(height: 10),
  //             Text(
  //               errorMessage,
  //               style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
  //             ),
  //           ],
  //           SizedBox(height: 20),
  //           // Continue Button with loader logic
  //           ElevatedButton(
  //             onPressed: isContinueButtonEnabled && !isLoading ? _verifyOtp : null, // Enable only if all digits are filled and not loading
  //             style: ElevatedButton.styleFrom(
  //               minimumSize: Size(double.infinity, 50), // Full width button
  //               backgroundColor: isContinueButtonEnabled && !isLoading ? Colors.orange : Colors.grey[300], // Button color change
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(8), // Rounded corners
  //               ),
  //             ),
  //             child: isLoading
  //                 ? CircularProgressIndicator(color: Colors.white)  // Show loader if loading
  //                 : Text("Continue", style: TextStyle(color: Colors.black)),
  //           ),
  //           SizedBox(height: 20),
  //           // Resend OTP Text with countdown
  //           GestureDetector(
  //             onTap: isResendingOtp || remainingTime > 0 ? null : _resendOtp,  // Disable if OTP is being resent or time is remaining
  //             child: Text(
  //               isResendingOtp ? "Resending..." : (remainingTime > 0 ? "Resend OTP in $remainingTime sec" : "Resend OTP"),  // Show countdown
  //               style: TextStyle(
  //                 color: remainingTime > 0 ? Colors.grey : Colors.orange,  // Make countdown grey
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
