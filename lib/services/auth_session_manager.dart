import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralises logout behaviour so any part of the app can terminate the
/// current session (for example when an auth token expires).
class AuthSessionManager {
  AuthSessionManager._();

  static final AuthSessionManager instance = AuthSessionManager._();

  /// Avoids duplicate logout flows while one is already in progress.
  bool _isLoggingOut = false;

  /// Callback invoked after local session data is cleared.
  Future<void> Function(String? reason)? _onLogout;

  /// Keys that should be removed from shared preferences when logging out.
  static const List<String> _authPreferenceKeys = <String>[
    'user_token',
    'token',
    'phone_number',
    'user_id',
    'first_name',
    'last_name',
    'firstName',
    'lastName',
    'email',
    'salon_name',
    'salon_address',
    'profile_complete',
    'profile_pending',
    'user_role_ids',
    'user_role_codes',
    'user_role_labels',
    'primary_role_id',
    'primary_role_code',
    'stylist_user_salons_json',
    'stylist_user_branches_json',
    'selected_branch_id',
    'selected_salon_id',
    'stylist_selected_salon_name',
    'stylist_selected_branch_name',
  ];

  /// Registers a callback that will be triggered once logout cleanup finishes.
  void registerOnLogoutCallback(
    Future<void> Function(String? reason) callback,
  ) {
    _onLogout = callback;
  }

  /// Forces the application to log out the current user.
  Future<void> forceLogout({String? reason}) async {
    if (_isLoggingOut) {
      return;
    }
    _isLoggingOut = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _clearAuthPreferences(prefs);

      final callback = _onLogout;
      if (callback != null) {
        await callback(reason);
      }
    } catch (error, stackTrace) {
      debugPrint('AuthSessionManager.forceLogout error: $error');
      debugPrint('$stackTrace');
    } finally {
      _isLoggingOut = false;
    }
  }

  Future<void> _clearAuthPreferences(SharedPreferences prefs) async {
    for (final key in _authPreferenceKeys) {
      await prefs.remove(key);
    }
  }
}
