// Md is deleting from here now
import 'dart:async';
import 'dart:convert'; // NEW
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:dotted_border/dotted_border.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/push_notification_service.dart';
import '../utils/api_service.dart'; // Import the correct api_service.dart file
import '../utils/colors.dart'; // Custom colors
import '../services/language_listener.dart';
import 'AddBookings.dart'; // Add Booking screen
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';


class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}
 const double _colWidth = 140;
  const double _rowHeight = 44.0;
// top-level constants (outside any class)
const String _kSalonsCacheKey = 'salons_cache_v1';
String _branchCacheKey(int id) => 'branch_cache_v1_$id';
final List<String> _defaultTimeSlots = _generateDefaultTimeSlots();

List<String> _generateDefaultTimeSlots() {
  final List<String> slots = [];
  final formatter = DateFormat('h:mm a');
  DateTime current = DateTime(0, 1, 1, 8, 0);
  final DateTime end = DateTime(0, 1, 1, 20, 0);
  while (current.isBefore(end)) {
    slots.add(formatter.format(current));
    current = current.add(const Duration(minutes: 15));
  }
  return slots;
}

class _BranchOption {
  const _BranchOption({
    required this.salonId,
    required this.salonName,
    required this.branchId,
    required this.branchName,
    required this.addressSummary,
    required this.branch,
  });

  final int salonId;
  final String salonName;
  final int branchId;
  final String branchName;
  final String addressSummary;
  final Map<String, dynamic> branch;
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> salons = [];
  bool isLoading = true;
  int? selectedSalonId;
  int? selectedBranchId; // Store branchId of the selected branch
  String? salonName;
  String? salonAddress;
  Map<String, dynamic>? selectedBranch; // Store branch details
  List<Map<String, dynamic>> bookings = [];
  DateTime selectedDate = DateTime.now(); // Initial date is today
  List<Map<String, dynamic>> teamMembers = [];
  List<String> timeSlots = []; // Declare the timeSlots list
  // Branch working hours for rendering grid/blocks
  String? _branchStartTimeStr; // e.g. "08:00:00"
  String? _branchEndTimeStr; // e.g. "20:00:00"
  bool _loadingBranch = false;
  bool _loadingDate = false;
  DateTime _weekAnchor = DateTime.now();
  bool get _isFetchingData => isLoading || _loadingBranch || _loadingDate;

  // Layout constants for the grid
  static const double _rowHeight = 44.0; // 15-min slot height
  static const double _colWidth = 140.0; // staff column width

  int pendingCount = 0;
  int cancelledCount = 0;
  int completedCount = 0;
  int confirmedCount = 0;

  // Timetable scroll controllers
  final ScrollController _timeColumnVController = ScrollController();
  final ScrollController _gridVController = ScrollController();
  final ScrollController _headerHController = ScrollController();
  final ScrollController _gridHController = ScrollController();
  bool _syncingV = false;
  bool _syncingH = false;

  StreamSubscription<BookingNotificationPayload>? _bookingPushSub;
  BookingNotificationPayload? _queuedBookingNotification;

  // ---- Helper: normalize status everywhere ----
  String _normalizeStatus(dynamic value) =>
      (value ?? '').toString().trim().toUpperCase();

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _normalizeSalonsList(Iterable<dynamic> raw) {
    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final rawBranches = (map['branches'] as List?) ?? const [];
        final branches = <Map<String, dynamic>>[];
        for (final branch in rawBranches) {
          if (branch is Map) {
            branches.add(Map<String, dynamic>.from(branch));
          }
        }
        map['branches'] = branches;
        result.add(map);
      }
    }
    return result;
  }

  String _branchAddressSummary(Map<String, dynamic> branch) {
    final address = branch['address'];
    if (address is Map) {
      final map = Map<String, dynamic>.from(address);
      final line1 = map['line1']?.toString().trim();
      if (line1 != null && line1.isNotEmpty) {
        return line1;
      }
    }
    return '';
  }
int get _totalColumns {
  if (teamMembers.isEmpty) return 3;              // always show 5
  return teamMembers.length < 3 ? 3 : teamMembers.length; 
}

  List<_BranchOption> _computeBranchOptions() {
    final options = <_BranchOption>[];
    final seenSalonIds = <int>{};
    final seenBranchIds = <int>{};
    for (final salon in salons) {
      final salonId = _asInt(salon['id']);
      if (salonId == null || !seenSalonIds.add(salonId)) continue;
      final salonName = (salon['name'] ?? '').toString();
      final branches = salon['branches'];
      if (branches is! List || branches.isEmpty) {
        continue;
      }
      for (final branchEntry in branches) {
        if (branchEntry is! Map || branchEntry.isEmpty) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asInt(branch['id']);
        if (branchId == null || !seenBranchIds.add(branchId)) continue;
        final branchName = (branch['name'] ?? '').toString();
        options.add(
          _BranchOption(
            salonId: salonId,
            salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
            branchId: branchId,
            branchName: branchName.isEmpty ? 'Branch #$branchId' : branchName,
            addressSummary: _branchAddressSummary(branch),
            branch: branch,
          ),
        );
      }
    }
    return options;
  }

  void _ensureBranchSelection() {
    if (!mounted) return;
    final options = _computeBranchOptions();
    if (options.isEmpty) {
      if (selectedBranchId != null) {
        setState(() {
          selectedBranchId = null;
          selectedSalonId = null;
          selectedBranch = null;
          salonName = null;
          salonAddress = null;
        });
      }
      return;
    }

    if (selectedBranchId != null &&
        options.any((option) => option.branchId == selectedBranchId)) {
      return;
    }

    final firstOption = options.first;
    onBranchChanged(
      firstOption.branchId,
      firstOption.salonId,
      firstOption.branch,
    );
  }
@override
void initState() {
  super.initState();

  _bookingPushSub = PushNotificationService.instance.bookingNotifications
      .listen((payload) {
    unawaited(_handleBookingNotification(payload));
  });

  final pendingNotification =
      PushNotificationService.instance.takePendingNavigationEvent();
  if (pendingNotification != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleBookingNotification(pendingNotification));
    });
  }

  _weekAnchor = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );

  _bootstrap();        // your existing bootstrap
  getSalonListApi();   // load salons
  _loadCachedSelectionAndFetch(); // ?? new helper

  // scroll sync setup...
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

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_timeColumnVController.hasClients && _gridVController.hasClients) {
      _gridVController.jumpTo(_timeColumnVController.offset);
    }
    if (_headerHController.hasClients && _gridHController.hasClients) {
      _gridHController.jumpTo(_headerHController.offset);
    }
  });
}

  // @override
  // void initState() {
  //   super.initState();
  //   _bookingPushSub = PushNotificationService.instance.bookingNotifications
  //       .listen((payload) {
  //         unawaited(_handleBookingNotification(payload));
  //       });

  //   final pendingNotification = PushNotificationService.instance
  //       .takePendingNavigationEvent();
  //   if (pendingNotification != null) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       unawaited(_handleBookingNotification(pendingNotification));
  //     });
  //   }

  //   _weekAnchor = DateTime(
  //     selectedDate.year,
  //     selectedDate.month,
  //     selectedDate.day,
  //   );
  //   _bootstrap();
  //   getSalonListApi();
  //   _loadCachedSelection();
  //   // Sync vertical scroll between time column and grid body
  //   _timeColumnVController.addListener(() {
  //     if (_syncingV) return;
  //     _syncingV = true;
  //     if (_gridVController.hasClients) {
  //       final off = _timeColumnVController.offset;
  //       if ((_gridVController.offset - off).abs() > 0.5) {
  //         _gridVController.jumpTo(off);
  //       }
  //     }
  //     _syncingV = false;
  //   });
  //   _gridVController.addListener(() {
  //     if (_syncingV) return;
  //     _syncingV = true;
  //     if (_timeColumnVController.hasClients) {
  //       final off = _gridVController.offset;
  //       if ((_timeColumnVController.offset - off).abs() > 0.5) {
  //         _timeColumnVController.jumpTo(off);
  //       }
  //     }
  //     _syncingV = false;
  //   });
  //   // Sync horizontal scroll between header and grid body
  //   _headerHController.addListener(() {
  //     if (_syncingH) return;
  //     _syncingH = true;
  //     if (_gridHController.hasClients) {
  //       final off = _headerHController.offset;
  //       if ((_gridHController.offset - off).abs() > 0.5) {
  //         _gridHController.jumpTo(off);
  //       }
  //     }
  //     _syncingH = false;
  //   });
  //   _gridHController.addListener(() {
  //     if (_syncingH) return;
  //     _syncingH = true;
  //     if (_headerHController.hasClients) {
  //       final off = _gridHController.offset;
  //       if ((_headerHController.offset - off).abs() > 0.5) {
  //         _headerHController.jumpTo(off);
  //       }
  //     }
  //     _syncingH = false;
  //   });

  //   // Ensure initial sync after first layout
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (_timeColumnVController.hasClients && _gridVController.hasClients) {
  //       _gridVController.jumpTo(_timeColumnVController.offset);
  //     }
  //     if (_headerHController.hasClients && _gridHController.hasClients) {
  //       _gridHController.jumpTo(_headerHController.offset);
  //     }
  //   });
  // }

  DateTime _startOfWeek(DateTime d, {bool mondayStart = true}) {
    final wd = d.weekday; // 1=Mon ... 7=Sun
    final diff = mondayStart ? (wd - 1) : (wd % 7);
    final onlyDate = DateTime(d.year, d.month, d.day);
    return onlyDate.subtract(Duration(days: diff));
  }
Future<void> _loadCachedSelectionAndFetch() async {
  final prefs = await SharedPreferences.getInstance();
  final cachedBranchId = prefs.getInt('selected_branch_id');
  final cachedSalonId = prefs.getInt('selected_salon_id');

  if (cachedBranchId != null && cachedSalonId != null) {
    // get branch data (from salon list or API)
    final branchData = await _loadBranchData(cachedBranchId);

    if (branchData != null) {
      print('[Bookings] Restoring cached branch=$cachedBranchId salon=$cachedSalonId');
      await onBranchChanged(cachedBranchId, cachedSalonId, branchData);
    } else {
      print('[Bookings] No branchData found for cached branch=$cachedBranchId');
    }
  } else {
    print('[Bookings] No cached branch selection found.');
  }
}
Map<String, dynamic>? _loadBranchData(int branchId) {
  for (final salon in salons) {
    final branches = salon['branches'] as List? ?? [];
    for (final branch in branches) {
      if (branch is Map && branch['id'] == branchId) {
        return Map<String, dynamic>.from(branch);
      }
    }
  }
  return null;
}

  void changeWeek(bool isNext) {
    setState(() {
      _weekAnchor = isNext
          ? _weekAnchor.add(const Duration(days: 7))
          : _weekAnchor.subtract(const Duration(days: 7));
    });
  }

  Future<void> _bootstrap() async {
    // 1) Load saved selection (branch/salon ids)
    await _loadCachedSelection();

    // 2) Salons: show cached list immediately; only fetch if missing
    final hadSalons = await _loadSalonsFromCache();
    if (!hadSalons) {
      await getSalonListApi(); // This will also cache salons (step 4)
    }

    // 3) Branch data (slots + team): restore if present, no network
    await _restoreBranchFromCacheIfAny();

    // 4) Done booting
    if (mounted) {
      setState(() {}); // ensure UI reflects restored cache
    }
  }

  Future<bool> _loadSalonsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSalonsCacheKey);
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        final normalized = _normalizeSalonsList(data);
        if (!mounted) {
          salons = normalized;
          return normalized.isNotEmpty;
        }
        setState(() {
          salons = normalized;
        });
        _ensureBranchSelection();
        _processQueuedBookingNotificationIfAny();
        return normalized.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _saveSalonsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSalonsCacheKey, jsonEncode(salons));
  }

  /// Save per-branch cache: start/end ? slots (derived) + teamMembers
  Future<void> _saveBranchCache(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'startTime': _branchStartTimeStr ?? '08:00:00',
      'endTime': _branchEndTimeStr ?? '20:00:00',
      'teamMembers': teamMembers,
    };
    await prefs.setString(_branchCacheKey(branchId), jsonEncode(payload));
  }

  /// Restore per-branch cache if available (NO network)
  Future<bool> _restoreBranchFromCacheIfAny() async {
    if (selectedBranchId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_branchCacheKey(selectedBranchId!));
    if (raw == null) return false;

    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final start = (obj['startTime'] ?? '08:00:00').toString();
      final end = (obj['endTime'] ?? '20:00:00').toString();
      final members = (obj['teamMembers'] as List?) ?? const [];

      setState(() {
        _branchStartTimeStr = start;
        _branchEndTimeStr = end;
        timeSlots = generateTimeSlots(start, end);
        teamMembers = List<Map<String, dynamic>>.from(
          members.map((e) => Map<String, dynamic>.from(e)),
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshAllData() async {
    if (_isFetchingData) return;
    setState(() {
      isLoading = true;
      if (selectedBranchId != null) {
        _loadingBranch = true;
      }
    });

    try {
      await getSalonListApi();

      if (selectedBranchId != null) {
        await getTeamMembers(selectedBranchId!);
        await getBookingsByDate(selectedBranchId!, selectedDate);
      } else {
        setState(() {
          bookings = [];
          pendingCount = 0;
          cancelledCount = 0;
          completedCount = 0;
          confirmedCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _loadingBranch = false;
        });
      }
    }
  }

  void _processQueuedBookingNotificationIfAny() {
    final queued = _queuedBookingNotification;
    if (queued == null) return;

    final options = _computeBranchOptions();
    final hasOption = options.any(
      (option) => option.branchId == queued.branchId,
    );
    if (!hasOption) return;

    _queuedBookingNotification = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handleBookingNotification(queued));
    });
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _loadCachedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSalonId = prefs.getInt('selected_salon_id');
      selectedBranchId = prefs.getInt('selected_branch_id');
      salonName = prefs.getString('salon_name');
      salonAddress = prefs.getString('salon_address');
    });
  }

  // Future<void> getSalonListApi() async {
  //   try {
  //     final response = await ApiService().getSalonListApi();
  //     if (response['success'] == true) {
  //       final data = (response['data'] as List?)?.toList() ?? <dynamic>[];
  //       final normalized = _normalizeSalonsList(data);
  //       if (!mounted) {
  //         salons = normalized;
  //         return;
  //       }
  //       setState(() {
  //         salons = normalized;
  //         isLoading = false;
  //       });
  //       _ensureBranchSelection();
  //       _processQueuedBookingNotificationIfAny();
  //       await _saveSalonsToCache();
  //     } else {
  //       throw Exception("Failed to fetch salon list");
  //     }
  //   } catch (e) {
  //     print("Error fetching salon list: $e");
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
  //       _ensureBranchSelection();
  //       _processQueuedBookingNotificationIfAny();
  //     }
  //   }
  // }

Future<void> getSalonListApi() async {
  try {
    final response = await ApiService().getSalonListApi();
    if (response['success'] == true) {
      final data = (response['data'] as List?)?.toList() ?? <dynamic>[];
      final normalized = _normalizeSalonsList(data);

      if (!mounted) {
        salons = normalized;
        return;
      }

      setState(() {
        salons = normalized;
        isLoading = false;
      });

      _ensureBranchSelection();
      _processQueuedBookingNotificationIfAny();
      await _saveSalonsToCache();

      // ?? Restore cached branch + fetch appointments automatically
      await _loadCachedSelectionAndFetch();

    } else {
      throw Exception("Failed to fetch salon list");
    }
  } catch (e) {
    print("Error fetching salon list: $e");
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      _ensureBranchSelection();
      _processQueuedBookingNotificationIfAny();
    }
  }
}
  List<String> generateTimeSlots(String startTime, String endTime) {
    List<String> timeSlots = [];

    // Convert startTime and endTime to DateTime objects
    DateTime start = DateFormat("HH:mm:ss").parse(startTime);
    DateTime end = DateFormat("HH:mm:ss").parse(endTime);

    // Exclude the last 15 minutes from the range
    DateTime effectiveEnd = end.subtract(const Duration(minutes: 15));

    // Add time slots up to and including effectiveEnd
    while (start.isBefore(effectiveEnd) ||
        start.isAtSameMomentAs(effectiveEnd)) {
      timeSlots.add(DateFormat("h:mm a").format(start));
      start = start.add(const Duration(minutes: 15));
    }

    return timeSlots;
  }

  Future<void> getBookingsByDate(int branchId, DateTime date) async {
    try {
      String formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(date); // Format date
      ApiService apiService = ApiService();

      final response = await apiService.fetchAppointments(
        branchId,
        formattedDate,
      );

      if (response != null &&
          response['success'] == true &&
          response['data'] != null) {
        List<dynamic> appointments = response['data'];

        // Try to fetch branch working hours from the payload (fallback-safe)
        String startTime = _branchStartTimeStr ?? '08:00:00';
        String endTime = _branchEndTimeStr ?? '20:00:00';
        if (appointments.isNotEmpty) {
          final b = appointments.first;
          if (b['branch'] != null) {
            startTime = (b['branch']['startTime'] ?? startTime).toString();
            endTime = (b['branch']['endTime'] ?? endTime).toString();
          }
        }

        // Generate time slots and populate the timeSlots list
        setState(() {
          timeSlots = generateTimeSlots(
            startTime,
            endTime,
          ); // Populate timeSlots
          _branchStartTimeStr = startTime;
          _branchEndTimeStr = endTime;
        });

        setState(() {
          bookings = List<Map<String, dynamic>>.from(appointments);
        });
        _recomputeStatusCounts();
      } else {
        setState(() {
          bookings = [];
          pendingCount = 0;
          cancelledCount = 0;
          completedCount = 0;
          confirmedCount = 0;
        });
        print('No appointments available for this date.');
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
  }

  // Count status by items (so counts match blocks in grid)
  void _recomputeStatusCounts() {
    int sumStatus(String statusMatch) {
      int t = 0;
      for (final b in bookings) {
        final s = _normalizeStatus(b['status']);
        if (s == statusMatch) {
          final items = (b['items'] as List?) ?? const [];
          t += items.isNotEmpty ? items.length : 1;
        }
      }
      return t;
    }

    setState(() {
      pendingCount = sumStatus('PENDING');
      cancelledCount = sumStatus('CANCELLED');
      completedCount = sumStatus('COMPLETED');
      confirmedCount = sumStatus('CONFIRMED');
    });
  }

  Future<void> getTeamMembers(int branchId) async {
    try {
      final response = await ApiService.getTeamMembers(branchId);
      if (response != null &&
          response['success'] == true &&
          response['data'] != null &&
          response['data'].isNotEmpty) {
        setState(() {
          teamMembers = List<Map<String, dynamic>>.from(response['data']);
        });
        // Cache the branch bundle (uses current _branchStartTimeStr/_branchEndTimeStr)
        await _saveBranchCache(branchId); // NEW
      } else {
        setState(() {
          teamMembers = [];
        });
        print('No team members available for this branch.');
        await _saveBranchCache(branchId); // save empty list too for consistency
      }
    } catch (e) {
      print('Error fetching team members: $e');
    }
  }

  // Combine selected date with a HH:mm[:ss] string to a local DateTime
  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    int h = 0, m = 0, s = 0;
    try {
      final parts = timeStr.split(':');
      if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
      if (parts.length > 2) s = int.tryParse(parts[2]) ?? 0;
    } catch (_) {}
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  // Safely parse ISO string to local DateTime
 DateTime? _parseLocal(String? iso) {
  if (iso == null) return null;
  try {
    return DateTime.parse(iso).toLocal(); // force IST/local
  } catch (_) {
    return null;
  }
}


  // Find staff column index for a booking item by matching user id
  int _findMemberColumnForItem(Map<String, dynamic> item) {
    final dynamic userId =
        item['assignedUserBranch']?['user']?['id'] ??
        item['assignedUserBranch']?['userId'] ??
        item['user']?['id'] ??
        item['userId'];
    if (userId == null) return -1;
    final idx = teamMembers.indexWhere((m) {
      final mid = m['id'] ?? m['user']?['id'] ?? m['userId'];
      return mid == userId;
    });
    return idx;
  }
List<Widget> _buildBackgroundGrid(int slotCount) {
  final List<Widget> widgets = [];

  // Horizontal row backgrounds
  for (int r = 0; r < slotCount; r++) {
    widgets.add(
      Positioned(
        top: r * _rowHeight,
        left: 0,
        right: 0,
        height: _rowHeight,
        child: Container(
          decoration: BoxDecoration(
            color: r % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ),
    );
  }

  // Vertical column separators
for (int c = 1; c < _totalColumns; c++) {
  widgets.add(
    Positioned(
      top: 0,
      bottom: 0,
      left: c * _colWidth - 1,
      width: 1,
      child: Container(color: Colors.grey.shade300),
    ),
  );
}


  return widgets;
}

  String _fmtTimeRange(DateTime s, DateTime e) {
    final f = DateFormat('h:mma');
    return '${f.format(s).toLowerCase()} - ${f.format(e).toLowerCase()}';
  }

  List<Map<String, dynamic>> _collectMergedSegments() {
    if (bookings.isEmpty ||
        _branchStartTimeStr == null ||
        _branchEndTimeStr == null) {
      return const [];
    }

    int? _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final DateTime dayStart = _combineDateAndTime(
      selectedDate,
      _branchStartTimeStr!,
    );
    final DateTime dayEnd = _combineDateAndTime(
      selectedDate,
      _branchEndTimeStr!,
    );

    // Step 1: flatten items
    final List<Map<String, dynamic>> flat = [];
    for (final booking in bookings) {
      final status = _normalizeStatus(booking['status']);
      final customer = booking['user'] as Map<String, dynamic>?;
      final customerName = [
        customer?['firstName']?.toString() ?? '',
        customer?['lastName']?.toString() ?? '',
      ].where((s) => s.isNotEmpty).join(' ').trim();

      final items = (booking['items'] as List?) ?? const [];
      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw as Map);

        final int col = _findMemberColumnForItem(item);
        if (col < 0) continue;

        final staffUserId =
            item['assignedUserBranch']?['user']?['id'] ??
            item['assignedUserBranch']?['userId'] ??
            item['user']?['id'] ??
            item['userId'];

        DateTime? s =
            _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
        DateTime? e =
            _parseLocal(item['endAt']) ?? _parseLocal(booking['endAt']);
        if (s == null || e == null) continue;

        // clamp
        if (s.isBefore(dayStart)) s = dayStart;
        if (e.isAfter(dayEnd)) e = dayEnd;
        if (!e.isAfter(s)) continue;

        flat.add({
          'booking': booking,
          'item': item,
          'appointmentId': booking['id'], // keep per-item appointment id
          'col': col,
          'customerId': booking['user']?['id'] ?? booking['userId'],
          'customerName': customerName.isEmpty ? 'Customer' : customerName,
          'staffUserId': staffUserId,
          'status': status,
          'start': s,
          'end': e,
          'service':
              item['branchService']?['displayName']?.toString() ?? 'Service',
          'priceMinor': _toInt(item['branchService']?['priceMinor']),
        });
      }
    }

    if (flat.isEmpty) return const [];

    // Step 2: group by col + customer + staff + status
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final it in flat) {
      final key =
          '${it['appointmentId']}|${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
      (groups[key] ??= <Map<String, dynamic>>[]).add(it);
    }

    // Step 3: within each group, sort by start and coalesce consecutive items
    final List<Map<String, dynamic>> segments = [];
    for (final g in groups.values) {
      g.sort(
        (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
      );
      if (g.isEmpty) continue;

      // seed
      int col = g.first['col'] as int;
      String status = g.first['status'] as String;
      String customerName = g.first['customerName'] as String;
      DateTime segStart = g.first['start'] as DateTime;
      DateTime segEnd = g.first['end'] as DateTime;
      final List<String> services = [g.first['service'] as String];
      int? priceTotal = _toInt(g.first['priceMinor']);
      final List<Map<String, dynamic>> segItems = [
        {
          'booking': g.first['booking'],
          'item': g.first['item'],
          'appointmentId': g.first['appointmentId'],
          'start': segStart,
          'end': segEnd,
          'service': g.first['service'],
          'priceMinor': g.first['priceMinor'],
        },
      ];

      for (int i = 1; i < g.length; i++) {
        final curr = g[i];
        final s = curr['start'] as DateTime;
        final e = curr['end'] as DateTime;

        // merge only if exactly consecutive
        if (s.isAtSameMomentAs(segEnd)) {
          segEnd = e;
          services.add(curr['service'] as String);
          final p = _toInt(curr['priceMinor']);
          if (p != null) priceTotal = (priceTotal ?? 0) + p;

          segItems.add({
            'booking': curr['booking'],
            'item': curr['item'],
            'appointmentId': curr['appointmentId'],
            'start': s,
            'end': e,
            'service': curr['service'],
            'priceMinor': curr['priceMinor'],
          });
        } else {
          // flush
          segments.add({
            'col': col,
            'status': status,
            'customerName': customerName,
            'start': segStart,
            'end': segEnd,
            'services': List<String>.from(services),
            'priceTotal': priceTotal,
            'items': List<Map<String, dynamic>>.from(segItems),
          });

          // start new
          col = curr['col'] as int;
          status = curr['status'] as String;
          customerName = curr['customerName'] as String;
          segStart = s;
          segEnd = e;
          services
            ..clear()
            ..add(curr['service'] as String);
          priceTotal = _toInt(curr['priceMinor']);
          segItems
            ..clear()
            ..add({
              'booking': curr['booking'],
              'item': curr['item'],
              'appointmentId': curr['appointmentId'],
              'start': s,
              'end': e,
              'service': curr['service'],
              'priceMinor': curr['priceMinor'],
            });
        }
      }

      // final flush
      segments.add({
        'col': col,
        'status': status,
        'customerName': customerName,
        'start': segStart,
        'end': segEnd,
        'services': List<String>.from(services),
        'priceTotal': priceTotal,
        'items': List<Map<String, dynamic>>.from(segItems),
      });
    }

    return segments;
  }

void _openAppointmentModal({
  required Map<String, dynamic> bookingOrSeg,
  required List<Map<String, dynamic>> items,
}) {
  final String status = _normalizeStatus(bookingOrSeg['status']);
  final String customerName = bookingOrSeg['customerName'] as String? ?? 'Customer';
  final int? priceTotal = bookingOrSeg['priceTotal'] as int?;
  final String timeRange = _fmtTimeRange(
    bookingOrSeg['start'] as DateTime,
    bookingOrSeg['end'] as DateTime,
  );

  final List<int> apptIds = items
      .map((it) => it['appointmentId'] as int?)
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (_, setSheetState) {
          return FractionallySizedBox(
            heightFactor: 0.60,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ? Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(translateText("Customer"),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: status == 'PENDING'
        ? Colors.blue.withOpacity(0.1)
        : status == 'CONFIRMED'
            ? Colors.pink.withOpacity(0.2)   // ? pink background
            : status == 'IN_PROGRESS'
                ? Colors.orange.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    status,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: status == 'PENDING'
          ? Colors.blue
          : status == 'CONFIRMED'
              ? Colors.black   // ? force black text
              : status == 'IN_PROGRESS'
                  ? Colors.black
                  : Colors.black54,
    ),
  ),
),

                      ],
                    ),

                    const Divider(height: 12, thickness: 0.8, color: Color(0xFFE0E0E0)),

                    // ? Time + price
                    Text(timeRange, style: const TextStyle(color: Colors.black54)),
                    if (priceTotal != null) ...[
                      SizedBox(height: 4),
                      Text('Total Price: ₹ $priceTotal',
                          style: const TextStyle(color: Colors.black87)),
                    ],

                    SizedBox(height: 12),

                    // ? Assigned To
                    Text(translateText("Assigned To"),
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                    SizedBox(height: 4),
                    Text(
                      _buildStylistName(items), // <-- helper inline below
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),

                    SizedBox(height: 12),

                    // ? Services list
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = items[i];
                          final String name =
                              (it['service']?.toString() ?? 'Service');
                          final int? priceMinor = it['priceMinor'] as int?;
                          final String priceText =
                              priceMinor != null ? '₹$priceMinor' : '';
                          final String range = _fmtTimeRange(
                            it['start'] as DateTime,
                            it['end'] as DateTime,
                          );

                          return ListTile(
                            dense: true,
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(range),
                            trailing: priceText.isNotEmpty
                                ? Text(priceText,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))
                                : null,
                          );
                        },
                      ),
                    ),

                    // ? Action buttons
                    SizedBox(height: 12),
                    _buildActionButton(status, apptIds, setSheetState),
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
Widget _buildActionButton(String status, List<int> apptIds, void Function(void Function()) setSheetState) {
  if (status == 'PENDING') {
    return ElevatedButton(
      onPressed: () {
        // handle confirm here
      },
      child: Text(translateText('Confirm')),
    );
  } else if (status == 'CONFIRMED') {
    return ElevatedButton(
      onPressed: () {
        // handle start job here
      },
      child: Text(translateText('Start Job')),
    );
  } else if (status == 'IN_PROGRESS') {
    return ElevatedButton(
      onPressed: () {
        // handle complete here
      },
      child: Text(translateText('Complete Job')),
    );
  } else {
    return ElevatedButton(
      onPressed: null,
      child: Text(status),
    );
  }
}

// Helper inline just for stylist
String _buildStylistName(List<Map<String, dynamic>> items) {
  String _formatUserName(dynamic rawUser) {
    if (rawUser is Map<String, dynamic>) {
      final first = rawUser['firstName']?.toString() ?? '';
      final last = rawUser['lastName']?.toString() ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;
      final fallback = rawUser['name']?.toString();
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return translateText('N/A');
  }

  final stylistNames = items.map((it) {
    final aub = it['assignedUserBranch'] as Map<String, dynamic>?;
    final rawUser = aub?['user'] ?? it['user'];
    return _formatUserName(rawUser);
  }).where((n) => n != 'N/A').toSet().toList();

  return stylistNames.isEmpty
      ? 'N/A'
      : stylistNames.length == 1
          ? stylistNames.first
          : stylistNames.join(', ');
}

  List<Widget> _buildBookingBlocks() {
    if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

    final startStr = _branchStartTimeStr ?? '08:00:00';
    final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);

    final merged = _collectMergedSegments();
    final List<Widget> blocks = [];

    for (final seg in merged) {
      final int col = seg['col'] as int;
      final String status = _normalizeStatus(seg['status']);
      final DateTime s = seg['start'] as DateTime;
      final DateTime e = seg['end'] as DateTime;
      final int minutesFromStart = s.difference(dayStart).inMinutes;
      final int totalMin = e.difference(s).inMinutes;

      final double top = (minutesFromStart / 15.0) * _rowHeight;
      final double height = (totalMin / 15.0) * _rowHeight; // seamless
      final double left = col * _colWidth + 6;
      final double width = _colWidth - 12;

      // ? Color mapping (green for IN_PROGRESS)
      Color bg = Colors.blue.shade300; // default (CONFIRMED)
      if (status == 'PENDING') bg = AppColors.pending;
      if (status == 'CONFIRMED') bg = AppColors.confirmed;
      if (status == 'IN_PROGRESS')
        bg = AppColors.inProgress; // green after Start Job
      if (status == 'COMPLETED') bg = AppColors.completed;
      if (status == 'CANCELLED') bg = AppColors.cancelled;

      final String customerName = seg['customerName'] as String? ?? 'Customer';
      final List<String> services = List<String>.from(seg['services'] as List);
      final int moreCount = (services.length > 1) ? services.length - 1 : 0;
      final String headService = services.isNotEmpty
          ? services.first
          : 'Service';
      final int? priceTotal = seg['priceTotal'] as int?;
      final String priceText = priceTotal != null ? '₹$priceTotal' : '';
      final String timeRange = _fmtTimeRange(s, e);

      final List<Map<String, dynamic>> segItems =
          List<Map<String, dynamic>>.from(seg['items'] as List);

      blocks.add(
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height < 44 ? 44 : height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
               if (segItems.isNotEmpty) {
  final b = segItems.first['booking'] as Map<String, dynamic>;
  _openAppointmentSheet(b, null); // pass null for multi-service blocks
}
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  // color: bg,
                  decoration: BoxDecoration(
                    color: Colors.white, // keep a neutral background
                    border: Border(
                      left: BorderSide(
                        color: bg, // use your status color here
                        width: 6, // thin vertical line thickness
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            moreCount > 0
                                ? '$headService + $moreCount more'
                                : headService,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                            ),
                          ),
                          if (priceText.isNotEmpty)
                            Text(
                              priceText,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 8,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            timeRange,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            status,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              fontSize: 10,
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
Future<Map<String, dynamic>?> _getFeedbackFromUser(
  BuildContext context,
  String customerName,
  List<Map<String, dynamic>> services,
) async {
  int rating = 0;
  final commentCtrl = TextEditingController();

  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (c) {
      return StatefulBuilder(
        builder: (c, setFBState) {
          final bottomInset = MediaQuery.of(c).viewInsets.bottom;
          final canSubmit = rating > 0 && commentCtrl.text.trim().isNotEmpty;

          Widget _star(int i) => IconButton(
                icon: Icon(
                  i <= rating ? Icons.star : Icons.star_border,
                  color: AppColors.starColor,
                  size: 32,
                ),
                onPressed: () => setFBState(() => rating = i),
              );

          return FractionallySizedBox(
            heightFactor: 0.75, // Taller like your screenshot
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 24,
                      bottom: 16 + bottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Avatar + Name + Subtitle
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.lightGray,
                              child: Text(
                                customerName.isNotEmpty
                                    ? customerName[0]
                                    : "?",
                                style: const TextStyle(
                                  color: AppColors.starColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color:AppColors.starColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(translateText("Customer Review"),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.starColor,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),

                        SizedBox(height: 20),

                        // Rating stars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) => _star(i + 1)),
                        ),

                        SizedBox(height: 16),

                        // Comment input
                        Text(translateText("Add detailed review"),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        TextField(
                          controller: commentCtrl,
                          maxLines: 1,
                          onChanged: (_) => setFBState(() {}),
                          decoration: InputDecoration(
                            hintText: translateText("Share your experience with this customer..."),
                            filled: true,
                            fillColor: Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        // Services list
                        Text(translateText("Services Provided"),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: services.length,
                            itemBuilder: (_, i) {
                              final s = services[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s["name"] ?? "-"),
                                    Text(
                                      s["time"] ?? "-",
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        SizedBox(height: 20),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canSubmit
                                ? () {
                                    Navigator.pop<Map<String, dynamic>>(c, {
                                      "rating": rating,
                                      "comment": commentCtrl.text.trim(),
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(translateText("Submit Review"),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                 Positioned(
      top: -50,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(c).pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.white, size: 22),
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

  void _openAppointmentSheet(
    Map<String, dynamic> booking,
    Map<String, dynamic>? item,
  ) {
    // Mutable state captured by StatefulBuilder
    String statusUpper = _normalizeStatus(booking['status']);
    bool loadingConfirm = false;
    bool loadingCancel = false;
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
      // backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List rawItems = (booking['items'] as List?) ?? const [];
            final Map<String, dynamic>? useItem =
                item ??
                (rawItems.isNotEmpty
                    ? rawItems.first as Map<String, dynamic>
                    : null);

            final List<Map<String, dynamic>> serviceItems = [
              for (final raw in rawItems)
                if (raw is Map<String, dynamic>)
                  raw
                else if (raw is Map)
                  raw.cast<String, dynamic>(),
            ];
            final bool hasMultipleServices = serviceItems.length > 1;

            final String headerTitle;
            if (hasMultipleServices && serviceItems.isNotEmpty) {
              final firstName =
                  serviceItems.first['branchService']?['displayName']
                      ?.toString() ??
                  'Service';
              headerTitle = '$firstName + ${serviceItems.length - 1} more';
            } else if (useItem != null) {
              headerTitle =
                  useItem['branchService']?['displayName']?.toString() ??
                  'Appointment';
            } else if (serviceItems.isNotEmpty) {
              headerTitle =
                  serviceItems.first['branchService']?['displayName']
                      ?.toString() ??
                  'Appointment';
            } else {
              headerTitle = 'Appointment';
            }

          String formatUserName(dynamic rawUser) {
  if (rawUser is Map) {
    final first = rawUser['firstName']?.toString() ?? '';
    final last = rawUser['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : (rawUser['name']?.toString() ?? '');
  }
  return '';
}

final staffNames = serviceItems
    .map((svc) => formatUserName(
          svc['assignedUserBranch']?['user'] ?? svc['user'],
        ))
    .where((n) => n.isNotEmpty)
    .toSet()
    .toList();

final String stylist = staffNames.isEmpty
    ? 'N/A'
    : staffNames.length == 1
        ? staffNames.first
        : staffNames.join(', '); // ?? show all instead of just "Multiple"


            int _toInt(dynamic value) {
              if (value is int) return value;
              if (value is num) return value.toInt();
              if (value is String) return int.tryParse(value) ?? 0;
              return 0;
            }

            final double serviceListMaxHeight = serviceItems.isEmpty
                ? 0
                : (serviceItems.length > 4
                      ? 320.0
                      : serviceItems.length * 72.0);

        // Always take booking-level start and end
final start = _parseLocal(booking['startAt']);
final end   = _parseLocal(booking['endAt']);

final DateFormat timeFormatter = DateFormat('h:mm a');
final String timeStr = (start != null && end != null)
    ? "${timeFormatter.format(start)} - ${timeFormatter.format(end)}"
    : '';

            // final DateFormat timeFormatter = DateFormat('h:mm a');
            // final String timeStr = start != null && end != null
            //     ? "${timeFormatter.format(start)} - ${timeFormatter.format(end)}"
            //     : '';

            final bool isPending = statusUpper == 'PENDING';
            final bool isConfirmed = statusUpper == 'CONFIRMED';

            final String primaryStylistName = formatUserName(
              useItem?['assignedUserBranch']?['user'] ?? useItem?['user'],
            );
            // final String stylist = hasMultipleServices
            //     ? 'Multiple team members'
            //     : (primaryStylistName.isNotEmpty ? primaryStylistName : 'N/A');

            final int durationMinutes = useItem != null
                ? _toInt(useItem['durationMin'])
                : 0;
            final String duration = !hasMultipleServices && durationMinutes > 0
                ? '$durationMinutes min'
                : '';

            final int singleServicePriceMinor = useItem != null
                ? _toInt(useItem['branchService']?['priceMinor'])
                : 0;
            final int aggregatedPriceMinor = serviceItems.fold<int>(
              0,
              (sum, svc) => sum + _toInt(svc['branchService']?['priceMinor']),
            );
            final String singleServicePrice =
                !hasMultipleServices && singleServicePriceMinor > 0
                ? '?$singleServicePriceMinor'
                : '';
            final String totalPrice =
                hasMultipleServices && aggregatedPriceMinor > 0
                ? '₹$aggregatedPriceMinor'
                : '';

            Future<void> onConfirm() async {
              if (selectedBranchId == null) return;
              setModalState(() => loadingConfirm = true);
              final resp = await ApiService().confirmAppointment(
                branchId: selectedBranchId!,
                appointmentId: booking['id'] as int,
              );
              setModalState(() => loadingConfirm = false);

              if (resp['success'] == true) {
                final newStatus = _normalizeStatus(
                  resp['data']?['status'] ?? 'CONFIRMED',
                );
                setModalState(() {
                  statusUpper = newStatus;
                });
                if (selectedBranchId != null) {
                  await getBookingsByDate(selectedBranchId!, selectedDate);
                }
                // Exact text as requested
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(translateText('Booking Confirmed'))),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      resp['message']?.toString() ?? 'Failed to confirm',
                    ),
                  ),
                );
              }
            }
Future<void> onStartJob() async {
  if (selectedBranchId == null || loadingStart) return;

  await showDialog(
    context: context,
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
            title: Text(translateText("Enter OTP"),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 350, // fixed modal width
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

    // ?? Dynamic colors based on hasError
    activeColor: hasError ? Colors.red : AppColors.starColor,
    selectedColor: hasError ? Colors.red : AppColors.starColor,
    inactiveColor: hasError ? Colors.red : AppColors.starColor,
    errorBorderColor: Colors.red,
  ),
  enableActiveFill: true,
  onChanged: (value) {
    otp = value;
    setDialogState(() {
      hasError = false; // reset error when typing again
    });
  },
),


                  // ?? Inline error under OTP field
                  if (errorMessage.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
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
                            errorMessage = translateText("Enter valid 6-digit OTP");
                              hasError = true; 
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = "";
                        });

                        Map<String, dynamic>? resp;
                        try {
                          resp = await ApiService.startAppointment(
                            branchId: selectedBranchId!,
                            appointmentId: booking['id'] as int,
                            otp: otp,
                          );
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = translateText("Failed to reach server");
                          });
                          return;
                        }

                        final success = resp['success'] == true;
                        final message = resp['message']?.toString() ??
                            (success ? 'Job started' : 'Invalid OTP');

                        setDialogState(() => isSubmitting = false);

                        if (!success) {
                          // ? Show inline error
                          setDialogState(() {
                            errorMessage = message;
                             hasError = true;
                          });
                          return;
                        }

                        // ? Success
                        Navigator.pop(dialogCtx);
                        final newStatus = _normalizeStatus(
                          resp['data']?['status'] ?? 'IN_PROGRESS',
                        );
                        setModalState(() {
                          statusUpper = newStatus;
                          booking['status'] = newStatus;
                        });

                        await getBookingsByDate(selectedBranchId!, selectedDate);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                ),
                child: isSubmitting
                    ? SizedBox(
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
  if (selectedBranchId == null) return;

  // Extract customer name
  final user = booking['user'] as Map<String, dynamic>?;
  final customerName =
      "${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}".trim();

  // Build services list
  final items = booking['items'] as List<dynamic>? ?? [];
  final services = items.map((it) {
    final serviceName = it['branchService']?['displayName']?.toString() ?? "Service";
    final startAt = DateTime.tryParse(it['startAt']?.toString() ?? "");
    final timeText = startAt != null
        ? DateFormat('hh:mm a').format(startAt)
        : "";
    return {
      "name": serviceName,
      "time": timeText,
    };
  }).toList();

  // Ask user for feedback
  final feedback = await _getFeedbackFromUser(context, customerName, services);
  if (feedback == null) return; // user cancelled

  final int rating = feedback['rating'] as int;
  final String comment = feedback['comment'] as String;

  // COMPLETE API
  setModalState(() => loadingComplete = true);
  final resp = await ApiService().completeAppointment(
    branchId: selectedBranchId!,
    appointmentId: booking['id'] as int,
    rating: rating,
    comment: comment,
  );
  setModalState(() => loadingComplete = false);

  // Handle result
  if (resp['success'] == true) {
    final newStatus = _normalizeStatus(
      resp['data']?['status'] ?? 'COMPLETED',
    );
    setModalState(() {
      statusUpper = newStatus;
    });

    await getBookingsByDate(selectedBranchId!, selectedDate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resp['message']?.toString() ?? 'Appointment completed'),
      ),
    );
  } else {
    final msg = (resp['message']?.toString().isNotEmpty ?? false)
        ? resp['message'].toString()
        : 'Failed to complete appointment';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

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
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                            ],
                          ),
                       Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(height: 4),Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Customer name + subtitle
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerName.isNotEmpty ? customerName : 'Customer',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(translateText('Customer'),
            style: TextStyle(
  fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    ),

    // Status badge
   Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: statusUpper == 'PENDING'
        ? Colors.blue.shade100
        : statusUpper == 'CONFIRMED'
            ? Colors.pink.shade100
            : statusUpper == 'IN_PROGRESS'
                ? AppColors.inProgressStatus
                : statusUpper == 'COMPLETED'
                    ? Colors.green.shade100   // ? light green bg
                    : Colors.grey.shade300,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    statusUpper,
    style: TextStyle(
      fontSize: 12,
      color: statusUpper == 'PENDING'
          ? Colors.black
          : statusUpper == 'CONFIRMED'
              ? Colors.black
              : statusUpper == 'IN_PROGRESS'
                  ?  Colors.black
                  : statusUpper == 'COMPLETED'
                      ? Colors.black   // ? black text
                      : Colors.black54,
    ),
  ),
),

  ],
),
SizedBox(height: 12),

    // Row: Date + Time
    const Divider( // ?? thin line between items
      height: 12,
      thickness: 0.8,
      color: Color(0xFFE0E0E0), // light grey
    ),
    if (start != null || timeStr.isNotEmpty)
      Row(
        children: [
          if (start != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translateText('Date'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(start),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          if (timeStr.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translateText('Time'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
        ],
      ),

    SizedBox(height: 12),

    // Row: Duration + Price
    if (duration.isNotEmpty || totalPrice.isNotEmpty || singleServicePrice.isNotEmpty)
      Row(
        children: [
          if (duration.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translateText('Duration'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    duration,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          if (!hasMultipleServices && singleServicePrice.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translateText('Total Price'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    singleServicePrice,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          if (hasMultipleServices && totalPrice.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translateText('Total Price'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    totalPrice,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
        ],
      ),

    SizedBox(height: 12),

    // Assigned To
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(translateText('Assigned To'),
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          stylist,
          style: const TextStyle(color: Colors.black87),
        ),
      ],
    ),
  ],
),
const Divider( // ?? thin line between items
      height: 12,
      thickness: 0.8,
      color: Color(0xFFE0E0E0), // light grey
    ),
                          if (serviceItems.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(translateText('Services'),
                              style: TextStyle( color: Colors.black54,
            fontWeight: FontWeight.bold,),
                            ),
                            SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: serviceListMaxHeight,
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                primary: false,
                                itemCount: serviceItems.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 12),
                                itemBuilder: (_, idx) {
                                  final serviceItem = serviceItems[idx];
                                  final DateTime? itemStart =
                                      _parseLocal(
                                        serviceItem['startAt']?.toString(),
                                      ) ??
                                      start;
                                  final DateTime? itemEnd =
                                      _parseLocal(
                                        serviceItem['endAt']?.toString(),
                                      ) ??
                                      end;
                                  final String range =
                                      (itemStart != null && itemEnd != null)
                                      ? '${timeFormatter.format(itemStart)} - ${timeFormatter.format(itemEnd)}'
                                      : '';
                                  final String staffName = formatUserName(
                                    serviceItem['assignedUserBranch']?['user'] ??
                                        serviceItem['user'],
                                  );
                                  final int itemPriceMinor = _toInt(
                                    serviceItem['branchService']?['priceMinor'],
                                  );
                                  final String itemPrice = itemPriceMinor > 0
                                      ? '?$itemPriceMinor'
                                      : '';
                                  final bool isSelected = identical(
                                    serviceItem,
                                    useItem,
                                  );
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                serviceItem['branchService']?['displayName']
                                                        ?.toString() ??
                                                    'Service',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          SizedBox(height: 12),
                          const Spacer(),

                          // ACTIONS:
                          if (isPending) ...[
                            // Pending ? Confirm
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loadingConfirm ? null : onConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.starColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: loadingConfirm
                                    ? SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(translateText('Accept'), style: TextStyle(
      color: Colors.white,   // ?? force white text
      fontWeight: FontWeight.w600,),),
                              ),
                            ),
                          ] else if (isConfirmed) ...[
                            // Confirmed ? Start Job
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
                                    ? SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(translateText('Start job')),
                              ),
                            ),
                          ] else if (statusUpper == 'IN_PROGRESS') ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loadingComplete
                                    ? null
                                    : onCompleteJob,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  backgroundColor: AppColors.starColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: loadingComplete
                                    ? SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(translateText('Complete Job')),
                              ),
                            ),
                          ] else ...[
                            // Completed / Cancelled / etc ? Grey disabled
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
                          ],

                          SizedBox(height: 10),
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
                            child: Icon(Icons.close, color: Colors.white),
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
  // Future<void> onBranchChanged(
  //   int branchId,
  //   int salonId,
  //   Map<String, dynamic> branchData,
  // ) async {
  //   final prefs = await SharedPreferences.getInstance(); // NEW
  //   await prefs.setInt('selected_branch_id', branchId); // NEW
  //   await prefs.setInt('selected_salon_id', salonId); // NEW

  //   final String startTime =
  //       (branchData['startTime'] ?? _branchStartTimeStr ?? '08:00:00')
  //           .toString();
  //   final String endTime =
  //       (branchData['endTime'] ?? _branchEndTimeStr ?? '20:00:00').toString();

  //   List<String> updatedSlots;
  //   try {
  //     updatedSlots = generateTimeSlots(startTime, endTime);
  //   } catch (_) {
  //     updatedSlots = timeSlots;
  //   }

  //   setState(() {
  //     _loadingBranch = true;
  //     selectedBranchId = branchId;
  //     selectedSalonId = salonId;
  //     selectedBranch = Map<String, dynamic>.from(branchData);
  //     _branchStartTimeStr = startTime;
  //     _branchEndTimeStr = endTime;
  //     timeSlots = updatedSlots;
  //   });

  //   try {
  //     await getTeamMembers(branchId); // fetch + cache team
  //     await _saveBranchCache(
  //       branchId,
  //     ); // ensure cache updated with new start/end + team
  //     await getBookingsByDate(
  //       branchId,
  //       selectedDate,
  //     ); // (optional) always refresh bookings on branch change
  //     _processQueuedBookingNotificationIfAny();
  //     print('[Bookings] processed any queued payload after branch change.');
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _loadingBranch = false;
  //       });
  //     }
  //   }
  // }
Future<void> onBranchChanged(
  int branchId,
  int salonId,
  Map<String, dynamic> branchData,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('selected_branch_id', branchId);
  await prefs.setInt('selected_salon_id', salonId);

  final String startTime =
      (branchData['startTime'] ?? _branchStartTimeStr ?? '08:00:00')
          .toString();
  final String endTime =
      (branchData['endTime'] ?? _branchEndTimeStr ?? '20:00:00').toString();

  List<String> updatedSlots;
  try {
    updatedSlots = generateTimeSlots(startTime, endTime);
  } catch (_) {
    updatedSlots = timeSlots;
  }

  setState(() {
    _loadingBranch = true;
    selectedBranchId = branchId;
    selectedSalonId = salonId;
    selectedBranch = Map<String, dynamic>.from(branchData);
    _branchStartTimeStr = startTime;
    _branchEndTimeStr = endTime;
    timeSlots = updatedSlots;
  });

  try {
    // ?? Step 1: Fetch team members
    await getTeamMembers(branchId);

    // ?? Step 2: Save branch cache
    await _saveBranchCache(branchId);

    // ?? Step 3: Always fetch bookings for current date
    print('[Bookings] calling getBookingsByDate ? branch=$branchId, date=$selectedDate');
    await getBookingsByDate(branchId, selectedDate);

    // ?? Step 4: Process any queued notifications
    _processQueuedBookingNotificationIfAny();

    print('[Bookings] processed queued payload after branch change.');
  } finally {
    if (mounted) {
      setState(() {
        _loadingBranch = false;
      });
    }
  }
}

  // Function to handle date change (previous and next)
  Future<void> _setSelectedDate(DateTime date) async {
    if (selectedBranchId == null) {
      setState(() {
        selectedDate = date;
      });
      return;
    }

    setState(() {
      selectedDate = date;
      _loadingDate = true;
    });

    try {
      await getBookingsByDate(selectedBranchId!, date);
    } finally {
      if (mounted) {
        setState(() {
          _loadingDate = false;
        });
      }
    }
  }

  Future<void> _handleBookingNotification(
    BookingNotificationPayload payload,
  ) async {
    print(
      '[Bookings] handling booking push: branch=' +
          payload.branchId.toString() +
          ', date=' +
          payload.date.toIso8601String() +
          ', tapped=' +
          payload.wasTapped.toString(),
    );
    if (!mounted) return;

    final options = _computeBranchOptions();
    _BranchOption? targetOption;
    for (final option in options) {
      if (option.branchId == payload.branchId) {
        targetOption = option;
        break;
      }
    }

    if (targetOption == null) {
      print(
        '[Bookings] branch=' +
            payload.branchId.toString() +
            ' not yet available, queueing payload.',
      );
      _queuedBookingNotification = payload;
      if (!isLoading && !_isFetchingData) {
        unawaited(_refreshAllData());
      }
      return;
    }

    if (selectedBranchId != targetOption.branchId) {
      await onBranchChanged(
        targetOption.branchId,
        targetOption.salonId,
        targetOption.branch,
      );
      if (!mounted) return;
    }

    if (selectedBranchId != targetOption.branchId) {
      _queuedBookingNotification = payload;
      return;
    }

    final bool shouldChangeDate = !isSameDay(selectedDate, payload.date);
    if (shouldChangeDate) {
      await _setSelectedDate(payload.date);
      print(
        '[Bookings] changed active date via push to ' +
            payload.date.toIso8601String(),
      );
    } else {
      await getBookingsByDate(selectedBranchId!, selectedDate);
      print('[Bookings] reloaded bookings for existing date via push.');
    }

    if (!payload.wasTapped && payload.message?.isNotEmpty == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(payload.message!)));
    }
  }

  Future<void> changeDate(bool isNext) async {
    final DateTime newDate = isNext
        ? selectedDate.add(const Duration(days: 1))
        : selectedDate.subtract(const Duration(days: 1));

    await _setSelectedDate(newDate);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    final branchOptions = _computeBranchOptions();
    final selectedBranchValue =
        branchOptions.any((option) => option.branchId == selectedBranchId)
        ? selectedBranchId
        : null;
    final branchHint = branchOptions.isEmpty
        ? context.t('Add a salon or branch to get started')
        : context.t('Pick a salon & branch to view bookings');
    final bool hasSalons = branchOptions.isNotEmpty;
    final List<String> displayTimeSlots =
        timeSlots.isEmpty ? _defaultTimeSlots : timeSlots;
    final bool hasTeamMembers = teamMembers.isNotEmpty;
    final bool hasSlots = timeSlots.isNotEmpty;
    final String primaryEmptyMessage = translateText(
      hasSalons ? 'Add team members to start' : 'Add a salon and team members',
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: DropdownButtonFormField<int>(
                  value: selectedBranchValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: translateText('Salon & Branch'),
                    hintText: branchHint,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.transparent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.grey,
                        width: 1.6,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.grey,
                  ),
                  dropdownColor: Colors.white,
                  menuMaxHeight: 360,
                  hint: Text(
                    branchHint,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  items: branchOptions
                      .map(
                        (option) => DropdownMenuItem<int>(
                          value: option.branchId,
                          child: _BranchDropdownOption(option: option),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: branchOptions.isNotEmpty
                      ? (context) => branchOptions
                            .map(
                              (option) => Align(
                                alignment: Alignment.centerLeft,
                                child: _BranchDropdownOption(
                                  option: option,
                                  compact: true,
                                ),
                              ),
                            )
                            .toList()
                      : null,
                  onChanged: branchOptions.isEmpty
                      ? null
                      : (newValue) {
                          if (newValue == null) return;
                          final option = branchOptions.firstWhere(
                            (element) => element.branchId == newValue,
                          );
                          onBranchChanged(
                            option.branchId,
                            option.salonId,
                            option.branch,
                          );
                        },
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
             IconButton(
  onPressed: () => changeWeek(false),
  icon: Container(
    padding: const EdgeInsets.all(8), // space around icon
    decoration: BoxDecoration(
      color: Colors.grey.shade200,    // light background
      borderRadius: BorderRadius.circular(8), // rounded square
    ),
    child: SvgPicture.asset(
      'assets/images/icons/previous.svg',
      width: 20,
      height: 20,
      color: Colors.black, // or AppColors.starColor
    ),
  ),
),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(7, (index) {
                          final DateTime weekStart = DateTime(
                            _weekAnchor.year,
                            _weekAnchor.month,
                            _weekAnchor.day,
                          );
                          final DateTime date = weekStart.add(
                            Duration(days: index),
                          );
                          final bool isSelected = isSameDay(date, selectedDate);
                          final now = DateTime.now();
                          final bool isToday = isSameDay(
                            date,
                            DateTime(now.year, now.month, now.day),
                          );

                          final Color bgColor = isSelected
                              ? Colors.black
                              : (isToday
                                    ? Colors.blue.withOpacity(0.10)
                                    : Colors.grey[200]!);

                          final Color textColor = isSelected
                              ? Colors.white
                              : (isToday ? Colors.blue : Colors.black);

                          final Border border = isToday
                              ? Border.all(color: Colors.blue, width: 1.5)
                              : Border.all(color: Colors.transparent);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: GestureDetector(
                              onTap: () => _setSelectedDate(date),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
  DateFormat('dd MMM').format(date), // ?? gives "30 Sep", "01 Oct"
  style: TextStyle(
    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    color: isSelected ? Colors.white : Colors.black,
  ),
),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
    IconButton(
  onPressed: () => changeWeek(true),
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
        Colors.black, // ?? ensures visible
        BlendMode.srcIn,
      ),
    ),
  ),
),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: Container(
                 color: Colors.white,

                  child: Column(
                    children: [
                      // Header row: Time + horizontally scrollable member headers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                  topLeft: Radius.circular(12),
                                ),
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                  left: BorderSide(color: Colors.grey.shade300),
                                  right: BorderSide(color: Colors.grey.shade300),
                                  bottom: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                translateText('Time'),
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _headerHController,
                                scrollDirection: Axis.horizontal,
                                primary: false,
                                physics: const ClampingScrollPhysics(),
                                child: Row(
                                  children: List.generate(_totalColumns, (index) {
                                    if (index >= teamMembers.length) {
                                      // Placeholder staff cell
                                      return _buildEmptyStaffCell(
                                        index == _totalColumns - 1,
                                      );
                                    }

                                    final m = teamMembers[index];
                                    final fn = (m['firstName'] ?? '').toString();
                                    final ln = (m['lastName'] ?? '').toString();
                                    final rawName = ('$fn $ln').trim();
                                    final displayName =
                                        rawName.isEmpty ? 'Staff' : rawName;
                                    final trimmedName = displayName.trim();
                                    final String initial = trimmedName.isEmpty
                                        ? 'S'
                                        : trimmedName[0].toUpperCase();
                                    final isLast = index == _totalColumns - 1;

                                    return Container(
                                      width: _colWidth,
                                      height: 60,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: isLast
                                            ? const BorderRadius.only(
                                                topRight: Radius.circular(12),
                                              )
                                            : null,
                                        border: Border(
                                          top: BorderSide(
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
                                      child: Row(
                                        children: [
                                          Container(
                                            height: 32,
                                            width: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.starColor,
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.starColor,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.starColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Body: left time column synced with grid rows on the right
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              // Time labels column (synced vertically)
                              SizedBox(
                                width: 100,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notif) {
                                    if (notif.metrics.axis == Axis.vertical) {
                                      if (!_syncingV &&
                                          _gridVController.hasClients) {
                                        _syncingV = true;
                                        final off =
                                            _timeColumnVController.offset;
                                        if ((_gridVController.offset - off)
                                                .abs() >
                                            0.5) {
                                          _gridVController.jumpTo(off);
                                        }
                                        _syncingV = false;
                                      }
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    controller: _timeColumnVController,
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemExtent: _rowHeight,
                                    itemCount: displayTimeSlots.length,
                                    itemBuilder: (context, i) {
                                      return Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: i % 2 == 0
                                              ? Colors.white
                                              : const Color(0xFFF0F0F0),
                                          border: Border(
                                            right: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                            bottom: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          displayTimeSlots[i],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Grid body (scrolls both ways)
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _gridHController,
                                  scrollDirection: Axis.horizontal,
                                  primary: false,
                                  physics: const ClampingScrollPhysics(),
                                  child: SizedBox(
                                    width: _totalColumns * _colWidth,
                                    child: NotificationListener<ScrollNotification>(
                                      onNotification: (notif) {
                                        if (notif.metrics.axis ==
                                            Axis.vertical) {
                                          if (!_syncingV &&
                                              _timeColumnVController
                                                  .hasClients) {
                                            _syncingV = true;
                                            final off =
                                                _gridVController.offset;
                                            if ((_timeColumnVController.offset -
                                                        off)
                                                    .abs() >
                                                0.5) {
                                              _timeColumnVController.jumpTo(
                                                off,
                                              );
                                            }
                                            _syncingV = false;
                                          }
                                        }
                                        return false;
                                      },
                                      child: SingleChildScrollView(
                                        controller: _gridVController,
                                        primary: false,
                                        physics: const ClampingScrollPhysics(),
                                        child: SizedBox(
                                          width: _totalColumns * _colWidth,
                                          height: displayTimeSlots.length *
                                              _rowHeight,
                                          child: Stack(
                                            children: [
                                              // Background grid
                                              ..._buildBackgroundGrid(
                                                displayTimeSlots.length,
                                              ),
                                              // Booking overlays
                                              ..._buildBookingBlocks(),
                                              if (!hasTeamMembers)
                                                Positioned(
                                                  top: _rowHeight * 4.5,
                                                  left: 24,
                                                  right: 24,
                                                  child: IgnorePointer(
                                                    child: Container(
                                                      alignment:
                                                          Alignment.center,
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(
                                                                0.92),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey.shade300,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        primaryEmptyMessage,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.black54,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else if (!hasSlots)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: Center(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                  0.92),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey.shade300,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          translateText(
                                                            'No time slots available',
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .black54,
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
                ),
              ),
            ],
          ),
          if (_isFetchingData)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.05),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
   floatingActionButton: FloatingActionButton.extended(
  heroTag: 'add_booking_fab', // ? unique tag
  onPressed: () async {
    if (selectedBranchId == null || selectedSalonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Please select a salon'))),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookingScreen(
          salonId: selectedSalonId,
          branchId: selectedBranchId,
        ),
      ),
    );

    if (result != null && selectedBranchId != null) {
      getBookingsByDate(selectedBranchId!, selectedDate);
    }
  },
  backgroundColor: AppColors.white,
  foregroundColor: AppColors.grey,
  icon: Image.asset(
    "assets/images/plusIcn.png",
    width: 18,
    height: 18,
  ),
  label: Text(
    translateText('Add Booking'),
    style: TextStyle(
      color: AppColors.darkGrey,
    ),
  ),
),
floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

    );
  }

  @override
  void dispose() {
    _bookingPushSub?.cancel();
    _timeColumnVController.dispose();
    _gridVController.dispose();
    _headerHController.dispose();
    _gridHController.dispose();
    super.dispose();
  }

  // Helper function to create status box with count and custom color
  Widget _statusBox(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BranchDropdownOption extends StatelessWidget {
  const _BranchDropdownOption({required this.option, this.compact = false});

  final _BranchOption option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = option.branch['address'] as Map<String, dynamic>? ?? {};
    final line1 = (address['line1'] ?? '').toString().trim();
    final city = (address['city'] ?? '').toString().trim();
    final location = city.isNotEmpty ? '$line1, $city' : line1;

    final salonLabel = option.salonName.trim().isEmpty
        ? option.branchName
        : option.salonName.trim();
    final branchLabel = option.branchName.trim();
    final hasDistinctBranch = branchLabel.isNotEmpty &&
        branchLabel.toLowerCase() != salonLabel.toLowerCase();
    final compactTitle = hasDistinctBranch
        ? '$salonLabel • $branchLabel'
        : salonLabel;

    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
          color: AppColors.starColor,
        ) ??
        TextStyle(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        );

    final branchStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: compact ? 12 : 13,
          color: Colors.blueGrey.shade600,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          fontSize: compact ? 12 : 13,
          color: Colors.blueGrey.shade600,
          fontWeight: FontWeight.w500,
        );

    final locationStyle =
        theme.textTheme.bodySmall?.copyWith(
          fontSize: compact ? 12 : 13,
          color: Colors.blueGrey.shade500,
        ) ??
        TextStyle(fontSize: compact ? 12 : 13, color: Colors.blueGrey.shade500);

    final bool showIcon = !compact;
    final bool showLocation = location.isNotEmpty;

    if (compact) {
      return Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: Colors.blueGrey.shade400,
          ),
          SizedBox(width: 4),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: compactTitle,
                    style: titleStyle,
                  ),
                  if (showLocation)
                    TextSpan(
                      text: ' • $location',
                      style: locationStyle,
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showIcon) ...[
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.starColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: AppColors.starColor,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salonLabel,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasDistinctBranch) ...[
                    SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 16,
                          color: Colors.blueGrey.shade400,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            branchLabel,
                            style: branchStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (showLocation) ...[
                    SizedBox(height: hasDistinctBranch ? 4 : 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.blueGrey.shade400,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            location,
                            style: locationStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const Divider(
          height: 12,
          thickness: 0.8,
          color: Color(0xFFE0E0E0),
        ),
      ],
    );

  }
}
Widget _buildEmptyStaffCell(bool isLast) {
  return Container(
    width: _colWidth,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: isLast
          ? const BorderRadius.only(topRight: Radius.circular(12))
          : null,
      border: Border(
        top: BorderSide(color: Colors.grey.shade300),
        right: BorderSide(color: Colors.grey.shade300),
        bottom: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    alignment: Alignment.center,
  );
}
