import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/stylist_appointments/widgets/stylist_appointment_details_component.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../features/stylist_item_entry/stylist_item_entry_feature.dart';
import '../utils/api_service.dart';
import '../utils/price_formatter.dart';
import '../widgets/fixed_slot_otp_field.dart';
import 'AddBookings.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const String _bookingsFontFamily = 'Manrope';
const Color _bookingsAccent = Color(0xFFC19A6B);
const Color _bookingsGold = Color(0xFF8B6500);
const Color _bookingsPrimaryText = Color(0xFF1C1917);
const Color _bookingsSecondaryText = Color(0xFF78716C);
const Color _bookingsDateText = Color(0xFF44403C);
const Color _bookingsUpcoming = Color(0xFF475569);
const Color _bookingsCard = Color(0xFFFFFFFF);
const Color _bookingsPage = Color(0xFFFBF9F8);
const Color _bookingsDark = Color(0xFF1C1917);
const Color _bookingsBorder = Color(0xFFE7E5E4);

TextStyle _bookingTextStyle({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _bookingsPrimaryText,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _bookingsFontFamily,
    fontFamilyFallback: const ['Inter'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class StylistBookingsScreen extends StatefulWidget {
  const StylistBookingsScreen({
    super.key,
    this.isOwnerMode = false,
  });

  final bool isOwnerMode;

  @override
  State<StylistBookingsScreen> createState() => _StylistBookingsScreenState();
}

enum _BookingViewTab {
  teamMembers,
  schedule,
  recent,
}

class _SalonBranchOption {
  const _SalonBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    this.addressSummary = '',
    this.isMain = false,
    this.isSalonActive = true,
    this.isBranchActive = true,
    this.startMinute,
    this.endMinute,
    this.hasWeeklySchedule = false,
    this.weeklySlots = const <String, List<_BranchDaySlot>>{},
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String addressSummary;
  final bool isMain;
  final bool isSalonActive;
  final bool isBranchActive;

  bool get canAcceptBookings => isSalonActive && isBranchActive;
  final int? startMinute;
  final int? endMinute;
  final bool hasWeeklySchedule;
  final Map<String, List<_BranchDaySlot>> weeklySlots;

  String get label {
    if (branchName.isNotEmpty) return branchName;
    if (salonName.isNotEmpty) return salonName;
    return 'Salon #$salonId';
  }

  List<_BranchDaySlot> slotsForDate(DateTime date) {
    if (hasWeeklySchedule) {
      return weeklySlots[_weekdayKeyForDate(date)] ?? const <_BranchDaySlot>[];
    }
    if (startMinute != null && endMinute != null && endMinute! > startMinute!) {
      return [
        _BranchDaySlot(startMinute: startMinute!, endMinute: endMinute!),
      ];
    }
    return const <_BranchDaySlot>[];
  }

  bool isClosedOnDate(DateTime date) {
    return hasWeeklySchedule && slotsForDate(date).isEmpty;
  }
}

class _BranchDaySlot {
  const _BranchDaySlot({
    required this.startMinute,
    required this.endMinute,
  });

  final int startMinute;
  final int endMinute;
}

enum _NoTeamMembersForDateReason {
  none,
  joiningDate,
  employmentDate,
  notScheduled,
}

class _TeamMemberDirectory {
  const _TeamMemberDirectory({
    this.serviceNames = const <String, List<String>>{},
    this.workingHours = const <String, List<_WorkingDayHours>>{},
    this.namesByUserId = const <int, String>{},
    this.namesByUserBranchId = const <int, String>{},
    this.noMembersReason = _NoTeamMembersForDateReason.none,
  });

  final Map<String, List<String>> serviceNames;
  final Map<String, List<_WorkingDayHours>> workingHours;
  final Map<int, String> namesByUserId;
  final Map<int, String> namesByUserBranchId;
  final _NoTeamMembersForDateReason noMembersReason;

  List<String> get names => serviceNames.keys.toList();
}

class _WorkingDayHours {
  const _WorkingDayHours({
    required this.day,
    required this.slots,
    this.ranges = const <_WorkingHourRange>[],
  });

  final String day;
  final List<String> slots;
  final List<_WorkingHourRange> ranges;
}

class _WorkingHourRange {
  const _WorkingHourRange({
    required this.startMinute,
    required this.endMinute,
  });

  final int startMinute;
  final int endMinute;
}

class _BookingStatusVisuals {
  const _BookingStatusVisuals({
    required this.label,
    required this.leadingColor,
    required this.cardBorderColor,
    required this.pillBackgroundColor,
    required this.pillBorderColor,
    required this.pillTextColor,
    required this.primaryButtonColor,
    required this.primaryTextColor,
  });

  final String label;
  final Color leadingColor;
  final Color cardBorderColor;
  final Color pillBackgroundColor;
  final Color pillBorderColor;
  final Color pillTextColor;
  final Color primaryButtonColor;
  final Color primaryTextColor;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty || text == 'null') return null;
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

String _normalizeStatus(dynamic value) {
  final normalized = (value ?? '').toString().trim().toUpperCase();
  return normalized.replaceAll('-', '_').replaceAll(' ', '_');
}

DateTime? _parseLocal(dynamic iso) {
  if (iso == null) return null;
  try {
    return DateTime.parse(iso.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime? _parseDateOnly(dynamic value) {
  final parsed = _parseLocal(value);
  return parsed == null ? null : _dateOnly(parsed);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatApiDate(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

String _formatShortWeekday(DateTime value) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[value.weekday - 1];
}

String _formatScheduleDate(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day}';
}

String _weekdayKeyForDate(DateTime value) {
  const days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  return days[value.weekday - 1];
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = _twoDigits(value.minute);
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${_twoDigits(hour)}:$minute $suffix';
}

int? _clockMinutes(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final match =
      RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([aApP][mM])?$').firstMatch(raw);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || minute > 59) return null;
  final suffix = match.group(3)?.toUpperCase();
  if (suffix != null) {
    if (hour < 1 || hour > 12) return null;
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
  } else if (hour > 23) {
    return null;
  }
  return hour * 60 + minute;
}

bool _hasProvidedWeeklySchedule(dynamic rawSchedule) {
  if (rawSchedule is List || rawSchedule is Map) return true;
  return false;
}

dynamic _rawScheduleValue(Map<dynamic, dynamic> source) {
  if (source.containsKey('schedule')) return source['schedule'];
  if (source.containsKey('schedules')) return source['schedules'];
  return null;
}

dynamic _effectiveBranchSchedule(
  Map<dynamic, dynamic> branch,
  Map<dynamic, dynamic>? salon,
) {
  final branchSchedule = _rawScheduleValue(branch);
  if (_hasProvidedWeeklySchedule(branchSchedule)) return branchSchedule;
  if (salon == null) return null;
  final salonSchedule = _rawScheduleValue(salon);
  if (_hasProvidedWeeklySchedule(salonSchedule)) return salonSchedule;
  return null;
}

String _formatMinutesLabel(int minutes) {
  final normalized = minutes % (24 * 60);
  return _formatTime(DateTime(0, 1, 1, normalized ~/ 60, normalized % 60));
}

String _formatMinutesShortLabel(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  if (minute == 0) return '$hour12 $suffix';
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

List<Map<String, dynamic>> _bookingItems(Map<String, dynamic> booking) {
  final rawItems = (booking['items'] as List?) ?? const [];
  return rawItems
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<Map<String, dynamic>> _bookingServices(Map<String, dynamic> booking) {
  final rawServices = (booking['services'] as List?) ?? const [];
  return rawServices
      .whereType<Map>()
      .map((service) => Map<String, dynamic>.from(service))
      .toList();
}

String _plainTextValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString().trim();
  return '';
}

String _serviceNameFromServiceObject(dynamic raw) {
  final direct = _plainTextValue(raw);
  if (direct.isNotEmpty) return direct;

  if (raw is! Map) return '';
  final map = Map<String, dynamic>.from(raw);
  for (final key in const [
    'displayName',
    'name',
    'serviceName',
    'title',
  ]) {
    final value = _plainTextValue(map[key]);
    if (value.isNotEmpty) return value;
  }

  for (final key in const [
    'masterService',
    'service',
    'branchService',
  ]) {
    final value = _serviceNameFromServiceObject(map[key]);
    if (value.isNotEmpty) return value;
  }

  return '';
}

String _serviceNameFromBookingItem(Map<String, dynamic> item) {
  for (final key in const [
    'serviceName',
    'displayName',
    'name',
    'title',
  ]) {
    final value = _plainTextValue(item[key]);
    if (value.isNotEmpty) return value;
  }

  for (final key in const [
    'branchService',
    'service',
    'masterService',
    'cartItem',
    'item',
  ]) {
    final value = _serviceNameFromServiceObject(item[key]);
    if (value.isNotEmpty) return value;
  }

  return '';
}

DateTime? _bookingDate(Map<String, dynamic> booking) {
  return _parseLocal(
        booking['date'] ??
            booking['appointmentDate'] ??
            booking['bookingDate'] ??
            booking['scheduledDate'],
      ) ??
      _bookingStart(booking);
}

DateTime? _bookingStart(Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  final explicitStart = _parseLocal(
    booking['startAt'] ?? (items.isNotEmpty ? items.first['startAt'] : null),
  );
  if (explicitStart != null) return explicitStart;

  final dateText = (booking['date'] ??
          booking['appointmentDate'] ??
          booking['bookingDate'] ??
          booking['scheduledDate'] ??
          '')
      .toString()
      .trim();
  final timeText = (booking['startTime'] ??
          booking['start'] ??
          booking['start_at'] ??
          booking['time'] ??
          '')
      .toString()
      .trim();
  if (dateText.isEmpty || timeText.isEmpty) return null;
  return _parseLocal('${dateText.split('T').first}T$timeText');
}

DateTime? _bookingEnd(Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  return _parseLocal(
    booking['endAt'] ?? (items.isNotEmpty ? items.first['endAt'] : null),
  );
}

int? _bookingBranchId(Map<String, dynamic> booking) {
  final branch = booking['branch'];
  if (branch is Map) {
    final branchId = _asInt(branch['id']);
    if (branchId != null) return branchId;
  }

  return _asInt(
    booking['branchId'] ?? booking['branch_id'] ?? booking['branchID'],
  );
}

// String _customerName(BuildContext context, Map<String, dynamic> booking) {
//   final user = booking['user'];
//   if (user is Map) {
//     final map = Map<String, dynamic>.from(user);
//     final first = map['firstName']?.toString().trim() ?? '';
//     final last = map['lastName']?.toString().trim() ?? '';
//     final full = '$first $last'.trim();
//     if (full.isNotEmpty) return full;
//     final name = map['name']?.toString().trim() ?? '';
//     if (name.isNotEmpty) return name;
//   }
//   return context.t('Customer');
// }
// String _customerName(BuildContext context, Map<String, dynamic> booking) {
//   final user = booking['user'];
//   if (user is Map) {
//     final map = Map<String, dynamic>.from(user);
//     final first = map['firstName']?.toString().trim() ?? '';
//     final last = map['lastName']?.toString().trim() ?? '';
//     final full = '$first $last'.trim();
//     if (full.isNotEmpty) return full;

//     final name = map['name']?.toString().trim() ?? '';
//     if (name.isNotEmpty) return name;
//   }

//   return translateText('Customer');
// }
String _customerName(BuildContext context, Map<String, dynamic> booking) {
  final user = booking['user'];
  final client = booking['client'];
  final customer = booking['customer'];

  final source = user is Map
      ? user
      : client is Map
          ? client
          : customer is Map
              ? customer
              : null;

  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    final first = map['firstName']?.toString().trim() ?? '';
    final last = map['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();

    if (full.isNotEmpty) return full;

    final name = map['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }

  return translateText('Customer');
}

String _customerPhone(Map<String, dynamic> booking) {
  final user = booking['user'];
  final client = booking['client'];
  final customer = booking['customer'];

  final source = user is Map
      ? user
      : client is Map
          ? client
          : customer is Map
              ? customer
              : null;

  if (source is! Map) return '';

  final map = Map<String, dynamic>.from(source);

  const keys = [
    'phoneNumber',
    'phone',
    'mobileNumber',
    'mobile',
    'contactNumber',
    'phone_number',
  ];

  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }

  return '';
}

String _phoneLaunchValue(String phone) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty) return '';
  final prefix = trimmed.startsWith('+') ? '+' : '';
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? '' : '$prefix$digits';
}

Future<void> _openCustomerPhoneAction(
  BuildContext context,
  Map<String, dynamic> booking, {
  required bool message,
}) async {
  final phone = _phoneLaunchValue(_customerPhone(booking));
  if (phone.isEmpty) {
    Fluttertoast.showToast(
        msg: context.t('Customer phone number not available'));
    return;
  }

  final uri = Uri(scheme: message ? 'sms' : 'tel', path: phone);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    Fluttertoast.showToast(
        msg: message
            ? context.t('Unable to open messages app')
            : context.t('Unable to open phone app'));
  }
}

String _branchAddressSummary(dynamic rawAddress) {
  if (rawAddress is! Map) return '';
  final address = Map<String, dynamic>.from(rawAddress);
  final parts = <String>[];

  void push(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null' || parts.contains(text)) {
      return;
    }
    parts.add(text);
  }

  push(address['line1']);
  push(address['line2']);
  push(address['village']);
  push(address['district']);
  push(address['city']);
  push(address['state']);
  push(address['postalCode']);
  push(address['country']);
  return parts.join(', ');
}

String _personName(dynamic raw) {
  if (raw is! Map) return '';
  final map = Map<String, dynamic>.from(raw);
  final first = map['firstName']?.toString().trim() ?? '';
  final last = map['lastName']?.toString().trim() ?? '';
  final full = '$first $last'.trim();
  if (full.isNotEmpty) return full;
  return map['name']?.toString().trim() ?? '';
}

String _initials(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.substring(0, 1).toUpperCase())
      .join();
}

// List<String> _assignedStaffNames(Map<String, dynamic> booking) {
//   final names = <String>[];
//   final seen = <String>{};

//   void addName(String value) {
//     final normalized = value.trim();
//     if (normalized.isEmpty) return;
//     if (seen.add(normalized)) {
//       names.add(normalized);
//     }
//   }

//   addName(_personName(booking['teamMember']));

//   for (final item in _bookingItems(booking)) {
//     addName(_personName(item['teamMember']));
//     addName(_personName(item['assignedUserBranch']?['user']));
//   }

//   return names;
// }
List<String> _assignedStaffNames(Map<String, dynamic> booking) {
  final names = <String>[];
  final seen = <String>{};

  void addName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;

    final key = normalized.toLowerCase();
    if (seen.add(key)) {
      names.add(normalized);
    }
  }

  addName(_personName(booking['teamMember']));
  addName(_personName(booking['professional']));
  addName(_personName(booking['assignedUserBranch']?['user']));

  for (final item in _bookingItems(booking)) {
    addName(_personName(item['teamMember']));
    addName(_personName(item['professional']));
    addName(_personName(item['assignedUserBranch']?['user']));
  }

  return names;
}

List<String> _professionalStatuses(Map<String, dynamic> booking) {
  final statuses = <String>[];

  void addStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    if (status.isEmpty || status == 'null') return;
    statuses.add(status.replaceAll('-', '_').replaceAll(' ', '_'));
  }

  addStatus(booking['professionalStatus']);
  addStatus(booking['assignedUserBranch']?['professionalStatus']);

  for (final item in _bookingItems(booking)) {
    addStatus(item['professionalStatus']);
    addStatus(item['assignedUserBranch']?['professionalStatus']);
  }

  return statuses;
}

String _assignedStaffSummary(
    BuildContext context, Map<String, dynamic> booking) {
  final names = _assignedStaffNames(booking);
  if (names.isEmpty) return '';
  return names.join(', ');
}

void _logBookingDetailsSnapshot(
  BuildContext context,
  Map<String, dynamic> booking, {
  String source = 'open_detail',
}) {
  final services = _detailServiceSegments(context, booking)
      .map(
        (service) => {
          'title': service.title,
          'time': service.timeLabel,
          'duration': service.metaLabel,
        },
      )
      .toList();
  final items = _bookingItems(booking);
  final rawServices = _bookingServices(booking);
  final itemServiceDebug = items
      .map(
        (item) => {
          'keys': item.keys.toList(),
          'resolvedName': _serviceNameFromBookingItem(item),
          'branchServiceKeys': item['branchService'] is Map
              ? Map<String, dynamic>.from(item['branchService']).keys.toList()
              : const <String>[],
          'serviceKeys': item['service'] is Map
              ? Map<String, dynamic>.from(item['service']).keys.toList()
              : const <String>[],
        },
      )
      .toList();

  debugPrint('[BookingDetailsLog] source=$source');
  debugPrint('[BookingDetailsLog] id=${booking['id']}');
  debugPrint(
      '[BookingDetailsLog] status=${_normalizeStatus(booking['status'])}');
  debugPrint('[BookingDetailsLog] customer=${_customerName(context, booking)}');
  debugPrint('[BookingDetailsLog] customerPhone=${_customerPhone(booking)}');
  debugPrint(
    '[BookingDetailsLog] assignedStaff=${_assignedStaffSummary(context, booking)}',
  );
  debugPrint('[BookingDetailsLog] timeRange=${_bookingTimeRange(booking)}');
  debugPrint(
    '[BookingDetailsLog] durationMinutes=${_bookingDurationMinutes(booking)}',
  );
  debugPrint('[BookingDetailsLog] totalAmount=${_bookingTotalPrice(booking)}');
  debugPrint(
      '[BookingDetailsLog] serviceSummary=${_serviceCardSummary(context, booking)}');
  debugPrint('[BookingDetailsLog] derivedServices=$services');
  debugPrint('[BookingDetailsLog] itemCount=${items.length}');
  debugPrint('[BookingDetailsLog] rawServiceCount=${rawServices.length}');
  debugPrint('[BookingDetailsLog] itemServiceDebug=$itemServiceDebug');
  debugPrint('[BookingDetailsLog] rawKeys=${booking.keys.toList()}');
}

void _logBookingsFetchSnapshot(
  BuildContext context,
  List<Map<String, dynamic>> bookings, {
  required String source,
}) {
  debugPrint('[BookingDetailsLog] source=$source count=${bookings.length}');
  if (bookings.isEmpty) {
    debugPrint('[BookingDetailsLog] source=$source no bookings returned');
    return;
  }
  _logBookingDetailsSnapshot(
    context,
    bookings.first,
    source: '$source:first_booking',
  );
}

String _serviceLabel(BuildContext context, Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    final firstName = _serviceNameFromBookingItem(items.first);
    final baseLabel =
        firstName.isNotEmpty ? firstName : context.t('Appointment');
    if (items.length == 1) return baseLabel;
    return '$baseLabel + ${items.length - 1}';
  }

  final services = _bookingServices(booking);
  if (services.isEmpty) return context.t('Appointment');

  final firstName = services.first['name']?.toString().trim() ?? '';
  final baseLabel = firstName.isNotEmpty ? firstName : context.t('Appointment');
  if (services.length == 1) return baseLabel;
  return '$baseLabel + ${services.length - 1}';
}

// String _serviceCardSummary(BuildContext context, Map<String, dynamic> booking) {
//   final items = _bookingItems(booking);
//   if (items.isNotEmpty) {
//     final names = items
//         .map(
//           (item) =>
//               item['branchService']?['displayName']?.toString().trim() ??
//               item['service']?.toString().trim() ??
//               item['displayName']?.toString().trim() ??
//               item['name']?.toString().trim() ??
//               '',
//         )
//         .where((name) => name.isNotEmpty)
//         .toList();
//     if (names.isEmpty) return context.t('Appointment');
//     if (names.length == 1) return names.first;
//     return '${names.first}, ...';
//   }

//   final services = _bookingServices(booking);
//   final names = services
//       .map((service) => service['name']?.toString().trim() ?? '')
//       .where((name) => name.isNotEmpty)
//       .toList();
//   if (names.isEmpty) return context.t('Appointment');
//   if (names.length == 1) return names.first;
//   return '${names.first}, ...';
// }
String _serviceCardSummary(BuildContext context, Map<String, dynamic> booking) {
  final appointmentLabel = translateText('Appointment');

  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    final names = items
        .map(_serviceNameFromBookingItem)
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) return appointmentLabel;
    if (names.length == 1) return names.first;
    return '${names.first}, ...';
  }

  final services = _bookingServices(booking);
  final names = services
      .map((service) => service['name']?.toString().trim() ?? '')
      .where((name) => name.isNotEmpty)
      .toList();

  if (names.isEmpty) return appointmentLabel;
  if (names.length == 1) return names.first;
  return '${names.first}, ...';
}

// List<StylistAppointmentServiceSegment> _detailServiceSegments(
//   BuildContext context,
//   Map<String, dynamic> booking,
// ) {
//   final items = _bookingItems(booking);
//   if (items.isNotEmpty) {
//     DateTime? fallbackStart = _bookingStart(booking);
//     return items.map((item) {
//       final name = item['branchService']?['displayName']?.toString().trim() ??
//           item['service']?.toString().trim() ??
//           item['displayName']?.toString().trim() ??
//           item['name']?.toString().trim() ??
//           context.t('Appointment');
//       final durationMin = _asInt(
//         item['durationMin'] ?? item['branchService']?['durationMin'],
//       );
//       final start = _parseLocal(item['startAt']) ?? fallbackStart;
//       final end = _parseLocal(item['endAt']) ??
//           (start != null && durationMin != null
//               ? start.add(Duration(minutes: durationMin))
//               : null);
//       if (end != null) fallbackStart = end;

//       return StylistAppointmentServiceSegment(
//         title: name.isEmpty ? context.t('Appointment') : name,
//         timeLabel: (start != null && end != null)
//             ? '${_formatTime(start)} - ${_formatTime(end)}'
//             : '--',
//         metaLabel:
//             durationMin != null && durationMin > 0 ? '${durationMin}m' : null,
//       );
//     }).toList();
//   }

//   final services = _bookingServices(booking);
//   if (services.isNotEmpty) {
//     DateTime? cursor = _bookingStart(booking);
//     return services.map((service) {
//       final name = service['name']?.toString().trim() ?? '';
//       final durationMin = _asInt(service['durationMin']);
//       final start = cursor;
//       final end = start != null && durationMin != null && durationMin > 0
//           ? start.add(Duration(minutes: durationMin))
//           : null;
//       if (end != null) cursor = end;

//       return StylistAppointmentServiceSegment(
//         title: name.isEmpty ? context.t('Appointment') : name,
//         timeLabel: (start != null && end != null)
//             ? '${_formatTime(start)} - ${_formatTime(end)}'
//             : '--',
//         metaLabel:
//             durationMin != null && durationMin > 0 ? '${durationMin}m' : null,
//       );
//     }).toList();
//   }

//   return [
//     StylistAppointmentServiceSegment(
//       title: context.t('Appointment'),
//       timeLabel: _bookingTimeRange(booking),
//     ),
//   ];
// }
List<StylistAppointmentServiceSegment> _detailServiceSegments(
  BuildContext context,
  Map<String, dynamic> booking,
) {
  final appointmentLabel = translateText('Appointment');

  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    DateTime? fallbackStart = _bookingStart(booking);

    return items.map((item) {
      final resolvedName = _serviceNameFromBookingItem(item);
      final name = resolvedName.isEmpty ? appointmentLabel : resolvedName;

      final durationMin = _asInt(
        item['durationMin'] ?? item['branchService']?['durationMin'],
      );

      final start = _parseLocal(item['startAt']) ?? fallbackStart;
      final end = _parseLocal(item['endAt']) ??
          (start != null && durationMin != null
              ? start.add(Duration(minutes: durationMin))
              : null);

      if (end != null) fallbackStart = end;

      return StylistAppointmentServiceSegment(
        title: name.isEmpty ? appointmentLabel : name,
        timeLabel: (start != null && end != null)
            ? '${_formatTime(start)} - ${_formatTime(end)}'
            : '--',
        metaLabel:
            durationMin != null && durationMin > 0 ? '${durationMin}m' : null,
      );
    }).toList();
  }

  return [
    StylistAppointmentServiceSegment(
      title: appointmentLabel,
      timeLabel: _bookingTimeRange(booking),
    ),
  ];
}

String _bookingTimeRange(Map<String, dynamic> booking) {
  final start = _bookingStart(booking);
  final end = _bookingEnd(booking);
  if (start == null || end == null) return '--';
  return '${_formatTime(start)} - ${_formatTime(end)}';
}

int _bookingDurationMinutes(Map<String, dynamic> booking) {
  final totalDurationMin = _asInt(booking['totalDurationMin']);
  if (totalDurationMin != null && totalDurationMin > 0) {
    return totalDurationMin;
  }

  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    final totalItemDuration = items.fold<int>(
      0,
      (sum, item) =>
          sum +
          (_asInt(item['durationMin'] ??
                  item['branchService']?['durationMin']) ??
              0),
    );
    if (totalItemDuration > 0) {
      return totalItemDuration;
    }
  }

  final services = _bookingServices(booking);
  if (services.isNotEmpty) {
    final totalServiceDuration = services.fold<int>(
      0,
      (sum, service) => sum + (_asInt(service['durationMin']) ?? 0),
    );
    if (totalServiceDuration > 0) {
      return totalServiceDuration;
    }
  }

  final start = _bookingStart(booking);
  final end = _bookingEnd(booking);
  if (start != null && end != null && end.isAfter(start)) {
    return end.difference(start).inMinutes;
  }

  return 60;
}

String _bookingTotalPrice(Map<String, dynamic> booking) {
  final totalPriceMinor = _asInt(
    booking['totalPriceMinor'] ??
        booking['totalAmountMinor'] ??
        booking['amountMinor'] ??
        booking['paymentAmountMinor'] ??
        booking['payableAmountMinor'] ??
        booking['finalAmountMinor'] ??
        booking['subtotalMinor'] ??
        booking['totalPrice'] ??
        booking['totalAmount'] ??
        booking['amount'] ??
        booking['paymentAmount'] ??
        booking['payableAmount'] ??
        booking['finalAmount'],
  );
  if (totalPriceMinor != null && totalPriceMinor > 0) {
    return formatMinorAmount(totalPriceMinor);
  }

  final items = _bookingItems(booking);
  final itemsTotalPriceMinor = items.fold<int>(
    0,
    (sum, item) =>
        sum +
        (_asInt(item['branchService']?['priceMinor'] ?? item['priceMinor']) ??
            0),
  );
  if (itemsTotalPriceMinor > 0) return formatMinorAmount(itemsTotalPriceMinor);

  final services = _bookingServices(booking);
  final totalPrice = services.fold<num>(
    0,
    (sum, service) => sum + ((service['price'] as num?) ?? 0),
  );
  if (totalPrice > 0) {
    return formatMinorAmount(totalPrice);
  }

  return formatMinorAmount(0);
}

String _statusLabel(BuildContext context, String status) {
  switch (status) {
    case 'PENDING':
      return context.t('Pending');
    case 'IN_PROGRESS':
      return context.t('In Progress');
    case 'COMPLETED':
      return context.t('Completed');
    case 'CANCELLED':
      return context.t('Cancelled');
    case 'NO_SHOW':
      return context.t('No Show');
    default:
      return context.t('Upcoming');
  }
}

_BookingStatusVisuals _statusVisuals(BuildContext context, String status) {
  switch (status) {
    case 'PENDING':
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: const Color(0xFFDCE8F6),
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: const Color(0xFFF1F5F9),
        pillBorderColor: const Color(0xFFF1F5F9),
        pillTextColor: _bookingsUpcoming,
        primaryButtonColor: _bookingsAccent,
        primaryTextColor: Colors.white,
      );
    case 'IN_PROGRESS':
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: _bookingsAccent,
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: Color(0xFFFFFBEB),
        pillBorderColor: Color(0xFFFFFBEB),
        pillTextColor: Color(0xFF92400E),
        primaryButtonColor: _bookingsDark,
        primaryTextColor: Colors.white,
      );
    case 'COMPLETED':
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: Color(0xFFDCE8F6),
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: Color(0xFFF0FDF4),
        pillBorderColor: Color(0xFFF0FDF4),
        pillTextColor: Color(0xFF166534),
        primaryButtonColor: _bookingsUpcoming,
        primaryTextColor: Colors.white,
      );
    case 'CANCELLED':
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: Color(0xFFE0B1B1),
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: Color(0xFFFFF3F3),
        pillBorderColor: Color(0xFFEAB9B9),
        pillTextColor: Color(0xFFB35A5A),
        primaryButtonColor: _bookingsUpcoming,
        primaryTextColor: Colors.white,
      );
    case 'NO_SHOW':
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: Color(0xFFE5E7EB),
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: Color(0xFFF3F4F6),
        pillBorderColor: Color(0xFFE5E7EB),
        pillTextColor: Color(0xFF374151),
        primaryButtonColor: _bookingsUpcoming,
        primaryTextColor: Colors.white,
      );
    default:
      return _BookingStatusVisuals(
        label: _statusLabel(context, status),
        leadingColor: Color(0xFFDCE8F6),
        cardBorderColor: _bookingsBorder,
        pillBackgroundColor: Color(0xFFF1F5F9),
        pillBorderColor: Color(0xFFF1F5F9),
        pillTextColor: _bookingsUpcoming,
        primaryButtonColor: _bookingsAccent,
        primaryTextColor: Colors.white,
      );
  }
}

bool _showsConfirmAction(String status, {required bool isOwnerMode}) =>
    isOwnerMode && status == 'PENDING';

bool _showsStartAction(String status) => status == 'CONFIRMED';
bool _canStartJob(Map<String, dynamic> booking) {
  final status = _normalizeStatus(booking['status']);
  if (!_showsStartAction(status)) return false;

  final start = _bookingStart(booking);
  if (start == null) return false;

  final now = DateTime.now();
  final allowedAt = start.subtract(const Duration(minutes: 15));
  return now.isAtSameMomentAs(allowedAt) || now.isAfter(allowedAt);
}

bool _showsFinishAction(String status) => status == 'IN_PROGRESS';

bool _showsNoShowAction(String status) =>
    status == 'CONFIRMED' || status == 'UPCOMING';

bool _canMarkNoShow(Map<String, dynamic> booking) {
  if (!_showsNoShowAction(_normalizeStatus(booking['status']))) {
    return false;
  }

  final start = _bookingStart(booking);
  if (start == null) return false;

  final allowedAt = start.add(const Duration(minutes: 15));
  final now = DateTime.now();
  return now.isAtSameMomentAs(allowedAt) || now.isAfter(allowedAt);
}

Color _scheduleStatusAccentColor(String status) {
  switch (status) {
    case 'IN_PROGRESS':
      return const Color(0xFFE9B5C9);
    case 'COMPLETED':
      return const Color(0xFF86CFA3);
    case 'CANCELLED':
      return const Color(0xFFE0B1B1);
    case 'PENDING':
      return const Color(0xFFDCE8F6);
    default:
      return _bookingsGold;
  }
}

bool _isBusyBooking(Map<String, dynamic> booking) {
  final status = _normalizeStatus(booking['status']);
  return status == 'IN_PROGRESS' || status == 'STARTED';
}

Color _professionalAvailabilityColor(List<Map<String, dynamic>> bookings) {
  final statuses = bookings.expand(_professionalStatuses).toList();
  if (statuses.any((status) =>
      status == 'busy' ||
      status == 'unavailable' ||
      status == 'in_progress' ||
      status == 'occupied')) {
    return const Color(0xFFDC2626);
  }
  if (statuses.any((status) => status == 'available')) {
    return const Color(0xFF22C55E);
  }

  return bookings.any(_isBusyBooking)
      ? const Color(0xFFDC2626)
      : const Color(0xFF22C55E);
}

String? _professionalBusyReason(
  BuildContext context,
  List<Map<String, dynamic>> bookings,
) {
  Map<String, dynamic>? busyBooking;
  for (final booking in bookings) {
    if (_normalizeStatus(booking['status']) == 'IN_PROGRESS') {
      busyBooking = booking;
      break;
    }
    if (busyBooking == null && _isBusyBooking(booking)) {
      busyBooking = booking;
    }
  }

  if (busyBooking != null) {
    final customer = _customerName(context, busyBooking);
    final service = _serviceCardSummary(context, busyBooking);
    final time = _bookingTimeRange(busyBooking);
    return '${context.t('Busy with')} $customer • $service • $time';
  }

  final statuses = bookings.expand(_professionalStatuses).toSet();
  if (statuses.contains('unavailable')) {
    return context.t('Professional is unavailable');
  }
  if (statuses.any((status) =>
      status == 'busy' || status == 'occupied' || status == 'in_progress')) {
    return context.t('Professional is busy');
  }

  return null;
}

Future<Map<String, dynamic>?> _showStartJobOtpDialog(
  BuildContext context, {
  required int branchId,
  required int appointmentId,
}) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      String otp = '';
      bool otpComplete = false;
      String errorMessage = '';
      bool isSubmitting = false;
      bool hasError = false;

      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              translateText('Enter OTP'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FixedSlotOtpField(
                    enabled: !isSubmitting,
                    hasError: hasError,
                    activeColor: _bookingsAccent,
                    inactiveColor: _bookingsAccent,
                    errorColor: Colors.red,
                    fillColor: Colors.white,
                    filledColor: _bookingsGold,
                    textColor: _bookingsPrimaryText,
                    filledTextColor: Colors.white,
                    onChanged: (value, complete) {
                      setDialogState(() {
                        otp = value;
                        otpComplete = complete;
                        hasError = false;
                      });
                    },
                    onSubmitted: null,
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(translateText('Cancel')),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!otpComplete || otp.length != 6) {
                          setDialogState(() {
                            errorMessage =
                                translateText('Enter valid 6-digit OTP');
                            hasError = true;
                          });
                          return;
                        }

                        final dialogNavigator = Navigator.of(dialogCtx);

                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = '';
                        });

                        final resp = await ApiService.startAppointment(
                          branchId: branchId,
                          appointmentId: appointmentId,
                          otp: otp,
                        );
                        final success = resp['success'] == true;
                        final message = resp['message']?.toString() ??
                            (success ? 'Job started' : 'Invalid OTP');

                        setDialogState(() => isSubmitting = false);

                        if (!success) {
                          setDialogState(() {
                            errorMessage = message;
                            hasError = true;
                          });
                          return;
                        }

                        dialogNavigator.pop(resp);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bookingsGold,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(translateText('Submit')),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> _showNoShowConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          translateText('Mark No Show?'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          translateText(
            'This will mark the appointment as no show. This cannot be undone.',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(translateText('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _bookingsDark,
              foregroundColor: Colors.white,
            ),
            child: Text(translateText('Mark No Show')),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

// Future<Map<String, dynamic>?> _showFinishJobFeedbackDialog(
//   BuildContext context, {
//   required String customerName,
// }) async {
//   int selectedRating = 0;
//   String commentText = '';

//   return showModalBottomSheet<Map<String, dynamic>>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (ctx) {
//       return StatefulBuilder(
//         builder: (ctx, setSheetState) {
//           return Padding(
//             padding: EdgeInsets.only(
//               left: 16,
//               right: 16,
//               bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
//             ),
//             child: Container(
//               padding: const EdgeInsets.all(18),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Center(
//                       child: Container(
//                         width: 44,
//                         height: 4,
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFD8D1C8),
//                           borderRadius: BorderRadius.circular(999),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     const Text(
//                       'Finish Job',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       customerName,
//                       style: const TextStyle(
//                         color: _bookingsUpcoming,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     Text(
//                       context.t('Rating'),
//                       style: const TextStyle(
//                         color: _bookingsUpcoming,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: List.generate(5, (index) {
//                         final rating = index + 1;
//                         return IconButton(
//                           onPressed: () {
//                             setSheetState(() => selectedRating = rating);
//                           },
//                           icon: Icon(
//                             rating <= selectedRating
//                                 ? Icons.star_rounded
//                                 : Icons.star_border_rounded,
//                             color: _bookingsAccent,
//                           ),
//                         );
//                       }),
//                     ),
//                     TextField(
//                       maxLength: 120,
//                       minLines: 3,
//                       maxLines: 4,
//                       onChanged: (value) => commentText = value,
//                       decoration: InputDecoration(
//                         hintText: context.t('Write comment'),
//                         filled: true,
//                         fillColor: _bookingsCard,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           borderSide: const BorderSide(
//                             color: Color(0xFFE6DFD7),
//                           ),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           borderSide: const BorderSide(
//                             color: Color(0xFFE6DFD7),
//                           ),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           borderSide: const BorderSide(color: _bookingsAccent),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: () {
//                           Navigator.pop(ctx, {
//                             'rating': selectedRating,
//                             'comment': commentText.trim(),
//                           });
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: _bookingsDark,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(18),
//                           ),
//                         ),
//                         child: Text(context.t('Submit')),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//     },
//   );
// }
Future<Map<String, dynamic>?> _showFinishJobFeedbackDialog(
  BuildContext context, {
  required String customerName,
}) async {
  int selectedRating = 0;
  String commentText = '';

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canSubmit = selectedRating > 0 && commentText.trim().isNotEmpty;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _bookingsBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color(0xFFF4EAD4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: _bookingsGold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('Finish Job'),
                                style: _bookingTextStyle(
                                  size: 20,
                                  weight: FontWeight.w900,
                                  color: _bookingsPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bookingTextStyle(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: _bookingsSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          color: _bookingsSecondaryText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.t('How was the service?'),
                      style: _bookingTextStyle(
                        size: 14,
                        weight: FontWeight.w900,
                        color: _bookingsPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        spacing: 4,
                        children: List.generate(5, (index) {
                          final rating = index + 1;
                          final isSelected = rating <= selectedRating;

                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setDialogState(() => selectedRating = rating);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF4D6)
                                    : const Color(0xFFFAF7F3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? _bookingsAccent
                                      : _bookingsBorder,
                                ),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isSelected
                                    ? _bookingsGold
                                    : _bookingsSecondaryText,
                                size: 25,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.t('Comment'),
                      style: _bookingTextStyle(
                        size: 13,
                        weight: FontWeight.w900,
                        color: _bookingsSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLength: 120,
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (value) {
                        setDialogState(() {
                          commentText = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: context.t('Write comment'),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F3),
                        counterStyle: _bookingTextStyle(
                          size: 11,
                          weight: FontWeight.w600,
                          color: _bookingsSecondaryText,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _bookingsBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _bookingsBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: _bookingsGold,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () {
                                Navigator.pop(ctx, {
                                  'rating': selectedRating,
                                  'comment': commentText.trim(),
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bookingsDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: const Color(0xFF9CA3AF),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.t('Submit'),
                          style: _bookingTextStyle(
                            size: 15,
                            weight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _StylistBookingsScreenState extends State<StylistBookingsScreen> {
  final GlobalKey _branchSelectorKey = GlobalKey();
  final ApiService _apiService = ApiService();

  List<_SalonBranchOption> _options = const [];
  List<Map<String, dynamic>> _bookings = const [];
  List<String> _teamMemberNames = const [];
  Map<String, List<String>> _teamMemberServiceNames =
      const <String, List<String>>{};
  Map<String, List<_WorkingDayHours>> _teamMemberWorkingHours =
      const <String, List<_WorkingDayHours>>{};
  Map<int, String> _teamMemberNamesByUserId = const <int, String>{};
  Map<int, String> _teamMemberNamesByUserBranchId = const <int, String>{};
  _NoTeamMembersForDateReason _noTeamMembersForDateReason =
      _NoTeamMembersForDateReason.none;
  _SalonBranchOption? _selectedOption;
  DateTime _selectedDate = DateTime.now();
  DateTime _visibleDateStart = DateTime.now();
  int? _userId;
  bool _isLoading = true;
  bool _loadingDate = false;
  int? _confirmingAppointmentId;
  int? _startingAppointmentId;
  int? _completingAppointmentId;
  int _selectedBookingView = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleDateStart = _selectedDate;
    _loadOptions(showPageLoader: false, showInlineLoader: true);
  }

  Map<String, List<_BranchDaySlot>> _weeklySlotsFromSchedule(
    dynamic rawSchedule,
  ) {
    final slotsByDay = <String, List<_BranchDaySlot>>{};

    void addSlot(String day, dynamic rawSlot) {
      if (rawSlot is! Map) return;
      final startMinute = _clockMinutes(
        rawSlot['start'] ?? rawSlot['startTime'],
      );
      final endMinute = _clockMinutes(
        rawSlot['end'] ?? rawSlot['endTime'],
      );
      if (startMinute == null || endMinute == null) return;
      if (endMinute <= startMinute) return;
      slotsByDay.putIfAbsent(day, () => <_BranchDaySlot>[]).add(
            _BranchDaySlot(startMinute: startMinute, endMinute: endMinute),
          );
    }

    if (rawSchedule is Map) {
      for (final entry in rawSchedule.entries) {
        final day = entry.key.toString().trim().toLowerCase();
        if (day.isEmpty) continue;
        final rawSlots = entry.value is List ? entry.value as List : const [];
        slotsByDay.putIfAbsent(day, () => <_BranchDaySlot>[]);
        for (final rawSlot in rawSlots) {
          addSlot(day, rawSlot);
        }
      }
    } else if (rawSchedule is List) {
      for (final rawDay in rawSchedule) {
        if (rawDay is! Map) continue;
        final day = rawDay['day']?.toString().trim().toLowerCase() ?? '';
        if (day.isEmpty) continue;

        final rawSlots = rawDay['slots'] is List
            ? rawDay['slots'] as List
            : <dynamic>[rawDay];
        slotsByDay.putIfAbsent(day, () => <_BranchDaySlot>[]);

        for (final rawSlot in rawSlots) {
          addSlot(day, rawSlot);
        }
      }
    } else {
      return const <String, List<_BranchDaySlot>>{};
    }

    for (final daySlots in slotsByDay.values) {
      daySlots.sort(
        (first, second) => first.startMinute.compareTo(second.startMinute),
      );
    }

    return slotsByDay;
  }

  List<_SalonBranchOption> _buildOptionsFromSalons(
      Iterable<dynamic> rawSalons) {
    final options = <_SalonBranchOption>[];
    for (final rawSalon in rawSalons) {
      if (rawSalon is! Map) continue;
      final salon = Map<String, dynamic>.from(rawSalon);
      final salonId = _asInt(salon['id']);
      final salonName = (salon['name'] ?? '').toString().trim();
      if (salonId == null) continue;

      final branches = (salon['branches'] as List?) ?? const [];
      if (branches.isNotEmpty) {
        for (final rawBranch in branches) {
          if (rawBranch is! Map) continue;
          final branch = Map<String, dynamic>.from(rawBranch);
          final branchId =
              _asInt(branch['id']) ?? _asInt(branch['branchId']) ?? salonId;
          final branchName =
              (branch['name'] ?? branch['branchName'] ?? salonName)
                  .toString()
                  .trim();
          final rawSchedule = _effectiveBranchSchedule(branch, salon);

          options.add(
            _SalonBranchOption(
              salonId: salonId,
              branchId: branchId,
              isSalonActive: salon['active'] != false,
              isBranchActive: branch['active'] != false,
              salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
              branchName: branchName.isEmpty
                  ? (salonName.isEmpty ? 'Salon #$salonId' : salonName)
                  : branchName,
              addressSummary: _branchAddressSummary(branch['address']),
              isMain: branch['isMain'] == true,
              startMinute: _clockMinutes(branch['startTime']),
              endMinute: _clockMinutes(branch['endTime']),
              hasWeeklySchedule: _hasProvidedWeeklySchedule(rawSchedule),
              weeklySlots: _weeklySlotsFromSchedule(rawSchedule),
            ),
          );
        }
        continue;
      }

      final derivedBranchId =
          _asInt(salon['branchId']) ?? _asInt(salon['branch_id']) ?? salonId;
      final derivedBranchName =
          (salon['branchName'] ?? salon['branch_name'])?.toString().trim();
      final rawSchedule = _rawScheduleValue(salon);

      options.add(
        _SalonBranchOption(
          salonId: salonId,
          branchId: derivedBranchId,
          salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
          branchName:
              (derivedBranchName != null && derivedBranchName.isNotEmpty)
                  ? derivedBranchName
                  : (salonName.isEmpty ? 'Salon #$salonId' : salonName),
          addressSummary: _branchAddressSummary(salon['address']),
          isMain: salon['isMain'] == true,
          isSalonActive: salon['active'] != false,
          isBranchActive: salon['active'] != false,
          startMinute: _clockMinutes(salon['startTime']),
          endMinute: _clockMinutes(salon['endTime']),
          hasWeeklySchedule: _hasProvidedWeeklySchedule(rawSchedule),
          weeklySlots: _weeklySlotsFromSchedule(rawSchedule),
        ),
      );
    }

    return options;
  }

  List<_SalonBranchOption> _buildOptionsFromUserBranches(
    Iterable<dynamic> rawUserBranches,
  ) {
    final options = <_SalonBranchOption>[];

    for (final rawEntry in rawUserBranches) {
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      final rawBranch = entry['branch'];
      if (rawBranch is! Map) continue;

      final branch = Map<String, dynamic>.from(rawBranch);
      final branchId = _asInt(branch['id']);
      final branchName = (branch['name'] ?? '').toString().trim();

      final rawSalon = branch['salon'];
      final salon =
          rawSalon is Map ? Map<String, dynamic>.from(rawSalon) : null;
      final rawSchedule = _effectiveBranchSchedule(branch, salon);
      final salonId = _asInt(salon?['id']) ?? branchId;
      final salonName = (salon?['name'] ?? branchName).toString().trim();

      if (branchId == null || salonId == null) continue;

      options.add(
        _SalonBranchOption(
          salonId: salonId,
          branchId: branchId,
          salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
          branchName: branchName.isEmpty
              ? (salonName.isEmpty ? 'Branch #$branchId' : salonName)
              : branchName,
          addressSummary: _branchAddressSummary(branch['address']),
          isMain: branch['isMain'] == true,
          isSalonActive: salon?['active'] != false,
          isBranchActive: branch['active'] != false,
          startMinute: _clockMinutes(branch['startTime']),
          endMinute: _clockMinutes(branch['endTime']),
          hasWeeklySchedule: _hasProvidedWeeklySchedule(rawSchedule),
          weeklySlots: _weeklySlotsFromSchedule(rawSchedule),
        ),
      );
    }

    return options;
  }

  Future<List<_SalonBranchOption>> _loadBaseOptions() async {
    if (widget.isOwnerMode) {
      final response = await _apiService.getSalonListApi();
      final data = (response['data'] as List?) ?? const [];
      final options = _buildOptionsFromSalons(data);
      if (options.isNotEmpty) {
        return options;
      }
      return _buildOptionsFromSalons(
        await UserRoleSession.instance.loadUserSalons(),
      );
    }

    var options = _buildOptionsFromUserBranches(
      await UserRoleSession.instance.loadUserBranches(),
    );
    if (options.isNotEmpty) {
      return options;
    }

    options = _buildOptionsFromSalons(
      await UserRoleSession.instance.loadUserSalons(),
    );
    if (options.isNotEmpty) {
      return options;
    }

    final response = await _apiService.getSalonListApi();
    final data = (response['data'] as List?) ?? const [];
    return _buildOptionsFromSalons(data);
  }

  Future<_BookingsFetchResult> _fetchBookingsForBranch({
    required int branchId,
    int? userId,
  }) async {
    try {
      final response = widget.isOwnerMode
          ? await _apiService.fetchAppointments(
              branchId,
              _formatApiDate(_selectedDate),
            )
          : await _apiService.fetchTeamAppointmentsByDate(
              branchId,
              userId!,
              _formatApiDate(_selectedDate),
            );
      final rawData = response['data'];
      final bookings = rawData is List
          ? rawData
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const <Map<String, dynamic>>[];
      return _BookingsFetchResult(
        bookings: bookings,
        errorMessage: response['success'] == true
            ? null
            : response['message']?.toString(),
      );
    } catch (e) {
      return _BookingsFetchResult(
        bookings: const [],
        errorMessage: e.toString(),
      );
    }
  }

  String _weekdayKey(DateTime value) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[value.weekday - 1];
  }

  bool _memberIsEmployedOnDate(
    Map<String, dynamic> branchEntry,
    DateTime date,
  ) {
    final selectedDate = _dateOnly(date);
    final joiningDate = _parseDateOnly(branchEntry['joiningDate']);
    if (joiningDate != null && joiningDate.isAfter(selectedDate)) {
      return false;
    }

    final leavingDate = _parseDateOnly(branchEntry['leavingDate']);
    if (leavingDate != null && leavingDate.isBefore(selectedDate)) {
      return false;
    }

    return true;
  }

  bool _memberHasFutureJoiningDate(
    Map<String, dynamic> branchEntry,
    DateTime date,
  ) {
    final joiningDate = _parseDateOnly(branchEntry['joiningDate']);
    return joiningDate != null && joiningDate.isAfter(_dateOnly(date));
  }

  bool _memberHasPastLeavingDate(
    Map<String, dynamic> branchEntry,
    DateTime date,
  ) {
    final leavingDate = _parseDateOnly(branchEntry['leavingDate']);
    return leavingDate != null && leavingDate.isBefore(_dateOnly(date));
  }

  bool _memberHasScheduleOnDate(
    Map<String, dynamic> branchEntry,
    Map<String, dynamic> member,
    DateTime date,
  ) {
    final schedules = _teamMemberScheduleItems(branchEntry, member);
    if (schedules.isEmpty) return false;

    final targetDay = _weekdayKey(date);
    for (final schedule in schedules) {
      final day = schedule['day']?.toString().trim().toLowerCase() ?? '';
      if (day != targetDay) continue;
      final start =
          (schedule['startTime'] ?? schedule['start'])?.toString().trim() ?? '';
      final end =
          (schedule['endTime'] ?? schedule['end'])?.toString().trim() ?? '';
      if (start.isNotEmpty && end.isNotEmpty) return true;
    }

    return false;
  }

  String _dayDisplayLabel(String day) {
    final normalized = day.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    return '${normalized.substring(0, 1).toUpperCase()}${normalized.substring(1)}';
  }

  int _weekdaySortOrder(String day) {
    const order = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    return order[day.trim().toLowerCase()] ?? 99;
  }

  dynamic _rawTeamMemberSchedules(
    Map<String, dynamic> branchEntry,
    Map<String, dynamic> member,
  ) {
    for (final value in [
      branchEntry['schedules'],
      member['schedules'],
    ]) {
      if (value is List && value.isNotEmpty) return value;
      if (value is Map && value.isNotEmpty) return value;
    }
    return null;
  }

  List<Map<String, dynamic>> _teamMemberScheduleItems(
    Map<String, dynamic> branchEntry,
    Map<String, dynamic> member,
  ) {
    final raw = _rawTeamMemberSchedules(branchEntry, member);
    if (raw is List) {
      final items = <Map<String, dynamic>>[];
      for (final item in raw.whereType<Map>()) {
        _addTeamMemberScheduleItems(
          items,
          Map<String, dynamic>.from(item),
        );
      }
      return items;
    }
    if (raw is Map) {
      final items = <Map<String, dynamic>>[];
      raw.forEach((key, value) {
        final day = key.toString().trim().toLowerCase();
        if (day.isEmpty) return;
        if (value is List) {
          for (final slot in value.whereType<Map>()) {
            _addTeamMemberScheduleItems(
              items,
              Map<String, dynamic>.from(slot),
              fallbackDay: day,
            );
          }
          return;
        }
        if (value is Map) {
          _addTeamMemberScheduleItems(
            items,
            Map<String, dynamic>.from(value),
            fallbackDay: day,
          );
        }
      });
      return items;
    }
    return const <Map<String, dynamic>>[];
  }

  void _addTeamMemberScheduleItems(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> schedule, {
    String? fallbackDay,
  }) {
    final day =
        (schedule['day'] ?? fallbackDay ?? '').toString().trim().toLowerCase();
    if (day.isEmpty) return;

    final slots = schedule['slots'];
    if (slots is List) {
      for (final slot in slots.whereType<Map>()) {
        items.add({
          'day': day,
          ...Map<String, dynamic>.from(slot),
        });
      }
      return;
    }

    items.add({
      'day': day,
      ...schedule,
    });
  }

  List<_WorkingDayHours> _workingHoursFromTeamMember(
    Map<String, dynamic> branchEntry,
    Map<String, dynamic> member,
  ) {
    final schedules = _teamMemberScheduleItems(branchEntry, member);
    if (schedules.isEmpty) {
      return const <_WorkingDayHours>[];
    }

    final slotsByDay = <String, List<String>>{};
    final rangesByDay = <String, List<_WorkingHourRange>>{};
    for (final schedule in schedules) {
      final day = schedule['day']?.toString().trim().toLowerCase() ?? '';
      final startMinute =
          _clockMinutes(schedule['startTime'] ?? schedule['start']);
      final endMinute = _clockMinutes(schedule['endTime'] ?? schedule['end']);
      if (day.isEmpty || startMinute == null || endMinute == null) continue;
      if (endMinute <= startMinute) continue;
      slotsByDay.putIfAbsent(day, () => <String>[]).add(
            '${_formatMinutesLabel(startMinute)} - ${_formatMinutesLabel(endMinute)}',
          );
      rangesByDay.putIfAbsent(day, () => <_WorkingHourRange>[]).add(
            _WorkingHourRange(
              startMinute: startMinute,
              endMinute: endMinute,
            ),
          );
    }

    final orderedDays = slotsByDay.keys.toList()
      ..sort((first, second) =>
          _weekdaySortOrder(first).compareTo(_weekdaySortOrder(second)));
    return orderedDays
        .map(
          (day) => _WorkingDayHours(
            day: _dayDisplayLabel(day),
            slots: slotsByDay[day] ?? const <String>[],
            ranges: rangesByDay[day] ?? const <_WorkingHourRange>[],
          ),
        )
        .toList();
  }

  _TeamMemberDirectory _emptyTeamMemberDirectory() {
    return const _TeamMemberDirectory();
  }

  Future<_TeamMemberDirectory> _fetchTeamMemberDirectory(
    int branchId, {
    required DateTime date,
  }) async {
    try {
      final response = await ApiService.getTeamMembers(branchId);
      final data = (response['data'] as List?) ?? const [];
      final serviceNamesByMember = <String, List<String>>{};
      final workingHoursByMember = <String, List<_WorkingDayHours>>{};
      final namesByUserId = <int, String>{};
      final namesByUserBranchId = <int, String>{};
      var hasBranchTeamMember = false;
      var hasFutureJoiningDateMember = false;
      var hasPastLeavingDateMember = false;
      var hasEmployedMemberWithoutSchedule = false;

      for (final item in data) {
        if (item is! Map) continue;
        final member = Map<String, dynamic>.from(item);
        final name = _personName(member).trim();
        if (name.isEmpty) continue;

        final memberUserId = _asInt(member['id']);
        if (memberUserId != null) {
          namesByUserId[memberUserId] = name;
        }

        final services = <String>[];
        final seen = <String>{};
        var worksOnSelectedDate = false;
        final assignments = member['userBranches'];
        if (assignments is List) {
          for (final assignment in assignments) {
            if (assignment is! Map) continue;
            final branchEntry = Map<String, dynamic>.from(assignment);
            final branch = branchEntry['branch'];
            final rawBranchId =
                branch is Map ? branch['id'] : branchEntry['branchId'];
            final memberBranchId = rawBranchId is int
                ? rawBranchId
                : rawBranchId is num
                    ? rawBranchId.toInt()
                    : int.tryParse('${rawBranchId ?? ''}');
            if (memberBranchId != branchId) {
              continue;
            }

            final isActive = _readBool(branchEntry['active']) ?? true;
            final allowOnlineBooking =
                _readBool(branchEntry['allowOnlineBooking']) ?? true;

            if (!isActive || !allowOnlineBooking) {
              continue;
            }

            hasBranchTeamMember = true;

            final workingHours = _workingHoursFromTeamMember(
              branchEntry,
              member,
            );
            if (workingHours.isNotEmpty) {
              workingHoursByMember[name] = workingHours;
            }

            if (!_memberIsEmployedOnDate(branchEntry, date)) {
              if (_memberHasFutureJoiningDate(branchEntry, date)) {
                hasFutureJoiningDateMember = true;
              } else if (_memberHasPastLeavingDate(branchEntry, date)) {
                hasPastLeavingDateMember = true;
              }
              continue;
            }

            if (!_memberHasScheduleOnDate(branchEntry, member, date)) {
              hasEmployedMemberWithoutSchedule = true;
              continue;
            }
            worksOnSelectedDate = true;

            for (final key in const [
              'userBranchId',
              'user_branch_id',
              'assignedUserBranchId',
              'assigned_user_branch_id',
              'assignmentId',
              'assignment_id',
            ]) {
              final userBranchId = _asInt(branchEntry[key]);
              if (userBranchId != null) {
                namesByUserBranchId[userBranchId] = name;
              }
            }

            final userBranchServices = branchEntry['userBranchServices'];
            if (userBranchServices is! List) continue;
            for (final rawService in userBranchServices) {
              if (rawService is! Map) continue;
              final branchService = rawService['branchService'];
              if (branchService is! Map) continue;
              final serviceName =
                  (branchService['displayName'] ?? branchService['name'] ?? '')
                      .toString()
                      .trim();
              if (serviceName.isEmpty) continue;
              if (seen.add(serviceName.toLowerCase())) {
                services.add(serviceName);
              }
            }
          }
        }

        if (worksOnSelectedDate) {
          serviceNamesByMember[name] = services;
        }
      }

      var noMembersReason = _NoTeamMembersForDateReason.none;
      if (serviceNamesByMember.isEmpty && hasBranchTeamMember) {
        if (hasEmployedMemberWithoutSchedule) {
          noMembersReason = _NoTeamMembersForDateReason.notScheduled;
        } else if (hasFutureJoiningDateMember) {
          noMembersReason = _NoTeamMembersForDateReason.joiningDate;
        } else if (hasPastLeavingDateMember) {
          noMembersReason = _NoTeamMembersForDateReason.employmentDate;
        } else {
          noMembersReason = _NoTeamMembersForDateReason.notScheduled;
        }
      }

      return _TeamMemberDirectory(
        serviceNames: serviceNamesByMember,
        workingHours: workingHoursByMember,
        namesByUserId: namesByUserId,
        namesByUserBranchId: namesByUserBranchId,
        noMembersReason: noMembersReason,
      );
    } catch (e) {
      debugPrint('[BookingsTeamMemberServices] failed=$e');
      return _emptyTeamMemberDirectory();
    }
  }

  Future<void> _loadOptions({
    bool showPageLoader = true,
    bool showInlineLoader = false,
  }) async {
    setState(() {
      if (showPageLoader) _isLoading = true;
      if (showInlineLoader) _loadingDate = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    String? errorMessage;
    List<_SalonBranchOption> options = const [];
    try {
      options = await _loadBaseOptions();
    } catch (e) {
      errorMessage = e.toString();
    }

    final saved = await StylistBranchSelectionStore.load();
    _SalonBranchOption? selected;
    if (saved.branchId != null) {
      for (final option in options) {
        if (option.branchId == saved.branchId) {
          selected = option;
          break;
        }
      }
    }
    selected ??= options.isNotEmpty ? options.first : null;

    if (selected != null) {
      await StylistBranchSelectionStore.save(
        salonId: selected.salonId,
        branchId: selected.branchId,
        salonName: selected.salonName,
        branchName: selected.branchName,
      );
    }

    List<Map<String, dynamic>> bookings = const [];
    List<String> teamMemberNames = const [];
    Map<String, List<String>> teamMemberServiceNames =
        const <String, List<String>>{};
    _TeamMemberDirectory teamMemberDirectory = _emptyTeamMemberDirectory();
    if (selected != null && (widget.isOwnerMode || userId != null)) {
      final result = await _fetchBookingsForBranch(
        branchId: selected.branchId,
        userId: userId,
      );
      bookings = result.bookings;
      errorMessage ??= result.errorMessage;
      if (widget.isOwnerMode) {
        teamMemberDirectory = await _fetchTeamMemberDirectory(
          selected.branchId,
          date: _selectedDate,
        );
        teamMemberServiceNames = teamMemberDirectory.serviceNames;
        teamMemberNames = teamMemberDirectory.names;
      }
    } else if (selected != null && !widget.isOwnerMode && userId == null) {
      errorMessage ??= 'Unable to load stylist bookings';
    }

    if (!mounted) return;
    _logBookingsFetchSnapshot(context, bookings, source: 'load_options');
    setState(() {
      _options = options;
      _selectedOption = selected;
      _userId = widget.isOwnerMode ? null : userId;
      _bookings = bookings;
      _teamMemberNames = teamMemberNames;
      _teamMemberServiceNames = teamMemberServiceNames;
      _teamMemberWorkingHours = teamMemberDirectory.workingHours;
      _teamMemberNamesByUserId = teamMemberDirectory.namesByUserId;
      _teamMemberNamesByUserBranchId = teamMemberDirectory.namesByUserBranchId;
      _noTeamMembersForDateReason = teamMemberDirectory.noMembersReason;
      _errorMessage = errorMessage;
      _isLoading = false;
      _loadingDate = false;
    });
  }

  Future<void> _reloadBookingsForSelectedOption() async {
    final selected = _selectedOption;
    if (selected == null) return;
    if (!widget.isOwnerMode && _userId == null) return;

    final result = await _fetchBookingsForBranch(
      branchId: selected.branchId,
      userId: _userId,
    );
    final teamMemberDirectory = widget.isOwnerMode
        ? await _fetchTeamMemberDirectory(selected.branchId,
            date: _selectedDate)
        : _TeamMemberDirectory(
            serviceNames: _teamMemberServiceNames,
            workingHours: _teamMemberWorkingHours,
            namesByUserId: _teamMemberNamesByUserId,
            namesByUserBranchId: _teamMemberNamesByUserBranchId,
            noMembersReason: _noTeamMembersForDateReason,
          );
    final teamMemberServiceNames = widget.isOwnerMode
        ? teamMemberDirectory.serviceNames
        : _teamMemberServiceNames;
    final teamMemberNames =
        widget.isOwnerMode ? teamMemberDirectory.names : _teamMemberNames;

    if (!mounted) return;
    _logBookingsFetchSnapshot(
      context,
      result.bookings,
      source: 'reload_bookings',
    );
    setState(() {
      _bookings = result.bookings;
      _teamMemberNames = teamMemberNames;
      _teamMemberServiceNames = teamMemberServiceNames;
      _teamMemberWorkingHours = teamMemberDirectory.workingHours;
      _teamMemberNamesByUserId = teamMemberDirectory.namesByUserId;
      _teamMemberNamesByUserBranchId = teamMemberDirectory.namesByUserBranchId;
      _noTeamMembersForDateReason = teamMemberDirectory.noMembersReason;
      _errorMessage = result.errorMessage;
    });
  }

  Future<void> _selectOption(_SalonBranchOption option) async {
    await StylistBranchSelectionStore.save(
      salonId: option.salonId,
      branchId: option.branchId,
      salonName: option.salonName,
      branchName: option.branchName,
    );

    setState(() {
      _selectedOption = option;
      _loadingDate = true;
      _errorMessage = null;
    });

    List<Map<String, dynamic>> bookings = const [];
    List<String> teamMemberNames = _teamMemberNames;
    Map<String, List<String>> teamMemberServiceNames = _teamMemberServiceNames;
    _TeamMemberDirectory teamMemberDirectory = _TeamMemberDirectory(
      serviceNames: _teamMemberServiceNames,
      workingHours: _teamMemberWorkingHours,
      namesByUserId: _teamMemberNamesByUserId,
      namesByUserBranchId: _teamMemberNamesByUserBranchId,
      noMembersReason: _noTeamMembersForDateReason,
    );
    String? errorMessage;
    if (!widget.isOwnerMode && _userId == null) {
      errorMessage = 'Unable to load stylist bookings';
    } else {
      final result = await _fetchBookingsForBranch(
        branchId: option.branchId,
        userId: _userId,
      );
      bookings = result.bookings;
      errorMessage = result.errorMessage;
      if (widget.isOwnerMode) {
        teamMemberDirectory = await _fetchTeamMemberDirectory(
          option.branchId,
          date: _selectedDate,
        );
        teamMemberServiceNames = teamMemberDirectory.serviceNames;
        teamMemberNames = teamMemberDirectory.names;
      }
    }

    if (!mounted) return;
    _logBookingsFetchSnapshot(context, bookings, source: 'select_branch');
    setState(() {
      _bookings = bookings;
      _teamMemberNames = teamMemberNames;
      _teamMemberServiceNames = teamMemberServiceNames;
      _teamMemberWorkingHours = teamMemberDirectory.workingHours;
      _teamMemberNamesByUserId = teamMemberDirectory.namesByUserId;
      _teamMemberNamesByUserBranchId = teamMemberDirectory.namesByUserBranchId;
      _noTeamMembersForDateReason = teamMemberDirectory.noMembersReason;
      _errorMessage = errorMessage;
      _loadingDate = false;
    });
  }

  Future<void> _setSelectedDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final selected = _selectedOption;
    final userId = _userId;

    setState(() {
      _selectedDate = normalizedDate;
      _loadingDate = true;
      _errorMessage = null;
    });

    List<Map<String, dynamic>> bookings = const [];
    String? errorMessage;
    _TeamMemberDirectory teamMemberDirectory = _TeamMemberDirectory(
      serviceNames: _teamMemberServiceNames,
      workingHours: _teamMemberWorkingHours,
      namesByUserId: _teamMemberNamesByUserId,
      namesByUserBranchId: _teamMemberNamesByUserBranchId,
      noMembersReason: _noTeamMembersForDateReason,
    );

    if (selected != null && (widget.isOwnerMode || userId != null)) {
      final result = await _fetchBookingsForBranch(
        branchId: selected.branchId,
        userId: userId,
      );
      bookings = result.bookings;
      errorMessage = result.errorMessage;
      if (widget.isOwnerMode) {
        teamMemberDirectory = await _fetchTeamMemberDirectory(
          selected.branchId,
          date: normalizedDate,
        );
      }
    }

    if (!mounted) return;
    _logBookingsFetchSnapshot(context, bookings, source: 'select_date');
    setState(() {
      _bookings = bookings;
      if (widget.isOwnerMode) {
        _teamMemberNames = teamMemberDirectory.names;
        _teamMemberServiceNames = teamMemberDirectory.serviceNames;
        _teamMemberWorkingHours = teamMemberDirectory.workingHours;
        _teamMemberNamesByUserId = teamMemberDirectory.namesByUserId;
        _teamMemberNamesByUserBranchId =
            teamMemberDirectory.namesByUserBranchId;
        _noTeamMembersForDateReason = teamMemberDirectory.noMembersReason;
      }
      _errorMessage = errorMessage;
      _loadingDate = false;
    });
  }

  void _shiftVisibleDates(int days) {
    setState(() {
      _visibleDateStart = _visibleDateStart.add(Duration(days: days));
    });
  }

  List<_BookingViewTab> get _bookingViewTabs => widget.isOwnerMode
      ? const <_BookingViewTab>[
          _BookingViewTab.teamMembers,
          _BookingViewTab.schedule,
          // _BookingViewTab.recent,
        ]
      : const <_BookingViewTab>[
          _BookingViewTab.schedule,
          _BookingViewTab.recent,
        ];

  int _safeBookingViewIndex(List<_BookingViewTab> tabs) {
    if (tabs.isEmpty) return 0;
    if (_selectedBookingView < 0) return 0;
    if (_selectedBookingView >= tabs.length) return tabs.length - 1;
    return _selectedBookingView;
  }

  String _bookingViewLabel(BuildContext context, _BookingViewTab tab) {
    return switch (tab) {
      _BookingViewTab.teamMembers => context.t('Team Members'),
      _BookingViewTab.schedule => context.t('Schedule'),
      _BookingViewTab.recent => context.t('Recent'),
    };
  }

  bool get _isRecentBookingView {
    final tabs = _bookingViewTabs;
    if (tabs.isEmpty) return false;
    return tabs[_safeBookingViewIndex(tabs)] == _BookingViewTab.recent;
  }

  bool get _isScheduleBookingView {
    final tabs = _bookingViewTabs;
    if (tabs.isEmpty) return false;
    return tabs[_safeBookingViewIndex(tabs)] == _BookingViewTab.schedule;
  }

  bool _isCompletedStatus(String status) {
    return status == 'COMPLETED' || status == 'COMPLETE';
  }

  bool _isUpcomingScheduleStatus(String status) {
    return !_isCompletedStatus(status) &&
        status != 'IN_PROGRESS' &&
        status != 'STARTED' &&
        status != 'CANCELLED' &&
        status != 'CANCELED' &&
        status != 'NO_SHOW' &&
        status != 'PENDING';
  }

  List<Map<String, dynamic>> _sortedBookings() {
    final items = [..._bookings];
    items.sort((a, b) {
      final first = _bookingStart(a);
      final second = _bookingStart(b);
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });
    return items;
  }

  List<Map<String, dynamic>> _bookingsForCurrentView(
    List<Map<String, dynamic>> sortedBookings,
  ) {
    final teamFilteredBookings = widget.isOwnerMode
        ? sortedBookings
        : sortedBookings.where(_shouldShowBookingForActiveTeam).toList();

    if (_isRecentBookingView) {
      return teamFilteredBookings
          .where((booking) {
            final status = _normalizeStatus(booking['status']);
            return _isCompletedStatus(status);
          })
          .toList()
          .reversed
          .toList();
    }
    if (!widget.isOwnerMode && _isScheduleBookingView) {
      return teamFilteredBookings.where((booking) {
        final status = _normalizeStatus(booking['status']);
        return _isUpcomingScheduleStatus(status);
      }).toList();
    }
    return teamFilteredBookings;
  }

  bool _shouldShowBookingForActiveTeam(Map<String, dynamic> booking) {
    return true;
  }

  List<String> _assignedStaffNamesForGrouping(
    Map<String, dynamic> booking,
  ) {
    final names = <String>[];
    final seen = <String>{};

    void addName(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        names.add(normalized);
      }
    }

    void addFromUserId(dynamic value) {
      final id = _asInt(value);
      if (id == null) return;
      addName(_teamMemberNamesByUserId[id] ?? '');
    }

    void addFromUserBranchId(dynamic value) {
      final id = _asInt(value);
      if (id == null) return;
      addName(_teamMemberNamesByUserBranchId[id] ?? '');
    }

    for (final name in _assignedStaffNames(booking)) {
      addName(name);
    }

    addName(_personName(booking['assignedUserBranch']?['user']));
    addName(_personName(booking['professional']));
    addFromUserId(booking['professional']?['id']);
    addFromUserId(booking['assignedUserId']);
    addFromUserId(booking['teamMemberId']);
    addFromUserBranchId(booking['assignedUserBranchId']);
    addFromUserBranchId(booking['userBranchId']);
    addFromUserBranchId(booking['assignedUserBranch']?['id']);
    addFromUserId(booking['assignedUserBranch']?['user']?['id']);

    for (final item in _bookingItems(booking)) {
      addName(_personName(item['assignedUserBranch']?['user']));
      addName(_personName(item['professional']));
      addFromUserId(item['professional']?['id']);
      addFromUserId(item['assignedUserId']);
      addFromUserId(item['teamMemberId']);
      addFromUserBranchId(item['assignedUserBranchId']);
      addFromUserBranchId(item['userBranchId']);
      addFromUserBranchId(item['assignedUserBranch']?['id']);
      addFromUserId(item['assignedUserBranch']?['user']?['id']);
    }

    return names;
  }

  // Map<String, List<Map<String, dynamic>>> _groupBookingsByStaff(
  //     BuildContext context, List<Map<String, dynamic>> bookings,
  //     {bool includeEmptyTeamMembers = false}) {
  //   final groups = <String, List<Map<String, dynamic>>>{};
  //   for (final booking in bookings) {
  //     final labels = _assignedStaffNamesForGrouping(booking);
  //   //   if (labels.isEmpty) {
  //   //     final key = context.t('Unassigned');
  //   //     groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(booking);
  //   //     continue;
  //   //   }
  //   //   for (final label in labels) {
  //   //     groups.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(booking);
  //   //   }
  //   // }
  //   for (final booking in bookings) {
  // final labels = _assignedStaffNamesForGrouping(booking);

  // if (labels.isEmpty) {
  //   continue;
  // }

  // for (final label in labels) {
  //   groups.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(booking);
  // }
  //   }}
  //   if (includeEmptyTeamMembers) {
  //     for (final name in _teamMemberNames) {
  //       groups.putIfAbsent(name, () => <Map<String, dynamic>>[]);
  //     }
  //   }
  //   return groups;
  // }

  Map<String, List<Map<String, dynamic>>> _groupBookingsByStaff(
    BuildContext context,
    List<Map<String, dynamic>> bookings, {
    bool includeEmptyTeamMembers = false,
  }) {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final booking in bookings) {
      final labels = _assignedStaffNamesForGrouping(booking);

      if (labels.isEmpty) continue;

      for (final label in labels) {
        groups.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(booking);
      }
    }

    if (includeEmptyTeamMembers) {
      for (final name in _teamMemberNames) {
        groups.putIfAbsent(name, () => <Map<String, dynamic>>[]);
      }
    }

    return groups;
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = _normalizeStatus(booking['status']);
    return _BookingListCard(
      booking: booking,
      assignedStaffLabel:
          widget.isOwnerMode ? _assignedStaffSummary(context, booking) : '',
      isOwnerMode: widget.isOwnerMode,
      onTap: () => _openBookingDetail(booking),
      // onPrimaryActionTap: _showsConfirmAction(
      //   status,
      //   isOwnerMode: widget.isOwnerMode,
      // )
      //     ? () => _handleConfirmFromList(booking)
      //     : _showsStartAction(status)
      //         ? () => _handleStartFromList(booking)
      //         : _showsFinishAction(status)
      //             ? () => _handleCompleteFromList(booking)
      //             : null,
      onPrimaryActionTap: _showsConfirmAction(
        status,
        isOwnerMode: widget.isOwnerMode,
      )
          ? () => _handleConfirmFromList(booking)
          : _showsStartAction(status)
              ? (_canStartJob(booking)
                  ? () => _handleStartFromList(booking)
                  : null)
              : _showsFinishAction(status)
                  ? () => _handleCompleteFromList(booking)
                  : null,
      isProcessing: (_confirmingAppointmentId != null &&
              _confirmingAppointmentId == _asInt(booking['id'])) ||
          (_startingAppointmentId != null &&
              _startingAppointmentId == _asInt(booking['id'])) ||
          (_completingAppointmentId != null &&
              _completingAppointmentId == _asInt(booking['id'])),
    );
  }

  Future<void> _openBranchPicker() async {
    if (_options.isEmpty) return;

    final selectorContext = _branchSelectorKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final selectorBox = selectorContext?.findRenderObject() as RenderBox?;
    if (overlay == null || selectorBox == null) return;

    final selectorOffset = selectorBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final selectorRect = selectorOffset & selectorBox.size;
    final menuWidth = overlay.size.width - 32;

    final selected = await showMenu<_SalonBranchOption>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      position: RelativeRect.fromLTRB(
        16,
        selectorRect.bottom + 8,
        16,
        0,
      ),
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _bookingsBorder),
      ),
      items: _options.map((option) {
        final isSelected = option.branchId == _selectedOption?.branchId;
        return PopupMenuItem<_SalonBranchOption>(
          value: option,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: _BranchDropdownItem(
            option: option,
            isSelected: isSelected,
          ),
        );
      }).toList(),
    );

    if (!mounted || selected == null) return;
    await _selectOption(selected);
  }

  Future<void> _openBookingDetail(Map<String, dynamic> booking) async {
    final selected = _selectedOption;
    if (selected == null) return;

    _logBookingDetailsSnapshot(context, booking);

    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _StylistBookingDetailScreen(
          booking: Map<String, dynamic>.from(booking),
          branchId: selected.branchId,
          isOwnerMode: widget.isOwnerMode,
        ),
      ),
    );

    if (shouldRefresh == true) {
      await _reloadBookingsForSelectedOption();
    }
  }

  void _openTeamMemberSchedule(
    String staffName,
    List<Map<String, dynamic>> bookings,
  ) {
    final selectedOption = _selectedOption;
    final selectedDaySlots = _selectedOption?.slotsForDate(_selectedDate) ??
        const <_BranchDaySlot>[];
    final selectedStartMinute = selectedDaySlots.isNotEmpty
        ? selectedDaySlots.first.startMinute
        : _selectedOption?.startMinute;
    final selectedEndMinute = selectedDaySlots.isNotEmpty
        ? selectedDaySlots
            .map((slot) => slot.endMinute)
            .reduce((first, second) => first > second ? first : second)
        : _selectedOption?.endMinute;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TeamMemberScheduleScreen(
          staffName: staffName,
          bookings: bookings,
          serviceNames: _teamMemberServiceNames[staffName] ?? const [],
          workingHours: _teamMemberWorkingHours[staffName] ?? const [],
          salonWorkingHours: _workingHoursFromBranchOption(selectedOption),
          selectedDate: _selectedDate,
          branchId: selectedOption?.branchId,
          branchStartMinute: selectedStartMinute,
          branchEndMinute: selectedEndMinute,
          onBookingTap: _openBookingDetail,
        ),
      ),
    );
  }

  List<_WorkingDayHours> _workingHoursFromBranchOption(
    _SalonBranchOption? option,
  ) {
    if (option == null) return const <_WorkingDayHours>[];

    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final result = <_WorkingDayHours>[];
    if (option.hasWeeklySchedule) {
      for (final day in days) {
        final slots = option.weeklySlots[day] ?? const <_BranchDaySlot>[];
        if (slots.isEmpty) continue;
        result.add(
          _WorkingDayHours(
            day: _dayDisplayLabel(day),
            slots: slots
                .map(
                  (slot) =>
                      '${_formatMinutesLabel(slot.startMinute)} - ${_formatMinutesLabel(slot.endMinute)}',
                )
                .toList(),
            ranges: slots
                .map(
                  (slot) => _WorkingHourRange(
                    startMinute: slot.startMinute,
                    endMinute: slot.endMinute,
                  ),
                )
                .toList(),
          ),
        );
      }
      return result;
    }

    final startMinute = option.startMinute;
    final endMinute = option.endMinute;
    if (startMinute == null || endMinute == null || endMinute <= startMinute) {
      return const <_WorkingDayHours>[];
    }

    final slotLabel =
        '${_formatMinutesLabel(startMinute)} - ${_formatMinutesLabel(endMinute)}';
    final range = _WorkingHourRange(
      startMinute: startMinute,
      endMinute: endMinute,
    );
    return days
        .map(
          (day) => _WorkingDayHours(
            day: _dayDisplayLabel(day),
            slots: [slotLabel],
            ranges: [range],
          ),
        )
        .toList();
  }

  Future<void> _handleConfirmFromList(Map<String, dynamic> booking) async {
    final selected = _selectedOption;
    final appointmentId = _asInt(booking['id']);
    if (selected == null ||
        appointmentId == null ||
        _confirmingAppointmentId != null) {
      return;
    }

    setState(() => _confirmingAppointmentId = appointmentId);
    final resp = await ApiService().confirmAppointment(
      branchId: selected.branchId,
      appointmentId: appointmentId,
    );
    if (!mounted) return;
    setState(() => _confirmingAppointmentId = null);

    if (resp['success'] == true) {
      booking['status'] = _normalizeStatus(
        resp['data']?['status'] ?? 'CONFIRMED',
      );
      Fluttertoast.showToast(
          msg: resp['message']?.toString() ??
              translateText('Booking Confirmed'));
      await _reloadBookingsForSelectedOption();
      return;
    }

    Fluttertoast.showToast(
        msg: resp['message']?.toString() ?? 'Failed to confirm appointment');
  }

  int? _selectedDateBranchEndMinute() {
    final selected = _selectedOption;
    if (selected == null) return null;

    final selectedDaySlots = selected.slotsForDate(_selectedDate);

    if (selectedDaySlots.isNotEmpty) {
      return selectedDaySlots
          .map((slot) => slot.endMinute)
          .reduce((first, second) => first > second ? first : second);
    }

    return selected.endMinute;
  }

  bool _isSelectedBranchBookingWindowOver() {
    final selected = _selectedOption;
    if (selected == null) return false;

    final today = _dateOnly(DateTime.now());
    final selectedDate = _dateOnly(_selectedDate);

    // Only block for today's date.
    // Future dates should still allow booking.
    if (!_isSameDay(today, selectedDate)) return false;

    final branchEndMinute = _selectedDateBranchEndMinute();
    if (branchEndMinute == null) return false;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return nowMinutes >= branchEndMinute;
  }

  String _selectedBranchEndTimeLabel() {
    final endMinute = _selectedDateBranchEndMinute();
    if (endMinute == null) return '';
    return _formatMinutesLabel(endMinute);
  }

  String? _noTeamMembersBlockedReason() {
    if (_teamMemberNames.isNotEmpty) return null;

    switch (_noTeamMembersForDateReason) {
      case _NoTeamMembersForDateReason.joiningDate:
        return context.t(
          'Team members whose joining date is later than the selected date are hidden from the schedule.',
        );
      case _NoTeamMembersForDateReason.employmentDate:
        return context.t(
          'Team members are hidden when their employment dates do not include the selected date.',
        );
      case _NoTeamMembersForDateReason.notScheduled:
        return context.t(
          'Team members who do not have working hours on the selected day are hidden from the schedule.',
        );
      case _NoTeamMembersForDateReason.none:
        return context.t('No team member available for this date');
    }
  }

  List<String> _addBookingBlockedReasons() {
    final reasons = <String>[];
    final selected = _selectedOption;

    if (selected == null) {
      reasons.add(translateText('Please select a salon'));
      return reasons;
    }

    if (!selected.canAcceptBookings) {
      reasons.add(
        !selected.isSalonActive
            ? translateText('This salon is inactive. Booking is disabled.')
            : translateText('This branch is inactive. Booking is disabled.'),
      );
    }

    if (selected.isClosedOnDate(_selectedDate)) {
      reasons.add(translateText('Salon is closed on the selected date'));
    }

    if (_isSelectedBranchBookingWindowOver()) {
      final endTime = _selectedBranchEndTimeLabel();
      reasons.add(
        endTime.isEmpty
            ? translateText('Booking time is over for today')
            : translateText(
                'Booking time is over for today. Branch closed at $endTime',
              ),
      );
    }

    if (widget.isOwnerMode && _teamMemberNames.isEmpty) {
      final reason = _noTeamMembersBlockedReason();
      if (reason != null && reason.isNotEmpty) {
        reasons.add(reason);
      }
    }

    return reasons;
  }

  void _showBlockedBookingToast(List<String> reasons) {
    if (reasons.isEmpty) return;

    final message = reasons.length == 1
        ? reasons.first
        : [
            translateText('Cannot add booking:'),
            ...reasons.asMap().entries.map(
                  (entry) => '${entry.key + 1}. ${entry.value}',
                ),
          ].join('\n');

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: const Color(0xFF1C1917),
      textColor: Colors.white,
      fontSize: 14,
    );
  }
  // Future<void> _openAddBooking() async {
  //   final selected = _selectedOption;
  //   if (selected == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(translateText('Please select a salon'))),
  //     );
  //     return;
  //   }
  //   if (selected.isClosedOnDate(_selectedDate)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           translateText('Salon is closed on the selected date'),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => AddBookingScreen(
  //         salonId: selected.salonId,
  //         branchId: selected.branchId,
  //       ),
  //     ),
  //   );

  //   if (!mounted || result == null) return;
  //   setState(() => _selectedBookingView = 0);
  //   await _reloadBookingsForSelectedOption();
  // }
  Future<void> _openAddBooking() async {
    final reasons = _addBookingBlockedReasons();
    if (reasons.isNotEmpty) {
      _showBlockedBookingToast(reasons);
      return;
    }

    final selected = _selectedOption;
    if (selected == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookingScreen(
          salonId: selected.salonId,
          branchId: selected.branchId,
          initialDate: _selectedDate,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() => _selectedBookingView = 0);
    await _reloadBookingsForSelectedOption();
  }
  // Future<void> _handleStartFromList(Map<String, dynamic> booking) async {
  //   final selected = _selectedOption;
  //   final appointmentId = _asInt(booking['id']);
  //   if (selected == null ||
  //       appointmentId == null ||
  //       _startingAppointmentId != null) {
  //     return;
  //   }

  //   setState(() => _startingAppointmentId = appointmentId);
  //   final resp = await _showStartJobOtpDialog(
  //     context,
  //     branchId: selected.branchId,
  //     appointmentId: appointmentId,
  //   );
  //   if (!mounted) return;
  //   setState(() => _startingAppointmentId = null);
  //   if (resp == null) return;

  //   final newStatus =
  //       _normalizeStatus(resp['data']?['status'] ?? 'IN_PROGRESS');
  //   booking['status'] = newStatus;
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(resp['message']?.toString() ?? 'Job started'),
  //     ),
  //   );
  //   await _reloadBookingsForSelectedOption();
  // }
  Future<void> _handleStartFromList(Map<String, dynamic> booking) async {
    final selected = _selectedOption;
    final appointmentId = _asInt(booking['id']);

    if (!_canStartJob(booking)) {
      Fluttertoast.showToast(
        msg: translateText(
          'You can start this job 15 minutes before appointment time',
        ),
      );
      return;
    }

    if (selected == null ||
        appointmentId == null ||
        _startingAppointmentId != null) {
      return;
    }

    setState(() => _startingAppointmentId = appointmentId);

    final resp = await _showStartJobOtpDialog(
      context,
      branchId: selected.branchId,
      appointmentId: appointmentId,
    );

    if (!mounted) return;

    setState(() => _startingAppointmentId = null);

    if (resp == null) return;

    final newStatus =
        _normalizeStatus(resp['data']?['status'] ?? 'IN_PROGRESS');

    booking['status'] = newStatus;

    Fluttertoast.showToast(msg: resp['message']?.toString() ?? 'Job started');

    await _reloadBookingsForSelectedOption();
  }

  Future<void> _handleCompleteFromList(Map<String, dynamic> booking) async {
    final selected = _selectedOption;
    final appointmentId = _asInt(booking['id']);
    if (selected == null ||
        appointmentId == null ||
        _completingAppointmentId != null) {
      return;
    }

    final feedback = await _showFinishJobFeedbackDialog(
      context,
      customerName: _customerName(context, booking),
    );
    if (!mounted || feedback == null) return;

    setState(() => _completingAppointmentId = appointmentId);
    final resp = await ApiService().completeAppointment(
      branchId: selected.branchId,
      appointmentId: appointmentId,
      rating: feedback['rating'] as int,
      comment: feedback['comment'] as String,
    );
    if (!mounted) return;
    setState(() => _completingAppointmentId = null);

    if (resp['success'] == true) {
      booking['status'] = _normalizeStatus(
        resp['data']?['status'] ?? 'COMPLETED',
      );
      Fluttertoast.showToast(
          msg: resp['message']?.toString() ?? 'Appointment completed');
      await _reloadBookingsForSelectedOption();
      return;
    }

    Fluttertoast.showToast(
        msg: resp['message']?.toString() ?? 'Failed to complete appointment');
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final selectedLabel = _selectedOption?.label.isNotEmpty == true
        ? _selectedOption!.label
        : context.t('Select Branch');
    final selectedAddressSummary = _selectedOption?.addressSummary ?? '';
    final canChangeBranch = _options.length > 1;
    final bookingViewTabs = _bookingViewTabs;
    final selectedBookingViewIndex = _safeBookingViewIndex(bookingViewTabs);
    final selectedBookingView = bookingViewTabs[selectedBookingViewIndex];
    final sortedBookings = _sortedBookings();
    final visibleBookings = _bookingsForCurrentView(sortedBookings);
    final dateRailStart = _visibleDateStart;
    final dateRail = List.generate(
      7,
      (index) => dateRailStart.add(Duration(days: index)),
    );
    final selectedDaySlots = _selectedOption?.slotsForDate(_selectedDate) ??
        const <_BranchDaySlot>[];
    final isSelectedDateClosed =
        _selectedOption?.isClosedOnDate(_selectedDate) == true;

    final bool noTeamMembersAvailable =
        widget.isOwnerMode && _teamMemberNames.isEmpty;

    final bool isBranchBookingWindowOver = _isSelectedBranchBookingWindowOver();

    final bool isSelectedBranchInactive =
        _selectedOption != null && !_selectedOption!.canAcceptBookings;

    final bool disableAddBooking = isSelectedBranchInactive ||
        isSelectedDateClosed ||
        noTeamMembersAvailable ||
        isBranchBookingWindowOver;
    final selectedStartMinute = selectedDaySlots.isNotEmpty
        ? selectedDaySlots.first.startMinute
        : _selectedOption?.startMinute;
    final selectedEndMinute = selectedDaySlots.isNotEmpty
        ? selectedDaySlots
            .map((slot) => slot.endMinute)
            .reduce((first, second) => first > second ? first : second)
        : _selectedOption?.endMinute;

    return Scaffold(
      backgroundColor: _bookingsPage,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => _loadOptions(
                showPageLoader: false,
                showInlineLoader: false,
              ),
              color: _bookingsAccent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                children: [
                  SizedBox(
                    height: 70,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.white),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: _HeaderBranchSelector(
                          key: _branchSelectorKey,
                          label: selectedLabel,
                          addressSummary: selectedAddressSummary,
                          isInteractive: canChangeBranch,
                          onTap: canChangeBranch ? _openBranchPicker : null,
                        ),
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _bookingsBorder,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('Daily Schedule'),
                                    style: _bookingTextStyle(
                                      size: 22,
                                      weight: FontWeight.w800,
                                      color: _bookingsPrimaryText,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatScheduleDate(_selectedDate),
                                    style: _bookingTextStyle(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: _bookingsSecondaryText,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _DateRailArrowButton(
                              icon: Icons.keyboard_arrow_left_rounded,
                              onTap: () => _shiftVisibleDates(-7),
                            ),
                            const SizedBox(width: 8),
                            _DateRailArrowButton(
                              icon: Icons.keyboard_arrow_right_rounded,
                              onTap: () => _shiftVisibleDates(7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          ignoring: _loadingDate,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(dateRail.length, (index) {
                                final date = dateRail[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index == dateRail.length - 1 ? 0 : 8,
                                  ),
                                  child: _CalendarDateCard(
                                    date: date,
                                    isSelected: _isSameDay(date, _selectedDate),
                                    isClosed:
                                        _selectedOption?.isClosedOnDate(date) ==
                                            true,
                                    onTap: () => _setSelectedDate(date),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _BookingViewTabs(
                          selectedIndex: selectedBookingViewIndex,
                          labels: bookingViewTabs
                              .map((tab) => _bookingViewLabel(context, tab))
                              .toList(),
                          onChanged: (index) {
                            setState(() => _selectedBookingView = index);
                          },
                        ),
                        if (!_isLoading &&
                            (_errorMessage != null || _options.isEmpty))
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              _errorMessage ?? context.t('No salons available'),
                              style: _bookingTextStyle(
                                size: 12,
                                weight: FontWeight.w600,
                                color: _bookingsSecondaryText,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  if (!_isLoading && isSelectedDateClosed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _BranchClosedState(
                        branchLabel: selectedLabel,
                        selectedDate: _selectedDate,
                      ),
                    )
                  else if (!_isLoading &&
                      selectedBookingView == _BookingViewTab.teamMembers &&
                      _teamMemberNames.isEmpty &&
                      visibleBookings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _NoTeamMembersForDateState(
                        reason: _noTeamMembersForDateReason,
                      ),
                    )
                  else if (selectedBookingView == _BookingViewTab.teamMembers)
                    _TeamMembersBoard(
                      staffGroups: _groupBookingsByStaff(
                        context,
                        visibleBookings,
                        includeEmptyTeamMembers: true,
                      ),
                      onStaffTap: _openTeamMemberSchedule,
                      onBookingTap: _openBookingDetail,
                      onAddBookingTap: _openAddBooking,
                    )
                  else if (!_isLoading && visibleBookings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _BookingEmptyState(),
                    )
                  else if (selectedBookingView == _BookingViewTab.schedule &&
                      widget.isOwnerMode)
                    _ScheduleBoard(
                      staffGroups: _groupBookingsByStaff(
                        context,
                        visibleBookings,
                      ),
                      onBookingTap: _openBookingDetail,
                      onAddBookingTap: _openAddBooking,
                      branchStartMinute: selectedStartMinute,
                      branchEndMinute: selectedEndMinute,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: visibleBookings
                            .map(
                              (booking) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildBookingCard(booking),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (widget.isOwnerMode &&
                      selectedBookingView == _BookingViewTab.schedule &&
                      !isSelectedDateClosed) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ScheduleClientButton(
                        onTap: _openAddBooking,
                        enabled: !disableAddBooking,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _BookingQuoteCard(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loadingDate || _isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _bookingsAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isOwnerMode &&
              selectedBookingView == _BookingViewTab.teamMembers &&
              !isSelectedDateClosed
          ? FloatingActionButton(
              heroTag: 'owner_team_add_booking_fab',
              onPressed: _openAddBooking,
              backgroundColor:
                  disableAddBooking ? const Color(0xFFD6D3D1) : _bookingsGold,
              foregroundColor:
                  disableAddBooking ? _bookingsSecondaryText : Colors.white,
              elevation: disableAddBooking ? 2 : 8,
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      floatingActionButtonLocation:
          widget.isOwnerMode ? FloatingActionButtonLocation.endFloat : null,
    );
  }
}

class _BookingsFetchResult {
  const _BookingsFetchResult({
    required this.bookings,
    required this.errorMessage,
  });

  final List<Map<String, dynamic>> bookings;
  final String? errorMessage;
}

class _BookingViewTabs extends StatelessWidget {
  const _BookingViewTabs({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBE9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onChanged(index),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : const [],
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bookingTextStyle(
                      size: 11,
                      weight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: isSelected ? _bookingsGold : _bookingsDateText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TeamMembersBoard extends StatelessWidget {
  const _TeamMembersBoard({
    required this.staffGroups,
    required this.onStaffTap,
    required this.onBookingTap,
    required this.onAddBookingTap,
  });

  final Map<String, List<Map<String, dynamic>>> staffGroups;
  final void Function(String staffName, List<Map<String, dynamic>> bookings)
      onStaffTap;
  final ValueChanged<Map<String, dynamic>> onBookingTap;
  final VoidCallback onAddBookingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: staffGroups.entries.map((entry) {
          final sortedBookings = [...entry.value]..sort((first, second) {
              final firstStart = _bookingStart(first);
              final secondStart = _bookingStart(second);
              if (firstStart == null && secondStart == null) return 0;
              if (firstStart == null) return 1;
              if (secondStart == null) return -1;
              return firstStart.compareTo(secondStart);
            });

          return _TeamMemberSlotsRow(
            staffName: entry.key,
            bookings: sortedBookings,
            onStaffTap: () => onStaffTap(entry.key, sortedBookings),
            onBookingTap: onBookingTap,
            onAddBookingTap: onAddBookingTap,
          );
        }).toList(),
      ),
    );
  }
}

class _TeamMemberSlotsRow extends StatefulWidget {
  const _TeamMemberSlotsRow({
    required this.staffName,
    required this.bookings,
    required this.onStaffTap,
    required this.onBookingTap,
    required this.onAddBookingTap,
  });

  final String staffName;
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onStaffTap;
  final ValueChanged<Map<String, dynamic>> onBookingTap;
  final VoidCallback onAddBookingTap;

  @override
  State<_TeamMemberSlotsRow> createState() => _TeamMemberSlotsRowState();
}

class _TeamMemberSlotsRowState extends State<_TeamMemberSlotsRow> {
  int? _selectedBookingIndex;

  @override
  void didUpdateWidget(covariant _TeamMemberSlotsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedBookingIndex != null &&
        _selectedBookingIndex! >= widget.bookings.length) {
      _selectedBookingIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availabilityColor = _professionalAvailabilityColor(widget.bookings);
    final selectedBooking = _selectedBookingIndex == null ||
            _selectedBookingIndex! >= widget.bookings.length
        ? null
        : widget.bookings[_selectedBookingIndex!];
    final bookingsToShow = selectedBooking == null
        ? widget.bookings
        : <Map<String, dynamic>>[selectedBooking];
    final visibleSlots = widget.bookings.isEmpty
        ? <Widget>[_TeamMemberNoBookingsCard(staffName: widget.staffName)]
        : bookingsToShow
            .map(
              (booking) => _TeamMemberSlotCard(
                booking: booking,
                onTap: () => widget.onBookingTap(booking),
              ),
            )
            .toList();
    final slotBookings = widget.bookings
        .asMap()
        .entries
        .where((entry) => _bookingStart(entry.value) != null)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0E9E4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFF4EAD4),
                    child: Text(
                      _initials(widget.staffName).isEmpty
                          ? '—'
                          : _initials(widget.staffName),
                      style: _bookingTextStyle(
                        size: 13,
                        weight: FontWeight.w900,
                        color: _bookingsGold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 1,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: availabilityColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.staffName.split(',').first.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bookingTextStyle(
                        size: 22,
                        weight: FontWeight.w900,
                        color: _bookingsPrimaryText,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.t('TEAM MEMBER'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bookingTextStyle(
                        size: 9,
                        weight: FontWeight.w900,
                        color: _bookingsSecondaryText,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: slotBookings.map((entry) {
                      final label = _formatTime(_bookingStart(entry.value)!);
                      final isSelected = _selectedBookingIndex == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TeamMemberSlotChip(
                          label: label,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedBookingIndex =
                                  isSelected ? null : entry.key;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: widget.onStaffTap,
                style: TextButton.styleFrom(
                  foregroundColor: _bookingsGold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('View Schedule'),
                      style: _bookingTextStyle(
                        size: 11,
                        weight: FontWeight.w900,
                        color: _bookingsGold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.bookings.isEmpty)
            _TeamMemberNoBookingsCard(staffName: widget.staffName)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleSlots.map((slot) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: slot,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamMemberSlotChip extends StatelessWidget {
  const _TeamMemberSlotChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 84,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _bookingsGold : const Color(0xFFFAF7F3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _bookingsGold : _bookingsBorder,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bookingTextStyle(
              size: 10,
              weight: FontWeight.w900,
              color: isSelected ? Colors.white : _bookingsDateText,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMemberSlotCard extends StatelessWidget {
  const _TeamMemberSlotCard({
    required this.booking,
    required this.onTap,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  static const double _width = 244;
  static const double _height = 172;

  @override
  Widget build(BuildContext context) {
    final status = _normalizeStatus(booking['status']);
    final visuals = _statusVisuals(context, status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: _width,
          height: _height,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visuals.cardBorderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(
                    label: visuals.label,
                    backgroundColor: visuals.pillBackgroundColor,
                    borderColor: visuals.pillBorderColor,
                    textColor: visuals.pillTextColor,
                  ),
                  const Spacer(),
                  Text(
                    _bookingStart(booking) == null
                        ? '--'
                        : _formatTime(_bookingStart(booking)!),
                    style: _bookingTextStyle(
                      size: 10,
                      weight: FontWeight.w900,
                      color: _bookingsSecondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _customerName(context, booking),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bookingTextStyle(
                  size: 14,
                  weight: FontWeight.w900,
                  color: _bookingsPrimaryText,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _serviceCardSummary(context, booking),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _bookingTextStyle(
                  size: 10,
                  weight: FontWeight.w700,
                  color: _bookingsSecondaryText,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              const Divider(color: _bookingsBorder, height: 18),
              Row(
                children: [
                  // Temporarily hidden by requirement: booking duration mins.
                  // Restore if duration should be visible on team-member cards.
                  // Text(
                  //   '${_bookingDurationMinutes(booking)} Mins',
                  //   style: _bookingTextStyle(
                  //     size: 10,
                  //     weight: FontWeight.w900,
                  //     color: _bookingsSecondaryText,
                  //   ),
                  // ),
                  const Spacer(),
                  _TeamMemberCardIconButton(
                    icon: Icons.phone_outlined,
                    onTap: () => _openCustomerPhoneAction(
                      context,
                      booking,
                      message: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TeamMemberCardIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () => _openCustomerPhoneAction(
                      context,
                      booking,
                      message: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberCardIconButton extends StatelessWidget {
  const _TeamMemberCardIconButton({
    required this.icon,
    required this.onTap,
    this.expand = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F3EE),
      shape: expand
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))
          : const CircleBorder(),
      child: InkWell(
        customBorder: expand
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))
            : const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: expand ? double.infinity : 34,
          height: 34,
          child: Icon(
            icon,
            color: _bookingsGold,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _TeamMemberNoBookingsCard extends StatelessWidget {
  const _TeamMemberNoBookingsCard({required this.staffName});

  final String staffName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _TeamMemberSlotCard._height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7D8C7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy_outlined,
            color: _bookingsGold,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            staffName.split(',').first.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 13,
              weight: FontWeight.w900,
              color: _bookingsPrimaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.t('No bookings for today'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 11,
              weight: FontWeight.w700,
              color: _bookingsSecondaryText,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStaffNameLabel extends StatelessWidget {
  const _ScheduleStaffNameLabel({
    required this.staffName,
    required this.bookings,
  });

  final String staffName;
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    final firstLetter = staffName.trim().isEmpty
        ? '—'
        : staffName.trim().characters.first.toUpperCase();
    final availabilityColor = _professionalAvailabilityColor(bookings);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFFFDC82),
                child: Text(
                  firstLetter,
                  style: _bookingTextStyle(
                    size: 11,
                    weight: FontWeight.w900,
                    color: _bookingsGold,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: availabilityColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              staffName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bookingTextStyle(
                size: 12,
                weight: FontWeight.w900,
                color: _bookingsGold,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTeamHeaderCell extends StatelessWidget {
  const _ScheduleTeamHeaderCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ScheduleBoard._headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: _ScheduleBoard._headerBackground,
        border: Border(
          right: BorderSide(color: _ScheduleBoard._gridBorder),
          bottom: BorderSide(color: _ScheduleBoard._gridBorder),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_2_outlined,
            color: _bookingsGold,
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            context.t('Team'),
            style: _bookingTextStyle(
              size: 12,
              weight: FontWeight.w900,
              color: _bookingsGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimeHeaderCell extends StatelessWidget {
  const _ScheduleTimeHeaderCell({required this.minute});

  final int minute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ScheduleBoard._slotWidth,
      height: _ScheduleBoard._headerHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _ScheduleBoard._headerBackground,
        border: Border(
          right: BorderSide(color: _ScheduleBoard._gridBorder),
          bottom: BorderSide(color: _ScheduleBoard._gridBorder),
        ),
      ),
      child: Text(
        _formatMinutesShortLabel(minute),
        textAlign: TextAlign.center,
        style: _bookingTextStyle(
          size: 9,
          weight: FontWeight.w800,
          color: _bookingsGold,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _ScheduleGridCell extends StatelessWidget {
  const _ScheduleGridCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ScheduleBoard._slotWidth,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: _ScheduleBoard._gridBorder),
          bottom: BorderSide(color: _ScheduleBoard._gridBorder),
        ),
      ),
    );
  }
}

class _ScheduleMemberCell extends StatelessWidget {
  const _ScheduleMemberCell({
    required this.staffName,
    required this.bookings,
  });

  final String staffName;
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ScheduleBoard._rowHeight,
      width: _ScheduleBoard._staffColumnWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: _ScheduleBoard._gridBorder),
          bottom: BorderSide(color: _ScheduleBoard._gridBorder),
        ),
      ),
      child: _ScheduleStaffNameLabel(
        staffName: staffName,
        bookings: bookings,
      ),
    );
  }
}

class _ScheduleBookingSideBar extends StatelessWidget {
  const _ScheduleBookingSideBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _ScheduleBookingStatusLabel extends StatelessWidget {
  const _ScheduleBookingStatusLabel({required this.visuals});

  final _BookingStatusVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: visuals.pillBackgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visuals.pillBorderColor),
      ),
      child: Text(
        visuals.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _bookingTextStyle(
          size: 8,
          weight: FontWeight.w900,
          color: visuals.pillTextColor,
          height: 1,
        ),
      ),
    );
  }
}

class _ScheduleBookingContent extends StatelessWidget {
  const _ScheduleBookingContent({
    required this.booking,
    required this.visuals,
  });

  final Map<String, dynamic> booking;
  final _BookingStatusVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _customerName(context, booking),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bookingTextStyle(
                    size: 12,
                    weight: FontWeight.w900,
                    color: _bookingsPrimaryText,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ScheduleBookingStatusLabel(visuals: visuals),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _serviceCardSummary(context, booking),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bookingTextStyle(
              size: 10,
              weight: FontWeight.w700,
              color: _bookingsSecondaryText,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              // Temporarily hidden by requirement: booking duration mins.
              // Restore if duration should be visible on schedule cards.
              // Text(
              //   '${_bookingDurationMinutes(booking)} ${context.t('Mins')}',
              //   style: _bookingTextStyle(
              //     size: 10,
              //     weight: FontWeight.w900,
              //     color: _bookingsSecondaryText,
              //     height: 1,
              //   ),
              // ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openCustomerPhoneAction(
                  context,
                  booking,
                  message: true,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: _bookingsGold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleBookingCompactContent extends StatelessWidget {
  const _ScheduleBookingCompactContent({
    required this.booking,
    required this.visuals,
  });

  final Map<String, dynamic> booking;
  final _BookingStatusVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _customerName(context, booking),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bookingTextStyle(
              size: 10,
              weight: FontWeight.w900,
              color: _bookingsPrimaryText,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          _ScheduleBookingStatusLabel(visuals: visuals),
          const SizedBox(height: 4),
          Text(
            _serviceCardSummary(context, booking),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bookingTextStyle(
              size: 8,
              weight: FontWeight.w700,
              color: _bookingsSecondaryText,
              height: 1,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '${_bookingDurationMinutes(booking)}M',
                style: _bookingTextStyle(
                  size: 8,
                  weight: FontWeight.w900,
                  color: _bookingsSecondaryText,
                  height: 1,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openCustomerPhoneAction(
                  context,
                  booking,
                  message: true,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 13,
                    color: _bookingsGold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleBookingTinyContent extends StatelessWidget {
  const _ScheduleBookingTinyContent({required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          _customerName(context, booking),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bookingTextStyle(
            size: 9,
            weight: FontWeight.w900,
            color: _bookingsPrimaryText,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TeamMemberScheduleScreen extends StatefulWidget {
  const _TeamMemberScheduleScreen({
    required this.staffName,
    required this.bookings,
    required this.serviceNames,
    required this.workingHours,
    required this.salonWorkingHours,
    required this.selectedDate,
    required this.onBookingTap,
    this.branchId,
    this.branchStartMinute,
    this.branchEndMinute,
  });

  final String staffName;
  final List<Map<String, dynamic>> bookings;
  final List<String> serviceNames;
  final List<_WorkingDayHours> workingHours;
  final List<_WorkingDayHours> salonWorkingHours;
  final DateTime selectedDate;
  final int? branchId;
  final int? branchStartMinute;
  final int? branchEndMinute;
  final ValueChanged<Map<String, dynamic>> onBookingTap;

  @override
  State<_TeamMemberScheduleScreen> createState() =>
      _TeamMemberScheduleScreenState();
}

class _TeamMemberScheduleScreenState extends State<_TeamMemberScheduleScreen> {
  late DateTime _selectedScheduleDate;
  late DateTime _visibleScheduleDateStart;
  late List<Map<String, dynamic>> _scheduleBookings;
  bool _loadingScheduleBookings = false;

  @override
  void initState() {
    super.initState();
    final date = widget.selectedDate;
    final today = DateTime.now();
    _selectedScheduleDate = DateTime(date.year, date.month, date.day);
    _visibleScheduleDateStart = DateTime(today.year, today.month, today.day);
    _scheduleBookings = List<Map<String, dynamic>>.from(widget.bookings);
  }

  void _shiftScheduleDate(int days) {
    setState(() {
      _visibleScheduleDateStart =
          _visibleScheduleDateStart.add(Duration(days: days));
    });
  }

  Future<void> _selectScheduleDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedScheduleDate = normalized;
      _loadingScheduleBookings = true;
    });

    final branchId = widget.branchId;
    if (branchId == null) {
      if (!mounted) return;
      setState(() => _loadingScheduleBookings = false);
      return;
    }

    try {
      final response = await ApiService().fetchAppointments(
        branchId,
        _formatApiDate(normalized),
      );
      final rawData = response['data'];
      final allBookings = rawData is List
          ? rawData
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const <Map<String, dynamic>>[];
      final staffKey = widget.staffName.trim().toLowerCase();
      final staffBookings = allBookings.where((booking) {
        return _assignedStaffSummary(context, booking).trim().toLowerCase() ==
            staffKey;
      }).toList();
      if (!mounted) return;
      setState(() {
        _scheduleBookings = staffBookings;
        _loadingScheduleBookings = false;
      });
    } catch (e) {
      debugPrint('[TeamScheduleBookings] failed=$e');
      if (!mounted) return;
      setState(() {
        _scheduleBookings = const [];
        _loadingScheduleBookings = false;
      });
    }
  }

  void _showWorkingHoursModal() {
    _showHoursModal(
      title: 'Working days and hours',
      subtitle: widget.staffName,
      hours: widget.workingHours,
      emptyMessage: 'No working hours available',
      closedLabel: 'Closed',
    );
  }

  void _showSalonHoursModal() {
    _showHoursModal(
      title: 'Salon hours',
      subtitle: 'Weekly working hours',
      hours: widget.salonWorkingHours,
      emptyMessage: 'No salon hours available',
      closedLabel: 'Off day',
    );
  }

  void _showHoursModal({
    required String title,
    required String subtitle,
    required List<_WorkingDayHours> hours,
    required String emptyMessage,
    required String closedLabel,
  }) {
    final weeklyHours = _weeklyHoursWithClosedDays(hours);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return SafeArea(
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EAD4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: _bookingsGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(title),
                              style: _bookingTextStyle(
                                size: 18,
                                weight: FontWeight.w900,
                                color: _bookingsPrimaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t(subtitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _bookingTextStyle(
                                size: 12,
                                weight: FontWeight.w700,
                                color: _bookingsSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: _bookingsSecondaryText,
                        iconSize: 20,
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: weeklyHours.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = weeklyHours[index];
                        final slots = item.slots.isEmpty
                            ? [context.t(closedLabel)]
                            : item.slots;
                        final isClosed = item.slots.isEmpty;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _bookingsBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 92,
                                child: Text(
                                  context.t(item.day),
                                  style: _bookingTextStyle(
                                    size: 13,
                                    weight: FontWeight.w900,
                                    color: _bookingsGold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: slots
                                      .map(
                                        (slot) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isClosed
                                                ? const Color(0xFFFFF1F2)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: isClosed
                                                  ? const Color(0xFFFECACA)
                                                  : _bookingsBorder,
                                            ),
                                          ),
                                          child: Text(
                                            slot,
                                            style: _bookingTextStyle(
                                              size: 11,
                                              weight: FontWeight.w800,
                                              color: isClosed
                                                  ? const Color(0xFF991B1B)
                                                  : _bookingsDateText,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_WorkingDayHours> _weeklyHoursWithClosedDays(
    List<_WorkingDayHours> hours,
  ) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final slotsByDay = <String, List<String>>{};
    final rangesByDay = <String, List<_WorkingHourRange>>{};

    for (final item in hours) {
      final day = item.day.trim().toLowerCase();
      if (day.isEmpty) continue;
      slotsByDay.putIfAbsent(day, () => <String>[]).addAll(item.slots);
      rangesByDay
          .putIfAbsent(day, () => <_WorkingHourRange>[])
          .addAll(item.ranges);
    }

    return days
        .map(
          (day) => _WorkingDayHours(
            day: _weeklyDayLabel(day),
            slots: slotsByDay[day] ?? const <String>[],
            ranges: rangesByDay[day] ?? const <_WorkingHourRange>[],
          ),
        )
        .toList();
  }

  String _weeklyDayLabel(String day) {
    if (day.isEmpty) return day;
    return '${day.substring(0, 1).toUpperCase()}${day.substring(1)}';
  }

  bool _isSelectedDateClosed() {
    final dayKey = _weekdayKeyForDate(_selectedScheduleDate);
    final dayHours = widget.salonWorkingHours
        .where((item) => item.day.trim().toLowerCase() == dayKey)
        .toList();

    if (dayHours.isEmpty) return true;
    return dayHours.every((item) => item.slots.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final sortedBookings = [..._scheduleBookings]..sort((first, second) {
        final firstStart = _bookingStart(first);
        final secondStart = _bookingStart(second);
        if (firstStart == null && secondStart == null) return 0;
        if (firstStart == null) return 1;
        if (secondStart == null) return -1;
        return firstStart.compareTo(secondStart);
      });
    final initials = _initials(widget.staffName);
    final availabilityColor = _professionalAvailabilityColor(sortedBookings);
    final busyReason = _professionalBusyReason(context, sortedBookings);
    final startLabel = widget.branchStartMinute == null
        ? null
        : _formatMinutesLabel(widget.branchStartMinute!);
    final endLabel = widget.branchEndMinute == null
        ? null
        : _formatMinutesLabel(widget.branchEndMinute!);
    final isSelectedDateClosed = _isSelectedDateClosed();

    return Scaffold(
      backgroundColor: _bookingsPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _bookingsGold,
            size: 24,
          ),
        ),
        title: Text(
          context.t('Schedule'),
          style: _bookingTextStyle(
            size: 22,
            weight: FontWeight.w900,
            color: _bookingsGold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: _bookingsBorder,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFF4EAD4),
                        child: Text(
                          initials.isEmpty ? '—' : initials,
                          style: _bookingTextStyle(
                            size: 16,
                            weight: FontWeight.w900,
                            color: _bookingsGold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: availabilityColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.staffName.split(',').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bookingTextStyle(
                            size: 22,
                            weight: FontWeight.w900,
                            color: _bookingsPrimaryText,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.t('TEAM MEMBER'),
                          style: _bookingTextStyle(
                            size: 9,
                            weight: FontWeight.w900,
                            color: _bookingsSecondaryText,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (_) => const Icon(
                                Icons.star_rounded,
                                color: _bookingsGold,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '4.9',
                              style: _bookingTextStyle(
                                size: 11,
                                weight: FontWeight.w800,
                                color: _bookingsPrimaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.serviceNames.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      context.t('ASSIGNED SERVICES'),
                      style: _bookingTextStyle(
                        size: 9,
                        weight: FontWeight.w900,
                        color: _bookingsSecondaryText,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EAD4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${widget.serviceNames.length}',
                        style: _bookingTextStyle(
                          size: 9,
                          weight: FontWeight.w900,
                          color: _bookingsGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.serviceNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final serviceName = widget.serviceNames[index];
                      return Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F3),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _bookingsBorder),
                        ),
                        child: Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bookingTextStyle(
                            size: 10,
                            weight: FontWeight.w800,
                            color: _bookingsDateText,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (busyReason != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          busyReason,
                          style: _bookingTextStyle(
                            size: 12,
                            weight: FontWeight.w800,
                            color: const Color(0xFF991B1B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              InkWell(
                onTap: _showSalonHoursModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bookingsBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: _bookingsGold,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          startLabel != null && endLabel != null
                              ? '${context.t('Salon Hours')}: $startLabel - $endLabel'
                              : context.t('Salon Hours'),
                          style: _bookingTextStyle(
                            size: 12,
                            weight: FontWeight.w800,
                            color: _bookingsDateText,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _bookingsGold,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _showWorkingHoursModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bookingsBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        color: _bookingsGold,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('Working days and hours'),
                          style: _bookingTextStyle(
                            size: 12,
                            weight: FontWeight.w900,
                            color: _bookingsDateText,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _bookingsGold,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _DateRailArrowButton(
                    icon: Icons.keyboard_arrow_left_rounded,
                    onTap: () => _shiftScheduleDate(-7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(7, (index) {
                          final date = _visibleScheduleDateStart
                              .add(Duration(days: index));
                          final isSelected =
                              _isSameDay(date, _selectedScheduleDate);
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == 6 ? 0 : 8,
                            ),
                            child: _CalendarDateCard(
                              date: date,
                              isSelected: isSelected,
                              isClosed: false,
                              onTap: () => _selectScheduleDate(date),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DateRailArrowButton(
                    icon: Icons.keyboard_arrow_right_rounded,
                    onTap: () => _shiftScheduleDate(7),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_loadingScheduleBookings)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _bookingsAccent,
                ),
              ),
            )
          else if (isSelectedDateClosed)
            _BranchClosedState(
              branchLabel: 'Salon',
              selectedDate: _selectedScheduleDate,
            )
          else
            _TeamMemberTimeline(
              bookings: sortedBookings,
              selectedDate: _selectedScheduleDate,
              branchStartMinute: widget.branchStartMinute,
              branchEndMinute: widget.branchEndMinute,
              onBookingTap: widget.onBookingTap,
            ),
          if (!isSelectedDateClosed && endLabel != null) ...[
            const SizedBox(height: 16),
            Text(
              '${context.t('Salon closes at')} $endLabel',
              textAlign: TextAlign.center,
              style: _bookingTextStyle(
                size: 11,
                weight: FontWeight.w800,
                color: _bookingsSecondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamMemberTimelineItem {
  const _TeamMemberTimelineItem({
    required this.startMinute,
    required this.endMinute,
    this.booking,
    this.message,
    this.isTailGap = false,
  });

  final int startMinute;
  final int endMinute;
  final Map<String, dynamic>? booking;
  final String? message;
  final bool isTailGap;

  bool get isBooking => booking != null;
  int get durationMinutes => (endMinute - startMinute).clamp(0, 24 * 60);
}

class _TeamMemberTimeline extends StatelessWidget {
  const _TeamMemberTimeline({
    required this.bookings,
    required this.selectedDate,
    required this.onBookingTap,
    this.branchStartMinute,
    this.branchEndMinute,
  });

  final List<Map<String, dynamic>> bookings;
  final DateTime selectedDate;
  final int? branchStartMinute;
  final int? branchEndMinute;
  final ValueChanged<Map<String, dynamic>> onBookingTap;

  List<_TeamMemberTimelineItem> _items(BuildContext context) {
    final sortedBookings = [...bookings]..sort((first, second) {
        final firstStart = _bookingStart(first);
        final secondStart = _bookingStart(second);
        if (firstStart == null && secondStart == null) return 0;
        if (firstStart == null) return 1;
        if (secondStart == null) return -1;
        return firstStart.compareTo(secondStart);
      });
    final bookingsWithStart = sortedBookings
        .where((booking) => _bookingStart(booking) != null)
        .toList();

    var startMinute = branchStartMinute ?? 9 * 60;
    var endMinute = branchEndMinute ?? 20 * 60;
    if (bookingsWithStart.isNotEmpty) {
      final firstStart = _bookingStart(bookingsWithStart.first)!;
      final lastBooking = bookingsWithStart.last;
      final lastStart = _bookingStart(lastBooking)!;
      final lastEnd = _bookingEnd(lastBooking);
      final lastEndMinute = lastEnd == null
          ? lastStart.hour * 60 +
              lastStart.minute +
              _bookingDurationMinutes(lastBooking)
          : lastEnd.hour * 60 + lastEnd.minute;
      startMinute = branchStartMinute ?? (firstStart.hour * 60);
      endMinute = branchEndMinute ?? ((lastEndMinute + 59) ~/ 60) * 60;
    }

    if (endMinute <= startMinute) {
      endMinute = startMinute + 8 * 60;
    }

    if (bookingsWithStart.isEmpty) {
      return [
        _TeamMemberTimelineItem(
          startMinute: startMinute,
          endMinute: endMinute,
          message: context.t('No bookings for today'),
          isTailGap: true,
        ),
      ];
    }

    final items = <_TeamMemberTimelineItem>[];
    var cursor = startMinute;
    for (final booking in bookingsWithStart) {
      final start = _bookingStart(booking)!;
      final bookingStartMinute = start.hour * 60 + start.minute;
      final end = _bookingEnd(booking);
      final bookingEndMinute = end == null
          ? bookingStartMinute + _bookingDurationMinutes(booking)
          : end.hour * 60 + end.minute;

      if (bookingStartMinute > cursor) {
        items.add(
          _TeamMemberTimelineItem(
            startMinute: cursor,
            endMinute: bookingStartMinute,
            message: context.t('No bookings'),
          ),
        );
      }

      items.add(
        _TeamMemberTimelineItem(
          startMinute: bookingStartMinute,
          endMinute: bookingEndMinute,
          booking: booking,
        ),
      );
      if (bookingEndMinute > cursor) {
        cursor = bookingEndMinute;
      }
    }

    if (cursor < endMinute) {
      items.add(
        _TeamMemberTimelineItem(
          startMinute: cursor,
          endMinute: endMinute,
          message: context.t('No bookings for today further'),
          isTailGap: true,
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final timelineItems = _items(context);
    return Column(
      children: List.generate(timelineItems.length, (index) {
        final item = timelineItems[index];
        return _TeamMemberTimelineEntry(
          item: item,
          isLast: index == timelineItems.length - 1,
          onTap:
              item.booking == null ? null : () => onBookingTap(item.booking!),
        );
      }),
    );
  }
}

class _TeamMemberTimelineEntry extends StatelessWidget {
  const _TeamMemberTimelineEntry({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final _TeamMemberTimelineItem item;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final visuals = booking == null
        ? null
        : _statusVisuals(context, _normalizeStatus(booking['status']));
    final lineHeight = item.isBooking ? 174.0 : 72.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMinutesLabel(item.startMinute),
                textAlign: TextAlign.right,
                style: _bookingTextStyle(
                  size: 11,
                  weight: FontWeight.w900,
                  color:
                      item.isBooking ? _bookingsGold : _bookingsSecondaryText,
                ),
              ),
              // Temporarily hidden by requirement: booking and gap duration mins
              // below timeline times. Keep this code for later restoration.
              // if (item.isBooking) ...[
              //   const SizedBox(height: 2),
              //   Text(
              //     '${_bookingDurationMinutes(booking!)} ${context.t('mins')}',
              //     textAlign: TextAlign.right,
              //     style: _bookingTextStyle(
              //       size: 10,
              //       weight: FontWeight.w800,
              //       color: _bookingsSecondaryText,
              //       height: 1.1,
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          children: [
            Container(
              width: item.isBooking ? 10 : 8,
              height: item.isBooking ? 10 : 8,
              decoration: BoxDecoration(
                color: item.isBooking ? _bookingsGold : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      item.isBooking ? _bookingsGold : const Color(0xFFD8C9B7),
                  width: 1.2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: lineHeight,
                color: const Color(0xFFE8DED6),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: item.isBooking ? 18 : 14),
            child: item.isBooking
                ? _TeamMemberTimelineBookingCard(
                    booking: booking!,
                    visuals: visuals!,
                    onTap: onTap!,
                  )
                : _TeamMemberTimelineGapCard(
                    message: item.message ?? context.t('No bookings'),
                    isTailGap: item.isTailGap,
                  ),
          ),
        ),
      ],
    );
  }
}

class _TeamMemberTimelineGapCard extends StatelessWidget {
  const _TeamMemberTimelineGapCard({
    required this.message,
    required this.isTailGap,
  });

  final String message;
  final bool isTailGap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: isTailGap ? 50 : 44,
        maxWidth: isTailGap ? 190 : double.infinity,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9DED4)),
      ),
      child: Text(
        message,
        style: _bookingTextStyle(
          size: 11,
          weight: FontWeight.w800,
          color: _bookingsSecondaryText,
          height: 1.25,
        ),
      ),
    );
  }
}

class _TeamMemberTimelineBookingCard extends StatelessWidget {
  const _TeamMemberTimelineBookingCard({
    required this.booking,
    required this.visuals,
    required this.onTap,
  });

  final Map<String, dynamic> booking;
  final _BookingStatusVisuals visuals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visuals.cardBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE9E4DD),
                child: Text(
                  _initials(_customerName(context, booking)),
                  style: _bookingTextStyle(
                    size: 11,
                    weight: FontWeight.w900,
                    color: _bookingsGold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerName(context, booking),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bookingTextStyle(
                        size: 12,
                        weight: FontWeight.w900,
                        color: _bookingsPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _serviceCardSummary(context, booking),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _bookingTextStyle(
                        size: 10,
                        weight: FontWeight.w700,
                        color: _bookingsSecondaryText,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: _StatusPill(
              label: visuals.label,
              backgroundColor: visuals.pillBackgroundColor,
              borderColor: visuals.pillBorderColor,
              textColor: visuals.pillTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamMemberCardIconButton(
                  icon: Icons.phone_outlined,
                  onTap: () => _openCustomerPhoneAction(
                    context,
                    booking,
                    message: false,
                  ),
                  expand: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TeamMemberCardIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () => _openCustomerPhoneAction(
                    context,
                    booking,
                    message: true,
                  ),
                  expand: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: _bookingsDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    context.t('VIEW DETAILS'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _bookingTextStyle(
                      size: 10,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleBoard extends StatelessWidget {
  const _ScheduleBoard({
    required this.staffGroups,
    required this.onBookingTap,
    required this.onAddBookingTap,
    this.branchStartMinute,
    this.branchEndMinute,
  });

  final Map<String, List<Map<String, dynamic>>> staffGroups;
  final ValueChanged<Map<String, dynamic>> onBookingTap;
  final VoidCallback onAddBookingTap;
  final int? branchStartMinute;
  final int? branchEndMinute;

  static const double _staffColumnWidth = 112;
  static const double _headerHeight = 62;
  static const int _slotMinutes = 15;
  static const double _slotWidth = 80;
  static const double _rowHeight = 146;
  static const double _cardWidth = 148;
  static const double _cardHeight = 126;
  static const Color _gridBorder = Color(0xFFD8C9B7);
  static const Color _headerBackground = Color(0xFFFFF8F2);

  @override
  Widget build(BuildContext context) {
    var earliestMinute = branchStartMinute ?? 9 * 60;
    var latestMinute = branchEndMinute ?? 20 * 60;
    var hasTime = false;

    for (final booking in staffGroups.values.expand((bookings) => bookings)) {
      final start = _bookingStart(booking);
      final end = _bookingEnd(booking);
      if (start == null) continue;
      final startMinute = start.hour * 60 + start.minute;
      final endMinute = end == null
          ? startMinute + _bookingDurationMinutes(booking)
          : end.hour * 60 + end.minute;
      if (branchStartMinute != null && branchEndMinute != null) {
        hasTime = true;
        continue;
      }
      if (!hasTime) {
        earliestMinute = (startMinute ~/ 60) * 60;
        latestMinute = ((endMinute + 59) ~/ 60) * 60;
        hasTime = true;
      } else {
        if (startMinute < earliestMinute) {
          earliestMinute = (startMinute ~/ 60) * 60;
        }
        if (endMinute > latestMinute) {
          latestMinute = ((endMinute + 59) ~/ 60) * 60;
        }
      }
    }

    if (latestMinute - earliestMinute < 180) {
      latestMinute = earliestMinute + 180;
    }

    var timeLabelCount =
        ((latestMinute - earliestMinute) / _slotMinutes).ceil() + 1;
    if (timeLabelCount < 3) timeLabelCount = 3;
    if (timeLabelCount > 64) timeLabelCount = 64;
    final boardWidth = timeLabelCount * _slotWidth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: _bookingsBorder),
            bottom: BorderSide(color: _bookingsBorder),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _staffColumnWidth,
              child: Column(
                children: [
                  const _ScheduleTeamHeaderCell(),
                  ...staffGroups.entries.map(
                    (entry) => _ScheduleMemberCell(
                      staffName: entry.key,
                      bookings: entry.value,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: boardWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: _headerHeight,
                        child: Row(
                          children: List.generate(timeLabelCount, (index) {
                            final minute =
                                earliestMinute + index * _slotMinutes;
                            return _ScheduleTimeHeaderCell(minute: minute);
                          }),
                        ),
                      ),
                      ...staffGroups.entries.map(
                        (entry) => _ScheduleBoardRow(
                          bookings: entry.value,
                          earliestMinute: earliestMinute,
                          boardWidth: boardWidth,
                          onBookingTap: onBookingTap,
                          onAddBookingTap: onAddBookingTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBoardRow extends StatelessWidget {
  const _ScheduleBoardRow({
    required this.bookings,
    required this.earliestMinute,
    required this.boardWidth,
    required this.onBookingTap,
    required this.onAddBookingTap,
  });

  final List<Map<String, dynamic>> bookings;
  final int earliestMinute;
  final double boardWidth;
  final ValueChanged<Map<String, dynamic>> onBookingTap;
  final VoidCallback onAddBookingTap;

  @override
  Widget build(BuildContext context) {
    final sortedBookings = [...bookings]..sort((first, second) {
        final firstStart = _bookingStart(first);
        final secondStart = _bookingStart(second);
        if (firstStart == null && secondStart == null) return 0;
        if (firstStart == null) return 1;
        if (secondStart == null) return -1;
        return firstStart.compareTo(secondStart);
      });
    // final addSlotLeft =
    //     _addSlotLeft(sortedBookings, earliestMinute, boardWidth);

    return SizedBox(
      height: _ScheduleBoard._rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: List.generate(
                (boardWidth / _ScheduleBoard._slotWidth).ceil(),
                (_) => const _ScheduleGridCell(),
              ),
            ),
          ),
          ...sortedBookings.map((booking) {
            final start = _bookingStart(booking);
            if (start == null) return const SizedBox.shrink();
            final startMinute = start.hour * 60 + start.minute;
            final end = _bookingEnd(booking);
            var endMinute = end == null
                ? startMinute + _bookingDurationMinutes(booking)
                : end.hour * 60 + end.minute;
            if (endMinute <= startMinute) {
              endMinute = startMinute + _bookingDurationMinutes(booking);
            }
            final visibleStartMinute =
                startMinute < earliestMinute ? earliestMinute : startMinute;
            final left = (((visibleStartMinute - earliestMinute) /
                        _ScheduleBoard._slotMinutes) *
                    _ScheduleBoard._slotWidth)
                .clamp(0.0, boardWidth)
                .toDouble();
            final availableWidth = boardWidth - left - 8;
            final durationWidth = ((endMinute - visibleStartMinute) /
                    _ScheduleBoard._slotMinutes) *
                _ScheduleBoard._slotWidth;
            if (availableWidth <= 0 || durationWidth <= 0) {
              return const SizedBox.shrink();
            }
            final width = durationWidth > availableWidth
                ? availableWidth
                : durationWidth.toDouble();

            return Positioned(
              left: left,
              top: 14,
              width: width,
              child: _ScheduleBoardAppointmentCard(
                booking: booking,
                onTap: () => onBookingTap(booking),
              ),
            );
          }),
          // if (addSlotLeft != null)
          //   Positioned(
          //     left: addSlotLeft,
          //     top: 16,
          //     width: 118,
          //     child: _ScheduleEmptySlot(
          //       onTap: onAddBookingTap,
          //     ),
          //   ),
        ],
      ),
    );
  }

  // ignore: unused_element
  double? _addSlotLeft(
    List<Map<String, dynamic>> sortedBookings,
    int earliestMinute,
    double boardWidth,
  ) {
    if (sortedBookings.isEmpty) return 12;
    var latestEndMinute = earliestMinute;
    for (final booking in sortedBookings) {
      final start = _bookingStart(booking);
      if (start == null) continue;
      final endMinute =
          start.hour * 60 + start.minute + _bookingDurationMinutes(booking);
      if (endMinute > latestEndMinute) {
        latestEndMinute = endMinute;
      }
    }
    final left =
        (((latestEndMinute - earliestMinute) / _ScheduleBoard._slotMinutes) *
                _ScheduleBoard._slotWidth) +
            12;
    if (left > boardWidth - _ScheduleBoard._cardWidth - 8) return null;
    return left
        .clamp(12.0, boardWidth - _ScheduleBoard._cardWidth - 8)
        .toDouble();
  }
}

class _ScheduleBoardAppointmentCard extends StatelessWidget {
  const _ScheduleBoardAppointmentCard({
    required this.booking,
    required this.onTap,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _normalizeStatus(booking['status']);
    final visuals = _statusVisuals(context, status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 120;
            final isTiny = constraints.maxWidth < 56;
            return Container(
              height: _ScheduleBoard._cardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: visuals.cardBorderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  _ScheduleBookingSideBar(
                    color: _scheduleStatusAccentColor(status),
                  ),
                  if (isTiny)
                    _ScheduleBookingTinyContent(booking: booking)
                  else if (isCompact)
                    _ScheduleBookingCompactContent(
                      booking: booking,
                      visuals: visuals,
                    )
                  else
                    _ScheduleBookingContent(
                      booking: booking,
                      visuals: visuals,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ScheduleEmptySlot extends StatelessWidget {
  const _ScheduleEmptySlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: _ScheduleBoard._cardHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7D8C7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                color: _bookingsGold,
                size: 18,
              ),
              const SizedBox(height: 5),
              Text(
                context.t('ADD BOOKING'),
                style: _bookingTextStyle(
                  size: 8,
                  weight: FontWeight.w900,
                  color: _bookingsGold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleClientButton extends StatelessWidget {
  const _ScheduleClientButton({
    required this.onTap,
    required this.enabled,
  });

  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          Icons.group_add_outlined,
          size: 18,
          color: enabled ? Colors.white : _bookingsSecondaryText,
        ),
        label: Text(
          context.t('Schedule a Client'),
          style: _bookingTextStyle(
            size: 13,
            weight: FontWeight.w900,
            color: enabled ? Colors.white : _bookingsSecondaryText,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _bookingsGold : const Color(0xFFD6D3D1),
          foregroundColor: enabled ? Colors.white : _bookingsSecondaryText,
          elevation: enabled ? 6 : 1,
          shadowColor: const Color(0x338B6500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _BookingQuoteCard extends StatelessWidget {
  const _BookingQuoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bookingsBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              children: [
                Text(
                  '”',
                  style: _bookingTextStyle(
                    size: 30,
                    weight: FontWeight.w900,
                    color: _bookingsAccent,
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"Beauty begins the moment\nyou decide to be yourself."',
                  textAlign: TextAlign.center,
                  style: _bookingTextStyle(
                    size: 15,
                    weight: FontWeight.w900,
                    color: _bookingsPrimaryText,
                    height: 1.25,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 218,
            width: double.infinity,
            child: Image.asset(
              'assets/images/salon2.jpeg',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBranchSelector extends StatelessWidget {
  const _HeaderBranchSelector({
    super.key,
    required this.label,
    this.addressSummary = '',
    required this.isInteractive,
    this.onTap,
  });

  final String label;
  final String addressSummary;
  final bool isInteractive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isInteractive ? onTap : null,
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(minWidth: 164),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: _bookingsAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bookingTextStyle(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _bookingsPrimaryText,
                              letterSpacing: 0.6,
                            ),
                          ),
                          if (addressSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              addressSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _bookingTextStyle(
                                size: 11,
                                weight: FontWeight.w600,
                                color: _bookingsSecondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isInteractive) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _bookingsSecondaryText,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchDropdownItem extends StatelessWidget {
  const _BranchDropdownItem({
    required this.option,
    required this.isSelected,
  });

  final _SalonBranchOption option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color:
            isSelected ? _bookingsAccent.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _bookingsAccent : _bookingsBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _bookingsAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: _bookingsAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bookingTextStyle(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _bookingsPrimaryText,
                    letterSpacing: 0.2,
                  ),
                ),
                if (option.addressSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.addressSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bookingTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _bookingsSecondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isSelected ? _bookingsAccent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _bookingsAccent : _bookingsBorder,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _DateRailArrowButton extends StatelessWidget {
  const _DateRailArrowButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _bookingsCard,
            shape: BoxShape.circle,
            border: Border.all(color: _bookingsBorder),
          ),
          child: Icon(
            icon,
            color: _bookingsGold,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _CalendarDateCard extends StatelessWidget {
  const _CalendarDateCard({
    required this.date,
    required this.isSelected,
    required this.isClosed,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isClosed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final backgroundColor = isClosed
        ? const Color(0xFFFCE7E7)
        : (isSelected
            ? _bookingsGold
            : (isToday ? const Color(0xFFEAF4FF) : _bookingsCard));
    final dayColor = isClosed
        ? const Color(0xFF8A3A3A)
        : (isSelected ? Colors.white : _bookingsSecondaryText);
    final dateColor = isClosed
        ? const Color(0xFF3B2F2F)
        : (isSelected ? Colors.white : _bookingsDateText);
    final closedLabelColor =
        isSelected ? _bookingsGold : const Color(0xFF8A3A3A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 68,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? _bookingsGold
                  : (isClosed ? const Color(0xFFF2C5C5) : _bookingsBorder),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? context.t('TODAY') : _formatShortWeekday(date),
                style: _bookingTextStyle(
                  color: dayColor,
                  size: 8,
                  weight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                date.day.toString(),
                style: _bookingTextStyle(
                  color: dateColor,
                  size: 16,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (isClosed) ...[
                const SizedBox(height: 3),
                Text(
                  context.t('CLOSED'),
                  style: _bookingTextStyle(
                    color: closedLabelColor,
                    size: 7.5,
                    weight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ] else
                const SizedBox(height: 10.5),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingEmptyState extends StatelessWidget {
  const _BookingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bookingsBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 36,
            color: _bookingsAccent,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('No bookings for this date'),
            style: _bookingTextStyle(
              size: 20,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('Pull to refresh or pick another date.'),
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 12,
              weight: FontWeight.w600,
              color: _bookingsSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTeamMembersForDateState extends StatelessWidget {
  const _NoTeamMembersForDateState({
    required this.reason,
  });

  final _NoTeamMembersForDateReason reason;

  String _message(BuildContext context) {
    switch (reason) {
      case _NoTeamMembersForDateReason.joiningDate:
        return context.t(
          'Team members whose joining date is later than the selected date are hidden from the schedule.',
        );
      case _NoTeamMembersForDateReason.employmentDate:
        return context.t(
          'Team members are hidden when their employment dates do not include the selected date.',
        );
      case _NoTeamMembersForDateReason.notScheduled:
        return context.t(
          'Team members who do not have working hours on the selected day are hidden from the schedule.',
        );
      case _NoTeamMembersForDateReason.none:
        return context.t(
          'Add a team member or select another date to view the schedule.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bookingsBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.groups_2_outlined,
            size: 34,
            color: _bookingsAccent,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('No team members available for this date'),
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 17,
              weight: FontWeight.w800,
              color: _bookingsPrimaryText,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _message(context),
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 12,
              weight: FontWeight.w600,
              color: _bookingsSecondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchClosedState extends StatelessWidget {
  const _BranchClosedState({
    required this.branchLabel,
    required this.selectedDate,
  });

  final String branchLabel;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final weekday = _formatScheduleDate(selectedDate).split(',').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bookingsBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 34,
            color: _bookingsAccent,
          ),
          const SizedBox(height: 12),
          Text(
            '${context.t(branchLabel)} ${context.t('is closed on')} ${context.t(weekday)}',
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 16,
              weight: FontWeight.w900,
              color: _bookingsPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'No working hours were provided for this day. Please choose another date to view or add bookings.',
            ),
            textAlign: TextAlign.center,
            style: _bookingTextStyle(
              size: 12,
              weight: FontWeight.w600,
              color: _bookingsSecondaryText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingListCard extends StatelessWidget {
  const _BookingListCard({
    required this.booking,
    required this.assignedStaffLabel,
    required this.isOwnerMode,
    required this.onTap,
    this.onPrimaryActionTap,
    this.isProcessing = false,
  });

  final Map<String, dynamic> booking;
  final String assignedStaffLabel;
  final bool isOwnerMode;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryActionTap;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final status = _normalizeStatus(booking['status']);
    final visuals = _statusVisuals(context, status);
    // final actionLabel = _showsConfirmAction(status, isOwnerMode: isOwnerMode)
    //     ? context.t('Accept').toUpperCase()
    //     : (_showsStartAction(status)
    //         ? context.t('Start Job').toUpperCase()
    //         : null);
    final actionLabel = _showsConfirmAction(status, isOwnerMode: isOwnerMode)
        ? context.t('Accept').toUpperCase()
        : (_showsStartAction(status)
            ? context.t('Start Job').toUpperCase()
            : (_showsFinishAction(status)
                ? context.t('Finish Job').toUpperCase()
                : null));

    final finishLabel = _showsFinishAction(status)
        ? context.t('Finish Job').toUpperCase()
        : null;
    final isStartAction = _showsStartAction(status);
    final isFinishAction = _showsFinishAction(status);
    final customer = _customerName(context, booking);
    final service = _serviceLabel(context, booking);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: visuals.cardBorderColor,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (status != 'CANCELLED')
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: status == 'IN_PROGRESS'
                          ? visuals.leadingColor
                          : visuals.leadingColor.withValues(alpha: 0.95),
                    ),
                  ),
                if (status != 'IN_PROGRESS' && status != 'CANCELLED')
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: visuals.leadingColor.withValues(alpha: 0.95),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (status != 'IN_PROGRESS' && status != 'CANCELLED')
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: visuals.leadingColor.withValues(alpha: 0.95),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (status == 'IN_PROGRESS')
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 138,
                      height: 16,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: visuals.leadingColor,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                ),
                                border: Border(
                                  left: BorderSide(
                                    color: visuals.leadingColor,
                                    width: 4,
                                  ),
                                  bottom: BorderSide(
                                    color: visuals.leadingColor,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _bookingTimeRange(booking),
                              style: _bookingTextStyle(
                                size: 12,
                                weight: FontWeight.w600,
                                color: _bookingsSecondaryText,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: visuals.label,
                            backgroundColor: visuals.pillBackgroundColor,
                            borderColor: visuals.pillBorderColor,
                            textColor: visuals.pillTextColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        service,
                        style: _bookingTextStyle(
                          size: 20,
                          height: 1.08,
                          weight: FontWeight.w500,
                          color: _bookingsPrimaryText,
                        ),
                      ),
                      if (customer.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/person1.png',
                              width: 14,
                              height: 14,
                              color: _bookingsSecondaryText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bookingTextStyle(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _bookingsSecondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (assignedStaffLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: _bookingsSecondaryText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${context.t('Assigned To')}: $assignedStaffLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bookingTextStyle(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _bookingsSecondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (actionLabel != null || finishLabel != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isProcessing ? null : onPrimaryActionTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isStartAction || isFinishAction
                                  ? _bookingsGold
                                  : visuals.primaryButtonColor,
                              foregroundColor: visuals.primaryTextColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isProcessing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    actionLabel ?? finishLabel!,
                                    style: _bookingTextStyle(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: _bookingTextStyle(
          color: textColor,
          size: 10,
          weight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StylistBookingDetailScreen extends StatefulWidget {
  const _StylistBookingDetailScreen({
    required this.booking,
    required this.branchId,
    required this.isOwnerMode,
  });

  final Map<String, dynamic> booking;
  final int branchId;
  final bool isOwnerMode;

  @override
  State<_StylistBookingDetailScreen> createState() =>
      _StylistBookingDetailScreenState();
}

class _BookingServiceOption {
  const _BookingServiceOption({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.durationMin,
    required this.path,
  });

  final int id;
  final String name;
  final int priceMinor;
  final int durationMin;
  final String path;
}

class _StylistBookingDetailScreenState
    extends State<_StylistBookingDetailScreen> {
  late Map<String, dynamic> _booking;
  late String _statusUpper;
  final List<StylistUsedItem> _addedItems = [];
  final List<StylistAppointmentServiceSegment> _addedServiceSegments = [];
  final Set<int> _addedServiceIds = <int>{};
  bool _loadingConfirm = false;
  bool _loadingStart = false;
  bool _loadingComplete = false;
  bool _loadingNoShow = false;
  bool _didChange = false;
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _statusUpper = _normalizeStatus(_booking['status']);
    _syncElapsedTicker();
  }

  void _syncElapsedTicker() {
    _elapsedTicker?.cancel();
    if (_statusUpper == 'IN_PROGRESS') {
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  // Future<void> _handleStartJob() async {
  //   if (_loadingStart) return;

  //   setState(() => _loadingStart = true);
  //   final resp = await _showStartJobOtpDialog(
  //     context,
  //     branchId: widget.branchId,
  //     appointmentId: _booking['id'] as int,
  //   );
  //   if (!mounted) return;
  //   setState(() => _loadingStart = false);
  //   if (resp == null) return;

  //   final newStatus =
  //       _normalizeStatus(resp['data']?['status'] ?? 'IN_PROGRESS');
  //   setState(() {
  //     _statusUpper = newStatus;
  //     _booking['status'] = newStatus;
  //     _didChange = true;
  //   });
  //   _syncElapsedTicker();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(resp['message']?.toString() ?? 'Job started'),
  //     ),
  //   );
  // }

  Future<void> _handleStartJob() async {
    if (!_canStartJob(_booking)) {
      Fluttertoast.showToast(
        msg: translateText(
          'You can start this job 15 minutes before appointment time',
        ),
      );
      return;
    }

    if (_loadingStart) return;

    setState(() => _loadingStart = true);

    final resp = await _showStartJobOtpDialog(
      context,
      branchId: widget.branchId,
      appointmentId: _booking['id'] as int,
    );

    if (!mounted) return;

    setState(() => _loadingStart = false);

    if (resp == null) return;

    final newStatus =
        _normalizeStatus(resp['data']?['status'] ?? 'IN_PROGRESS');

    setState(() {
      _statusUpper = newStatus;
      _booking['status'] = newStatus;
      _didChange = true;
    });

    _syncElapsedTicker();

    Fluttertoast.showToast(msg: resp['message']?.toString() ?? 'Job started');
  }

  Future<void> _handleConfirmJob() async {
    if (_loadingConfirm) return;

    setState(() => _loadingConfirm = true);
    final resp = await ApiService().confirmAppointment(
      branchId: widget.branchId,
      appointmentId: _booking['id'] as int,
    );
    if (!mounted) return;

    setState(() => _loadingConfirm = false);

    if (resp['success'] == true) {
      final newStatus = _normalizeStatus(
        resp['data']?['status'] ?? 'CONFIRMED',
      );
      setState(() {
        _statusUpper = newStatus;
        _booking['status'] = newStatus;
        _didChange = true;
      });
      Fluttertoast.showToast(
          msg: resp['message']?.toString() ??
              translateText('Booking Confirmed'));
      return;
    }

    Fluttertoast.showToast(
        msg: resp['message']?.toString() ?? 'Failed to confirm appointment');
  }

  Future<void> _handleCompleteJob() async {
    if (_loadingComplete) return;

    final feedback = await _showFinishJobFeedbackDialog(
      context,
      customerName: _customerName(context, _booking),
    );
    if (feedback == null) return;

    setState(() => _loadingComplete = true);
    final resp = await ApiService().completeAppointment(
      branchId: widget.branchId,
      appointmentId: _booking['id'] as int,
      rating: feedback['rating'] as int,
      comment: feedback['comment'] as String,
      serviceIds: _completionServiceIds(),
    );
    if (!mounted) return;

    setState(() => _loadingComplete = false);

    if (resp['success'] == true) {
      final newStatus = _normalizeStatus(
        resp['data']?['status'] ?? 'COMPLETED',
      );
      setState(() {
        _statusUpper = newStatus;
        _booking['status'] = newStatus;
        _didChange = true;
      });
      _syncElapsedTicker();
      Fluttertoast.showToast(
          msg: resp['message']?.toString() ?? 'Appointment completed');
      return;
    }

    Fluttertoast.showToast(
        msg: resp['message']?.toString() ?? 'Failed to complete appointment');
  }

  Future<void> _handleNoShow() async {
    if (_loadingNoShow) return;

    if (!_canMarkNoShow(_booking)) {
      Fluttertoast.showToast(
          msg: translateText(
              'No Show is available 15 minutes after start time'));
      return;
    }

    final confirmed = await _showNoShowConfirmationDialog(context);
    if (!confirmed || !mounted) return;

    final appointmentId = _asInt(_booking['id']);
    final branchId = _bookingBranchId(_booking) ?? widget.branchId;
    if (appointmentId == null) {
      Fluttertoast.showToast(msg: translateText('Invalid appointment'));
      return;
    }

    setState(() => _loadingNoShow = true);
    final resp = await ApiService().noShowAppointment(
      branchId: branchId,
      appointmentId: appointmentId,
    );
    if (!mounted) return;

    setState(() => _loadingNoShow = false);

    if (resp['success'] == true) {
      final newStatus = _normalizeStatus(resp['data']?['status'] ?? 'NO_SHOW');
      setState(() {
        _statusUpper = newStatus;
        _booking['status'] = newStatus;
        _didChange = true;
      });
      _syncElapsedTicker();
      Fluttertoast.showToast(
          msg: resp['message']?.toString() ?? 'Appointment marked no show');
      return;
    }

    Fluttertoast.showToast(
        msg: resp['message']?.toString() ?? 'Failed to mark no show');
  }

  Future<void> _showAddItemsInfo() async {
    if (_statusUpper == 'NO_SHOW') return;
    final item = await showStylistItemEntryFlow(context);
    if (!mounted || item == null) return;

    setState(() {
      _addedItems.add(item);
      _didChange = true;
    });

    Fluttertoast.showToast(msg: '${item.name} added locally for this booking.');
  }

  List<int> _completionServiceIds() => _addedServiceIds.toList();

  Set<int> _bookedServiceIds() {
    final ids = <int>{};

    void collectFromNode(
      dynamic node, {
      required bool includeDirectId,
    }) {
      if (node is List) {
        for (final item in node) {
          collectFromNode(
            item,
            includeDirectId: includeDirectId,
          );
        }
        return;
      }
      if (node is! Map) return;

      final map = Map<String, dynamic>.from(node);
      final directId = _asInt(map['branchServiceId'] ?? map['serviceId']);
      if (directId != null) {
        ids.add(directId);
      }
      if (includeDirectId) {
        final nestedDirectId = _asInt(map['id']);
        if (nestedDirectId != null) {
          ids.add(nestedDirectId);
        }
      }

      for (final key in const [
        'branchService',
        'service',
        'masterService',
        'cartItem',
        'item',
      ]) {
        final nested = map[key];
        if (nested is Map) {
          collectFromNode(nested, includeDirectId: true);
        }
      }
    }

    collectFromNode(_bookingItems(_booking), includeDirectId: false);
    collectFromNode(_bookingServices(_booking), includeDirectId: true);
    return ids;
  }

  List<_BookingServiceOption> _extractServiceOptions(dynamic raw) {
    final options = <_BookingServiceOption>[];
    void visit(dynamic node, [List<String> path = const []]) {
      if (node is List) {
        for (final item in node) {
          visit(item, path);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      final name = (map['displayName'] ??
              map['name'] ??
              map['title'] ??
              map['serviceName'] ??
              '')
          .toString()
          .trim();
      final id = _asInt(map['id'] ?? map['branchServiceId']);
      final priceMinor = _asInt(
            map['priceMinor'] ??
                map['defaultPriceMinor'] ??
                map['price'] ??
                map['amountMinor'],
          ) ??
          0;
      final durationMin = _asInt(map['durationMin'] ?? map['duration']) ?? 0;
      final looksLikeService =
          id != null && name.isNotEmpty && (durationMin > 0 || priceMinor > 0);
      if (looksLikeService) {
        options.add(
          _BookingServiceOption(
            id: id,
            name: name,
            priceMinor: priceMinor,
            durationMin: durationMin,
            path: path.where((part) => part.isNotEmpty).join(' • '),
          ),
        );
      }

      final nextPath =
          name.isEmpty || looksLikeService ? path : [...path, name];
      for (final key in const [
        'data',
        'categories',
        'subCategories',
        'subcategories',
        'services',
        'items',
        'results',
      ]) {
        visit(map[key], nextPath);
      }
    }

    visit(raw);
    final seen = <int>{};
    return options.where((option) => seen.add(option.id)).toList();
  }

  Future<void> _showAddServicesDialog() async {
    if (_statusUpper == 'NO_SHOW') return;
    if (_statusUpper != 'IN_PROGRESS') {
      Fluttertoast.showToast(
        msg: translateText('Add Services is available only for active jobs'),
      );
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    bool loaderShown = false;

    Future<void> showLoader() async {
      if (loaderShown || !mounted) return;
      loaderShown = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (loaderContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _bookingsGold,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      translateText('Loading services...'),
                      style: _bookingTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: _bookingsPrimaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    showLoader();

    try {
      final response = await ApiService().getBranchService(
        branchId: widget.branchId,
      );
      if (!mounted) return;

      if (loaderShown && rootNavigator.canPop()) {
        rootNavigator.pop();
      }

      final bookedIds = _bookedServiceIds();
      final services = _extractServiceOptions(response['data'] ?? response)
          .where(
            (service) =>
                !bookedIds.contains(service.id) &&
                !_addedServiceIds.contains(service.id),
          )
          .toList();

      if (services.isEmpty) {
        Fluttertoast.showToast(
          msg: translateText('No more services available to add'),
        );
        return;
      }

      final selected = <int>{};
      final picked = await showDialog<List<_BookingServiceOption>>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: _bookingsGold,
                  secondary: _bookingsAccent,
                  surface: Colors.white,
                ),
              ),
              child: Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 640,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _bookingsBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 22,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                translateText('Add Services'),
                                style: _bookingTextStyle(
                                  size: 20,
                                  weight: FontWeight.w800,
                                  color: _bookingsPrimaryText,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded),
                              color: _bookingsSecondaryText,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _bookingsBorder),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F1E3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.content_cut_rounded,
                                color: _bookingsGold,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                translateText(
                                  'Select services not already booked for this appointment.',
                                ),
                                style: _bookingTextStyle(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _bookingsSecondaryText,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: services.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final isSelected = selected.contains(service.id);
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selected.remove(service.id);
                                  } else {
                                    selected.add(service.id);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFEF8EA)
                                      : const Color(0xFFFCFBF9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? _bookingsGold.withValues(alpha: 0.55)
                                        : _bookingsBorder,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _bookingsGold
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? _bookingsGold
                                              : _bookingsSecondaryText,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service.name,
                                            style: _bookingTextStyle(
                                              size: 15,
                                              weight: FontWeight.w800,
                                              color: _bookingsPrimaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (service.path.isNotEmpty)
                                                service.path,
                                              if (service.durationMin > 0)
                                                '${service.durationMin} min',
                                              if (service.priceMinor > 0)
                                                formatMinorAmount(
                                                  service.priceMinor,
                                                ),
                                            ].join(' • '),
                                            style: _bookingTextStyle(
                                              size: 12,
                                              weight: FontWeight.w600,
                                              color: _bookingsSecondaryText,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  foregroundColor: _bookingsGold,
                                  side: const BorderSide(color: _bookingsGold),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  translateText('Cancel'),
                                  style: _bookingTextStyle(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: _bookingsGold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(
                                          dialogContext,
                                          services
                                              .where((service) =>
                                                  selected.contains(service.id))
                                              .toList(),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _bookingsGold,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFE5E7EB),
                                  disabledForegroundColor:
                                      const Color(0xFF9CA3AF),
                                  minimumSize: const Size.fromHeight(48),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  translateText('Add'),
                                  style: _bookingTextStyle(
                                    size: 14,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      if (!mounted || picked == null || picked.isEmpty) return;
      setState(() {
        for (final service in picked) {
          _addedServiceIds.add(service.id);
        }
        _addedServiceSegments.addAll(
          picked.map(
            (service) => StylistAppointmentServiceSegment(
              title: service.name,
              timeLabel: service.durationMin > 0
                  ? '${service.durationMin} min'
                  : translateText('Added'),
              metaLabel: service.priceMinor > 0
                  ? formatMinorAmount(service.priceMinor)
                  : null,
            ),
          ),
        );
        _didChange = true;
      });
    } catch (error) {
      if (loaderShown && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    }
  }

  Future<void> _refreshBookingDetails() async {
    try {
      final start = _bookingStart(_booking);
      final targetDate = start ?? DateTime.now();
      final response = widget.isOwnerMode
          ? await ApiService().fetchAppointments(
              widget.branchId,
              _formatApiDate(targetDate),
            )
          : await ApiService().fetchTeamAppointmentsByDate(
              widget.branchId,
              _asInt(_booking['assignedUserBranchId']) ??
                  _asInt(_booking['assignedUserId']) ??
                  _asInt(_booking['teamMember']?['id']) ??
                  _asInt(_booking['userBranchId']) ??
                  0,
              _formatApiDate(targetDate),
            );

      final rawData = response['data'];
      final bookings = rawData is List
          ? rawData
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const <Map<String, dynamic>>[];

      final appointmentId = _asInt(_booking['id']);
      final refreshed = appointmentId == null
          ? null
          : bookings.cast<Map<String, dynamic>?>().firstWhere(
                (item) => _asInt(item?['id']) == appointmentId,
                orElse: () => null,
              );

      if (!mounted) return;

      if (refreshed != null) {
        setState(() {
          _booking = Map<String, dynamic>.from(refreshed);
          _statusUpper = _normalizeStatus(_booking['status']);
        });
        _syncElapsedTicker();
        return;
      }

      Fluttertoast.showToast(
          msg: translateText('Unable to refresh appointment details'));
    } catch (error) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: error.toString());
    }
  }

  Duration _detailElapsedTime() {
    final start = _bookingStart(_booking);
    if (_statusUpper != 'IN_PROGRESS' && _statusUpper != 'COMPLETED') {
      return Duration.zero;
    }

    if (start == null) {
      return _statusUpper == 'COMPLETED'
          ? Duration(minutes: _bookingDurationMinutes(_booking))
          : Duration.zero;
    }

    final now = DateTime.now();
    if (_statusUpper == 'IN_PROGRESS') {
      return now.isAfter(start) ? now.difference(start) : Duration.zero;
    }

    final end = _bookingEnd(_booking);
    if (end != null && end.isAfter(start)) {
      return end.difference(start);
    }

    return Duration(minutes: _bookingDurationMinutes(_booking));
  }

  String _formatDurationClock(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final visuals = _statusVisuals(context, _statusUpper);
    final serviceSummary = _serviceCardSummary(context, _booking);
    final serviceSegments = [
      ..._detailServiceSegments(context, _booking),
      ..._addedServiceSegments,
    ];
    final assignedStaffLabel =
        widget.isOwnerMode ? _assignedStaffSummary(context, _booking) : '';
    final timeRange = _bookingTimeRange(_booking);
    final totalAmount = _bookingTotalPrice(_booking);
    final bookingDate = _bookingDate(_booking);
    final elapsed = _detailElapsedTime();
    final scheduledMinutes = _bookingDurationMinutes(_booking);
    final progress = scheduledMinutes <= 0
        ? 0.0
        : (elapsed.inSeconds / (scheduledMinutes * 60)).clamp(0.0, 1.0);
    final statusHeadline = _statusLabel(context, _statusUpper);
    const preferences = [
      StylistAppointmentPreferenceData(
        title: 'Cool Ash',
        dateLabel: 'AUG 2023',
      ),
      StylistAppointmentPreferenceData(
        title: 'Soft Layers',
        dateLabel: 'JAN 2023',
      ),
      StylistAppointmentPreferenceData(
        title: 'HydraGlaze',
        dateLabel: 'MAY 2023',
      ),
    ];
    // final primaryAction = _showsConfirmAction(
    //   _statusUpper,
    //   isOwnerMode: widget.isOwnerMode,
    // )
    //     ? context.t('Accept').toUpperCase()
    //     : (_showsFinishAction(_statusUpper)
    //         ? context.t('Finish Job').toUpperCase()
    //         : (_showsStartAction(_statusUpper)
    //             ? context.t('Start Job').toUpperCase()
    //             : null));
    final canStartJob = _canStartJob(_booking);

    final primaryAction = _showsConfirmAction(
      _statusUpper,
      isOwnerMode: widget.isOwnerMode,
    )
        ? context.t('Accept').toUpperCase()
        : (_showsFinishAction(_statusUpper)
            ? context.t('Finish Job').toUpperCase()
            : (_showsStartAction(_statusUpper)
                ? context.t('Start Job').toUpperCase()
                : null));

    final primaryColor =
        (_showsFinishAction(_statusUpper) || _showsStartAction(_statusUpper))
            ? _bookingsGold
            : _bookingsAccent;
    final showNoShowAction = _showsNoShowAction(_statusUpper);
    final canAddServices = _statusUpper == 'IN_PROGRESS';
    final isPrimaryProcessing =
        _loadingConfirm || _loadingStart || _loadingComplete;
    final isAnyActionProcessing = isPrimaryProcessing || _loadingNoShow;
    final canNoShow =
        showNoShowAction && _canMarkNoShow(_booking) && !isAnyActionProcessing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context, _didChange);
        }
      },
      child: StylistAppointmentDetailsComponent(
        onBack: () => Navigator.pop(context, _didChange),
        statusHeadline: statusHeadline,
        statusCode: _statusUpper,
        statusLabel: _statusLabel(context, _statusUpper),
        statusPillBackgroundColor: visuals.pillBackgroundColor,
        statusPillBorderColor: visuals.pillBorderColor,
        statusPillTextColor: visuals.pillTextColor,
        elapsedClock: _formatDurationClock(elapsed),
        progress: progress,
        elapsedMinutes: elapsed.inMinutes,
        scheduledMinutes: scheduledMinutes,
        dateLabel: bookingDate == null ? '-' : _formatScheduleDate(bookingDate),
        timeRange: timeRange,
        customerName: _customerName(context, _booking),
        customerPhone: _customerPhone(_booking),
        serviceSummary: serviceSummary,
        assignedStaffLabel: assignedStaffLabel,
        serviceSegments: serviceSegments,
        preferences: preferences,
        totalAmount: totalAmount,
        primaryAction: primaryAction,
        primaryActionColor: primaryColor,
        isPrimaryLoading: isPrimaryProcessing,
        // onPrimaryAction: _loadingNoShow
        //     ? null
        //     : (_showsConfirmAction(
        //         _statusUpper,
        //         isOwnerMode: widget.isOwnerMode,
        //       )
        //         ? _handleConfirmJob
        //         : (_showsFinishAction(_statusUpper)
        //             ? _handleCompleteJob
        //             : (_showsStartAction(_statusUpper)
        //                 ? _handleStartJob
        //                 : null))),
        onPrimaryAction: _loadingNoShow
            ? null
            : (_showsConfirmAction(
                _statusUpper,
                isOwnerMode: widget.isOwnerMode,
              )
                ? _handleConfirmJob
                : (_showsFinishAction(_statusUpper)
                    ? _handleCompleteJob
                    : (canStartJob ? _handleStartJob : null))),
        secondaryAction:
            showNoShowAction ? context.t('No Show').toUpperCase() : null,
        secondaryActionColor: const Color(0xFF374151),
        isSecondaryLoading: _loadingNoShow,
        onSecondaryAction: canNoShow ? _handleNoShow : null,
        addedItems: _addedItems,
        onAddItems: _showAddItemsInfo,
        onAddServices: _showAddServicesDialog,
        canAddServices: canAddServices,
        onRefresh: _refreshBookingDetails,
      ),
    );
  }
}
