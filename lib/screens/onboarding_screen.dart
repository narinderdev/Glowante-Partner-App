import 'package:bloc_onboarding/screens/login_screen.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/user_defaults_manager.dart';
import 'package:flutter/material.dart';

const Color _onboardingGold = Color(0xFF9A7400);
const Color _onboardingDot = Color(0xFFE1B84A);

class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.description,
    required this.imageAsset,
    this.centerContent = false,
  });

  final String title;
  final String description;
  final String imageAsset;
  final bool centerContent;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  static const int _indicatorPageCount = 3;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: '',
      description: '',
      imageAsset: 'assets/images/iii1.png',
    ),
    OnboardingPage(
      title: 'Precision in Every Appointment',
      description:
          'Minimize gaps and maximize bookings with our smart scheduling engine designed for high-end establishments.',
      imageAsset: 'assets/images/iii2.png',
    ),
    OnboardingPage(
      title: "Master Your Salon's Rhythm",
      description:
          "Effortlessly coordinate your team, manage bookings, and elevate your salon's artistry from a single, intuitive workspace.",
      imageAsset: 'assets/images/iii3.png',
    ),
    OnboardingPage(
      title: 'Data-Driven Growth',
      description:
          'Gain deep insights into staff performance and customer loyalty to scale your beauty empire with confidence.',
      imageAsset: 'assets/images/gettingstarted.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    UserDefaultsManager.onboardingStatus(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _goNext() {
    if (_currentIndex == _pages.length - 1) {
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final page = _pages[index];
          final isLast = index == _pages.length - 1;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                page.imageAsset,
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x08000000),
                      Color(0x99000000),
                    ],
                    stops: [0.0, 0.46, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    children: [
                      Expanded(
                        child: page.centerContent
                            ? _CenteredIntroContent(page: page)
                            : _BottomIntroContent(page: page),
                      ),
                      if (isLast)
                        _GetStartedButton(onPressed: _finishOnboarding)
                      else
                        _OnboardingControls(
                          currentIndex: _currentIndex,
                          pageCount: _indicatorPageCount,
                          onNext: _goNext,
                          centerArrow: page.centerContent,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CenteredIntroContent extends StatelessWidget {
  const _CenteredIntroContent({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    if (page.title.isEmpty && page.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              translateText(page.title),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE7C55E),
                fontFamily: 'Georgia',
                fontFamilyFallback: ['Times New Roman', 'serif'],
                fontSize: 28,
                height: 1.14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              translateText(page.description),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFEFE7DD),
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomIntroContent extends StatelessWidget {
  const _BottomIntroContent({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    if (page.title.isEmpty && page.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translateText(page.title),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              translateText(page.description),
              style: const TextStyle(
                color: Color(0xFFF2F0EC),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.currentIndex,
    required this.pageCount,
    required this.onNext,
    required this.centerArrow,
  });

  final int currentIndex;
  final int pageCount;
  final VoidCallback onNext;
  final bool centerArrow;

  @override
  Widget build(BuildContext context) {
    if (centerArrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PageDots(currentIndex: currentIndex, pageCount: pageCount),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onNext,
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFEDE3D2),
              size: 28,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _PageDots(currentIndex: currentIndex, pageCount: pageCount),
        const Spacer(),
        _RoundNextButton(onPressed: onNext),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.currentIndex,
    required this.pageCount,
  });

  final int currentIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 8),
          width: isActive ? 30 : 9,
          height: isActive ? 9 : 10,
          decoration: BoxDecoration(
            color: isActive
                ? _onboardingDot
                : Colors.white.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _RoundNextButton extends StatelessWidget {
  const _RoundNextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: 72,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: _onboardingGold,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: const Color(0x66000000),
        ),
        child: const Icon(Icons.arrow_forward_rounded, size: 36),
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _onboardingGold,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: const Color(0x66000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              translateText('Get Started'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.arrow_forward_rounded, size: 26),
          ],
        ),
      ),
    );
  }
}
