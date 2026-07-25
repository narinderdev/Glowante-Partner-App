import 'package:flutter/material.dart';
import '../utils/colors.dart';

// The only page-loader message in the app — changing what the user sees
// while any screen loads means editing this one line, not a call site.
const String _kAppLoaderMessage = 'Loading...please wait';

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
      message: _kAppLoaderMessage,
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
    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );

    if (!isPage) return spinner;

    final badgeSize = size + 46;
    final text = message?.trim() ?? '';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(child: spinner),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 18),
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
