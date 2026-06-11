import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/auth/auth_event.dart';
import 'package:bloc_onboarding/bloc/auth/auth_state.dart';
import 'package:bloc_onboarding/screens/otp_screen.dart';
import 'package:bloc_onboarding/services/push_notification_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const _loginGold = Color(0xFFB88422);
const _loginDeepGold = Color(0xFF8B6500);
const _loginInk = Color(0xFF4B4038);
const _loginBorder = Color(0xFFE8D9BC);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isContinueEnabled = false;
  final String _countryCode = '+91';
  String? _errorMessage;
  String? _lastSnackMessage;
  DateTime? _lastSnackTime;
  static const Duration _snackCooldown = Duration(seconds: 2);
  @override
  void initState() {
    super.initState();
    phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    phoneController.removeListener(_handlePhoneChanged);
    _phoneFocusNode.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _handlePhoneChanged() {
    final phone = phoneController.text.trim();
    final bool isValid = RegExp(r'^[6-9]\d{9}$').hasMatch(phone) &&
        !RegExp(r'^0+$').hasMatch(phone);
    if (isValid != _isContinueEnabled) {
      setState(() => _isContinueEnabled = isValid);
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final phoneNumber = phoneController.text.trim();

    // ✅ Validation checks
    if (phoneNumber.isEmpty ||
        phoneNumber.length != 10 ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phoneNumber) ||
        RegExp(r'^0+$').hasMatch(phoneNumber)) {
      setState(() {
        _errorMessage =
            translateText('Please enter a valid 10-digit mobile number');
      });
      return;
    }

    // ✅ clear error if valid
    setState(() {
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String? deviceToken;
    try {
      deviceToken = await PushNotificationService.instance.getToken();
      debugPrint('FCM Device Token: $deviceToken');
    } catch (error) {
      debugPrint('Unable to fetch FCM token: $error');
    }

    if (!mounted) return;
    context.read<AuthBloc>().add(
          AuthLoginEvent(
            phoneNumber: phoneNumber,
            deviceToken: deviceToken,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFFFF9F3),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFFFF9F3),
        resizeToAvoidBottomInset: false,
        body: BlocListener<AuthBloc, AuthState>(
          listener: _handleAuthState,
          child: Stack(
            children: [
              const Positioned.fill(child: _LoginBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final compact = height < 760;
                    final shouldScroll = height < 620;
                    final topGap = compact ? 2.0 : 8.0;
                    final heroGap = compact ? 12.0 : 16.0;
                    final sectionGap = compact ? 13.0 : 18.0;
                    final inputButtonGap = compact ? 22.0 : 28.0;
                    final quoteGap = compact ? 12.0 : 16.0;
                    final verticalPadding = compact ? 10.0 : 16.0;
                    final topChildren = <Widget>[
                      SizedBox(height: topGap),
                      _buildHeroHeader(compact: compact),
                      SizedBox(height: heroGap),
                      _LoginFeatureCard(compact: compact),
                      SizedBox(height: sectionGap),
                      _buildPhoneSection(compact: compact),
                      SizedBox(height: inputButtonGap),
                      _buildLoginButton(compact: compact),
                    ];
                    final middleContent = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuote(compact: compact),
                        SizedBox(height: quoteGap),
                        _OrnamentDivider(width: compact ? 150 : 168),
                      ],
                    );
                    final scrollChildren = <Widget>[
                      ...topChildren,
                      SizedBox(height: quoteGap),
                      middleContent,
                    ];

                    final column = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: shouldScroll
                          ? [
                              ...scrollChildren,
                              SizedBox(height: compact ? 18 : 24),
                              _buildFooter(compact: compact),
                            ]
                          : [
                              ...topChildren,
                              Expanded(
                                child: Center(child: middleContent),
                              ),
                              _buildFooter(compact: compact),
                            ],
                    );

                    final content = Padding(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        verticalPadding,
                        22,
                        verticalPadding,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: shouldScroll
                              ? column
                              : SizedBox(
                                  height: height - (verticalPadding * 2),
                                  child: column,
                                ),
                        ),
                      ),
                    );

                    if (shouldScroll) {
                      return SingleChildScrollView(child: content);
                    }
                    return content;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAuthState(BuildContext context, AuthState state) {
    if (state is AuthLoginSuccess) {
      final dynamic rawPhone = state.response['phoneNumber'];
      final String phoneNumber = (rawPhone is String && rawPhone.isNotEmpty)
          ? rawPhone
          : phoneController.text.trim();
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phoneNumber: phoneNumber),
        ),
      );
    }

    if (state is AuthError) {
      setState(() => _isLoading = false);
      final now = DateTime.now();
      final bool shouldShow = _lastSnackMessage != state.message ||
          _lastSnackTime == null ||
          now.difference(_lastSnackTime!) > _snackCooldown;
      if (shouldShow) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message)));
        _lastSnackMessage = state.message;
        _lastSnackTime = now;
      }
    }
  }

  Widget _buildHeroHeader({required bool compact}) {
    return Column(
      children: [
        Image.asset(
          'assets/images/finallogo.png',
          height: compact ? 58 : 66,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Image.asset('assets/images/logo.png', height: compact ? 58 : 66),
        ),
        SizedBox(height: compact ? 12 : 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            translateText('Workspace Entry'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _loginInk,
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: compact ? 28 : 31,
              height: 0.98,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: compact ? 9 : 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            translateText('THE DIGITAL HEART OF YOUR SALON'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _loginDeepGold,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? 2.9 : 3.3,
            ),
          ),
        ),
        SizedBox(height: compact ? 9 : 13),
        _OrnamentDivider(width: compact ? 148 : 170),
      ],
    );
  }

  Widget _buildPhoneSection({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText('MOBILE NUMBER'),
          style: TextStyle(
            color: Color(0xFF6E6259),
            fontSize: compact ? 10.5 : 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: compact ? 54 : 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _errorMessage == null
                  ? _loginBorder
                  : const Color(0xFFD14D3F),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0FFFFFFF),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  'assets/images/flag.png',
                  width: 28,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _countryCode,
                style: const TextStyle(
                  color: _loginInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                width: 1.4,
                height: 28,
                margin: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
                color: const Color(0xFFE7D8BF),
              ),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  focusNode: _phoneFocusNode,
                  cursorColor: const Color(0xFF8B6500),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(
                    color: _loginInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: translateText('Enter mobile number'),
                    hintStyle: const TextStyle(
                      color: Color(0xFFB3AAA2),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Color(0xFFC0392B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginButton({required bool compact}) {
    return SizedBox(
      height: compact ? 66 : 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: (_isContinueEnabled && !_isLoading)
              ? const Color(0xFF8B6500)
              : AppColors.starColor.withValues(alpha: 0.45),
          border: Border.all(color: AppColors.starColor, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x268B6500),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (_isContinueEnabled && !_isLoading) ? _submit : null,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            overlayColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.08),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        translateText('Login'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: const Offset(50, 0),
                        child: const Center(
                          child: Icon(Icons.arrow_forward_rounded, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildQuote({required bool compact}) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Text(
          translateText(
            "Elevate your salon's potential with\nseamless team management\nand effortless bookings.",
          ),
          textAlign: TextAlign.center,
          textWidthBasis: TextWidthBasis.parent,
          style: TextStyle(
            color: const Color(0xFF75695F),
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
            fontStyle: FontStyle.italic,
            fontSize: compact ? 15.5 : 17.5,
            height: compact ? 1.34 : 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter({required bool compact}) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            translateText('Professional Access Only  •  © 2024 Glowante'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF8B8580),
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFeatureCard extends StatelessWidget {
  const _LoginFeatureCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: compact ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _loginBorder, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14B88422),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _FeatureItem(
              icon: Icons.auto_awesome_rounded,
              label: translateText('Shine bright'),
              compact: compact,
            ),
          ),
          _FeatureDivider(compact: compact),
          Expanded(
            child: _FeatureItem(
              icon: Icons.eco_outlined,
              label: translateText('Feel radiant'),
              compact: compact,
            ),
          ),
          _FeatureDivider(compact: compact),
          Expanded(
            child: _FeatureItem(
              icon: Icons.favorite_rounded,
              label: translateText('Choose Glowante'),
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: compact ? 42 : 46,
          width: compact ? 42 : 46,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1D6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _loginGold, size: compact ? 20 : 22),
        ),
        SizedBox(height: compact ? 7 : 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: _loginInk,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.2,
      height: compact ? 58 : 66,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFEADCC6),
    );
  }
}

class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(child: _GoldLine()),
          Container(
            width: 30,
            alignment: Alignment.center,
            child: const Text(
              '✦',
              style: TextStyle(
                color: Color(0xFFD1A332),
                fontSize: 24,
                height: 1,
              ),
            ),
          ),
          const Expanded(child: _GoldLine()),
        ],
      ),
    );
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00D1A332),
            Color(0xFFD1A332),
            Color(0x00D1A332),
          ],
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFBF7),
            Color(0xFFFFF2E7),
            Color(0xFFFFF8F1),
            Color(0xFFFFE3BD),
          ],
          stops: [0.0, 0.42, 0.68, 1.0],
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(
              child: CustomPaint(painter: _LoginBackgroundPainter())),
          Positioned(
              top: 52, left: 58, child: _Sparkle(size: 8, opacity: 0.55)),
          Positioned(
              top: 118, left: -4, child: _Sparkle(size: 30, opacity: 0.42)),
          Positioned(
              bottom: 70, left: -8, child: _Sparkle(size: 18, opacity: 0.42)),
          Positioned(
              bottom: 238, right: -4, child: _Sparkle(size: 20, opacity: 0.45)),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size,
        shadows: const [
          Shadow(color: Color(0x99FFFFFF), blurRadius: 16),
          Shadow(color: Color(0x44D1A332), blurRadius: 24),
        ],
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  const _LoginBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void drawGlow({
      required Offset center,
      required double radius,
      required Color color,
      required double opacity,
    }) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    drawGlow(
      center: Offset(size.width * 0.18, size.height * 0.12),
      radius: size.width * 0.62,
      color: const Color(0xFFFFFFFF),
      opacity: 0.72,
    );
    drawGlow(
      center: Offset(size.width * 0.92, size.height * 0.34),
      radius: size.width * 0.7,
      color: const Color(0xFFFFE4CF),
      opacity: 0.5,
    );
    drawGlow(
      center: Offset(size.width * 0.86, size.height * 0.82),
      radius: size.width * 0.68,
      color: const Color(0xFFFFB66D),
      opacity: 0.42,
    );

    final lowerRect =
        Rect.fromLTWH(0, size.height * 0.76, size.width, size.height * 0.24);
    final bottomWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x00FFE4BC),
          const Color(0xFFFFE2C0).withValues(alpha: 0.14),
          const Color(0xFFFFC07A).withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(lowerRect);
    canvas.drawRect(lowerRect, bottomWash);

    final rightSheet = Path()
      ..moveTo(size.width * 0.58, size.height * 0.82)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.78,
        size.width * 0.88,
        size.height * 0.78,
        size.width * 1.12,
        size.height * 0.72,
      )
      ..lineTo(size.width * 1.12, size.height)
      ..lineTo(size.width * 0.58, size.height)
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.95,
        size.width * 0.78,
        size.height * 0.88,
        size.width * 0.58,
        size.height * 0.82,
      )
      ..close();
    final rightSheetPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0x00FFC27A),
          const Color(0xFFFFC27A).withValues(alpha: 0.26),
          const Color(0xFFFFA94E).withValues(alpha: 0.46),
        ],
      ).createShader(
        Rect.fromLTWH(
          size.width * 0.48,
          size.height * 0.7,
          size.width * 0.58,
          size.height * 0.3,
        ),
      );
    canvas.drawPath(rightSheet, rightSheetPaint);

    void drawRibbon({
      required double y,
      required double stroke,
      required double opacity,
      required double lift,
      required double rightLift,
      Color color = const Color(0xFFFFBE72),
    }) {
      final ribbonPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0x00FFFFFF),
            color.withValues(alpha: opacity * 0.18),
            color.withValues(alpha: opacity),
            const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.48),
          ],
          stops: const [0.0, 0.38, 0.76, 1.0],
        ).createShader(Rect.fromLTWH(0, y - 90, size.width, 180))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(-size.width * 0.2, y + 18)
        ..cubicTo(
          size.width * 0.2,
          y - lift,
          size.width * 0.56,
          y + lift * 0.26,
          size.width * 0.86,
          y - rightLift,
        )
        ..quadraticBezierTo(
          size.width * 1.03,
          y - rightLift - 26,
          size.width * 1.22,
          y - rightLift - 34,
        );
      canvas.drawPath(path, ribbonPaint);
    }

    drawRibbon(
      y: size.height * 0.925,
      stroke: 50,
      opacity: 0.2,
      lift: 30,
      rightLift: 116,
    );
    drawRibbon(
      y: size.height * 0.955,
      stroke: 42,
      opacity: 0.18,
      lift: 28,
      rightLift: 92,
      color: const Color(0xFFFFCE91),
    );
    drawRibbon(
      y: size.height * 0.99,
      stroke: 34,
      opacity: 0.16,
      lift: 24,
      rightLift: 70,
      color: const Color(0xFFFFDDB2),
    );

    void drawHighlight(double y, double rightLift, double opacity) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            const Color(0xFFFFFFFF).withValues(alpha: opacity),
            const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.7),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.42, 0.72, 1.0],
        ).createShader(Rect.fromLTWH(0, y - 30, size.width, 70))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(-size.width * 0.12, y + 10)
        ..cubicTo(
          size.width * 0.2,
          y - 16,
          size.width * 0.58,
          y + 20,
          size.width * 0.88,
          y - rightLift,
        )
        ..quadraticBezierTo(
          size.width * 1.03,
          y - rightLift - 22,
          size.width * 1.16,
          y - rightLift - 24,
        );
      canvas.drawPath(path, paint);
    }

    drawHighlight(size.height * 0.925, 98, 0.52);
    drawHighlight(size.height * 0.982, 62, 0.42);

    final rightGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC178).withValues(alpha: 0.34),
          const Color(0xFFFFE2BF).withValues(alpha: 0.16),
          const Color(0x00FFC178),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 1.02, size.height * 0.86),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.86),
      size.width * 0.5,
      rightGlow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
