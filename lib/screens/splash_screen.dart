import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloc_onboarding/screens/onboarding_screen.dart';
import 'package:bloc_onboarding/screens/bottom_nav.dart';
import 'package:bloc_onboarding/screens/stylist_bottom_nav.dart';
import 'package:bloc_onboarding/screens/UpdateProfileScreen.dart';
import '../services/auth_session_manager.dart';
import '../services/stylist_branch_selection.dart';
import '../services/token_expiration_service.dart';
import '../services/user_role_session.dart';
import '../utils/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isCircleExpanded = false;
  bool showGlowanteLogo = false;

  double flowerScale = 1.0;
  double flowerOpacity = 1.0;
  double logoOpacity = 0.0;
  double logoOffset = 100.0;

  @override
  void initState() {
    super.initState();
    startSplashSequence();
  }

  void startSplashSequence() async {
    await startSplashAnimation();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _checkLoginStatus(); // 👈 check token after animation
  }

  Future<void> startSplashAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => isCircleExpanded = true);

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      flowerScale = 1.8;
      flowerOpacity = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      showGlowanteLogo = true;
      logoOpacity = 1.0;
      logoOffset = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 1000));
  }

  // 👇 NEW: check login status
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("user_token");

    if (token != null && token.isNotEmpty) {
      if (TokenExpirationService.isTokenExpired(token)) {
        await AuthSessionManager.instance
            .forceLogout(reason: "session_expired");
        return;
      }

      final bool storedFlag = prefs.getBool('profile_complete') ?? false;
      final String? storedFirstName =
          prefs.getString('first_name') ?? prefs.getString('firstName');
      final String? storedLastName =
          prefs.getString('last_name') ?? prefs.getString('lastName');
      final bool derivedComplete =
          (storedFirstName?.trim().isNotEmpty ?? false) &&
              (storedLastName?.trim().isNotEmpty ?? false);
      final bool profileComplete = storedFlag || derivedComplete;
      final bool usesStylistShell =
          await UserRoleSession.instance.usesStylistShell();

      if (!mounted) return;
      if (profileComplete) {
        if (usesStylistShell) {
          await _logStylistBranchResponse();
        }
        await prefs.setBool('profile_complete', true);
        await prefs.setBool('profile_pending', false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => usesStylistShell
                ? const StylistBottomNav(tabIndex: 0)
                : const BottomNav(tabIndex: 2),
          ),
        );
      } else {
        await prefs.setBool('profile_pending', true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateUserProfileScreen(
              token: token,
              isStylist: usesStylistShell,
            ),
          ),
        );
      }
    } else {
      if (!mounted) return;
      // ❌ Not logged in → go to Onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  Future<int?> _resolveStylistBranchId() async {
    final selected = await StylistBranchSelectionStore.load();
    if (selected.branchId != null) {
      return selected.branchId;
    }

    final userBranches = await UserRoleSession.instance.loadUserBranches();
    for (final rawEntry in userBranches) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final rawBranch = entry['branch'];
      if (rawBranch is! Map) continue;

      final branch = Map<String, dynamic>.from(rawBranch);
      final branchId = _asInt(branch['id']);
      if (branchId != null) {
        return branchId;
      }
    }

    return null;
  }

  Future<void> _logStylistBranchResponse() async {
    try {
      final branchId = await _resolveStylistBranchId();
      if (branchId == null) {
        debugPrint('[SplashStylistBranch] No branch id found before home');
        return;
      }

      debugPrint(
        '[SplashStylistBranch] Calling branch details API before home for branchId=$branchId',
      );
      final response = await ApiService().getBranchDetail(branchId);
      debugPrint('[SplashStylistBranch] Response: $response');
    } catch (e) {
      debugPrint('[SplashStylistBranch] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 1500),
            width: isCircleExpanded ? screenWidth * 3 : 200,
            height: isCircleExpanded ? screenWidth * 3 : 200,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
          AnimatedOpacity(
            opacity: flowerOpacity,
            duration: const Duration(milliseconds: 1000),
            child: Center(
              child: Transform.scale(
                scale: flowerScale,
                child: Image.asset(
                  "assets/images/flower.png",
                  width: 150,
                  height: 150,
                ),
              ),
            ),
          ),
          if (showGlowanteLogo)
            AnimatedOpacity(
              opacity: logoOpacity,
              duration: const Duration(milliseconds: 1500),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                transform: Matrix4.translationValues(0, logoOffset, 0),
                width: screenWidth * 0.6,
                child: Image.asset(
                  "assets/images/finallogo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    "assets/images/splash_logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
