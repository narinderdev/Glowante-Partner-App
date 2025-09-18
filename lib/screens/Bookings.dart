//Md
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';  // For date formatting
import '../utils/api_service.dart';  // Import the correct api_service.dart file
import 'AddBookings.dart';  // Add Booking screen

class BookingsScreen extends StatefulWidget {
  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> salons = [];
   bool isLoading = true;
  int? selectedSalonId;
  int? selectedBranchId;  // Store branchId of the selected branch
  Map<String, dynamic>? selectedBranch;  // Store branch details
  List<Map<String, dynamic>> bookings = [];
  DateTime selectedDate = DateTime.now();  // Initial date is today
  List<Map<String, dynamic>> teamMembers = []; // Store team members for the selected branch
  List<String> timeSlots = []; // Declare the timeSlots list
  // Branch working hours for rendering grid/blocks
  String? _branchStartTimeStr; // e.g. "08:00:00"
  String? _branchEndTimeStr;   // e.g. "20:00:00"

  // Layout constants for the grid
  static const double _rowHeight = 44.0;   // 15-min slot height
  static const double _colWidth = 140.0;   // staff column width

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

  @override
  void initState() {
    super.initState();
    getSalonListApi();
    // Sync vertical scroll between time column and grid body
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
    // Sync horizontal scroll between header and grid body
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

    // Ensure initial sync after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timeColumnVController.hasClients && _gridVController.hasClients) {
        _gridVController.jumpTo(_timeColumnVController.offset);
      }
      if (_headerHController.hasClients && _gridHController.hasClients) {
        _gridHController.jumpTo(_headerHController.offset);
      }
    });
  }
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
         date1.month == date2.month &&
         date1.day == date2.day;
}


Future<void> getSalonListApi() async {
    try {
      final response = await ApiService().getSalonListApi(); // Call the method from ApiService

      if (response['success'] == true) {
        List salonsList = response['data'];
        setState(() {
          salons = salonsList.map<Map<String, dynamic>>((salon) {
            return {
              'id': salon['id'],
              'name': salon['name'],
              'branches': salon['branches'],
            };
          }).toList();  // Ensure this returns the expected List<Map<String, dynamic>>
          isLoading = false; // Stop loading after data is fetched
        });
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("Error fetching salon list: $e");
      setState(() {
        isLoading = false; // Stop loading in case of an error
      });
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
  while (start.isBefore(effectiveEnd) || start.isAtSameMomentAs(effectiveEnd)) {
    timeSlots.add(DateFormat("h:mm a").format(start));
    start = start.add(const Duration(minutes: 15));
  }

  return timeSlots;
}

Future<void> getBookingsByDate(int branchId, DateTime date) async {
  try {
    String formattedDate = DateFormat('yyyy-MM-dd').format(date); // Format date
    ApiService apiService = ApiService();

    final response = await apiService.fetchAppointments(branchId, formattedDate);

    if (response != null && response['success'] == true && response['data'] != null) {
      List<dynamic> appointments = response['data'];

      // Try to fetch branch working hours from the payload (fallback-safe)
      String startTime = '08:00:00';
      String endTime = '20:00:00';
      if (appointments.isNotEmpty) {
        final b = appointments.first;
        if (b['branch'] != null) {
          startTime = (b['branch']['startTime'] ?? startTime).toString();
          endTime = (b['branch']['endTime'] ?? endTime).toString();
        }
      }

      // Generate time slots and populate the timeSlots list
      setState(() {
        timeSlots = generateTimeSlots(startTime, endTime); // Populate timeSlots
        print("Generated Time Slots: $timeSlots"); // Debugging line to check the time slots
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
    int sumStatus(String status) {
      int t = 0;
      for (final b in bookings) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        if (s == status) {
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


  // Fetch team members for the selected branch
  Future<void> getTeamMembers(int branchId) async {
    try {
      final response = await ApiService.getTeamMembers(branchId);

      // Check if the response is valid and contains team members data
      if (response != null && response['success'] == true && response['data'] != null && response['data'].isNotEmpty) {
        setState(() {
          teamMembers = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        setState(() {
          teamMembers = []; // Clear the list if no data
        });
        print('No team members available for this branch.');
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
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  // Find staff column index for a booking item by matching user id
  int _findMemberColumnForItem(Map<String, dynamic> item) {
    final dynamic userId = item['assignedUserBranch']?['user']?['id'] ??
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

  // Background grid rows + vertical separators for the timetable
  List<Widget> _buildBackgroundGrid() {
    final List<Widget> widgets = [];
    // Row backgrounds
    for (int r = 0; r < timeSlots.length; r++) {
      widgets.add(Positioned(
        top: r * _rowHeight,
        left: 0,
        right: 0,
        height: _rowHeight,
        child: Container(
          decoration: BoxDecoration(
            color: r % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ));
    }
    // Vertical separators between staff columns
    for (int c = 1; c < (teamMembers.isEmpty ? 1 : teamMembers.length); c++) {
      widgets.add(Positioned(
        top: 0,
        bottom: 0,
        left: c * _colWidth - 1,
        width: 1,
        child: Container(color: Colors.grey.shade300),
      ));
    }
    return widgets;
  }

  // Build booking blocks overlayed on the grid
  // List<Map<String, dynamic>> _generateBookingSegments(DateTime dayStart, DateTime dayEnd) {
  //   final List<Map<String, dynamic>> segments = [];

  //   for (final booking in bookings) {
  //     final status = (booking['status'] ?? '').toString().toUpperCase();
  //     final userId = booking['user']?['id'];
  //     final rawItems = ((booking['items'] as List?) ?? const [])
  //         .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map))
  //         .toList();

  //     rawItems.sort((a, b) {
  //       final DateTime? aStart = _parseLocal(a['startAt']) ?? _parseLocal(booking['startAt']);
  //       final DateTime? bStart = _parseLocal(b['startAt']) ?? _parseLocal(booking['startAt']);
  //       if (aStart == null || bStart == null) return 0;
  //       return aStart.compareTo(bStart);
  //     });

  //     Map<String, dynamic>? current;
  //     DateTime? currentEndRaw;

  //     for (final item in rawItems) {
  //       final assignedId = item['assignedUserBranch']?['id'];
  //       final DateTime? rawStart = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
  //       final DateTime? rawEnd = _parseLocal(item['endAt']) ?? _parseLocal(booking['endAt']);
  //       if (rawStart == null || rawEnd == null) {
  //         continue;
  //       }

  //       final bool canMerge = current != null &&
  //           current['assignedId'] == assignedId &&
  //           current['userId'] == userId &&
  //           currentEndRaw != null && currentEndRaw.isAtSameMomentAs(rawStart);

  //       if (canMerge) {
  //         current['rawEnd'] = rawEnd;
  //         currentEndRaw = rawEnd;
  //         (current['items'] as List<Map<String, dynamic>>).add(item);
  //         final serviceName = item['branchService']?['displayName']?.toString();
  //         if (serviceName != null && serviceName.isNotEmpty) {
  //           (current['services'] as List<String>).add(serviceName);
  //         }
  //         final priceMinor = item['branchService']?['priceMinor'];
  //         if (priceMinor is num) {
  //           current['totalPriceMinor'] = (current['totalPriceMinor'] as num) + priceMinor;
  //         }
  //         continue;
  //       }

  //       if (current != null) {
  //         segments.add(current);
  //       }

  //       final serviceName = item['branchService']?['displayName']?.toString();
  //       final priceMinor = item['branchService']?['priceMinor'];
  //       current = {
  //         'booking': booking,
  //         'items': <Map<String, dynamic>>[item],
  //         'status': status,
  //         'userId': userId,
  //         'assignedId': assignedId,
  //         'rawStart': rawStart,
  //         'rawEnd': rawEnd,
  //         'services': <String>[if (serviceName != null && serviceName.isNotEmpty) serviceName],
  //         'totalPriceMinor': priceMinor is num ? priceMinor : 0,
  //         'representativeItem': item,
  //       };
  //       currentEndRaw = rawEnd;
  //     }

  //     if (current != null) {
  //       segments.add(current);
  //     }
  //   }

  //   return segments;
  // }
/// Collect items and merge consecutive ones for the same customer + staff + status
/// on the same day into one visual segment.
///
/// Each returned segment:
///   - 'col' (int) -> staff column index
///   - 'start'/'end' (DateTime) -> merged time range (local)
///   - 'status' (String)
///   - 'services' (List<String>) -> aggregated service names in order
///   - 'priceTotal' (int?) -> sum of priceMinor (if available)
///   - 'cuts' (List<int>) -> minute offsets from segment.start where thin dividers should be drawn
///   - 'mergedCount' (int) -> how many items were merged
// List<Map<String, dynamic>> _collectAndMergeSegments() {
//   if (bookings.isEmpty || (_branchStartTimeStr == null) || (_branchEndTimeStr == null)) {
//     return const <Map<String, dynamic>>[];
//   }
//   final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
//   final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

//   // Group key: staffCol|customerId|staffUserId|status
//   final Map<String, List<Map<String, dynamic>>> groups = {};

//   for (final booking in bookings) {
//     final status = (booking['status'] ?? '').toString().toUpperCase();
//     final customerId = booking['user']?['id'] ?? booking['userId'];
//     final items = (booking['items'] as List?) ?? const [];

//     for (final raw in items) {
//       final item = Map<String, dynamic>.from(raw as Map);

//       final int col = _findMemberColumnForItem(item);
//       if (col < 0) continue;

//       final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
//                           item['assignedUserBranch']?['userId'] ??
//                           item['user']?['id'] ??
//                           item['userId'];

//       DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
//       DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
//       if (s == null || e == null) continue;

//       // Clamp to branch hours
//       if (s.isBefore(dayStart)) s = dayStart;
//       if (e.isAfter(dayEnd)) e = dayEnd;
//       if (!e.isAfter(s)) continue;

//       final key = '$col|$customerId|$staffUserId|$status';
//       (groups[key] ??= <Map<String, dynamic>>[]).add({
//         'col': col,
//         'customerId': customerId,
//         'staffUserId': staffUserId,
//         'status': status,
//         'start': s,
//         'end': e,
//         'service': item['branchService']?['displayName']?.toString() ?? 'Service',
//         'priceMinor': item['branchService']?['priceMinor'],
//         'raw': item,
//       });
//     }
//   }

//   // Merge consecutive slots inside each group
//   final List<Map<String, dynamic>> segments = [];
//   for (final entry in groups.entries) {
//     final list = entry.value..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
//     if (list.isEmpty) continue;

//     DateTime segStart = list.first['start'];
//     DateTime segEnd   = list.first['end'];
//     final int col     = list.first['col'];
//     final String status = list.first['status'];
//     final List<String> services = [list.first['service']];
//     int? priceTotal = list.first['priceMinor'] is int ? (list.first['priceMinor'] as int) : null;
//     final List<int> cuts = []; // minute offsets from segStart
//     int mergedCount = 1;

//     for (int i = 1; i < list.length; i++) {
//       final DateTime s = list[i]['start'];
//       final DateTime e = list[i]['end'];
//       final String st = list[i]['status'];

//       // Merge only if exactly consecutive and same status
//       if (st == status && s.isAtSameMomentAs(segEnd)) {
//         // Thin divider position measured from current segStart
//         cuts.add(segEnd.difference(segStart).inMinutes);
//         segEnd = e;
//         services.add(list[i]['service']);
//         final thisPrice = list[i]['priceMinor'];
//         if (thisPrice is int) {
//           priceTotal = (priceTotal ?? 0) + thisPrice;
//         }
//         mergedCount++;
//       } else {
//         // finalize previous segment
//         segments.add({
//           'col': col,
//           'status': status,
//           'start': segStart,
//           'end': segEnd,
//           'services': List<String>.from(services),
//           'priceTotal': priceTotal,
//           'cuts': List<int>.from(cuts),
//           'mergedCount': mergedCount,
//         });
//         // start new segment
//         segStart = s;
//         segEnd = e;
//         services
//           ..clear()
//           ..add(list[i]['service']);
//         priceTotal = list[i]['priceMinor'] is int ? list[i]['priceMinor'] as int : null;
//         cuts.clear();
//         mergedCount = 1;
//       }
//     }

//     // push the last open segment
//     segments.add({
//       'col': col,
//       'status': status,
//       'start': segStart,
//       'end': segEnd,
//       'services': List<String>.from(services),
//       'priceTotal': priceTotal,
//       'cuts': List<int>.from(cuts),
//       'mergedCount': mergedCount,
//     });
//   }

//   return segments;
// }
String _fmtTimeRange(DateTime s, DateTime e) {
  final f = DateFormat('h:mma');
  return '${f.format(s).toLowerCase()} - ${f.format(e).toLowerCase()}';
}
List<Map<String, dynamic>> _collectMergedSegments() {
  if (bookings.isEmpty || _branchStartTimeStr == null || _branchEndTimeStr == null) {
    return const [];
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
  final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

  // Step 1: flatten items
  final List<Map<String, dynamic>> flat = [];
  for (final booking in bookings) {
    final status = (booking['status'] ?? '').toString().toUpperCase();
    final customer = booking['user'] as Map<String, dynamic>?;
    final customerName = [
      customer?['firstName']?.toString() ?? '',
      customer?['lastName']?.toString() ?? ''
    ].where((s) => s.isNotEmpty).join(' ').trim();

    final items = (booking['items'] as List?) ?? const [];
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);

      final int col = _findMemberColumnForItem(item);
      if (col < 0) continue;

      final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
                          item['assignedUserBranch']?['userId'] ??
                          item['user']?['id'] ??
                          item['userId'];

      DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
      DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
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
        'service': item['branchService']?['displayName']?.toString() ?? 'Service',
        'priceMinor': _toInt(item['branchService']?['priceMinor']),
      });
    }
  }

  if (flat.isEmpty) return const [];

  // Step 2: group by col + customer + staff + status
  final Map<String, List<Map<String, dynamic>>> groups = {};
  for (final it in flat) {
    final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
    (groups[key] ??= <Map<String, dynamic>>[]).add(it);
  }

  // Step 3: within each group, sort by start and coalesce consecutive items
  final List<Map<String, dynamic>> segments = [];
  for (final g in groups.values) {
    g.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    if (g.isEmpty) continue;

    // seed
    int col = g.first['col'] as int;
    String status = g.first['status'] as String;
    String customerName = g.first['customerName'] as String;
    DateTime segStart = g.first['start'] as DateTime;
    DateTime segEnd   = g.first['end'] as DateTime;
    final List<String> services = [g.first['service'] as String];
    int? priceTotal = _toInt(g.first['priceMinor']);
    final List<Map<String, dynamic>> segItems = [
      {
        'booking': g.first['booking'],
        'item': g.first['item'],
        'appointmentId': g.first['appointmentId'], // ✅ seed includes appointmentId
        'start': segStart,
        'end': segEnd,
        'service': g.first['service'],
        'priceMinor': g.first['priceMinor'],
      }
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
          'appointmentId': curr['appointmentId'], // ✅ use curr appointmentId
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
            'appointmentId': curr['appointmentId'], // ✅ seed appointmentId
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

/// Build merged "segments" for display but keep all underlying items.
/// Merge rule: same staff column, same customer, same staff user, same status,
/// and next.start == prev.end (exactly consecutive).
///
/// Segment shape:
///  {
// /    'col': int,
// /    'status': String,
// /    'customerName': String,
// /    'start': DateTime,
// /    'end': DateTime,
// /    'services': List<String>,
// /    'priceTotal': int?,   // sum of priceMinor
// /    'items': [ {'booking':Map,'item':Map,'start':DateTime,'end':DateTime,'priceMinor':int?,'service':String} ]
///  }
// List<Map<String, dynamic>> _collectMergedSegments() {
//   if (bookings.isEmpty || _branchStartTimeStr == null || _branchEndTimeStr == null) {
//     return const [];
//   }

//   final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
//   final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

//   // Step 1: flatten items
//   final List<Map<String, dynamic>> flat = [];
//   for (final booking in bookings) {
//     final status = (booking['status'] ?? '').toString().toUpperCase();
//     final customer = booking['user'] as Map<String, dynamic>?;
//     final customerName = [
//       customer?['firstName']?.toString() ?? '',
//       customer?['lastName']?.toString() ?? ''
//     ].where((s) => s.isNotEmpty).join(' ').trim();

//     final items = (booking['items'] as List?) ?? const [];
//     for (final raw in items) {
//       final item = Map<String, dynamic>.from(raw as Map);

//       final int col = _findMemberColumnForItem(item);
//       if (col < 0) continue;

//       final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
//                           item['assignedUserBranch']?['userId'] ??
//                           item['user']?['id'] ??
//                           item['userId'];

//       DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
//       DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
//       if (s == null || e == null) continue;

//       // clamp
//       if (s.isBefore(dayStart)) s = dayStart;
//       if (e.isAfter(dayEnd)) e = dayEnd;
//       if (!e.isAfter(s)) continue;

//       flat.add({
//         'booking': booking,
//         'item': item,
//         'col': col,
//         'customerId': booking['user']?['id'] ?? booking['userId'],
//         'customerName': customerName.isEmpty ? 'Customer' : customerName,
//         'staffUserId': staffUserId,
//         'status': status,
//         'start': s,
//         'end': e,
//         'service': item['branchService']?['displayName']?.toString() ?? 'Service',
//         'priceMinor': item['branchService']?['priceMinor'],
//       });
//     }
//   }

//   if (flat.isEmpty) return const [];

//   // Step 2: group by col + customer + staff + status
//   final Map<String, List<Map<String, dynamic>>> groups = {};
//   for (final it in flat) {
//     final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
//     (groups[key] ??= <Map<String, dynamic>>[]).add(it);
//   }

//   // Step 3: within each group, sort by start and coalesce consecutive items
//   final List<Map<String, dynamic>> segments = [];
//   for (final g in groups.values) {
//     g.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
//     if (g.isEmpty) continue;

//     // seed
//     int col = g.first['col'] as int;
//     String status = g.first['status'] as String;
//     String customerName = g.first['customerName'] as String;
//     DateTime segStart = g.first['start'] as DateTime;
//     DateTime segEnd   = g.first['end'] as DateTime;
//     final List<String> services = [g.first['service'] as String];
//     int? priceTotal = (g.first['priceMinor'] is int) ? g.first['priceMinor'] as int : null;
//     final List<Map<String, dynamic>> segItems = [
//       {
//         'booking': g.first['booking'],
//         'item': g.first['item'],
//         'start': segStart,
//         'end': segEnd,
//         'service': g.first['service'],
//         'priceMinor': g.first['priceMinor'],
//       }
//     ];

//     for (int i = 1; i < g.length; i++) {
//       final curr = g[i];
//       final s = curr['start'] as DateTime;
//       final e = curr['end'] as DateTime;

//       // merge only if exactly consecutive
//       if (s.isAtSameMomentAs(segEnd)) {
//         segEnd = e;
//         services.add(curr['service'] as String);
//         if (curr['priceMinor'] is int) {
//           priceTotal = (priceTotal ?? 0) + (curr['priceMinor'] as int);
//         }
//         segItems.add({
//           'booking': curr['booking'],
//           'item': curr['item'],
//           'start': s,
//           'end': e,
//           'service': curr['service'],
//           'priceMinor': curr['priceMinor'],
//         });
//       } else {
//         // flush
//         segments.add({
//           'col': col,
//           'status': status,
//           'customerName': customerName,
//           'start': segStart,
//           'end': segEnd,
//           'services': List<String>.from(services),
//           'priceTotal': priceTotal,
//           'items': List<Map<String, dynamic>>.from(segItems),
//         });
//         // start new
//         col = curr['col'] as int;
//         status = curr['status'] as String;
//         customerName = curr['customerName'] as String;
//         segStart = s;
//         segEnd = e;
//         services
//           ..clear()
//           ..add(curr['service'] as String);
//         priceTotal = curr['priceMinor'] is int ? curr['priceMinor'] as int : null;
//         segItems
//           ..clear()
//           ..add({
//             'booking': curr['booking'],
//             'item': curr['item'],
//             'start': s,
//             'end': e,
//             'service': curr['service'],
//             'priceMinor': curr['priceMinor'],
//           });
//       }
//     }

//     // final flush
//     segments.add({
//       'col': col,
//       'status': status,
//       'customerName': customerName,
//       'start': segStart,
//       'end': segEnd,
//       'services': List<String>.from(services),
//       'priceTotal': priceTotal,
//       'items': List<Map<String, dynamic>>.from(segItems),
//     });
//   }

//   return segments;
// }
// void _openMergedSegmentSheet(Map<String, dynamic> seg) {
//   final DateTime s = seg['start'] as DateTime;
//   final DateTime e = seg['end'] as DateTime;
//   final String status = (seg['status'] as String).toUpperCase();
//   final String customerName = seg['customerName'] as String? ?? 'Customer';
//   final int? priceTotal = seg['priceTotal'] as int?;
//   final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.white,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//     ),
//     builder: (ctx) {
//       return FractionallySizedBox(
//         heightFactor: 0.55,
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // header
//               Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       customerName,
//                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               Text(_fmtTimeRange(s, e), style: const TextStyle(color: Colors.black54)),
//               const SizedBox(height: 4),
//               Text('Status: $status', style: const TextStyle(color: Colors.black54)),
//               if (priceTotal != null) ...[
//                 const SizedBox(height: 4),
//                 Text('Total Price: ₹$priceTotal', style: const TextStyle(color: Colors.black87)),
//               ],
//               const SizedBox(height: 12),
//               const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
//               const SizedBox(height: 8),

//               // list of underlying items
//               Expanded(
//                 child: ListView.separated(
//                   itemCount: items.length,
//                   separatorBuilder: (_, __) => const Divider(height: 1),
//                   itemBuilder: (context, i) {
//                     final it = items[i];
//                     final booking = it['booking'] as Map<String, dynamic>;
//                     final item = it['item'] as Map<String, dynamic>;
//                     final String name = (it['service']?.toString() ?? 'Service');
//                     final int? priceMinor = it['priceMinor'] as int?;
//                     final String priceText = priceMinor != null ? '₹$priceMinor' : '';
//                     final String range = _fmtTimeRange(it['start'] as DateTime, it['end'] as DateTime);

//                     return ListTile(
//                       dense: true,
//                       title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
//                       subtitle: Text(range),
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           if (priceText.isNotEmpty)
//                             Padding(
//                               padding: const EdgeInsets.only(right: 8),
//                               child: Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600)),
//                             ),
//                           TextButton(
//                             onPressed: () {
//                               Navigator.pop(context); // close merged sheet
//                               _openAppointmentSheet(booking, item); // open your existing per-item sheet
//                             },
//                             child: const Text('View'),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),

//               SizedBox(
//                 width: double.infinity,
//                 child: OutlinedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text('Close'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
void _openMergedSegmentSheet(Map<String, dynamic> seg) {
  final DateTime s = seg['start'] as DateTime;
  final DateTime e = seg['end'] as DateTime;
  final String status = (seg['status'] as String).toUpperCase();
  final String customerName = seg['customerName'] as String? ?? 'Customer';
  final int? priceTotal = seg['priceTotal'] as int?;
  final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

  // Unique appointment IDs to confirm
  final List<int> apptIds = items
      .map((it) => (it['appointmentId'] as int?))
      .where((id) => id != null)
      .cast<int>()
      .toSet()
      .toList()
    ..sort();

  final String timeRange = _fmtTimeRange(s, e);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      bool loadingConfirm = false;

      Future<void> onConfirmAll() async {
        if (selectedBranchId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a branch first.')),
          );
          return;
        }
        if (status != 'PENDING' || apptIds.isEmpty) return;

        loadingConfirm = true;
        (ctx as Element).markNeedsBuild();

        int ok = 0, fail = 0;
        for (final id in apptIds) {
          try {
            final resp = await ApiService().confirmAppointment(
              branchId: selectedBranchId!,
              appointmentId: id,
            );
            if (resp['success'] == true) {
              ok++;
            } else {
              fail++;
            }
          } catch (_) {
            fail++;
          }
        }

        loadingConfirm = false;
        (ctx as Element).markNeedsBuild();

        Navigator.pop(context);
        if (selectedBranchId != null) {
          await getBookingsByDate(selectedBranchId!, selectedDate);
        }

        final msg = fail == 0
            ? 'Confirmed $ok appointment(s).'
            : 'Confirmed $ok, failed $fail.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

      return FractionallySizedBox(
        heightFactor: 0.60,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(timeRange, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text('Status: $status', style: const TextStyle(color: Colors.black54)),
              if (priceTotal != null) ...[
                const SizedBox(height: 4),
                Text('Total Price: ₹$priceTotal', style: const TextStyle(color: Colors.black87)),
              ],
              const SizedBox(height: 12),

              // Services list (no View buttons)
              const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final String name = (it['service']?.toString() ?? 'Service');
                    final int? priceMinor = it['priceMinor'] as int?;
                    final String priceText = priceMinor != null ? '₹$priceMinor' : '';
                    final String range = _fmtTimeRange(it['start'] as DateTime, it['end'] as DateTime);

                    return ListTile(
                      dense: true,
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(range),
                      trailing: priceText.isNotEmpty
                          ? Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600))
                          : null,
                    );
                  },
                ),
              ),

              // Single Confirm All button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (status == 'PENDING' && !loadingConfirm) ? onConfirmAll : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: loadingConfirm
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          apptIds.length <= 1 ? 'Confirm' : 'Confirm All (${apptIds.length})',
                        ),
                ),
              ),
              const SizedBox(height: 8),
              // SizedBox(
              //   width: double.infinity,
              //   child: OutlinedButton(
              //     onPressed: () => Navigator.pop(context),
              //     style: OutlinedButton.styleFrom(
              //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              //     ),
              //     child: const Text('Close'),
              //   ),
              // ),
            ],
          ),
        ),
      );
    },
  );
}

  // List<Widget> _buildBookingBlocks() {
  //   if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

  //   final startStr = _branchStartTimeStr ?? '08:00:00';
  //   final endStr = _branchEndTimeStr ?? '20:00:00';
  //   final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);
  //   final DateTime dayEnd = _combineDateAndTime(selectedDate, endStr);

  //   final List<Widget> blocks = [];

  //   for (final booking in bookings) {
  //     final status = (booking['status'] ?? '').toString().toUpperCase();
  //     final items = (booking['items'] as List?) ?? const [];

  //     for (final raw in items) {
  //       final item = Map<String, dynamic>.from(raw as Map);
  //       final col = _findMemberColumnForItem(item);
  //       if (col < 0) continue;

  //       final DateTime? rawStart = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
  //       final DateTime? rawEnd = _parseLocal(item['endAt']) ?? _parseLocal(booking['endAt']);
  //       if (rawStart == null || rawEnd == null) continue;

  //       // Clamp within branch working hours
  //       DateTime start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
  //       DateTime end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
  //       if (!end.isAfter(start)) continue;

  //       final int minutesFromStart = start.difference(dayStart).inMinutes;
  //       final int durationMin = item['durationMin'] is int
  //           ? item['durationMin'] as int
  //           : end.difference(start).inMinutes;

  //       final double top = (minutesFromStart / 15.0) * _rowHeight;
  //       final double height = (durationMin / 15.0) * _rowHeight - 2;
  //       final double left = col * _colWidth + 6;
  //       final double width = _colWidth - 12;

  //       Color bg = Colors.blue.shade300;
  //       if (status == 'PENDING') bg = Colors.orange.shade300;
  //       if (status == 'CANCELLED') bg = Colors.red.shade300;
  //       if (status == 'COMPLETED') bg = Colors.green.shade300;

  //       final serviceName = item['branchService']?['displayName']?.toString() ?? 'Service';
  //       final priceMinor = item['branchService']?['priceMinor'];
  //       final priceText = priceMinor != null ? '₹$priceMinor' : '';

  //       blocks.add(Positioned(
  //         left: left,
  //         top: top,
  //         width: width,
  //         height: height < 30 ? 30 : height,
  //         child: Material(
  //           color: Colors.transparent,
  //           child: InkWell(
  //             borderRadius: BorderRadius.circular(12),
  //             onTap: () => _openAppointmentSheet(booking, item),
  //             child: ClipRRect(
  //               borderRadius: BorderRadius.circular(12),
  //               child: Container(
  //                 color: bg,
  //                 padding: const EdgeInsets.all(10),
  //                 child: Builder(builder: (_) {
  //                   final bool compact = height < 72;
  //                   if (compact) {
  //                     return Align(
  //                       alignment: Alignment.topLeft,
  //                       child: Text(
  //                         serviceName,
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87),
  //                       ),
  //                     );
  //                   }
  //                   return Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                     children: [
  //                       Text(
  //                         serviceName,
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
  //                       ),
  //                       if (priceText.isNotEmpty)
  //                         Text('Price: $priceText', style: const TextStyle(color: Colors.black87)),
  //                       Align(
  //                         alignment: Alignment.bottomRight,
  //                         child: Text(
  //                           status,
  //                           style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
  //                         ),
  //                       ),
  //                     ],
  //                   );
  //                 }),
  //               ),
  //             ),
  //           ),
  //         ),
  //       ));
  //     }
  //   }

  //   return blocks;
  // }
// Build booking blocks overlayed on the grid (with merge logic)
// List<Widget> _buildBookingBlocks() {
//   if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

//   final startStr = _branchStartTimeStr ?? '08:00:00';
//   final endStr   = _branchEndTimeStr   ?? '20:00:00';
//   final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);
//   // final DateTime dayEnd   = _combineDateAndTime(selectedDate, endStr); // not needed here

//   final merged = _collectAndMergeSegments();
//   final List<Widget> blocks = [];

//   for (final seg in merged) {
//     final int col = seg['col'] as int;
//     final DateTime start = seg['start'] as DateTime;
//     final DateTime end   = seg['end'] as DateTime;
//     final String status  = (seg['status'] as String).toUpperCase();
//     final List<String> services = List<String>.from(seg['services'] as List);
//     final int mergedCount = seg['mergedCount'] as int;
//     final List<int> cuts = List<int>.from(seg['cuts'] as List);
//     final int? priceTotal = seg['priceTotal'] as int?;

//     final int minutesFromStart = start.difference(dayStart).inMinutes;
//     final int durationMin = end.difference(start).inMinutes;

//     final double top = (minutesFromStart / 15.0) * _rowHeight;
//     // If this segment represents multiple merged items, remove the 2px gap entirely.
//     // For single items, keep the tiny gap (-2) like before.
//     final double height = (durationMin / 15.0) * _rowHeight - (mergedCount > 1 ? 0 : 2);
//     final double left = col * _colWidth + 6;
//     final double width = _colWidth - 12;

//     Color bg = Colors.blue.shade300;
//     if (status == 'PENDING')   bg = Colors.orange.shade300;
//     if (status == 'CANCELLED') bg = Colors.red.shade300;
//     if (status == 'COMPLETED') bg = Colors.green.shade300;

//     final String title = services.join(' • ');
//     final String priceText = (priceTotal != null) ? '₹$priceTotal' : '';

//     // Toggle this to false if you want ZERO visual separation inside merged blocks.
//     const bool showThinInternalDivider = true;

//     blocks.add(Positioned(
//       left: left,
//       top: top,
//       width: width,
//       height: height < 30 ? 30 : height,
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () {
//             // If you want a specific item, you can decide what to pass.
//             // For merged segments, we just pass null so the sheet shows the block-level info.
//             _openAppointmentSheet(
//               // You may pass a representative booking map if needed.
//               // Here we keep existing behavior by not changing the sheet contract.
//               // You can adapt as you like.
//               {'status': status, 'items': const []}, 
//               null,
//             );
//           },
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: Stack(
//               children: [
//                 // Background
//                 Container(color: bg, padding: const EdgeInsets.all(10)),

//                 // Optional thin internal dividers at the exact join points
//                 if (showThinInternalDivider && cuts.isNotEmpty) ...cuts.map((m) {
//                   final double y = (m / 15.0) * _rowHeight; // position inside block
//                   return Positioned(
//                     left: 0,
//                     right: 0,
//                     top: y - 0.5, // center a 1px line
//                     height: 1,
//                     child: Container(color: Colors.black.withOpacity(0.15)),
//                   );
//                 }),

//                 // Content
//                 Padding(
//                   padding: const EdgeInsets.all(10),
//                   child: Builder(builder: (_) {
//                     final bool compact = height < 72;
//                     if (compact) {
//                       return Align(
//                         alignment: Alignment.topLeft,
//                         child: Text(
//                           title,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 12,
//                             color: Colors.black87,
//                           ),
//                         ),
//                       );
//                     }
//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           title,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
//                         ),
//                         if (priceText.isNotEmpty)
//                           Text('Price: $priceText', style: const TextStyle(color: Colors.black87)),
//                         Align(
//                           alignment: Alignment.bottomRight,
//                           child: Text(
//                             status,
//                             style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
//                           ),
//                         ),
//                       ],
//                     );
//                   }),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     ));
//   }

//   return blocks;
// }
// List<Widget> _buildBookingBlocks() {
//   if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

//   const bool showThinLineBetween = true; // set false for completely seamless

//   final startStr = _branchStartTimeStr ?? '08:00:00';
//   final endStr   = _branchEndTimeStr   ?? '20:00:00';
//   final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);
//   final DateTime dayEnd   = _combineDateAndTime(selectedDate, endStr);

//   // 1) Flatten items with computed props
//   final List<Map<String, dynamic>> allItems = [];
//   for (final booking in bookings) {
//     final String status = (booking['status'] ?? '').toString().toUpperCase();
//     final dynamic customerId = booking['user']?['id'] ?? booking['userId'];
//     final items = (booking['items'] as List?) ?? const [];

//     for (final raw in items) {
//       final item = Map<String, dynamic>.from(raw as Map);

//       final int col = _findMemberColumnForItem(item);
//       if (col < 0) continue;

//       final dynamic staffUserId = item['assignedUserBranch']?['user']?['id'] ??
//                                   item['assignedUserBranch']?['userId'] ??
//                                   item['user']?['id'] ??
//                                   item['userId'];

//       final DateTime? rawStart = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
//       final DateTime? rawEnd   = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
//       if (rawStart == null || rawEnd == null) continue;

//       // Clamp within branch working hours
//       DateTime start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
//       DateTime end   = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
//       if (!end.isAfter(start)) continue;

//       final int durationMin = item['durationMin'] is int
//           ? item['durationMin'] as int
//           : end.difference(start).inMinutes;

//       allItems.add({
//         'booking': booking,
//         'item': item,
//         'col': col,
//         'customerId': customerId,
//         'staffUserId': staffUserId,
//         'status': status,
//         'start': start,
//         'end': end,
//         'durationMin': durationMin,
//         'serviceName': item['branchService']?['displayName']?.toString() ?? 'Service',
//         'priceMinor': item['branchService']?['priceMinor'],
//       });
//     }
//   }

//   if (allItems.isEmpty) return const <Widget>[];

//   // 2) Group by (col, customerId, staffUserId) and mark consecutive flags
//   final Map<String, List<Map<String, dynamic>>> groups = {};
//   for (final it in allItems) {
//     final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}';
//     (groups[key] ??= <Map<String, dynamic>>[]).add(it);
//   }
//   for (final entry in groups.entries) {
//     final g = entry.value..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
//     for (int i = 0; i < g.length; i++) {
//       final curr = g[i];
//       final prev = i > 0 ? g[i - 1] : null;
//       final next = i < g.length - 1 ? g[i + 1] : null;

//       bool hasPrevConsec = false;
//       bool hasNextConsec = false;

//       if (prev != null) {
//         // same group guarantees same col/customer/staff; just check time adjacency
//         hasPrevConsec = (curr['start'] as DateTime).isAtSameMomentAs(prev['end'] as DateTime);
//       }
//       if (next != null) {
//         hasNextConsec = (next['start'] as DateTime).isAtSameMomentAs(curr['end'] as DateTime);
//       }

//       curr['hasPrevConsec'] = hasPrevConsec;
//       curr['hasNextConsec'] = hasNextConsec;
//     }
//   }

//   // 3) Build widgets (iterate over all items; order doesn’t matter because Positioned)
//   final List<Widget> blocks = [];
//   for (final it in allItems) {
//     final int col = it['col'] as int;
//     final DateTime start = it['start'] as DateTime;
//     final DateTime end   = it['end'] as DateTime;
//     final int durationMin = it['durationMin'] as int;
//     final String status = (it['status'] as String).toUpperCase();

//     final int minutesFromStart = start.difference(dayStart).inMinutes;
//     final double top = (minutesFromStart / 15.0) * _rowHeight;

//     // Remove the gap ONLY if this item is immediately followed by a consecutive one
//     final bool hasPrevConsec = it['hasPrevConsec'] == true;
//     final bool hasNextConsec = it['hasNextConsec'] == true;
//     final double baseHeight = (durationMin / 15.0) * _rowHeight;
//     final double height = (baseHeight - (hasNextConsec ? 0.0 : 2.0)).clamp(30.0, double.infinity);

//     final double left = col * _colWidth + 6;
//     final double width = _colWidth - 12;

//     Color bg = Colors.blue.shade300;
//     if (status == 'PENDING')   bg = Colors.orange.shade300;
//     if (status == 'CANCELLED') bg = Colors.red.shade300;
//     if (status == 'COMPLETED') bg = Colors.green.shade300;

//     final String serviceName = it['serviceName'] as String;
//     final dynamic priceMinor = it['priceMinor'];
//     final String priceText = priceMinor != null ? '₹$priceMinor' : '';

//     final booking = it['booking'] as Map<String, dynamic>;
//     final item    = it['item'] as Map<String, dynamic>;

//     final BorderRadius radius = BorderRadius.only(
//       topLeft:    Radius.circular(hasPrevConsec ? 0 : 12),
//       topRight:   Radius.circular(hasPrevConsec ? 0 : 12),
//       bottomLeft: Radius.circular(hasNextConsec ? 0 : 12),
//       bottomRight:Radius.circular(hasNextConsec ? 0 : 12),
//     );

//     blocks.add(Positioned(
//       left: left,
//       top: top,
//       width: width,
//       height: height,
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: radius,
//           onTap: () => _openAppointmentSheet(booking, item),
//           child: ClipRRect(
//             borderRadius: radius,
//             child: Stack(
//               children: [
//                 // Background
//                 Container(color: bg),

//                 // Optional 1px hairline at the join with the previous consecutive item
//                 if (showThinLineBetween && hasPrevConsec)
//                   Positioned(
//                     left: 0,
//                     right: 0,
//                     top: 0,
//                     height: 1,
//                     child: Container(color: Colors.black.withOpacity(0.15)),
//                   ),

//                 // Content
//                 Padding(
//                   padding: const EdgeInsets.all(10),
//                   child: Builder(builder: (_) {
//                     final bool compact = height < 72;
//                     if (compact) {
//                       return Align(
//                         alignment: Alignment.topLeft,
//                         child: Text(
//                           serviceName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 12,
//                             color: Colors.black87,
//                           ),
//                         ),
//                       );
//                     }
//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           serviceName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
//                         ),
//                         if (priceText.isNotEmpty)
//                           Text('Price: $priceText', style: const TextStyle(color: Colors.black87)),
//                         Align(
//                           alignment: Alignment.bottomRight,
//                           child: Text(
//                             status,
//                             style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
//                           ),
//                         ),
//                       ],
//                     );
//                   }),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     ));
//   }

//   return blocks;
// }
List<Widget> _buildBookingBlocks() {
  if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

  final startStr = _branchStartTimeStr ?? '08:00:00';
  final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);

  final merged = _collectMergedSegments();
  final List<Widget> blocks = [];

  for (final seg in merged) {
    final int col = seg['col'] as int;
    final String status = (seg['status'] as String).toUpperCase();
    final DateTime s = seg['start'] as DateTime;
    final DateTime e = seg['end'] as DateTime;
    final int minutesFromStart = s.difference(dayStart).inMinutes;
    final int totalMin = e.difference(s).inMinutes;

    final double top = (minutesFromStart / 15.0) * _rowHeight;
    final double height = (totalMin / 15.0) * _rowHeight; // no -2 → perfectly seamless
    final double left = col * _colWidth + 6;
    final double width = _colWidth - 12;

    // colors by status
    Color bg = Colors.blue.shade300;         // CONFIRMED
    if (status == 'PENDING')   bg = Colors.orange.shade300;
    if (status == 'CANCELLED') bg = Colors.red.shade300;
    if (status == 'COMPLETED') bg = Colors.green.shade300;

    final String customerName = seg['customerName'] as String? ?? 'Customer';
    final List<String> services = List<String>.from(seg['services'] as List);
    final int moreCount = (services.length > 1) ? services.length - 1 : 0;
    final String headService = services.isNotEmpty ? services.first : 'Service';

    final int? priceTotal = seg['priceTotal'] as int?;
    final String priceText = priceTotal != null ? '₹$priceTotal' : '';

    final String timeRange = _fmtTimeRange(s, e);
    final List<Map<String, dynamic>> segItems = List<Map<String, dynamic>>.from(seg['items'] as List);

    blocks.add(Positioned(
      left: left,
      top: top,
      width: width,
      height: height < 44 ? 44 : height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openMergedSegmentSheet(seg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // top block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      Text(
                        moreCount > 0 ? '$headService + $moreCount more' : headService,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      if (priceText.isNotEmpty)
                        Text(priceText, style: const TextStyle(color: Colors.black87,)),
                    ],
                  ),
                  // bottom row
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(timeRange, style: const TextStyle(color: Colors.black87,fontSize: 10)),
                      Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87,fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  return blocks;
}

  // Show bottom sheet with appointment details and actions
void _openAppointmentSheet(Map<String, dynamic> booking, Map<String, dynamic>? item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final List items = (booking['items'] as List?) ?? const [];
          final Map? useItem = item ?? (items.isNotEmpty ? items.first as Map : null);

          final String services = useItem != null
              ? (useItem['branchService']?['displayName']?.toString() ?? '')
              : items
                  .map((e) => (e as Map)['branchService']?['displayName']?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .join(', ');

          final start = _parseLocal(useItem?['startAt']?.toString()) ?? _parseLocal(booking['startAt']);
          final end = _parseLocal(useItem?['endAt']?.toString()) ?? _parseLocal(booking['endAt']);
          final timeStr = start != null && end != null
              ? "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}"
              : '';

          final String statusUpper = (booking['status'] ?? '').toString().toUpperCase();
          final bool isPending = statusUpper == 'PENDING';

          final stylist = useItem?['assignedUserBranch']?['user']?['firstName'] ?? 'N/A';
          final duration = useItem?['durationMin'] != null ? '${useItem!['durationMin']} min' : '';
          final priceMinor = useItem?['branchService']?['priceMinor'];
          final price = priceMinor != null ? '₹$priceMinor' : '';

          // Separate loading states
          bool loadingConfirm = false;
          bool loadingCancel = false;

          Future<void> onConfirm() async {
            if (selectedBranchId == null) return;
            setModalState(() => loadingConfirm = true);
            final resp = await ApiService().confirmAppointment(
              branchId: selectedBranchId!,
              appointmentId: booking['id'] as int,
            );
            setModalState(() => loadingConfirm = false);

            if (resp['success'] == true) {
              Navigator.of(context).pop();
              getBookingsByDate(selectedBranchId!, selectedDate);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(resp['message']?.toString() ?? 'Confirmed')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to confirm')),
              );
            }
          }

          Future<void> onCancel() async {
            if (selectedBranchId == null) return;
            setModalState(() => loadingCancel = true);
            final resp = await ApiService().cancelAppointment(
              branchId: selectedBranchId!,
              appointmentId: booking['id'] as int,
            );
            setModalState(() => loadingCancel = false);

            if (resp['success'] == true) {
              Navigator.of(context).pop();
              getBookingsByDate(selectedBranchId!, selectedDate);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(resp['message']?.toString() ?? 'Cancelled')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to cancel')),
              );
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          services.isEmpty ? 'Appointment' : services,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (timeStr.isNotEmpty)
                    Text(timeStr, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text('Status: $statusUpper', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text('Stylist: $stylist', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  if (duration.isNotEmpty)
                    Text('Duration: $duration', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  if (price.isNotEmpty)
                    Text('Price: $price', style: const TextStyle(color: Colors.black54)),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (loadingConfirm || !isPending) ? null : onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: loadingConfirm
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Confirm'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (loadingCancel || !isPending) ? null : onCancel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: loadingCancel
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close'),
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

  // Function to handle branch selection
  void onBranchChanged(int branchId, int salonId) {
    setState(() {
      selectedBranchId = branchId;
      selectedSalonId = salonId;
    });

    // Fetch team members for the selected branch
    getTeamMembers(branchId);

    // Fetch bookings for the selected branch and date
    getBookingsByDate(branchId, selectedDate);
  }

  // Function to handle date change (previous and next)
  void changeDate(bool isNext) {
    setState(() {
      if (isNext) {
        selectedDate = selectedDate.add(Duration(days: 1)); // Move to the next day
      } else {
        selectedDate = selectedDate.subtract(Duration(days: 1)); // Move to the previous day
      }
    });

    // Fetch bookings for the updated date
    if (selectedBranchId != null) {
      getBookingsByDate(selectedBranchId!, selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: () async {
                if (selectedBranchId == null || selectedSalonId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a branch')),
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
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Add Booking'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
        padding: const EdgeInsets.all(8.0),
        child: salons.isEmpty
            ? isLoading
                ? Center(child: CircularProgressIndicator()) // Show loader while fetching data
                : Text("Please select a branch") // Show message when no data
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: DropdownButtonFormField<int>(
                  hint: Text("Select Salon Branch", style: TextStyle(fontWeight: FontWeight.w600)),
                  value: selectedBranchId,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      final salon = salons.firstWhere((s) =>
                          (s['branches'] as List).any((b) => b['id'] == newValue));
                      final branch = (salon['branches'] as List)
                          .firstWhere((b) => b['id'] == newValue);
                      selectedBranch = {
                        'salonId': salon['id'],
                        'branchId': branch['id'],
                        'branchName': branch['name'],
                      };

                      onBranchChanged(branch['id'], salon['id']);  // Call the function to fetch team members and bookings
                    }
                  },
                  items: salons.expand((salon) {
                    final branches = salon['branches'] as List;
                    return branches.map<DropdownMenuItem<int>>((branch) {
                      return DropdownMenuItem(
                        value: branch['id'],
                        child: Text(branch['name']),
                      );
                    }).toList();
                  }).toList(),
                ),
              ),
      ),
          const SizedBox(height: 16),
// Status counts display in 4 boxes with horizontal scroll
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      _statusBox('Pending', pendingCount, Colors.orange),
      _statusBox('Cancelled', cancelledCount, Colors.red),
      _statusBox('Completed', completedCount, Colors.green),
      _statusBox('Confirmed', confirmedCount, Colors.blue),
    ],
  ),
),
const SizedBox(height: 16),
// Date selection and navigation
Row(
  children: [
    // Fixed left arrow icon
    IconButton(
      icon: Icon(Icons.chevron_left),
      onPressed: () => changeDate(false), // Previous date
    ),

    // Wrap the date selection part with Flexible to avoid overflow
    Flexible(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            // Ensure the date range starts from today, making it the center
            DateTime date = selectedDate.add(Duration(days: index - 3)); // Adjust to show a week range
            bool isSelected = isSameDay(date, selectedDate); // Check if this date is selected

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = date; // Set the selected date
                  });
                  if (selectedBranchId != null) {
                    getBookingsByDate(selectedBranchId!, selectedDate);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date), // Day of the week
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(date), // Day number
                        style: TextStyle(
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

    // Fixed right arrow icon
    IconButton(
      icon: Icon(Icons.chevron_right),
      onPressed: () => changeDate(true), // Next date
    ),
  ],
),

const SizedBox(height: 16),
// Timetable grid (fixed time column + scrollable team columns)
SizedBox(height: 8),
Expanded(
  child: Container(
    color: const Color(0xFFF7F4F1),
    child: Column(
      children: [
        // Header row: Time + horizontally scrollable member headers
        Row(
          children: [
            Container(
              width: 100,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade600,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHController,
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: List.generate(teamMembers.length, (index) {
                    final m = teamMembers[index];
                    return Container(
                      width: 140,
                      height: 44,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                          right: BorderSide(color: Colors.grey.shade300),
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        '${m['firstName']} ${m['lastName']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1, thickness: 1),
        // Body: left time column synced with grid rows on the right
        Expanded(
          child: Row(
            children: [
              // Time labels column (synced vertically)
              SizedBox(
                width: 100,
                child: timeSlots.isEmpty
                    ? const SizedBox()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notif) {
                          if (notif.metrics.axis == Axis.vertical) {
                            if (!_syncingV && _gridVController.hasClients) {
                              _syncingV = true;
                              final off = _timeColumnVController.offset;
                              if ((_gridVController.offset - off).abs() > 0.5) {
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
                          dragStartBehavior: DragStartBehavior.start,
                          itemExtent: 44,
                          itemCount: timeSlots.length,
                          itemBuilder: (context, i) {
                            return Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: i % 2 == 0 ? Colors.white : const Color(0xFFF0F0F0),
                                border: Border(
                                  right: BorderSide(color: Colors.grey.shade300),
                                  bottom: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                timeSlots[i],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                    width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
                    child: timeSlots.isEmpty
                        ? const Center(child: Text('No time slots available'))
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notif) {
                              if (notif.metrics.axis == Axis.vertical) {
                                if (!_syncingV && _timeColumnVController.hasClients) {
                                  _syncingV = true;
                                  final off = _gridVController.offset;
                                  if ((_timeColumnVController.offset - off).abs() > 0.5) {
                                    _timeColumnVController.jumpTo(off);
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
                                width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
                                height: timeSlots.length * _rowHeight,
                                child: Stack(
                                  children: [
                                    // Background grid
                                    ..._buildBackgroundGrid(),
                                    // Booking overlays
                                    ..._buildBookingBlocks(),
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
      ],
    ),
  ),
),
        ],
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
  // Helper function to create status box with count
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
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}}





