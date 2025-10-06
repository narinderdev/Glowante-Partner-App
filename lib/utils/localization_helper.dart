import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/translations.dart';

String translateText(String key, {Map<String, String>? params}) {
  var value = AppTranslations.t(key, LanguageListener.latestLang);
  if (params != null && params.isNotEmpty) {
    params.forEach((placeholder, replacement) {
      final token = '{$placeholder}';
      value = value.replaceAll(token, replacement);
    });
  }
  return value;
}

extension LocalizationExt on BuildContext {
  String t(String key, {Map<String, String>? params}) {
    watch<LanguageListener>();
    return translateText(key, params: params);
  }
}

extension TranslateStringExt on String {
  String tr(BuildContext context, {Map<String, String>? params}) {
    return context.t(this, params: params);
  }
}

