import 'package:flutter/material.dart';

import '../screens/update_required_dialog.dart';
import 'app_update_service.dart';

/// Single source of truth for showing the mandatory-update modal over
/// whatever screen the user is currently on. MyApp's periodic timer and
/// app-resume handler call this for a mid-session gate, and SplashScreen
/// calls it right after routing onward (never before — the modal must
/// never interrupt the splash animation itself). Centralising it here
/// means every caller shares the same "already showing" guard instead of
/// risking duplicate/racing dialogs.
class AppUpdateGate {
  AppUpdateGate._();

  static final AppUpdateGate instance = AppUpdateGate._();

  bool _isShowing = false;

  Future<void> checkAndShowIfNeeded(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (_isShowing) return;
    final result = await AppUpdateService.instance.check();
    if (result == null || _isShowing) return;

    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;

    // Never resets to false: once shown, the dialog is never popped by
    // anything but "Update Now", so there's nothing to re-arm for.
    _isShowing = true;
    await UpdateRequiredDialog.show(
      dialogContext,
      storeUrl: result.storeUrl,
      message: result.message,
    );
  }
}
