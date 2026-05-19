import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/stylist_appointments/widgets/stylist_appointment_details_component.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../features/stylist_item_entry/stylist_item_entry_feature.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'AddBookings.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

const String _bookingsFontFamily = 'Manrope';
const Color _bookingsAccent = Color(0xFFC19A6B);
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

class _SalonBranchOption {
  const _SalonBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    this.addressSummary = '',
    this.isMain = false,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String addressSummary;
  final bool isMain;

  String get label {
    if (branchName.isNotEmpty) return branchName;
    if (salonName.isNotEmpty) return salonName;
    return 'Salon #$salonId';
  }
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatApiDate(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

String _formatShortWeekday(DateTime value) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[value.weekday - 1];
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = _twoDigits(value.minute);
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${_twoDigits(hour)}:$minute $suffix';
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

DateTime? _bookingStart(Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  return _parseLocal(
    booking['startAt'] ?? (items.isNotEmpty ? items.first['startAt'] : null),
  );
}

DateTime? _bookingEnd(Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  return _parseLocal(
    booking['endAt'] ?? (items.isNotEmpty ? items.first['endAt'] : null),
  );
}

String _customerName(BuildContext context, Map<String, dynamic> booking) {
  final user = booking['user'];
  if (user is Map) {
    final map = Map<String, dynamic>.from(user);
    final first = map['firstName']?.toString().trim() ?? '';
    final last = map['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final name = map['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return context.t('Customer');
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

List<String> _assignedStaffNames(Map<String, dynamic> booking) {
  final names = <String>[];
  final seen = <String>{};

  void addName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    if (seen.add(normalized)) {
      names.add(normalized);
    }
  }

  addName(_personName(booking['teamMember']));

  for (final item in _bookingItems(booking)) {
    addName(_personName(item['teamMember']));
    addName(_personName(item['assignedUserBranch']?['user']));
  }

  return names;
}

String _assignedStaffSummary(
    BuildContext context, Map<String, dynamic> booking) {
  final names = _assignedStaffNames(booking);
  if (names.isEmpty) return '';
  return names.join(', ');
}

String _serviceLabel(BuildContext context, Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    final firstName =
        items.first['branchService']?['displayName']?.toString().trim() ??
            items.first['service']?.toString().trim() ??
            items.first['displayName']?.toString().trim() ??
            items.first['name']?.toString().trim() ??
            '';
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

String _serviceCardSummary(BuildContext context, Map<String, dynamic> booking) {
  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    final names = items
        .map(
          (item) =>
              item['branchService']?['displayName']?.toString().trim() ??
              item['service']?.toString().trim() ??
              item['displayName']?.toString().trim() ??
              item['name']?.toString().trim() ??
              '',
        )
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return context.t('Appointment');
    if (names.length == 1) return names.first;
    return '${names.first}, ...';
  }

  final services = _bookingServices(booking);
  final names = services
      .map((service) => service['name']?.toString().trim() ?? '')
      .where((name) => name.isNotEmpty)
      .toList();
  if (names.isEmpty) return context.t('Appointment');
  if (names.length == 1) return names.first;
  return '${names.first}, ...';
}

List<StylistAppointmentServiceSegment> _detailServiceSegments(
  BuildContext context,
  Map<String, dynamic> booking,
) {
  final items = _bookingItems(booking);
  if (items.isNotEmpty) {
    DateTime? fallbackStart = _bookingStart(booking);
    return items.map((item) {
      final name = item['branchService']?['displayName']?.toString().trim() ??
          item['service']?.toString().trim() ??
          item['displayName']?.toString().trim() ??
          item['name']?.toString().trim() ??
          context.t('Appointment');
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
        title: name.isEmpty ? context.t('Appointment') : name,
        timeLabel: (start != null && end != null)
            ? '${_formatTime(start)} - ${_formatTime(end)}'
            : '--',
        metaLabel:
            durationMin != null && durationMin > 0 ? '${durationMin}m' : null,
      );
    }).toList();
  }

  final services = _bookingServices(booking);
  if (services.isNotEmpty) {
    DateTime? cursor = _bookingStart(booking);
    return services.map((service) {
      final name = service['name']?.toString().trim() ?? '';
      final durationMin = _asInt(service['durationMin']);
      final start = cursor;
      final end = start != null && durationMin != null && durationMin > 0
          ? start.add(Duration(minutes: durationMin))
          : null;
      if (end != null) cursor = end;

      return StylistAppointmentServiceSegment(
        title: name.isEmpty ? context.t('Appointment') : name,
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
      title: context.t('Appointment'),
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
  final totalPriceMinor = _asInt(booking['totalPriceMinor']);
  if (totalPriceMinor != null && totalPriceMinor > 0) {
    return '₹$totalPriceMinor';
  }

  final items = _bookingItems(booking);
  final itemsTotalPriceMinor = items.fold<int>(
    0,
    (sum, item) =>
        sum +
        (_asInt(item['branchService']?['priceMinor'] ?? item['priceMinor']) ??
            0),
  );
  if (itemsTotalPriceMinor > 0) return '₹$itemsTotalPriceMinor';

  final services = _bookingServices(booking);
  final totalPrice = services.fold<num>(
    0,
    (sum, service) => sum + ((service['price'] as num?) ?? 0),
  );
  if (totalPrice > 0) {
    return '₹${totalPrice % 1 == 0 ? totalPrice.toInt() : totalPrice.toStringAsFixed(2)}';
  }

  return '₹2,400';
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

bool _showsFinishAction(String status) => status == 'IN_PROGRESS';

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
                  PinCodeTextField(
                    appContext: dialogCtx,
                    length: 6,
                    autoDismissKeyboard: true,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(10),
                      fieldHeight: 54,
                      fieldWidth: 44,
                      activeFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      activeColor: hasError ? Colors.red : _bookingsAccent,
                      selectedColor: hasError ? Colors.red : _bookingsAccent,
                      inactiveColor: hasError ? Colors.red : _bookingsAccent,
                      errorBorderColor: Colors.red,
                    ),
                    enableActiveFill: true,
                    onChanged: (value) {
                      otp = value;
                      setDialogState(() => hasError = false);
                    },
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
                        if (otp.length != 6) {
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
                  backgroundColor: _bookingsAccent,
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

Future<Map<String, dynamic>?> _showFinishJobFeedbackDialog(
  BuildContext context, {
  required String customerName,
}) async {
  int selectedRating = 0;
  String commentText = '';

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8D1C8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Finish Job',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: _bookingsUpcoming,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.t('Rating'),
                      style: const TextStyle(
                        color: _bookingsUpcoming,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        return IconButton(
                          onPressed: () {
                            setSheetState(() => selectedRating = rating);
                          },
                          icon: Icon(
                            rating <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: _bookingsAccent,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (value) => commentText = value,
                      decoration: InputDecoration(
                        hintText: context.t('Write comment'),
                        filled: true,
                        fillColor: _bookingsCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE6DFD7),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE6DFD7),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _bookingsAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx, {
                            'rating': selectedRating,
                            'comment': commentText.trim(),
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bookingsDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(context.t('Submit')),
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
  _SalonBranchOption? _selectedOption;
  DateTime _selectedDate = DateTime.now();
  DateTime _visibleDateStart = DateTime.now();
  int? _userId;
  bool _isLoading = true;
  bool _loadingDate = false;
  int? _confirmingAppointmentId;
  int? _startingAppointmentId;
  int? _completingAppointmentId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleDateStart = _selectedDate;
    _loadOptions(showPageLoader: false, showInlineLoader: true);
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

          options.add(
            _SalonBranchOption(
              salonId: salonId,
              branchId: branchId,
              salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
              branchName: branchName.isEmpty
                  ? (salonName.isEmpty ? 'Salon #$salonId' : salonName)
                  : branchName,
              addressSummary: _branchAddressSummary(branch['address']),
              isMain: branch['isMain'] == true,
            ),
          );
        }
        continue;
      }

      final derivedBranchId =
          _asInt(salon['branchId']) ?? _asInt(salon['branch_id']) ?? salonId;
      final derivedBranchName =
          (salon['branchName'] ?? salon['branch_name'])?.toString().trim();

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
    if (selected != null && (widget.isOwnerMode || userId != null)) {
      final result = await _fetchBookingsForBranch(
        branchId: selected.branchId,
        userId: userId,
      );
      bookings = result.bookings;
      errorMessage ??= result.errorMessage;
    } else if (selected != null && !widget.isOwnerMode && userId == null) {
      errorMessage ??= 'Unable to load stylist bookings';
    }

    if (!mounted) return;
    setState(() {
      _options = options;
      _selectedOption = selected;
      _userId = widget.isOwnerMode ? null : userId;
      _bookings = bookings;
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

    if (!mounted) return;
    setState(() {
      _bookings = result.bookings;
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
    }

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
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

    if (selected != null && (widget.isOwnerMode || userId != null)) {
      final result = await _fetchBookingsForBranch(
        branchId: selected.branchId,
        userId: userId,
      );
      bookings = result.bookings;
      errorMessage = result.errorMessage;
    }

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _errorMessage = errorMessage;
      _loadingDate = false;
    });
  }

  void _shiftVisibleDates(int days) {
    setState(() {
      _visibleDateStart = _visibleDateStart.add(Duration(days: days));
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp['message']?.toString() ?? translateText('Booking Confirmed'),
          ),
        ),
      );
      await _reloadBookingsForSelectedOption();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resp['message']?.toString() ?? 'Failed to confirm appointment',
        ),
      ),
    );
  }

  Future<void> _openAddBooking() async {
    final selected = _selectedOption;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Please select a salon'))),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookingScreen(
          salonId: selected.salonId,
          branchId: selected.branchId,
        ),
      ),
    );

    if (!mounted || result == null) return;
    await _reloadBookingsForSelectedOption();
  }

  Future<void> _handleStartFromList(Map<String, dynamic> booking) async {
    final selected = _selectedOption;
    final appointmentId = _asInt(booking['id']);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resp['message']?.toString() ?? 'Job started'),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp['message']?.toString() ?? 'Appointment completed',
          ),
        ),
      );
      await _reloadBookingsForSelectedOption();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resp['message']?.toString() ?? 'Failed to complete appointment',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final selectedLabel = _selectedOption?.label.isNotEmpty == true
        ? _selectedOption!.label
        : context.t('Select Branch');
    final selectedAddressSummary = _selectedOption?.addressSummary ?? '';
    final canChangeBranch = _options.length > 1;
    final sortedBookings = _sortedBookings();
    final dateRailStart = _visibleDateStart;
    final dateRail = List.generate(
      7,
      (index) => dateRailStart.add(Duration(days: index)),
    );

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
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _HeaderBranchSelector(
                      key: _branchSelectorKey,
                      label: selectedLabel,
                      addressSummary: selectedAddressSummary,
                      isInteractive: canChangeBranch,
                      onTap: canChangeBranch ? _openBranchPicker : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _bookingsBorder,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IgnorePointer(
                          ignoring: _loadingDate,
                          child: Row(
                            children: [
                              _DateRailArrowButton(
                                icon: Icons.keyboard_arrow_left_rounded,
                                onTap: () => _shiftVisibleDates(-7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        List.generate(dateRail.length, (index) {
                                      final date = dateRail[index];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: index == dateRail.length - 1
                                              ? 0
                                              : 6,
                                        ),
                                        child: _CalendarDateCard(
                                          date: date,
                                          isSelected:
                                              _isSameDay(date, _selectedDate),
                                          onTap: () => _setSelectedDate(date),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _DateRailArrowButton(
                                icon: Icons.keyboard_arrow_right_rounded,
                                onTap: () => _shiftVisibleDates(7),
                              ),
                            ],
                          ),
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
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                  if (!_isLoading && sortedBookings.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _BookingEmptyState(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: sortedBookings
                            .map(
                              (booking) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _BookingListCard(
                                  booking: booking,
                                  assignedStaffLabel: widget.isOwnerMode
                                      ? _assignedStaffSummary(context, booking)
                                      : '',
                                  isOwnerMode: widget.isOwnerMode,
                                  onTap: () => _openBookingDetail(booking),
                                  onPrimaryActionTap: _showsConfirmAction(
                                    _normalizeStatus(booking['status']),
                                    isOwnerMode: widget.isOwnerMode,
                                  )
                                      ? () => _handleConfirmFromList(booking)
                                      : _showsStartAction(
                                          _normalizeStatus(booking['status']),
                                        )
                                          ? () => _handleStartFromList(booking)
                                          : _showsFinishAction(
                                              _normalizeStatus(
                                                booking['status'],
                                              ),
                                            )
                                              ? () => _handleCompleteFromList(
                                                    booking,
                                                  )
                                              : null,
                                  isProcessing:
                                      (_confirmingAppointmentId != null &&
                                              _confirmingAppointmentId ==
                                                  _asInt(booking['id'])) ||
                                          (_startingAppointmentId != null &&
                                              _startingAppointmentId ==
                                                  _asInt(booking['id'])) ||
                                          (_completingAppointmentId != null &&
                                              _completingAppointmentId ==
                                                  _asInt(booking['id'])),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
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
      floatingActionButton: widget.isOwnerMode
          ? FloatingActionButton.extended(
              heroTag: 'owner_add_booking_fab',
              onPressed: _openAddBooking,
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.grey,
              icon: Image.asset(
                'assets/images/plusIcn.png',
                width: 18,
                height: 18,
              ),
              label: Text(
                translateText('Add Booking'),
                style: TextStyle(
                  color: AppColors.darkGrey,
                ),
              ),
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
          constraints: const BoxConstraints(minWidth: 164),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _bookingsPage,
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
          width: 36,
          height: 64,
          decoration: BoxDecoration(
            color: _bookingsCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bookingsBorder),
          ),
          child: Icon(
            icon,
            color: _bookingsSecondaryText,
            size: 20,
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
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final backgroundColor = isSelected
        ? _bookingsAccent
        : (isToday ? const Color(0xFFEAF4FF) : _bookingsCard);
    final dayColor = isSelected ? Colors.white : _bookingsSecondaryText;
    final dateColor = isSelected ? Colors.white : _bookingsDateText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _bookingsBorder),
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
            children: [
              Text(
                _formatShortWeekday(date).toUpperCase(),
                style: _bookingTextStyle(
                  color: dayColor,
                  size: 10,
                  weight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              // const SizedBox(height: 2),
              Text(
                date.day.toString(),
                style: _bookingTextStyle(
                  color: dateColor,
                  size: 18,
                  weight: FontWeight.w500,
                ),
              ),
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
    final actionLabel = _showsConfirmAction(status, isOwnerMode: isOwnerMode)
        ? context.t('Accept').toUpperCase()
        : (_showsStartAction(status)
            ? context.t('Start Job').toUpperCase()
            : null);
    final finishLabel = _showsFinishAction(status)
        ? context.t('Finish Job').toUpperCase()
        : null;
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
                              backgroundColor: visuals.primaryButtonColor,
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

class _StylistBookingDetailScreenState
    extends State<_StylistBookingDetailScreen> {
  late Map<String, dynamic> _booking;
  late String _statusUpper;
  final List<StylistUsedItem> _addedItems = [];
  bool _loadingConfirm = false;
  bool _loadingStart = false;
  bool _loadingComplete = false;
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

  Future<void> _handleStartJob() async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resp['message']?.toString() ?? 'Job started'),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp['message']?.toString() ?? translateText('Booking Confirmed'),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resp['message']?.toString() ?? 'Failed to confirm appointment',
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp['message']?.toString() ?? 'Appointment completed',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resp['message']?.toString() ?? 'Failed to complete appointment',
        ),
      ),
    );
  }

  Future<void> _showAddItemsInfo() async {
    final item = await showStylistItemEntryFlow(context);
    if (!mounted || item == null) return;

    setState(() {
      _addedItems.add(item);
      _didChange = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added locally for this booking.'),
      ),
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText('Unable to refresh appointment details'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
    final serviceSegments = _detailServiceSegments(context, _booking);
    final assignedStaffLabel =
        widget.isOwnerMode ? _assignedStaffSummary(context, _booking) : '';
    final timeRange = _bookingTimeRange(_booking);
    final totalAmount = _bookingTotalPrice(_booking);
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
        _showsFinishAction(_statusUpper) ? _bookingsDark : _bookingsAccent;

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
        timeRange: timeRange,
        serviceSummary: serviceSummary,
        assignedStaffLabel: assignedStaffLabel,
        serviceSegments: serviceSegments,
        preferences: preferences,
        totalAmount: totalAmount,
        primaryAction: primaryAction,
        primaryActionColor: primaryColor,
        isPrimaryLoading: _loadingConfirm || _loadingStart || _loadingComplete,
        onPrimaryAction: _showsConfirmAction(
          _statusUpper,
          isOwnerMode: widget.isOwnerMode,
        )
            ? _handleConfirmJob
            : (_showsFinishAction(_statusUpper)
                ? _handleCompleteJob
                : (_showsStartAction(_statusUpper) ? _handleStartJob : null)),
        addedItems: _addedItems,
        onAddItems: _showAddItemsInfo,
        onRefresh: _refreshBookingDetails,
      ),
    );
  }
}
