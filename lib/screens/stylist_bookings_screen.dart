import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistBookingsScreen extends StatefulWidget {
  const StylistBookingsScreen({super.key});

  @override
  State<StylistBookingsScreen> createState() => _StylistBookingsScreenState();
}

class _SalonBranchOption {
  const _SalonBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;

  String get label {
    if (salonName.isNotEmpty &&
        branchName.isNotEmpty &&
        salonName != branchName) {
      return '$salonName • $branchName';
    }
    if (salonName.isNotEmpty) return salonName;
    if (branchName.isNotEmpty) return branchName;
    return 'Salon #$salonId';
  }
}

class _StylistBookingsScreenState extends State<StylistBookingsScreen> {
  static const double _rowHeight = 44.0;
  static const double _scheduleWidth = 420.0;
  static const double _verticalScrollBottomInset = 24.0;

  final ApiService _apiService = ApiService();
  final ScrollController _timeColumnVController = ScrollController();
  final ScrollController _gridVController = ScrollController();
  final ScrollController _headerHController = ScrollController();
  final ScrollController _gridHController = ScrollController();

  List<_SalonBranchOption> _options = const [];
  List<Map<String, dynamic>> _bookings = const [];
  _SalonBranchOption? _selectedOption;
  DateTime _selectedDate = DateTime.now();
  DateTime _weekAnchor = DateTime.now();
  int? _userId;
  bool _isLoading = true;
  bool _loadingDate = false;
  String? _errorMessage;
  bool _syncingV = false;
  bool _syncingH = false;
  List<String> _timeSlots = const [];
  late DateTime _dayStart;
  late DateTime _dayEnd;

  @override
  void initState() {
    super.initState();
    _weekAnchor = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final defaultSchedule = _buildDefaultScheduleRange();
    _timeSlots = defaultSchedule.timeSlots;
    _dayStart = defaultSchedule.dayStart;
    _dayEnd = defaultSchedule.dayEnd;
    _loadOptions();

    _timeColumnVController.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_gridVController.hasClients) {
        final off = _timeColumnVController.offset;
        if ((_gridVController.offset - off).abs() > 0.5) {
          _gridVController.jumpTo(off);
        }
      }
      _syncingV = false;
    });

    _gridVController.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_timeColumnVController.hasClients) {
        final off = _gridVController.offset;
        if ((_timeColumnVController.offset - off).abs() > 0.5) {
          _timeColumnVController.jumpTo(off);
        }
      }
      _syncingV = false;
    });

    _headerHController.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_gridHController.hasClients) {
        final off = _headerHController.offset;
        if ((_gridHController.offset - off).abs() > 0.5) {
          _gridHController.jumpTo(off);
        }
      }
      _syncingH = false;
    });

    _gridHController.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_headerHController.hasClients) {
        final off = _gridHController.offset;
        if ((_headerHController.offset - off).abs() > 0.5) {
          _headerHController.jumpTo(off);
        }
      }
      _syncingH = false;
    });
  }

  ({
    List<String> timeSlots,
    DateTime dayStart,
    DateTime dayEnd,
  }) _buildDefaultScheduleRange() {
    return _buildScheduleRangeFromMinutes(
      startMinutes: 8 * 60,
      endMinutes: 20 * 60,
    );
  }

  ({
    List<String> timeSlots,
    DateTime dayStart,
    DateTime dayEnd,
  }) _buildScheduleRangeFromMinutes({
    required int startMinutes,
    required int endMinutes,
  }) {
    final slots = <String>[];
    final formatter = DateFormat('h:mm a');
    final safeEndMinutes =
        endMinutes > startMinutes ? endMinutes : startMinutes + 12 * 60;
    final dayStart = _combineDateAndTime(
      _selectedDate,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    final dayEnd = _combineDateAndTime(
      _selectedDate,
      safeEndMinutes ~/ 60,
      safeEndMinutes % 60,
    );
    DateTime current = dayStart;

    while (current.isBefore(dayEnd)) {
      slots.add(formatter.format(current));
      current = current.add(const Duration(minutes: 15));
    }

    if (slots.isEmpty) {
      slots.add(formatter.format(dayStart));
    }

    return (
      timeSlots: slots,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  String _normalizeStatus(dynamic value) =>
      (value ?? '').toString().trim().toUpperCase();

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime? _parseLocal(dynamic iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime _combineDateAndTime(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  int _minutesFromMidnight(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay? _parseScheduleTime(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    final normalized = raw.toLowerCase();
    final match = RegExp(r'(\d{1,2})\s*:\s*(\d{2})(?::)?\s*([ap]m)?')
        .firstMatch(normalized);
    if (match == null) return null;

    final parsedHour = int.tryParse(match.group(1) ?? '');
    final parsedMinute = int.tryParse(match.group(2) ?? '');
    if (parsedHour == null || parsedMinute == null) {
      return null;
    }

    final meridiem = match.group(3);
    int hour = parsedHour;
    if (meridiem != null) {
      if (meridiem == 'pm' && hour < 12) {
        hour += 12;
      } else if (meridiem == 'am' && hour == 12) {
        hour = 0;
      }
    }

    if (hour < 0 || hour > 23 || parsedMinute < 0 || parsedMinute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: parsedMinute);
  }

  ({
    List<String> timeSlots,
    DateTime dayStart,
    DateTime dayEnd,
  }) _resolveScheduleRange(Map<String, dynamic>? branchData) {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final targetDay = DateFormat('EEEE').format(_selectedDate).toLowerCase();
    final rawSchedule = branchData?['schedule'];

    if (rawSchedule is List) {
      for (final rawEntry in rawSchedule) {
        if (rawEntry is! Map) continue;
        final entry = Map<String, dynamic>.from(rawEntry);
        final day = (entry['day'] ?? '').toString().trim().toLowerCase();
        if (day != targetDay) continue;

        final rawSlots = entry['slots'];
        if (rawSlots is! List) continue;

        for (final rawSlot in rawSlots) {
          if (rawSlot is! Map) continue;
          final slot = Map<String, dynamic>.from(rawSlot);
          final slotStart = _parseScheduleTime(slot['start']);
          final slotEnd = _parseScheduleTime(slot['end']);
          if (slotStart != null) {
            if (startTime == null ||
                _minutesFromMidnight(slotStart) <
                    _minutesFromMidnight(startTime)) {
              startTime = slotStart;
            }
          }
          if (slotEnd != null) {
            if (endTime == null ||
                _minutesFromMidnight(slotEnd) > _minutesFromMidnight(endTime)) {
              endTime = slotEnd;
            }
          }
        }
      }
    }

    startTime ??= _parseScheduleTime(branchData?['startTime']);
    endTime ??= _parseScheduleTime(branchData?['endTime']);

    if (startTime == null || endTime == null) {
      return _buildDefaultScheduleRange();
    }

    return _buildScheduleRangeFromMinutes(
      startMinutes: _minutesFromMidnight(startTime),
      endMinutes: _minutesFromMidnight(endTime),
    );
  }

  Future<
      ({
        List<String> timeSlots,
        DateTime dayStart,
        DateTime dayEnd,
      })> _loadBranchScheduleRange(int branchId) async {
    try {
      final response = await _apiService.getBranchDetail(branchId);
      final rawData = response['data'];
      final branchData =
          rawData is Map ? Map<String, dynamic>.from(rawData) : null;
      final schedule = _resolveScheduleRange(branchData);
      final todayName = DateFormat('EEEE').format(_selectedDate);
      final todayDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final rawSchedule = branchData?['schedule'];
      String resolvedSlot = 'fallback';
      if (rawSchedule is List) {
        final targetDay = todayName.toLowerCase();
        for (final rawEntry in rawSchedule) {
          if (rawEntry is! Map) continue;
          final entry = Map<String, dynamic>.from(rawEntry);
          final day = (entry['day'] ?? '').toString().trim().toLowerCase();
          if (day != targetDay) continue;
          final rawSlots = entry['slots'];
          if (rawSlots is List &&
              rawSlots.isNotEmpty &&
              rawSlots.first is Map) {
            final firstSlot = Map<String, dynamic>.from(rawSlots.first as Map);
            resolvedSlot =
                '${firstSlot['start'] ?? '--'} to ${firstSlot['end'] ?? '--'}';
          } else {
            resolvedSlot = 'no slots';
          }
          break;
        }
      }
      debugPrint(
        '[StylistBookings] today=$todayName date=$todayDate slot=$resolvedSlot',
      );
      debugPrint(
        '[StylistBookings] resolved schedule for branchId=$branchId on ${DateFormat('EEEE').format(_selectedDate)} '
        'from ${DateFormat('h:mm a').format(schedule.dayStart)} to ${DateFormat('h:mm a').format(schedule.dayEnd)}',
      );
      return schedule;
    } catch (e) {
      debugPrint('[StylistBookings] failed to load branch schedule: $e');
      return _buildDefaultScheduleRange();
    }
  }

  String _customerName(Map<String, dynamic> booking) {
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

  String _serviceLabel(Map<String, dynamic> booking) {
    final rawItems = (booking['items'] as List?) ?? const [];
    final items =
        rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (items.isEmpty) return context.t('Appointment');

    final firstName =
        items.first['branchService']?['displayName']?.toString().trim() ?? '';
    final baseLabel =
        firstName.isNotEmpty ? firstName : context.t('Appointment');
    if (items.length == 1) return baseLabel;
    return '$baseLabel + ${items.length - 1}';
  }

  String _readPriceText(Map<String, dynamic> booking) {
    final rawItems = (booking['items'] as List?) ?? const [];
    final items =
        rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    final totalPriceMinor = items.fold<int>(
      0,
      (sum, item) => sum + (_asInt(item['branchService']?['priceMinor']) ?? 0),
    );
    return totalPriceMinor > 0 ? '₹$totalPriceMinor' : '';
  }

  String _readTimeRange(Map<String, dynamic> booking) {
    final rawItems = (booking['items'] as List?) ?? const [];
    final items =
        rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    final start = _parseLocal(
      booking['startAt'] ?? (items.isNotEmpty ? items.first['startAt'] : null),
    );
    final end = _parseLocal(
      booking['endAt'] ?? (items.isNotEmpty ? items.first['endAt'] : null),
    );
    if (start == null || end == null) return '';
    final formatter = DateFormat('h:mm a');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.pending;
      case 'CONFIRMED':
        return AppColors.confirmed;
      case 'IN_PROGRESS':
        return AppColors.inProgress;
      case 'COMPLETED':
        return AppColors.completed;
      case 'CANCELLED':
        return AppColors.cancelled;
      default:
        return Colors.blue.shade300;
    }
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
        ),
      );
    }

    return options;
  }

  List<_SalonBranchOption> _buildOptionsFromUserBranches(
      Iterable<dynamic> rawUserBranches) {
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
        ),
      );
    }

    return options;
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    List<_SalonBranchOption> options = _buildOptionsFromUserBranches(
      await UserRoleSession.instance.loadUserBranches(),
    );
    if (options.isEmpty) {
      options = _buildOptionsFromSalons(
        await UserRoleSession.instance.loadUserSalons(),
      );
    }
    String? errorMessage;

    if (options.isEmpty) {
      try {
        final response = await _apiService.getSalonListApi();
        final data = (response['data'] as List?) ?? const [];
        options = _buildOptionsFromSalons(data);
        errorMessage = response['success'] == true
            ? null
            : response['message']?.toString();
      } catch (e) {
        errorMessage = e.toString();
      }
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
    final schedule = selected != null
        ? await _loadBranchScheduleRange(selected.branchId)
        : _buildDefaultScheduleRange();
    if (selected != null && userId != null) {
      debugPrint(
        '[StylistBookings] loading initial bookings for branchId=${selected.branchId}, salonId=${selected.salonId}, userId=$userId, date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
      final response = await _apiService.fetchTeamAppointmentsByDate(
        selected.branchId,
        userId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      final rawData = response['data'];
      if (rawData is List) {
        bookings = rawData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        debugPrint(
          '[StylistBookings] parsed ${bookings.length} bookings for initial load',
        );
      }
      if (response['success'] != true) {
        errorMessage ??= response['message']?.toString();
        debugPrint('[StylistBookings] initial load error=$errorMessage');
      }
    } else if (selected != null && userId == null) {
      errorMessage ??= context.t('Unable to load stylist bookings');
      debugPrint('[StylistBookings] user_id missing for initial load');
    }

    if (!mounted) return;
    setState(() {
      _options = options;
      _selectedOption = selected;
      _userId = userId;
      _bookings = bookings;
      _timeSlots = schedule.timeSlots;
      _dayStart = schedule.dayStart;
      _dayEnd = schedule.dayEnd;
      _errorMessage = errorMessage;
      _isLoading = false;
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
      _isLoading = true;
      _errorMessage = null;
    });

    List<Map<String, dynamic>> bookings = const [];
    final schedule = await _loadBranchScheduleRange(option.branchId);
    String? errorMessage;
    if (_userId != null) {
      debugPrint(
        '[StylistBookings] loading bookings after dropdown change for branchId=${option.branchId}, salonId=${option.salonId}, userId=$_userId, date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
      final response = await _apiService.fetchTeamAppointmentsByDate(
        option.branchId,
        _userId!,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      final rawData = response['data'];
      if (rawData is List) {
        bookings = rawData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        debugPrint(
          '[StylistBookings] parsed ${bookings.length} bookings after dropdown change',
        );
      }
      if (response['success'] != true) {
        errorMessage = response['message']?.toString();
        debugPrint('[StylistBookings] dropdown load error=$errorMessage');
      }
    } else {
      errorMessage = context.t('Unable to load stylist bookings');
      debugPrint('[StylistBookings] user_id missing after dropdown change');
    }

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _timeSlots = schedule.timeSlots;
      _dayStart = schedule.dayStart;
      _dayEnd = schedule.dayEnd;
      _errorMessage = errorMessage;
      _isLoading = false;
    });
  }

  List<Widget> _buildBackgroundGrid() {
    final widgets = <Widget>[];

    for (int r = 0; r < _timeSlots.length; r++) {
      widgets.add(
        Positioned(
          top: r * _rowHeight,
          left: 0,
          right: 0,
          height: _rowHeight,
          child: Container(
            decoration: BoxDecoration(
              color: r.isEven ? Colors.white : const Color(0xFFF9F9F9),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildBookingBlocks() {
    if (_bookings.isEmpty) return const <Widget>[];

    final blocks = <Widget>[];

    for (final booking in _bookings) {
      final rawItems = (booking['items'] as List?) ?? const [];
      final items =
          rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
      final start = _parseLocal(
        booking['startAt'] ??
            (items.isNotEmpty ? items.first['startAt'] : null),
      );
      final end = _parseLocal(
        booking['endAt'] ?? (items.isNotEmpty ? items.first['endAt'] : null),
      );
      if (start == null || end == null) continue;

      final blockStart = start.isBefore(_dayStart) ? _dayStart : start;
      final blockEnd = end.isAfter(_dayEnd) ? _dayEnd : end;
      if (!blockEnd.isAfter(_dayStart) || !blockStart.isBefore(_dayEnd)) {
        continue;
      }

      final minutesFromStart = blockStart.difference(_dayStart).inMinutes;
      final totalMinutes = blockEnd.difference(blockStart).inMinutes;
      final top = (minutesFromStart / 15.0) * _rowHeight;
      final height = (totalMinutes / 15.0) * _rowHeight;
      final status = _normalizeStatus(booking['status']);

      blocks.add(
        Positioned(
          left: 12,
          right: 12,
          top: top,
          height: height < 52 ? 52 : height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openAppointmentSheet(booking),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(
                        color: _statusColor(status),
                        width: 5,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customerName(booking),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            _serviceLabel(booking),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                            ),
                          ),
                          if (_readPriceText(booking).isNotEmpty)
                            Text(
                              _readPriceText(booking),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 8,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _readTimeRange(booking),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return blocks;
  }

  Future<void> _reloadBookingsForSelectedOption() async {
    final selected = _selectedOption;
    final userId = _userId;
    if (selected == null || userId == null) return;

    final response = await _apiService.fetchTeamAppointmentsByDate(
      selected.branchId,
      userId,
      DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    final rawData = response['data'];
    final bookings = rawData is List
        ? rawData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _errorMessage =
          response['success'] == true ? null : response['message']?.toString();
    });
  }

  Future<void> _setSelectedDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final selected = _selectedOption;
    final userId = _userId;

    setState(() {
      _selectedDate = normalizedDate;
      _weekAnchor = normalizedDate;
      _loadingDate = true;
      _errorMessage = null;
    });

    final schedule = selected != null
        ? await _loadBranchScheduleRange(selected.branchId)
        : _buildDefaultScheduleRange();

    List<Map<String, dynamic>> bookings = const [];
    String? errorMessage;

    if (selected != null && userId != null) {
      debugPrint(
        '[StylistBookings] loading bookings after date change for branchId=${selected.branchId}, salonId=${selected.salonId}, userId=$userId, date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
      final response = await _apiService.fetchTeamAppointmentsByDate(
        selected.branchId,
        userId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      final rawData = response['data'];
      if (rawData is List) {
        bookings = rawData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (response['success'] != true) {
        errorMessage = response['message']?.toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _timeSlots = schedule.timeSlots;
      _dayStart = schedule.dayStart;
      _dayEnd = schedule.dayEnd;
      _errorMessage = errorMessage;
      _loadingDate = false;
    });
  }

  void _changeWeek(bool isNext) {
    setState(() {
      _weekAnchor = isNext
          ? _weekAnchor.add(const Duration(days: 7))
          : _weekAnchor.subtract(const Duration(days: 7));
    });
  }

  Future<Map<String, dynamic>?> _getFeedbackFromUser(
    BuildContext context,
    String customerName,
    List<Map<String, String>> services,
  ) async {
    int selectedRating = 5;
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        customerName.isEmpty
                            ? context.t('Customer')
                            : customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t('Services'),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...services.map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${service['name'] ?? ''}${service['time']?.isNotEmpty == true ? ' • ${service['time']}' : ''}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.t('Rating'),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          final rating = index + 1;
                          return IconButton(
                            onPressed: () {
                              setSheetState(() {
                                selectedRating = rating;
                              });
                            },
                            icon: Icon(
                              rating <= selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: AppColors.starColor,
                            ),
                          );
                        }),
                      ),
                      TextField(
                        minLines: 3,
                        maxLines: 4,
                        onChanged: (value) {
                          commentText = value;
                        },
                        decoration: InputDecoration(
                          hintText: context.t('Write comment'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                            backgroundColor: AppColors.starColor,
                            foregroundColor: Colors.white,
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

  void _openAppointmentSheet(Map<String, dynamic> booking) {
    String statusUpper = _normalizeStatus(booking['status']);
    bool loadingStart = false;
    bool loadingComplete = false;
    final customer = booking['user'] as Map<String, dynamic>?;
    final customerName = [
      customer?['firstName']?.toString() ?? '',
      customer?['lastName']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ').trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final rawItems = (booking['items'] as List?) ?? const [];
            final serviceItems = [
              for (final raw in rawItems)
                if (raw is Map<String, dynamic>)
                  raw
                else if (raw is Map)
                  raw.cast<String, dynamic>(),
            ];

            String formatUserName(dynamic rawUser) {
              if (rawUser is Map) {
                final first = rawUser['firstName']?.toString() ?? '';
                final last = rawUser['lastName']?.toString() ?? '';
                final combined = '$first $last'.trim();
                if (combined.isNotEmpty) return combined;
                return rawUser['name']?.toString() ?? '';
              }
              return '';
            }

            int toInt(dynamic value) {
              if (value is int) return value;
              if (value is num) return value.toInt();
              if (value is String) return int.tryParse(value) ?? 0;
              return 0;
            }

            final start = _parseLocal(booking['startAt']);
            final end = _parseLocal(booking['endAt']);
            final timeFormatter = DateFormat('h:mm a');
            final timeStr = (start != null && end != null)
                ? '${timeFormatter.format(start)} - ${timeFormatter.format(end)}'
                : '';
            final staffNames = serviceItems
                .map(
                  (svc) => formatUserName(
                    svc['assignedUserBranch']?['user'] ?? svc['user'],
                  ),
                )
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();
            final stylist =
                staffNames.isEmpty ? context.t('N/A') : staffNames.join(', ');
            final useItem = serviceItems.isNotEmpty ? serviceItems.first : null;
            final durationMinutes =
                useItem != null ? toInt(useItem['durationMin']) : 0;
            final duration = durationMinutes > 0 ? '$durationMinutes min' : '';
            final totalPriceMinor = serviceItems.fold<int>(
              0,
              (sum, svc) => sum + toInt(svc['branchService']?['priceMinor']),
            );
            final totalPrice = totalPriceMinor > 0 ? '₹$totalPriceMinor' : '';

            Future<void> onStartJob() async {
              if (_selectedOption == null || loadingStart) return;

              await showDialog(
                context: sheetContext,
                barrierDismissible: false,
                builder: (dialogCtx) {
                  String otp = "";
                  String errorMessage = "";
                  bool isSubmitting = false;
                  bool hasError = false;

                  return StatefulBuilder(
                    builder: (dialogCtx, setDialogState) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          translateText("Enter OTP"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: SizedBox(
                          width: 350,
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
                                  borderRadius: BorderRadius.circular(8),
                                  fieldHeight: 55,
                                  fieldWidth: 45,
                                  activeFillColor: Colors.white,
                                  selectedFillColor: Colors.white,
                                  inactiveFillColor: Colors.white,
                                  activeColor: hasError
                                      ? Colors.red
                                      : AppColors.starColor,
                                  selectedColor: hasError
                                      ? Colors.red
                                      : AppColors.starColor,
                                  inactiveColor: hasError
                                      ? Colors.red
                                      : AppColors.starColor,
                                  errorBorderColor: Colors.red,
                                ),
                                enableActiveFill: true,
                                onChanged: (value) {
                                  otp = value;
                                  setDialogState(() {
                                    hasError = false;
                                  });
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
                            child: Text(translateText("Cancel")),
                          ),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (otp.length != 6) {
                                      setDialogState(() {
                                        errorMessage = translateText(
                                          "Enter valid 6-digit OTP",
                                        );
                                        hasError = true;
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isSubmitting = true;
                                      errorMessage = "";
                                    });

                                    final resp =
                                        await ApiService.startAppointment(
                                      branchId: _selectedOption!.branchId,
                                      appointmentId: booking['id'] as int,
                                      otp: otp,
                                    );
                                    final success = resp['success'] == true;
                                    final message =
                                        resp['message']?.toString() ??
                                            (success
                                                ? 'Job started'
                                                : 'Invalid OTP');

                                    setDialogState(() => isSubmitting = false);

                                    if (!success) {
                                      setDialogState(() {
                                        errorMessage = message;
                                        hasError = true;
                                      });
                                      return;
                                    }

                                    Navigator.pop(dialogCtx);
                                    final newStatus = _normalizeStatus(
                                      resp['data']?['status'] ?? 'IN_PROGRESS',
                                    );
                                    setModalState(() {
                                      statusUpper = newStatus;
                                      booking['status'] = newStatus;
                                    });
                                    await _reloadBookingsForSelectedOption();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
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
                                : Text(translateText("Submit")),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            Future<void> onCompleteJob() async {
              if (_selectedOption == null) return;

              final services = serviceItems.map<Map<String, String>>((it) {
                final serviceName =
                    it['branchService']?['displayName']?.toString() ??
                        "Service";
                final startAt =
                    DateTime.tryParse(it['startAt']?.toString() ?? "");
                final timeText = startAt != null
                    ? DateFormat('hh:mm a').format(startAt)
                    : "";
                return {
                  "name": serviceName,
                  "time": timeText,
                };
              }).toList();

              final feedback = await _getFeedbackFromUser(
                context,
                customerName,
                services,
              );
              if (feedback == null) return;

              setModalState(() => loadingComplete = true);
              final resp = await ApiService().completeAppointment(
                branchId: _selectedOption!.branchId,
                appointmentId: booking['id'] as int,
                rating: feedback['rating'] as int,
                comment: feedback['comment'] as String,
              );
              setModalState(() => loadingComplete = false);

              if (resp['success'] == true) {
                final newStatus = _normalizeStatus(
                  resp['data']?['status'] ?? 'COMPLETED',
                );
                setModalState(() {
                  statusUpper = newStatus;
                  booking['status'] = newStatus;
                });
                await _reloadBookingsForSelectedOption();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      resp['message']?.toString() ?? 'Appointment completed',
                    ),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      resp['message']?.toString() ??
                          'Failed to complete appointment',
                    ),
                  ),
                );
              }
            }

            final badgeBg = statusUpper == 'PENDING'
                ? Colors.blue.shade100
                : statusUpper == 'CONFIRMED'
                    ? Colors.pink.shade100
                    : statusUpper == 'IN_PROGRESS'
                        ? AppColors.inProgressStatus
                        : statusUpper == 'COMPLETED'
                            ? Colors.green.shade100
                            : Colors.grey.shade300;

            return FractionallySizedBox(
              heightFactor: 0.70,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName.isNotEmpty
                                          ? customerName
                                          : context.t('Customer'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      translateText('Customer'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusUpper,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(
                            height: 12,
                            thickness: 0.8,
                            color: Color(0xFFE0E0E0),
                          ),
                          if (start != null || timeStr.isNotEmpty)
                            Row(
                              children: [
                                if (start != null)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translateText('Date'),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('EEE, dd MMM yyyy')
                                              .format(start),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (timeStr.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translateText('Time'),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(timeStr),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          if (duration.isNotEmpty || totalPrice.isNotEmpty)
                            Row(
                              children: [
                                if (duration.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translateText('Duration'),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(duration),
                                      ],
                                    ),
                                  ),
                                if (totalPrice.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translateText('Total Price'),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(totalPrice),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Text(
                            translateText('Assigned To'),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(stylist),
                          const Divider(
                            height: 18,
                            thickness: 0.8,
                            color: Color(0xFFE0E0E0),
                          ),
                          if (serviceItems.isNotEmpty)
                            Expanded(
                              child: ListView.separated(
                                itemCount: serviceItems.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 12),
                                itemBuilder: (_, idx) {
                                  final serviceItem = serviceItems[idx];
                                  final serviceName =
                                      serviceItem['branchService']
                                                  ?['displayName']
                                              ?.toString() ??
                                          'Service';
                                  final itemStart = _parseLocal(
                                    serviceItem['startAt']?.toString(),
                                  );
                                  final itemEnd = _parseLocal(
                                    serviceItem['endAt']?.toString(),
                                  );
                                  final range = (itemStart != null &&
                                          itemEnd != null)
                                      ? '${timeFormatter.format(itemStart)} - ${timeFormatter.format(itemEnd)}'
                                      : '';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (range.isNotEmpty)
                                        Text(
                                          range,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(height: 12),
                          if (statusUpper == 'CONFIRMED')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loadingStart ? null : onStartJob,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: AppColors.starColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: loadingStart
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(translateText('Start job')),
                              ),
                            )
                          else if (statusUpper == 'IN_PROGRESS')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    loadingComplete ? null : onCompleteJob,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  backgroundColor: AppColors.starColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: loadingComplete
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(translateText('Complete Job')),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(statusUpper),
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    final String selectedLabel = _selectedOption?.label.isNotEmpty == true
        ? _selectedOption!.label
        : context.t('Select a salon in Bookings first');
    final timetableHeight = math.max(
      320.0,
      MediaQuery.of(context).size.height -
          MediaQuery.of(context).padding.top -
          kToolbarHeight -
          220,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.t('Bookings'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOptions,
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(5, 8, 5, 8),
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey(_selectedOption?.branchId),
              initialValue: _selectedOption?.branchId,
              decoration: InputDecoration(
                labelText: context.t('Branch'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: context.t('Select Branch'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.starColor),
                ),
              ),
              items: _options
                  .map(
                    (option) => DropdownMenuItem<int>(
                      value: option.branchId,
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _options.isEmpty
                  ? null
                  : (branchId) {
                      if (branchId == null) return;
                      final option = _options.firstWhere(
                        (item) => item.branchId == branchId,
                      );
                      _selectOption(option);
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeWeek(false),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/previous.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IgnorePointer(
                        ignoring: _loadingDate,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(7, (index) {
                              final date = DateTime(
                                _weekAnchor.year,
                                _weekAnchor.month,
                                _weekAnchor.day,
                              ).add(Duration(days: index));
                              final isSelected =
                                  _isSameDay(date, _selectedDate);
                              final now = DateTime.now();
                              final isToday = _isSameDay(
                                date,
                                DateTime(now.year, now.month, now.day),
                              );

                              final bgColor = isSelected
                                  ? Colors.black
                                  : (isToday
                                      ? Colors.blue.withValues(alpha: 0.10)
                                      : Colors.grey.shade200);
                              final textColor = isSelected
                                  ? Colors.white
                                  : (isToday ? Colors.blue : Colors.black);

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () => _setSelectedDate(date),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      DateFormat('dd MMM').format(date),
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      if (_loadingDate)
                        IgnorePointer(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.starColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _changeWeek(true),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/next.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null || _options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  _errorMessage ?? context.t('No salons available'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 12),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                            left: BorderSide(color: Colors.grey.shade300),
                            right: BorderSide(color: Colors.grey.shade300),
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          context.t('Time'),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(5),
                          ),
                          child: SingleChildScrollView(
                            controller: _headerHController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Container(
                              width: _scheduleWidth,
                              height: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                  right:
                                      BorderSide(color: Colors.grey.shade300),
                                  bottom:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  selectedLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.starColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: timetableHeight,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: SingleChildScrollView(
                            controller: _timeColumnVController,
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: [
                                ...List.generate(_timeSlots.length, (i) {
                                  return Container(
                                    width: 100,
                                    height: _rowHeight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        left: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        right: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        bottom: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _timeSlots[i],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(
                                  height: _verticalScrollBottomInset,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _gridHController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _gridHController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: SizedBox(
                                width: _scheduleWidth,
                                child: SingleChildScrollView(
                                  controller: _gridVController,
                                  physics: const ClampingScrollPhysics(),
                                  child: SizedBox(
                                    width: _scheduleWidth,
                                    height: (_timeSlots.length * _rowHeight) +
                                        _verticalScrollBottomInset,
                                    child: Stack(
                                      children: [
                                        ..._buildBackgroundGrid(),
                                        ..._buildBookingBlocks(),
                                        if (!_isLoading && _bookings.isEmpty)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: Center(
                                                child: Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 20,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.92),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    context.t(
                                                      'No bookings for this date',
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black54,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeColumnVController.dispose();
    _gridVController.dispose();
    _headerHController.dispose();
    _gridHController.dispose();
    super.dispose();
  }
}
