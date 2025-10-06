// services/language_listener.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageListener extends ChangeNotifier {
  static String _latestLang = 'en';

  String _currentLang = _latestLang;

  String get currentLang => _currentLang;

  static String get latestLang => _latestLang;

  Locale get currentLocale => Locale(_currentLang);

  LanguageListener() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language') ?? _currentLang;
    _updateLanguage(savedLanguage, notify: true);
  }

  Future<void> changeLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    _updateLanguage(langCode, notify: true);
  }

  void _updateLanguage(String langCode, {bool notify = false}) {
    _currentLang = langCode;
    _latestLang = langCode;
    if (notify) {
      notifyListeners();
    }
  }
}

