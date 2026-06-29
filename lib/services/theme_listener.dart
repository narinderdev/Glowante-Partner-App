import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeListener extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  String get currentThemeLabel =>
      _themeMode == ThemeMode.dark ? 'Dark' : 'Light';

  ThemeListener() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefsKey) ?? 'light';
    _applyThemeMode(_parseThemeMode(savedMode), notify: true);
  }

  Future<void> changeThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeModeToString(themeMode));
    _applyThemeMode(themeMode, notify: true);
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    return mode == ThemeMode.dark ? 'dark' : 'light';
  }

  void _applyThemeMode(ThemeMode themeMode, {bool notify = false}) {
    _themeMode = themeMode;
    if (notify) {
      notifyListeners();
    }
  }
}
