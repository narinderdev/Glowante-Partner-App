import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

class AppLoader extends StatelessWidget {
  const AppLoader._({
    super.key,
    required this.size,
    required this.strokeWidth,
    required this.color,
    this.message,
    required this.isPage,
  });

  factory AppLoader.page({
    Key? key,
    double size = 30,
  }) {
    return AppLoader._(
      key: key,
      size: size,
      strokeWidth: 3,
      color: AppColors.starColor,
      message: translateText('Loading...please wait'),
      isPage: true,
    );
  }

  factory AppLoader.inline({
    Key? key,
    double size = 18,
    double strokeWidth = 2.2,
    Color color = Colors.white,
  }) {
    return AppLoader._(
      key: key,
      size: size,
      strokeWidth: strokeWidth,
      color: color,
      isPage: false,
    );
  }

  final double size;
  final double strokeWidth;
  final Color color;
  final String? message;
  final bool isPage;

  @override
  Widget build(BuildContext context) {
    final loader = _AppIconLoader(size: size);

    if (!isPage) return loader;

    final text = message?.trim() ?? '';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loader,
          if (text.isNotEmpty) ...[
            const SizedBox(height: 30),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6E6259),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppIconLoader extends StatefulWidget {
  const _AppIconLoader({required this.size});

  final double size;

  @override
  State<_AppIconLoader> createState() => _AppIconLoaderState();
}

class _AppIconLoaderState extends State<_AppIconLoader>
    with SingleTickerProviderStateMixin {
  static const _iconPaths = [
    'assets/images/icons/hairdresser.png',
    'assets/images/icons/makeup.png',
    'assets/images/icons/nail-polish.png',
  ];

  late final AnimationController _controller;
  late final Animation<double> _rotation;
  int _iconIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: math.pi / 4).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: math.pi / 4, end: -math.pi / 4).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -math.pi / 4, end: 0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 1,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _iconIndex = (_iconIndex + 1) % _iconPaths.length);
      _controller.forward(from: 0);
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualSize = widget.size + 28;

    return SizedBox.square(
      dimension: visualSize,
      child: AnimatedBuilder(
        animation: _rotation,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Image.asset(
            _iconPaths[_iconIndex],
            key: ValueKey(_iconPaths[_iconIndex]),
            width: visualSize,
            height: visualSize,
            fit: BoxFit.contain,
          ),
        ),
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotation.value,
            child: child,
          );
        },
      ),
    );
  }
}
