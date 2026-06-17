import 'package:intl/intl.dart';

final NumberFormat _rupeeFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

num? minorAmountToRupees(dynamic value) {
  if (value == null) return null;
  if (value is num) return value / 100;
  final parsed = num.tryParse(value.toString().trim());
  return parsed == null ? null : parsed / 100;
}

int rupeesToMinorAmount(num value) => (value * 100).round();

String formatMinorAmount(
  dynamic value, {
  String fallback = '₹0.00',
  bool trimZeroDecimals = false,
}) {
  final rupees = minorAmountToRupees(value);
  if (rupees == null) return fallback;
  if (trimZeroDecimals && rupees == rupees.roundToDouble()) {
    return '₹${rupees.toStringAsFixed(0)}';
  }
  return _rupeeFormatter.format(rupees);
}

String formatRupeeAmount(
  dynamic value, {
  String fallback = '₹0.00',
  bool trimZeroDecimals = false,
}) {
  if (value == null) return fallback;
  final rupees = value is num ? value : num.tryParse(value.toString().trim());
  if (rupees == null) return fallback;
  if (trimZeroDecimals && rupees == rupees.roundToDouble()) {
    return '₹${rupees.toStringAsFixed(0)}';
  }
  return _rupeeFormatter.format(rupees);
}
