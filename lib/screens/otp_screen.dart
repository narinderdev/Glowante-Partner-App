import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloc_onboarding/utils/api_service.dart'; // Import ApiService for OTP verification
import 'package:bloc_onboarding/utils/error_parser.dart';
import 'bottom_nav.dart'; // Import BottomNav (for your 4-tab navigation)
import 'login_screen.dart'; // Import the LoginScreen
import '../screens/UpdateProfileScreen.dart'; // Import UpdateUserProfileScreen
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final List<TextEditingController> otpControllers;
  final List<FocusNode> focusNodes = List.generate(
    6,
    (_) => FocusNode(),
  ); // Create a focus node for each field
  late final OTPInteractor _otpInteractor;
  late final OTPTextEditController _otpTextEditController;
  bool _isProgrammaticFill = false;
  String errorMessage = ''; // To store error message
  bool isResendingOtp = false; // Track whether OTP is being resent
  int remainingTime = 30; // Set initial time to 30 seconds
  Timer? _timer; // Timer instance to handle countdown
  bool isContinueButtonEnabled =
      false; // Track if the Continue button should be enabled
  bool isLoading = false; // Track loading state for button
  bool _autoSubmitScheduled = false;

  // API service instance
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    otpControllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );

    _otpInteractor = OTPInteractor();
    _otpTextEditController = OTPTextEditController(
      codeLength: 6,
      otpInteractor: _otpInteractor,
      onCodeReceive: (code) {
        _fillFromCode(code);
      },
    )..addListener(() {
        if (_isProgrammaticFill) return;
        final text = _otpTextEditController.text;
        if (text.length > 1) {
          _fillFromCode(text);
        }
      });

    // Replace the first controller with OTP-aware controller
    otpControllers.first.dispose();
    otpControllers[0] = _otpTextEditController;

    // Start the countdown timer immediately when the screen is initialized
    _startCountdown();

  }

  void _maybeSubmitOtp() {
    if (!mounted || isLoading || _autoSubmitScheduled) return;
    final String otp = otpControllers.map((c) => c.text).join();
    final bool allFilled =
        otp.length == otpControllers.length && otpControllers.every((c) => c.text.isNotEmpty);
    if (!allFilled) return;
    _autoSubmitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String latestOtp = otpControllers.map((c) => c.text).join();
      final bool stillFilled = latestOtp.length == otpControllers.length &&
          otpControllers.every((c) => c.text.isNotEmpty);
      if (!stillFilled || isLoading) {
        _autoSubmitScheduled = false;
        return;
      }
      _verifyOtp();
    });
  }
void _clearOtpAndFocus() {
  _isProgrammaticFill = true;
  for (final c in otpControllers) c.clear();
  _isProgrammaticFill = false;

  setState(() {
    isContinueButtonEnabled = false;
  });

  // focus first box
  if (focusNodes.isNotEmpty) {
    FocusScope.of(context).requestFocus(focusNodes[0]);
  }
}

  Future<void> _verifyOtp() async {
    _autoSubmitScheduled = false;
    String otp = otpControllers.map((controller) => controller.text).join();
    if (otp.length < 6) {
      setState(() {
        errorMessage = translateText('Please enter a valid 6-digit OTP');
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
          final bool hasFirstName =
              firstName != null && firstName.trim().isNotEmpty;
          final bool hasLastName =
              lastName != null && lastName.trim().isNotEmpty;

          if (hasFirstName) {
            await prefs.setString('first_name', firstName);
            await prefs.setString('firstName', firstName);
          } else {
            await prefs.remove('first_name');
            await prefs.remove('firstName');
          }
          if (hasLastName) {
            await prefs.setString('last_name', lastName);
            await prefs.setString('lastName', lastName);
          } else {
            await prefs.remove('last_name');
            await prefs.remove('lastName');
          }
          final bool hasFullName = hasFirstName && hasLastName;
          await prefs.setBool('profile_complete', hasFullName);
          await prefs.setBool('profile_pending', !hasFullName);

          print("Token saved: $token");
          print("Phone saved: ${widget.phoneNumber}");
          print("First Name saved: $firstName");
          print("Last Name saved: $lastName");

          // Navigate
          if (hasFullName) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UpdateUserProfileScreen(token: token),
              ),
            );
          }
        } else {
          setState(() {
            errorMessage = translateText('User data or token is missing');
          });
        }
      } else {
        setState(() {
          errorMessage = extractMessage(
            response,
            fallback: 'Invalid or expired OTP',
          );
        });
        _clearOtpAndFocus();
      }
    } catch (e) {
      setState(() {
        errorMessage = extractErrorMessage(
          e,
          fallback: 'Invalid or expired OTP',
        );
      });
       _clearOtpAndFocus();   
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _fillFromCode(String code) {
    final digitsOnly = code.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return;

    final limited = digitsOnly.length > otpControllers.length
        ? digitsOnly.substring(0, otpControllers.length)
        : digitsOnly;

    _isProgrammaticFill = true;
    for (int i = 0; i < otpControllers.length; i++) {
      if (i < limited.length) {
        otpControllers[i].text = limited[i];
        otpControllers[i].selection = const TextSelection.collapsed(offset: 1);
      } else {
        otpControllers[i].clear();
      }
    }
    _isProgrammaticFill = false;

    setState(() {
      isContinueButtonEnabled = limited.length == otpControllers.length;
    });

    if (limited.length >= otpControllers.length) {
      FocusScope.of(context).unfocus();
    } else {
      final nextIndex = limited.length;
      FocusScope.of(context).requestFocus(focusNodes[nextIndex]);
    }

    _maybeSubmitOtp();
  }

  void _handleOtpInput(String value, int index) {
    if (_isProgrammaticFill) return;

    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      _fillFromCode(digitsOnly);
      return;
    }

    if (digitsOnly.isEmpty) {
      _isProgrammaticFill = true;
      otpControllers[index].clear();
      _isProgrammaticFill = false;
      if (index > 0) {
        FocusScope.of(context).requestFocus(focusNodes[index - 1]);
        otpControllers[index - 1].selection = TextSelection.fromPosition(
          TextPosition(offset: otpControllers[index - 1].text.length),
        );
      }
    } else {
      _isProgrammaticFill = true;
      otpControllers[index].text = digitsOnly;
      otpControllers[index].selection =
          TextSelection.collapsed(offset: digitsOnly.length);
      _isProgrammaticFill = false;

      if (index < otpControllers.length - 1) {
        FocusScope.of(context).requestFocus(focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    }

    setState(() {
      isContinueButtonEnabled =
          otpControllers.every((controller) => controller.text.isNotEmpty);
      if (digitsOnly.isNotEmpty) {
        errorMessage = '';
      }
    });

    _maybeSubmitOtp();
  }

  Future<void> _resendOtp() async {
    setState(() {
      isResendingOtp = true;
    });

    try {
      final response = await apiService.resendOtp(widget.phoneNumber);

      if (response['success'] == true) {
        _isProgrammaticFill = true;
        for (var controller in otpControllers) {
          controller.clear();
        }
        _isProgrammaticFill = false;

        FocusScope.of(context).requestFocus(focusNodes[0]);

        setState(() {
          errorMessage = '';
          isContinueButtonEnabled = false;
        });

        Fluttertoast.showToast(
          msg: translateText('OTP has been resent successfully'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
        );

        _startCountdown();
      } else {
        setState(() {
          errorMessage = extractMessage(
            response,
            fallback: 'Failed to resend OTP',
          );
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = extractErrorMessage(
          e,
          fallback: 'Failed to resend OTP',
        );
      });
    } finally {
      setState(() {
        isResendingOtp = false;
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
          remainingTime--; // Decrease the remaining time by 1 every second
        });
        // print('Remaining time: $remainingTime');  // Log to check timer progression
      } else {
        _timer?.cancel(); // Stop the timer when countdown reaches 0
        // print('Timer finished');  // Log when timer finishes
      }
    });
  }

  // Function to reset the countdown and go back to the LoginScreen when back is pressed
  void _onBackPressed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ), // Navigate back to LoginScreen
    );
  }

  @override
  void dispose() {
    // Dispose all the focus nodes to avoid memory leaks
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    for (final controller in otpControllers) {
      controller.dispose();
    }
    _timer?.cancel(); // Cancel the timer when disposing
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        automaticallyImplyLeading: false, // disable default
        leading: BackButton(
          color: Colors.white, // white arrow
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
          },
        ),
        // No title text
        title: null,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.starColor,
                AppColors.getStartedButton,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
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
                translateText("OTP Verification"),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Enter the OTP sent to *****${widget.phoneNumber.substring(6)}",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              RawKeyboardListener(
                focusNode:
                    FocusNode(), // Provide a focus node for keyboard listener
                onKey: (event) {
                  if (event is RawKeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    int index = focusNodes.indexWhere((node) => node.hasFocus);
                    if (index != -1) {
                      if (otpControllers[index].text.isNotEmpty) {
                        otpControllers[index].clear();
                      } else if (index > 0) {
                        otpControllers[index - 1].clear();
                        FocusScope.of(context)
                            .requestFocus(focusNodes[index - 1]);
                      }
                    }

                    // Recalculate after backspace clears
                    Future.microtask(() {
                      setState(() {
                        isContinueButtonEnabled = otpControllers
                            .every((controller) => controller.text.isNotEmpty);
                      });
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // children: List.generate(6, (index) {
                  //   return Container(
                  //     width: 40,
                  //     height: 50,
                  //     margin: const EdgeInsets.symmetric(horizontal: 5),
                  //     child: TextField(
                  //       controller: otpControllers[index],
                  //       focusNode: focusNodes[index],
                  //       keyboardType: TextInputType.number,
                  //       textAlign: TextAlign.center,
                  //       maxLength: 1,
                  //       maxLengthEnforcement: MaxLengthEnforcement.none,
                  //       autofillHints: index == 0
                  //           ? const [AutofillHints.oneTimeCode]
                  //           : null,
                  //       inputFormatters: [
                  //         FilteringTextInputFormatter.digitsOnly
                  //       ],
                  //       decoration: InputDecoration(
                  //         counterText: "",
                  //         border: OutlineInputBorder(
                  //           borderRadius: BorderRadius.circular(8),
                  //         ),
                  //       ),
                  //       onChanged: (value) => _handleOtpInput(value, index),
                  //     ),
                  //   );
                  // }),
                  children: List.generate(6, (index) {
  final bool filled = otpControllers[index].text.isNotEmpty;
  final bool focused = focusNodes[index].hasFocus;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 44,
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: filled ? AppColors.getStartedButton : Colors.white,                 // 👈 fill
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: focused
            ? AppColors.getStartedButton                                   // focus ring
            : (filled ? AppColors.getStartedButton : Colors.grey.shade400),
        width: focused ? 2 : 1.2,
      ),
      boxShadow: focused
          ? [BoxShadow(color: AppColors.getStartedButton.withOpacity(.25), blurRadius: 6)]
          : null,
    ),
    alignment: Alignment.center,
    child: TextField(
      controller: otpControllers[index],
      focusNode: focusNodes[index],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: filled ? Colors.white : Colors.black,                      // 👈 white digit
      ),
      cursorColor: filled ? Colors.white : Colors.black,                  // 👈 white cursor
      decoration: const InputDecoration(
        counterText: "",
        border: InputBorder.none,                                         // we draw border ourselves
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) => _handleOtpInput(value, index),
    ),
  );
}),

                ),
              ),

              if (errorMessage.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(errorMessage, style: TextStyle(color: Colors.red)),
              ],
              SizedBox(height: 20),
              // Continue Button
              ElevatedButton(
                onPressed:
                    isContinueButtonEnabled && !isLoading ? _verifyOtp : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: isContinueButtonEnabled && !isLoading
                      ? AppColors.starColor
                      : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(translateText("Login"),
                        style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 20),
              // Resend OTP
              GestureDetector(
                onTap: isResendingOtp || remainingTime > 0 ? null : _resendOtp,
                child: Text(
                  isResendingOtp
                      ? "Resending..."
                      : (remainingTime > 0
                          ? "Resend OTP in $remainingTime sec"
                          : "Resend OTP"),
                  style: TextStyle(
                    color:
                        remainingTime > 0 ? Colors.grey : AppColors.starColor,
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
}
