import 'package:flutter/services.dart';

class AppInputRules {
  AppInputRules._();

  static const int nameMaxLength = 50;
  static const int emailMaxLength = 100;
  static const int phoneMaxLength = 10;
  static const int shortTextMaxLength = 60;
  static const int mediumTextMaxLength = 120;
  static const int longTextMaxLength = 250;

  static final RegExp namePattern = RegExp(r"[A-Za-z ]");
  static final RegExp alphaNumericSlashDashPattern = RegExp(r'[A-Za-z0-9/-]');
  static final RegExp generalTextPattern = RegExp(r"[A-Za-z0-9 .,'&()/-]");

  static List<TextInputFormatter> get nameFormatters => [
        FilteringTextInputFormatter.allow(namePattern),
        LengthLimitingTextInputFormatter(nameMaxLength),
      ];

  static List<TextInputFormatter> get phoneFormatters => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(phoneMaxLength),
      ];

  static List<TextInputFormatter> get emailFormatters => [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(emailMaxLength),
      ];

  static List<TextInputFormatter> alphaNumericSlashDashFormatters({
    int maxLength = shortTextMaxLength,
  }) =>
      [
        FilteringTextInputFormatter.allow(alphaNumericSlashDashPattern),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  static List<TextInputFormatter> generalTextFormatters({
    int maxLength = mediumTextMaxLength,
  }) =>
      [
        FilteringTextInputFormatter.allow(generalTextPattern),
        LengthLimitingTextInputFormatter(maxLength),
      ];
}
