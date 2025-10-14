import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_manager.dart';

/// Polls the stored auth token and enforces logout when the token is no longer
/// valid. This acts as a safety net in addition to per-request checks.
class TokenExpirationService {
  TokenExpirationService._();

  static final TokenExpirationService instance =
      TokenExpirationService._();

  static const Duration _defaultInterval = Duration(minutes: 1);
  static const Duration _expiryGrace = Duration(seconds: 5);

  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_defaultInterval, (_) => _checkToken());
    // Run an immediate check so we do not wait for the first interval tick.
    unawaited(_checkToken());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('user_token');
      if (token == null || token.isEmpty) {
        return;
      }

      if (isTokenExpired(token)) {
        await AuthSessionManager.instance
            .forceLogout(reason: 'session_expired');
      }
    } catch (error, stackTrace) {
      debugPrint('TokenExpirationService check failed: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Returns true when the provided token is expired or about to expire.
  static bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    final Map<String, dynamic>? payload = _decodePayload(token);
    if (payload == null) {
      return false;
    }

    final dynamic expValue = payload['exp'];
    if (expValue == null) {
      return false;
    }

    final int? expirySeconds = _coerceToInt(expValue);
    if (expirySeconds == null) {
      return false;
    }

    final DateTime expiry =
        DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000, isUtc: true);
    final DateTime now = DateTime.now().toUtc().subtract(_expiryGrace);
    return now.isAfter(expiry);
  }

  static Map<String, dynamic>? _decodePayload(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final String normalized = base64Url.normalize(parts[1]);
      final List<int> decodedBytes = base64Url.decode(normalized);
      final String jsonPayload = utf8.decode(decodedBytes);
      final dynamic payload = json.decode(jsonPayload);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } catch (error) {
      debugPrint('Token payload decode failed: $error');
    }
    return null;
  }

  static int? _coerceToInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
