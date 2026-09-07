import 'package:flutter/material.dart';

import '../utils/colors.dart';
import 'app_loader.dart';

class LogoutOptionsDialog extends StatelessWidget {
  const LogoutOptionsDialog({
    super.key,
    required this.title,
    required this.message,
    required this.currentDeviceLabel,
    required this.allDevicesLabel,
    required this.cancelLabel,
    required this.isLoggingOut,
    required this.loggingOutAllDevices,
    required this.onCurrentDevice,
    required this.onAllDevices,
    required this.onCancel,
  });

  final String title;
  final String message;
  final String currentDeviceLabel;
  final String allDevicesLabel;
  final String cancelLabel;
  final bool isLoggingOut;
  final bool? loggingOutAllDevices;
  final VoidCallback onCurrentDevice;
  final VoidCallback onAllDevices;
  final VoidCallback onCancel;

  static const Color _surface = Color(0xFFFBFAF8);
  static const Color _softGold = Color(0xFFF5EAD2);
  static const Color _border = Color(0xFFE8DED6);
  static const Color _ink = Color(0xFF201A17);
  static const Color _muted = Color(0xFF736961);
  static const Color _danger = Color(0xFF9F261F);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: _softGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.starColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            _LogoutActionButton(
              label: currentDeviceLabel,
              icon: Icons.phone_iphone_rounded,
              isPrimary: true,
              isBusy: isLoggingOut && loggingOutAllDevices == false,
              isDisabled: isLoggingOut,
              onPressed: onCurrentDevice,
            ),
            const SizedBox(height: 10),
            _LogoutActionButton(
              label: allDevicesLabel,
              icon: Icons.devices_other_rounded,
              isPrimary: false,
              isBusy: isLoggingOut && loggingOutAllDevices == true,
              isDisabled: isLoggingOut,
              onPressed: onAllDevices,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: isLoggingOut ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  disabledForegroundColor: const Color(0xFFB7AEA6),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutActionButton extends StatelessWidget {
  const _LogoutActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.isBusy,
    required this.isDisabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isBusy;
  final bool isDisabled;
  final VoidCallback onPressed;

  static const Color _outlineFill = Color(0xFFFFFEFC);
  static const Color _outlineDisabled = Color(0xFFB7AEA6);

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? Colors.white : LogoutOptionsDialog._danger;
    final loaderColor = isPrimary ? Colors.white : AppColors.starColor;
    final content = isBusy
        ? AppLoader.inline(size: 18, strokeWidth: 2, color: loaderColor)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.starColor,
            disabledBackgroundColor: const Color(0x998B6500),
            foregroundColor: foreground,
            disabledForegroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _outlineFill,
          foregroundColor: foreground,
          disabledForegroundColor: _outlineDisabled,
          side: const BorderSide(color: AppColors.starColor),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: content,
      ),
    );
  }
}
