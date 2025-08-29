import 'package:shared_preferences/shared_preferences.dart';

class UserDefaultsManager {
  static Future<void> onboardingStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('hasSeenOnboarding', status);
  }

  static Future<bool?> getOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding');
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> setLocationStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('locationUpdated', status);
  }

  static Future<bool?> getLocationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('locationUpdated');
  }

  static Future<void> setProfileStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('profileUpdated', status);
  }

  static Future<bool?> getProfileStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('profileUpdated');
  }
}
