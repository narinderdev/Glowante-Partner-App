import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloc_onboarding/screens/onboarding_screen.dart';
import 'package:bloc_onboarding/screens/bottom_nav.dart';

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
    await Future.delayed(const Duration(milliseconds: 1000));
    _checkLoginStatus(); // 👈 check token after animation
  }

  Future<void> startSplashAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => isCircleExpanded = true);

    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      flowerScale = 1.8;
      flowerOpacity = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 800));
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
    String? token = prefs.getString('user_token');

    if (token != null && token.isNotEmpty) {
      // ✅ Already logged in → go to BottomNav
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 0)),
      );
    } else {
      // ❌ Not logged in → go to Onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
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
                  "assets/images/splash_logo.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
