// services/language_listener.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageListener extends ChangeNotifier {
  String _currentLang = 'en';

  String get currentLang => _currentLang;

  Locale get currentLocale => Locale(_currentLang);

  LanguageListener() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLang = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    _currentLang = langCode;
    notifyListeners();
  }
}
