import 'package:flutter/material.dart';
import 'package:bloc_onboarding/screens/login_screen.dart';
import 'package:bloc_onboarding/utils/user_defaults_manager.dart';

class OnboardingPage {
  final String title;
  final String imageAsset;

  OnboardingPage({required this.title, required this.imageAsset});
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<OnboardingPage> pages = [
    OnboardingPage(
      title: "Discover and book luxurious salon experiences near you",
      imageAsset: "assets/images/on_boarding_1.png",
    ),
    OnboardingPage(
      title: "Discover and book luxurious salon experiences near you",
      imageAsset: "assets/images/on_boarding_2.png",
    ),
    OnboardingPage(
      title: "Get started on your journey to a better you – beauty, wellness, and more",
      imageAsset: "assets/images/on_boarding_3.png",
    ),
  ];

  int currentIndex = 0;
  double imageScale = 1.0;
  double floatOffset = 0;
  bool animate = true;

  @override
  void initState() {
    super.initState();
    _startImageAnimation();
  }

  void _startImageAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        animate = true;
        imageScale = 1.0;
        floatOffset = -10;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
                animate = false;
                imageScale = 0.95;
                floatOffset = 10;
              });
              _startImageAnimation();
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: animate ? 1 : 0.2,
                    duration: const Duration(milliseconds: 800),
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      transform: Matrix4.identity()
                        ..translate(0.0, floatOffset)
                        ..scale(imageScale),
                      child: Image.asset(page.imageAsset, fit: BoxFit.cover),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: animate ? 1 : 0,
                            child: Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (index == pages.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 800),
                                opacity: animate ? 1 : 0,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      UserDefaultsManager.onboardingStatus(true);
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>  LoginScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text(
                                      "Get Started",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (index) {
                final isActive = index == currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: isActive ? 30 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.orange : Colors.white38,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
