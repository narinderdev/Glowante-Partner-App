import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Gates the app on a minimum supported version via Firebase Remote
/// Config, so a shipped update can be made mandatory without a new app
/// release — the manager only has to change the "min_supported_version"
/// parameter in the Firebase console.
class AppUpdateCheckResult {
  const AppUpdateCheckResult({required this.storeUrl, required this.message});

  final String storeUrl;
  final String message;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const _defaultAndroidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.glowante.salon';
  static const _defaultIosStoreUrl =
      'https://apps.apple.com/in/app/glowante-partner/id6749371720';
  static const _defaultMessage =
      'A new version of the app is available. Please update to continue.';

  /// Flip to true locally, then hot-restart, to preview the update-required
  /// dialog in a debug build — bypasses Remote Config entirely, so nothing
  /// server-side needs to change or be remembered/reverted. Set back to
  /// false (or just don't commit the flip) when done.
  static bool debugPreviewUpdateDialog = false;

  /// Returns null when no update is required (including when the check
  /// itself fails, e.g. offline) — startup must never hard-block on a
  /// Remote Config fetch failure.
  ///
  /// Always null in debug builds (`flutter run`) — that's local development
  /// only, never something a real user has installed, so it must never be
  /// gated by Remote Config — unless [debugPreviewUpdateDialog] is
  /// explicitly flipped on to preview the dialog.
  Future<AppUpdateCheckResult?> check() async {
    if (kDebugMode) {
      if (!debugPreviewUpdateDialog) return null;
      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      return AppUpdateCheckResult(
        storeUrl: isIOS ? _defaultIosStoreUrl : _defaultAndroidStoreUrl,
        message: _defaultMessage,
      );
    }
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        'min_supported_version': '',
        'update_message': _defaultMessage,
        'android_store_url': _defaultAndroidStoreUrl,
        'ios_store_url': _defaultIosStoreUrl,
      });
      await remoteConfig.fetchAndActivate();

      final minVersion = remoteConfig.getString('min_supported_version').trim();
      if (minVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!_isOlderThan(packageInfo.version, minVersion)) return null;

      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      final storeUrl = remoteConfig.getString(
        isIOS ? 'ios_store_url' : 'android_store_url',
      );
      final message = remoteConfig.getString('update_message');

      return AppUpdateCheckResult(
        storeUrl: storeUrl.isNotEmpty
            ? storeUrl
            : (isIOS ? _defaultIosStoreUrl : _defaultAndroidStoreUrl),
        message: message.isNotEmpty ? message : _defaultMessage,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] check failed, skipping gate: $e');
      return null;
    }
  }

  bool _isOlderThan(String current, String minimum) {
    final currentParts = _versionParts(current);
    final minParts = _versionParts(minimum);
    final length = currentParts.length > minParts.length
        ? currentParts.length
        : minParts.length;
    for (var i = 0; i < length; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minParts.length ? minParts[i] : 0;
      if (c != m) return c < m;
    }
    return false;
  }

  List<int> _versionParts(String version) {
    // Strip build-number ("+34") and flavor suffixes ("-dev"/"-test" from
    // android/app/build.gradle.kts's versionNameSuffix) before parsing, so
    // e.g. "2.0.4-dev" compares as 2.0.4 instead of silently truncating to
    // 2.0.0 at the first non-numeric segment.
    return version
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}
