import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../utils/colors.dart';

/// Non-dismissible modal — shown over whatever screen the user is
/// currently on when AppUpdateService.check() finds the installed
/// version below Remote Config's min_supported_version. No barrier tap,
/// no back button, and nothing ever pops it: the only way out is
/// "Update Now".
class UpdateRequiredDialog extends StatelessWidget {
  const UpdateRequiredDialog({
    super.key,
    required this.storeUrl,
    required this.message,
  });

  final String storeUrl;
  final String message;

  static Future<void> show(
    BuildContext context, {
    required String storeUrl,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: UpdateRequiredDialog(storeUrl: storeUrl, message: message),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                size: 56,
                color: AppColors.starColor,
              ),
              const SizedBox(height: 16),
              Text(
                translateText('Update Required'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    translateText('Update Now'),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
