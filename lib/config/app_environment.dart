import 'package:flutter/foundation.dart';

enum AppFlavor {
  dev,
  test,
  prod,
}

class AppEnvironment {
  static const String _flavorName =
      String.fromEnvironment('APP_FLAVOR', defaultValue: 'prod');

  static AppFlavor get flavor {
    switch (_flavorName.toLowerCase()) {
      case 'dev':
        return AppFlavor.dev;
      case 'test':
        return AppFlavor.test;
      case 'prod':
      case 'production':
      default:
        return AppFlavor.prod;
    }
  }

  static String get baseUrl {
    switch (flavor) {
      case AppFlavor.dev:
        return 'https://dev-api.glowante.com/';
      case AppFlavor.test:
        return 'https://test-api.glowante.com/';
      case AppFlavor.prod:
        return 'https://api.glowante.com/';
    }
  }

  static String get platform {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'flutter_android';
      default:
        return 'flutter_android';
    }
  }
}
