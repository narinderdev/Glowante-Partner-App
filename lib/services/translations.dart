class AppTranslations {
  static const Map<String, Map<String, String>> translations = {
    'en': {
        'Language': 'Language',
      'profile': 'Profile',
      'catalog': 'Catalog',
      'salons': 'Salons',
      'bookings': 'Bookings',
      'logout': 'Logout',
      'delete_account': 'Delete Account',
      'privacy_policy': 'Privacy Policy',
      'terms_conditions': 'Terms & Conditions',
      'use_current_location': 'Use Current Location',
      'submit_location': 'Submit Location',
      'get_started': 'Get Started',
    },
    'hi': {
        'Language': 'भाषा',
      'profile': 'प्रोफ़ाइल',
      'catalog': 'कैटलॉग',
      'salons': 'सैलून',
      'bookings': 'बुकिंग्स',
      'logout': 'लॉग आउट',
      'delete_account': 'खाता हटाएं',
      'privacy_policy': 'गोपनीयता नीति',
      'terms_conditions': 'नियम और शर्तें',
      'use_current_location': 'वर्तमान स्थान का उपयोग करें',
      'submit_location': 'स्थान जमा करें',
      'get_started': 'शुरू करें',
    },
  };

  static String t(String key, String langCode) {
    return translations[langCode]?[key] ?? key;
  }
}
