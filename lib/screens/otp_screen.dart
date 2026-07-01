import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloc_onboarding/utils/api_service.dart'; // Import ApiService for OTP verification
import 'package:bloc_onboarding/utils/error_parser.dart';
import 'login_screen.dart'; // Import the LoginScreen
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../services/user_role_session.dart';
import 'role_selection_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final List<TextEditingController> otpControllers;
  late final List<FocusNode> otpFocusNodes;
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
  String _lastOtpText = '';

  // API service instance
  final ApiService apiService = ApiService();

  static const Color _otpGold = Color(0xFF8B6500);
  static const Color _otpGoldLight = Color(0xFFD0A23B);
  static const Color _otpInk = Color(0xFF1F1A16);
  static const Color _otpMuted = Color(0xFF776D64);
  static const Color _otpBorder = Color(0xFFE8DDD2);
  static const Color _otpFieldFill = Color(0xFFFBF7F4);

  String get _maskedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return widget.phoneNumber;
    return '•••••${digits.substring(digits.length - 4)}';
  }

  @override
  void initState() {
    super.initState();
    otpControllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    otpFocusNodes = List<FocusNode>.generate(6, (_) => FocusNode());

    // _otpInteractor = OTPInteractor();
    // _otpTextEditController = OTPTextEditController(
    //   codeLength: 6,
    //   otpInteractor: _otpInteractor,
    //   onCodeReceive: (code) {
    //     _fillFromCode(code);
    //   },
    // )..addListener(() {
    //     final currentText = _otpTextEditController.text;
    //     if (_isProgrammaticFill) {
    //       _lastOtpText = currentText;
    //       return;
    //     }
    //     if (currentText == _lastOtpText) return;
    //     _lastOtpText = currentText;
    //     _handleOtpCodeChanged(
    //       currentText,
    //       selectionOffset: _otpTextEditController.selection.baseOffset,
    //     );
    //   });
    _otpInteractor = OTPInteractor();

    _otpInteractor.getAppSignature().then((signature) {
      debugPrint('OTP app signature/hash: $signature');
    });

    _otpTextEditController = OTPTextEditController(
      codeLength: 6,
      otpInteractor: _otpInteractor,
      onCodeReceive: (code) {
        _fillFromCode(code);
      },
    );

    _otpTextEditController.startListenRetriever((sms) {
      final text = sms ?? '';

      // Example SMS:
      // Your Glowante login OTP is 908751. Valid for 10 min. Do not share.
      // GLOWANTE PERSONAL CARE PRIVATE LIMITED
      // LfDtnM4puKz

      final match = RegExp(r'\b\d{6}\b').firstMatch(text);
      return match?.group(0) ?? '';
    });

    _otpTextEditController.addListener(() {
      final currentText = _otpTextEditController.text;

      if (_isProgrammaticFill) {
        _lastOtpText = currentText;
        return;
      }

      if (currentText == _lastOtpText) return;

      _lastOtpText = currentText;

      _handleOtpCodeChanged(
        currentText,
        selectionOffset: _otpTextEditController.selection.baseOffset,
      );
    });
    for (final focusNode in otpFocusNodes) {
      focusNode.addListener(() {
        if (mounted) setState(() {});
      });
    }

    // Start the countdown timer immediately when the screen is initialized
    _startCountdown();
  }

  void _maybeSubmitOtp() {
    if (!mounted || isLoading || _autoSubmitScheduled) return;
    final String otp = otpControllers.map((c) => c.text).join();
    final bool allFilled = otp.length == otpControllers.length &&
        otpControllers.every((c) => c.text.isNotEmpty);
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
    for (final c in otpControllers) {
      c.clear();
    }
    _otpTextEditController.clear();
    _otpTextEditController.selection = const TextSelection.collapsed(offset: 0);
    _lastOtpText = '';
    _isProgrammaticFill = false;

    setState(() {
      isContinueButtonEnabled = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      FocusScope.of(context).requestFocus(otpFocusNodes.first);
      otpControllers.first.selection = const TextSelection.collapsed(offset: 0);
      setState(() {});
    });
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
        debugPrint("OTP Verified successfully");

        String? token = response['data']?['token'];
        Map<String, dynamic>? user = response['data']?['user'];

        if (token != null && user != null) {
          String? firstName = user['firstName'];
          String? lastName = user['lastName'];
          final int? userId = user['id'] is int
              ? user['id'] as int
              : int.tryParse('${user['id']}');

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_token', token);
          await prefs.setString('phone_number', widget.phoneNumber);
          if (userId != null) {
            await prefs.setInt('user_id', userId);
          } else {
            await prefs.remove('user_id');
          }
          await UserRoleSession.instance.persistUserRoles(user);
          await UserRoleSession.instance.persistUserSalons(user);
          await UserRoleSession.instance.persistUserBranches(user);
          await UserRoleSession.instance.persistUserPermissions(user);
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

          debugPrint("Token saved: $token");
          debugPrint("Phone saved: ${widget.phoneNumber}");
          debugPrint("First Name saved: $firstName");
          debugPrint("Last Name saved: $lastName");

          debugPrint(
            '[HomeReach] OTP verified. Resolving role entry for userId=$userId, phone=${widget.phoneNumber}',
          );
          if (!mounted) return;
          await RoleSelectionScreen.continueWithSingleRole(
            context: context,
            token: token,
            user: user,
            profileComplete: hasFullName,
          );
          return;

          // Role selection is intentionally skipped after login.
          // final selectableRoleCount = RoleSelectionScreen.selectableRoleCount(
          //   user,
          // );
          // if (selectableRoleCount <= 1) {
          //   await RoleSelectionScreen.continueWithSingleRole(
          //     context: context,
          //     token: token,
          //     user: user,
          //     profileComplete: hasFullName,
          //   );
          //   return;
          // }
          //
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => RoleSelectionScreen(
          //       token: token,
          //       user: user,
          //       profileComplete: hasFullName,
          //     ),
          //   ),
          // );
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

  void _setOtpDigits(
    String code, {
    bool updateInputController = false,
    int? selectionOffset,
  }) {
    final digitsOnly = code.replaceAll(RegExp(r'\D'), '');
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
    if (updateInputController && _otpTextEditController.text != limited) {
      _otpTextEditController.text = limited;
      _lastOtpText = limited;
      _otpTextEditController.selection = TextSelection.collapsed(
        offset: (selectionOffset ?? limited.length)
            .clamp(0, limited.length)
            .toInt(),
      );
    }
    _isProgrammaticFill = false;

    setState(() {
      isContinueButtonEnabled = limited.length == otpControllers.length;
      if (limited.isNotEmpty) {
        errorMessage = '';
      }
    });

    _maybeSubmitOtp();
  }

  void _handleOtpBoxChanged(int index, String value) {
    if (_isProgrammaticFill) return;
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      _setOtpDigits(digitsOnly, updateInputController: true);
      final nextIndex = digitsOnly.length >= otpControllers.length
          ? otpControllers.length - 1
          : digitsOnly.length;
      FocusScope.of(context).requestFocus(otpFocusNodes[nextIndex]);
      return;
    }

    _isProgrammaticFill = true;
    if (digitsOnly.isEmpty) {
      otpControllers[index].clear();
    } else {
      otpControllers[index].text = digitsOnly;
      otpControllers[index].selection =
          const TextSelection.collapsed(offset: 1);
    }
    final compactOtp =
        otpControllers.map((controller) => controller.text).join();
    _otpTextEditController.text = compactOtp;
    _lastOtpText = compactOtp;
    _isProgrammaticFill = false;

    setState(() {
      isContinueButtonEnabled =
          otpControllers.every((controller) => controller.text.isNotEmpty);
      if (digitsOnly.isNotEmpty) errorMessage = '';
    });
    if (digitsOnly.isEmpty) {
      FocusScope.of(context).requestFocus(otpFocusNodes[index]);
      otpControllers[index].selection =
          const TextSelection.collapsed(offset: 0);
      return;
    }
    if (index < otpFocusNodes.length - 1) {
      FocusScope.of(context).requestFocus(otpFocusNodes[index + 1]);
    } else {
      otpFocusNodes[index].unfocus();
    }
    _maybeSubmitOtp();
  }

  void _fillFromCode(String code) {
    if (code.replaceAll(RegExp(r'\D'), '').isEmpty) return;
    _setOtpDigits(code, updateInputController: true);
  }

  void _handleOtpCodeChanged(
    String value, {
    int? selectionOffset,
  }) {
    _setOtpDigits(
      value,
      updateInputController: true,
      selectionOffset: selectionOffset,
    );
  }

  int _focusedOtpIndex() {
    for (int i = 0; i < otpFocusNodes.length; i++) {
      if (otpFocusNodes[i].hasFocus) return i;
    }
    return 0;
  }

  void _focusOtpDigit(int index) {
    if (isLoading) return;
    final safeIndex = index.clamp(0, otpControllers.length - 1).toInt();
    FocusScope.of(context).requestFocus(otpFocusNodes[safeIndex]);
    otpControllers[safeIndex].selection = TextSelection.collapsed(
      offset: otpControllers[safeIndex].text.length,
    );
    setState(() {});
  }

  Future<void> _resendOtp() async {
    setState(() {
      isResendingOtp = true;
    });

    try {
      final response = await apiService.resendOtp(widget.phoneNumber);

      if (response['success'] == true) {
        if (!mounted) return;
        _isProgrammaticFill = true;
        for (var controller in otpControllers) {
          controller.clear();
        }
        _otpTextEditController.clear();
        _lastOtpText = '';
        _isProgrammaticFill = false;

        FocusScope.of(context).requestFocus(otpFocusNodes.first);

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
    debugPrint("Starting countdown...");

    // Cancel the previous timer if it exists
    _timer?.cancel();

    // Reset the remaining time to 30 seconds
    setState(() {
      remainingTime = 30;
    });
    debugPrint("Remaining time set to: $remainingTime"); // Log initial time set

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

  @override
  void dispose() {
    for (final controller in otpControllers) {
      controller.dispose();
    }
    for (final focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    _otpTextEditController.stopListen();
    _otpTextEditController.dispose();
    _timer?.cancel(); // Cancel the timer when disposing
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final otpBoxWidth = ((screenWidth - 80) / 6).clamp(38.0, 48.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: false, // disable default
        leading: BackButton(
          color: _otpGold,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
          },
        ),
        title: Text(
          translateText("OTP Verification"),
          style: const TextStyle(
            color: _otpGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _otpBorder),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _otpBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5EAD2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: _otpGold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        translateText("Verify Your Number"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _otpInk,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${translateText("Enter the OTP sent to")} $_maskedPhone',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _otpMuted,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => FocusScope.of(context)
                            .requestFocus(otpFocusNodes[_focusedOtpIndex()]),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            final bool filled =
                                otpControllers[index].text.isNotEmpty;
                            final bool focused =
                                otpFocusNodes[index].hasFocus && !isLoading;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: otpBoxWidth,
                              height: 54,
                              decoration: BoxDecoration(
                                color: filled ? _otpGold : _otpFieldFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: focused || filled
                                      ? _otpGoldLight
                                      : _otpBorder,
                                  width: focused ? 1.7 : 1.1,
                                ),
                                boxShadow: focused
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x268B6500),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              // child: TextField(
                              //   controller: otpControllers[index],
                              //   focusNode: otpFocusNodes[index],
                              //   enabled: !isLoading,
                              //   keyboardType: TextInputType.number,
                              //   textInputAction: index == 5
                              //       ? TextInputAction.done
                              //       : TextInputAction.next,
                              //   maxLength: 1,
                              //   autofillHints: index == 0
                              //       ? const [AutofillHints.oneTimeCode]
                              //       : null,
                              //   inputFormatters: [
                              //     FilteringTextInputFormatter.digitsOnly,
                              //       LengthLimitingTextInputFormatter(1),
                              //   ],
                              //   textAlign: TextAlign.center,
                              //   style: TextStyle(
                              //     fontSize: 20,
                              //     fontWeight: FontWeight.w800,
                              //     color: filled ? Colors.white : _otpInk,
                              //   ),
                              //   cursorColor: filled ? Colors.white : _otpGold,
                              //   decoration: const InputDecoration(
                              //     counterText: '',
                              //     border: InputBorder.none,
                              //     enabledBorder: InputBorder.none,
                              //     focusedBorder: InputBorder.none,
                              //     disabledBorder: InputBorder.none,
                              //     isCollapsed: true,
                              //     contentPadding: EdgeInsets.zero,
                              //   ),
                              //   onTap: () => _focusOtpDigit(index),
                              //   onChanged: (value) =>
                              //       _handleOtpBoxChanged(index, value),
                              //   onSubmitted: (_) {
                              //     if (index < 5) {
                              //       FocusScope.of(context)
                              //           .requestFocus(otpFocusNodes[index + 1]);
                              //       return;
                              //     }
                              //     if (isContinueButtonEnabled && !isLoading) {
                              //       _verifyOtp();
                              //     }
                              //   },
                              // ),
                              child: KeyboardListener(
                                focusNode: FocusNode(skipTraversal: true),
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace &&
                                      otpControllers[index].text.isEmpty &&
                                      index > 0) {
                                    otpControllers[index - 1].clear();

                                    final compactOtp = otpControllers
                                        .map((controller) => controller.text)
                                        .join();

                                    _otpTextEditController.text = compactOtp;
                                    _lastOtpText = compactOtp;

                                    setState(() {
                                      isContinueButtonEnabled =
                                          otpControllers.every((controller) =>
                                              controller.text.isNotEmpty);
                                    });

                                    FocusScope.of(context)
                                        .requestFocus(otpFocusNodes[index - 1]);
                                    otpControllers[index - 1].selection =
                                        const TextSelection.collapsed(
                                            offset: 0);
                                  }
                                },
                                child: TextField(
                                  controller: otpControllers[index],
                                  focusNode: otpFocusNodes[index],
                                  enabled: !isLoading,
                                  keyboardType: TextInputType.number,
                                  textInputAction: index == 5
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  autofillHints: index == 0
                                      ? const [AutofillHints.oneTimeCode]
                                      : null,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlign: TextAlign.center,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: filled ? Colors.white : _otpInk,
                                  ),
                                  cursorColor: filled ? Colors.white : _otpGold,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    isDense: true,
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onTap: () => _focusOtpDigit(index),
                                  onChanged: (value) =>
                                      _handleOtpBoxChanged(index, value),
                                  onSubmitted: (_) {
                                    if (index < 5) {
                                      FocusScope.of(context).requestFocus(
                                          otpFocusNodes[index + 1]);
                                      return;
                                    }

                                    if (isContinueButtonEnabled && !isLoading) {
                                      _verifyOtp();
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFD2CE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isContinueButtonEnabled && !isLoading
                              ? _verifyOtp
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _otpGold,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFD8CEC5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0x338B6500),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  translateText("Verify & Continue")
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: isResendingOtp || remainingTime > 0
                            ? null
                            : _resendOtp,
                        child: Text(
                          isResendingOtp
                              ? translateText("Resending...")
                              : (remainingTime > 0
                                  ? '${translateText("Resend OTP in")} $remainingTime ${translateText("sec")}'
                                  : translateText("Resend OTP")),
                          style: TextStyle(
                            color: remainingTime > 0 ? _otpMuted : _otpGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _otpBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: _otpGold,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your OTP is used only to verify your login securely.',
                          style: TextStyle(
                            color: _otpMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
