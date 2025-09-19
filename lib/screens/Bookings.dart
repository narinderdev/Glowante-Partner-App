// // //Md
// // import 'package:flutter/material.dart';
// // import 'package:flutter/gestures.dart';
// // import 'package:intl/intl.dart';  // For date formatting
// // import '../utils/api_service.dart';  // Import the correct api_service.dart file
// // import 'AddBookings.dart';  // Add Booking screen

// // class BookingsScreen extends StatefulWidget {
// //   @override
// //   _BookingsScreenState createState() => _BookingsScreenState();
// // }

// // class _BookingsScreenState extends State<BookingsScreen> {
// //   List<Map<String, dynamic>> salons = [];
// //    bool isLoading = true;
// //   int? selectedSalonId;
// //   int? selectedBranchId;  // Store branchId of the selected branch
// //   Map<String, dynamic>? selectedBranch;  // Store branch details
// //   List<Map<String, dynamic>> bookings = [];
// //   DateTime selectedDate = DateTime.now();  // Initial date is today
// //   List<Map<String, dynamic>> teamMembers = []; // Store team members for the selected branch
// //   List<String> timeSlots = []; // Declare the timeSlots list
// //   // Branch working hours for rendering grid/blocks
// //   String? _branchStartTimeStr; // e.g. "08:00:00"
// //   String? _branchEndTimeStr;   // e.g. "20:00:00"

// //   // Layout constants for the grid
// //   static const double _rowHeight = 44.0;   // 15-min slot height
// //   static const double _colWidth = 140.0;   // staff column width

// //   int pendingCount = 0;
// //   int cancelledCount = 0;
// //   int completedCount = 0;
// //   int confirmedCount = 0;

// //   // Timetable scroll controllers
// //   final ScrollController _timeColumnVController = ScrollController();
// //   final ScrollController _gridVController = ScrollController();
// //   final ScrollController _headerHController = ScrollController();
// //   final ScrollController _gridHController = ScrollController();
// //   bool _syncingV = false;
// //   bool _syncingH = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     getSalonListApi();
// //     // Sync vertical scroll between time column and grid body
// //     _timeColumnVController.addListener(() {
// //       if (_syncingV) return;
// //       _syncingV = true;
// //       if (_gridVController.hasClients) {
// //         final off = _timeColumnVController.offset;
// //         if ((_gridVController.offset - off).abs() > 0.5) {
// //           _gridVController.jumpTo(off);
// //         }
// //       }
// //       _syncingV = false;
// //     });
// //     _gridVController.addListener(() {
// //       if (_syncingV) return;
// //       _syncingV = true;
// //       if (_timeColumnVController.hasClients) {
// //         final off = _gridVController.offset;
// //         if ((_timeColumnVController.offset - off).abs() > 0.5) {
// //           _timeColumnVController.jumpTo(off);
// //         }
// //       }
// //       _syncingV = false;
// //     });
// //     // Sync horizontal scroll between header and grid body
// //     _headerHController.addListener(() {
// //       if (_syncingH) return;
// //       _syncingH = true;
// //       if (_gridHController.hasClients) {
// //         final off = _headerHController.offset;
// //         if ((_gridHController.offset - off).abs() > 0.5) {
// //           _gridHController.jumpTo(off);
// //         }
// //       }
// //       _syncingH = false;
// //     });
// //     _gridHController.addListener(() {
// //       if (_syncingH) return;
// //       _syncingH = true;
// //       if (_headerHController.hasClients) {
// //         final off = _gridHController.offset;
// //         if ((_headerHController.offset - off).abs() > 0.5) {
// //           _headerHController.jumpTo(off);
// //         }
// //       }
// //       _syncingH = false;
// //     });

// //     // Ensure initial sync after first layout
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       if (_timeColumnVController.hasClients && _gridVController.hasClients) {
// //         _gridVController.jumpTo(_timeColumnVController.offset);
// //       }
// //       if (_headerHController.hasClients && _gridHController.hasClients) {
// //         _gridHController.jumpTo(_headerHController.offset);
// //       }
// //     });
// //   }
// // bool isSameDay(DateTime date1, DateTime date2) {
// //   return date1.year == date2.year &&
// //          date1.month == date2.month &&
// //          date1.day == date2.day;
// // }


// // Future<void> getSalonListApi() async {
// //     try {
// //       final response = await ApiService().getSalonListApi(); // Call the method from ApiService

// //       if (response['success'] == true) {
// //         List salonsList = response['data'];
// //         setState(() {
// //           salons = salonsList.map<Map<String, dynamic>>((salon) {
// //             return {
// //               'id': salon['id'],
// //               'name': salon['name'],
// //               'branches': salon['branches'],
// //             };
// //           }).toList();  // Ensure this returns the expected List<Map<String, dynamic>>
// //           isLoading = false; // Stop loading after data is fetched
// //         });
// //       } else {
// //         throw Exception("Failed to fetch salon list");
// //       }
// //     } catch (e) {
// //       print("Error fetching salon list: $e");
// //       setState(() {
// //         isLoading = false; // Stop loading in case of an error
// //       });
// //     }
// //   }

// // List<String> generateTimeSlots(String startTime, String endTime) {
// //   List<String> timeSlots = [];

// //   // Convert startTime and endTime to DateTime objects
// //   DateTime start = DateFormat("HH:mm:ss").parse(startTime);
// //   DateTime end = DateFormat("HH:mm:ss").parse(endTime);

// //   // Exclude the last 15 minutes from the range
// //   DateTime effectiveEnd = end.subtract(const Duration(minutes: 15));

// //   // Add time slots up to and including effectiveEnd
// //   while (start.isBefore(effectiveEnd) || start.isAtSameMomentAs(effectiveEnd)) {
// //     timeSlots.add(DateFormat("h:mm a").format(start));
// //     start = start.add(const Duration(minutes: 15));
// //   }

// //   return timeSlots;
// // }

// // Future<void> getBookingsByDate(int branchId, DateTime date) async {
// //   try {
// //     String formattedDate = DateFormat('yyyy-MM-dd').format(date); // Format date
// //     ApiService apiService = ApiService();

// //     final response = await apiService.fetchAppointments(branchId, formattedDate);

// //     if (response != null && response['success'] == true && response['data'] != null) {
// //       List<dynamic> appointments = response['data'];

// //       // Try to fetch branch working hours from the payload (fallback-safe)
// //       String startTime = '08:00:00';
// //       String endTime = '20:00:00';
// //       if (appointments.isNotEmpty) {
// //         final b = appointments.first;
// //         if (b['branch'] != null) {
// //           startTime = (b['branch']['startTime'] ?? startTime).toString();
// //           endTime = (b['branch']['endTime'] ?? endTime).toString();
// //         }
// //       }

// //       // Generate time slots and populate the timeSlots list
// //       setState(() {
// //         timeSlots = generateTimeSlots(startTime, endTime); // Populate timeSlots
// //         print("Generated Time Slots: $timeSlots"); // Debugging line to check the time slots
// //         _branchStartTimeStr = startTime;
// //         _branchEndTimeStr = endTime;
// //       });

// //       setState(() {
// //         bookings = List<Map<String, dynamic>>.from(appointments);
// //       });
// //       _recomputeStatusCounts();
// //     } else {
// //       setState(() {
// //         bookings = [];
// //         pendingCount = 0;
// //         cancelledCount = 0;
// //         completedCount = 0;
// //         confirmedCount = 0;
// //       });
// //       print('No appointments available for this date.');
// //     }
// //   } catch (e) {
// //     print('Error fetching bookings: $e');
// //   }
// // }

// //   // Count status by items (so counts match blocks in grid)
// //   void _recomputeStatusCounts() {
// //     int sumStatus(String status) {
// //       int t = 0;
// //       for (final b in bookings) {
// //         final s = (b['status'] ?? '').toString().toUpperCase();
// //         if (s == status) {
// //           final items = (b['items'] as List?) ?? const [];
// //           t += items.isNotEmpty ? items.length : 1;
// //         }
// //       }
// //       return t;
// //     }

// //     setState(() {
// //       pendingCount = sumStatus('PENDING');
// //       cancelledCount = sumStatus('CANCELLED');
// //       completedCount = sumStatus('COMPLETED');
// //       confirmedCount = sumStatus('CONFIRMED');
// //     });
// //   }


// //   // Fetch team members for the selected branch
// //   Future<void> getTeamMembers(int branchId) async {
// //     try {
// //       final response = await ApiService.getTeamMembers(branchId);

// //       // Check if the response is valid and contains team members data
// //       if (response != null && response['success'] == true && response['data'] != null && response['data'].isNotEmpty) {
// //         setState(() {
// //           teamMembers = List<Map<String, dynamic>>.from(response['data']);
// //         });
// //       } else {
// //         setState(() {
// //           teamMembers = []; // Clear the list if no data
// //         });
// //         print('No team members available for this branch.');
// //       }
// //     } catch (e) {
// //       print('Error fetching team members: $e');
// //     }
// //   }

// //   // Combine selected date with a HH:mm[:ss] string to a local DateTime
// //   DateTime _combineDateAndTime(DateTime date, String timeStr) {
// //     int h = 0, m = 0, s = 0;
// //     try {
// //       final parts = timeStr.split(':');
// //       if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
// //       if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
// //       if (parts.length > 2) s = int.tryParse(parts[2]) ?? 0;
// //     } catch (_) {}
// //     return DateTime(date.year, date.month, date.day, h, m, s);
// //   }

// //   // Safely parse ISO string to local DateTime
// //   DateTime? _parseLocal(String? iso) {
// //     if (iso == null) return null;
// //     try {
// //       return DateTime.parse(iso).toLocal();
// //     } catch (_) {
// //       return null;
// //     }
// //   }

// //   // Find staff column index for a booking item by matching user id
// //   int _findMemberColumnForItem(Map<String, dynamic> item) {
// //     final dynamic userId = item['assignedUserBranch']?['user']?['id'] ??
// //         item['assignedUserBranch']?['userId'] ??
// //         item['user']?['id'] ??
// //         item['userId'];
// //     if (userId == null) return -1;
// //     final idx = teamMembers.indexWhere((m) {
// //       final mid = m['id'] ?? m['user']?['id'] ?? m['userId'];
// //       return mid == userId;
// //     });
// //     return idx;
// //   }

// //   // Background grid rows + vertical separators for the timetable
// //   List<Widget> _buildBackgroundGrid() {
// //     final List<Widget> widgets = [];
// //     // Row backgrounds
// //     for (int r = 0; r < timeSlots.length; r++) {
// //       widgets.add(Positioned(
// //         top: r * _rowHeight,
// //         left: 0,
// //         right: 0,
// //         height: _rowHeight,
// //         child: Container(
// //           decoration: BoxDecoration(
// //             color: r % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
// //             border: Border(
// //               bottom: BorderSide(color: Colors.grey.shade300),
// //             ),
// //           ),
// //         ),
// //       ));
// //     }
// //     // Vertical separators between staff columns
// //     for (int c = 1; c < (teamMembers.isEmpty ? 1 : teamMembers.length); c++) {
// //       widgets.add(Positioned(
// //         top: 0,
// //         bottom: 0,
// //         left: c * _colWidth - 1,
// //         width: 1,
// //         child: Container(color: Colors.grey.shade300),
// //       ));
// //     }
// //     return widgets;
// //   }

// // String _fmtTimeRange(DateTime s, DateTime e) {
// //   final f = DateFormat('h:mma');
// //   return '${f.format(s).toLowerCase()} - ${f.format(e).toLowerCase()}';
// // }
// // List<Map<String, dynamic>> _collectMergedSegments() {
// //   if (bookings.isEmpty || _branchStartTimeStr == null || _branchEndTimeStr == null) {
// //     return const [];
// //   }

// //   int? _toInt(dynamic v) {
// //     if (v is int) return v;
// //     if (v is num) return v.toInt();
// //     if (v is String) return int.tryParse(v);
// //     return null;
// //   }

// //   final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
// //   final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

// //   // Step 1: flatten items
// //   final List<Map<String, dynamic>> flat = [];
// //   for (final booking in bookings) {
// //     final status = (booking['status'] ?? '').toString().toUpperCase();
// //     final customer = booking['user'] as Map<String, dynamic>?;
// //     final customerName = [
// //       customer?['firstName']?.toString() ?? '',
// //       customer?['lastName']?.toString() ?? ''
// //     ].where((s) => s.isNotEmpty).join(' ').trim();

// //     final items = (booking['items'] as List?) ?? const [];
// //     for (final raw in items) {
// //       final item = Map<String, dynamic>.from(raw as Map);

// //       final int col = _findMemberColumnForItem(item);
// //       if (col < 0) continue;

// //       final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
// //                           item['assignedUserBranch']?['userId'] ??
// //                           item['user']?['id'] ??
// //                           item['userId'];

// //       DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
// //       DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
// //       if (s == null || e == null) continue;

// //       // clamp
// //       if (s.isBefore(dayStart)) s = dayStart;
// //       if (e.isAfter(dayEnd)) e = dayEnd;
// //       if (!e.isAfter(s)) continue;

// //       flat.add({
// //         'booking': booking,
// //         'item': item,
// //         'appointmentId': booking['id'], // keep per-item appointment id
// //         'col': col,
// //         'customerId': booking['user']?['id'] ?? booking['userId'],
// //         'customerName': customerName.isEmpty ? 'Customer' : customerName,
// //         'staffUserId': staffUserId,
// //         'status': status,
// //         'start': s,
// //         'end': e,
// //         'service': item['branchService']?['displayName']?.toString() ?? 'Service',
// //         'priceMinor': _toInt(item['branchService']?['priceMinor']),
// //       });
// //     }
// //   }

// //   if (flat.isEmpty) return const [];

// //   // Step 2: group by col + customer + staff + status
// //   final Map<String, List<Map<String, dynamic>>> groups = {};
// //   for (final it in flat) {
// //     final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
// //     (groups[key] ??= <Map<String, dynamic>>[]).add(it);
// //   }

// //   // Step 3: within each group, sort by start and coalesce consecutive items
// //   final List<Map<String, dynamic>> segments = [];
// //   for (final g in groups.values) {
// //     g.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
// //     if (g.isEmpty) continue;

// //     // seed
// //     int col = g.first['col'] as int;
// //     String status = g.first['status'] as String;
// //     String customerName = g.first['customerName'] as String;
// //     DateTime segStart = g.first['start'] as DateTime;
// //     DateTime segEnd   = g.first['end'] as DateTime;
// //     final List<String> services = [g.first['service'] as String];
// //     int? priceTotal = _toInt(g.first['priceMinor']);
// //     final List<Map<String, dynamic>> segItems = [
// //       {
// //         'booking': g.first['booking'],
// //         'item': g.first['item'],
// //         'appointmentId': g.first['appointmentId'], // ✅ seed includes appointmentId
// //         'start': segStart,
// //         'end': segEnd,
// //         'service': g.first['service'],
// //         'priceMinor': g.first['priceMinor'],
// //       }
// //     ];

// //     for (int i = 1; i < g.length; i++) {
// //       final curr = g[i];
// //       final s = curr['start'] as DateTime;
// //       final e = curr['end'] as DateTime;

// //       // merge only if exactly consecutive
// //       if (s.isAtSameMomentAs(segEnd)) {
// //         segEnd = e;
// //         services.add(curr['service'] as String);
// //         final p = _toInt(curr['priceMinor']);
// //         if (p != null) priceTotal = (priceTotal ?? 0) + p;

// //         segItems.add({
// //           'booking': curr['booking'],
// //           'item': curr['item'],
// //           'appointmentId': curr['appointmentId'], // ✅ use curr appointmentId
// //           'start': s,
// //           'end': e,
// //           'service': curr['service'],
// //           'priceMinor': curr['priceMinor'],
// //         });
// //       } else {
// //         // flush
// //         segments.add({
// //           'col': col,
// //           'status': status,
// //           'customerName': customerName,
// //           'start': segStart,
// //           'end': segEnd,
// //           'services': List<String>.from(services),
// //           'priceTotal': priceTotal,
// //           'items': List<Map<String, dynamic>>.from(segItems),
// //         });

// //         // start new
// //         col = curr['col'] as int;
// //         status = curr['status'] as String;
// //         customerName = curr['customerName'] as String;
// //         segStart = s;
// //         segEnd = e;
// //         services
// //           ..clear()
// //           ..add(curr['service'] as String);
// //         priceTotal = _toInt(curr['priceMinor']);
// //         segItems
// //           ..clear()
// //           ..add({
// //             'booking': curr['booking'],
// //             'item': curr['item'],
// //             'appointmentId': curr['appointmentId'], // ✅ seed appointmentId
// //             'start': s,
// //             'end': e,
// //             'service': curr['service'],
// //             'priceMinor': curr['priceMinor'],
// //           });
// //       }
// //     }

// //     // final flush
// //     segments.add({
// //       'col': col,
// //       'status': status,
// //       'customerName': customerName,
// //       'start': segStart,
// //       'end': segEnd,
// //       'services': List<String>.from(services),
// //       'priceTotal': priceTotal,
// //       'items': List<Map<String, dynamic>>.from(segItems),
// //     });
// //   }

// //   return segments;
// // }

// // void _openMergedSegmentSheet(Map<String, dynamic> seg) {
// //   final DateTime s = seg['start'] as DateTime;
// //   final DateTime e = seg['end'] as DateTime;
// //   final String status = (seg['status'] as String).toUpperCase();
// //   final String customerName = seg['customerName'] as String? ?? 'Customer';
// //   final int? priceTotal = seg['priceTotal'] as int?;
// //   final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

// //   // Unique appointment IDs to confirm
// //   final List<int> apptIds = items
// //       .map((it) => (it['appointmentId'] as int?))
// //       .where((id) => id != null)
// //       .cast<int>()
// //       .toSet()
// //       .toList()
// //     ..sort();

// //   final String timeRange = _fmtTimeRange(s, e);

// //   showModalBottomSheet(
// //     context: context,
// //     isScrollControlled: true,
// //     backgroundColor: Colors.white,
// //     shape: const RoundedRectangleBorder(
// //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
// //     ),
// //     builder: (ctx) {
// //       bool loadingConfirm = false;

// //       Future<void> onConfirmAll() async {
// //         if (selectedBranchId == null) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             const SnackBar(content: Text('Please select a branch first.')),
// //           );
// //           return;
// //         }
// //         if (status != 'PENDING' || apptIds.isEmpty) return;

// //         loadingConfirm = true;
// //         (ctx as Element).markNeedsBuild();

// //         int ok = 0, fail = 0;
// //         for (final id in apptIds) {
// //           try {
// //             final resp = await ApiService().confirmAppointment(
// //               branchId: selectedBranchId!,
// //               appointmentId: id,
// //             );
// //             if (resp['success'] == true) {
// //               ok++;
// //             } else {
// //               fail++;
// //             }
// //           } catch (_) {
// //             fail++;
// //           }
// //         }

// //         loadingConfirm = false;
// //         (ctx as Element).markNeedsBuild();

// //         Navigator.pop(context);
// //         if (selectedBranchId != null) {
// //           await getBookingsByDate(selectedBranchId!, selectedDate);
// //         }

// //         final msg = fail == 0
// //             ? 'Confirmed $ok appointment(s).'
// //             : 'Confirmed $ok, failed $fail.';
// //         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
// //       }

// //       return FractionallySizedBox(
// //         heightFactor: 0.60,
// //         child: Padding(
// //           padding: const EdgeInsets.all(16),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               // Header
// //               Row(
// //                 children: [
// //                   Expanded(
// //                     child: Text(
// //                       customerName,
// //                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
// //                       overflow: TextOverflow.ellipsis,
// //                     ),
// //                   ),
// //                   IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
// //                 ],
// //               ),
// //               const SizedBox(height: 4),
// //               Text(timeRange, style: const TextStyle(color: Colors.black54)),
// //               const SizedBox(height: 4),
// //               Text('Status: $status', style: const TextStyle(color: Colors.black54)),
// //               if (priceTotal != null) ...[
// //                 const SizedBox(height: 4),
// //                 Text('Total Price: ₹$priceTotal', style: const TextStyle(color: Colors.black87)),
// //               ],
// //               const SizedBox(height: 12),

// //               // Services list (no View buttons)
// //               const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
// //               const SizedBox(height: 6),
// //               Expanded(
// //                 child: ListView.separated(
// //                   itemCount: items.length,
// //                   separatorBuilder: (_, __) => const Divider(height: 1),
// //                   itemBuilder: (context, i) {
// //                     final it = items[i];
// //                     final String name = (it['service']?.toString() ?? 'Service');
// //                     final int? priceMinor = it['priceMinor'] as int?;
// //                     final String priceText = priceMinor != null ? '₹$priceMinor' : '';
// //                     final String range = _fmtTimeRange(it['start'] as DateTime, it['end'] as DateTime);

// //                     return ListTile(
// //                       dense: true,
// //                       title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
// //                       subtitle: Text(range),
// //                       trailing: priceText.isNotEmpty
// //                           ? Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600))
// //                           : null,
// //                     );
// //                   },
// //                 ),
// //               ),

// //               // Single Confirm All button
// //               SizedBox(
// //                 width: double.infinity,
// //                 child: ElevatedButton(
// //                   onPressed: (status == 'PENDING' && !loadingConfirm) ? onConfirmAll : null,
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.blue,
// //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                   ),
// //                   child: loadingConfirm
// //                       ? const SizedBox(
// //                           height: 18, width: 18,
// //                           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
// //                         )
// //                       : Text(
// //                           apptIds.length <= 1 ? 'Confirm' : 'Confirm All (${apptIds.length})',
// //                         ),
// //                 ),
// //               ),
// //               const SizedBox(height: 8),
// //               // SizedBox(
// //               //   width: double.infinity,
// //               //   child: OutlinedButton(
// //               //     onPressed: () => Navigator.pop(context),
// //               //     style: OutlinedButton.styleFrom(
// //               //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //               //     ),
// //               //     child: const Text('Close'),
// //               //   ),
// //               // ),
// //             ],
// //           ),
// //         ),
// //       );
// //     },
// //   );
// // }

// // List<Widget> _buildBookingBlocks() {
// //   if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

// //   final startStr = _branchStartTimeStr ?? '08:00:00';
// //   final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);

// //   final merged = _collectMergedSegments();
// //   final List<Widget> blocks = [];

// //   for (final seg in merged) {
// //     final int col = seg['col'] as int;
// //     final String status = (seg['status'] as String).toUpperCase();
// //     final DateTime s = seg['start'] as DateTime;
// //     final DateTime e = seg['end'] as DateTime;
// //     final int minutesFromStart = s.difference(dayStart).inMinutes;
// //     final int totalMin = e.difference(s).inMinutes;

// //     final double top = (minutesFromStart / 15.0) * _rowHeight;
// //     final double height = (totalMin / 15.0) * _rowHeight; // no -2 → perfectly seamless
// //     final double left = col * _colWidth + 6;
// //     final double width = _colWidth - 12;

// //     // colors by status
// //     Color bg = Colors.blue.shade300;         // CONFIRMED
// //     if (status == 'PENDING')   bg = Colors.orange.shade300;
// //     if (status == 'CANCELLED') bg = Colors.red.shade300;
// //     if (status == 'COMPLETED') bg = Colors.green.shade300;

// //     final String customerName = seg['customerName'] as String? ?? 'Customer';
// //     final List<String> services = List<String>.from(seg['services'] as List);
// //     final int moreCount = (services.length > 1) ? services.length - 1 : 0;
// //     final String headService = services.isNotEmpty ? services.first : 'Service';

// //     final int? priceTotal = seg['priceTotal'] as int?;
// //     final String priceText = priceTotal != null ? '₹$priceTotal' : '';

// //     final String timeRange = _fmtTimeRange(s, e);
// //     final List<Map<String, dynamic>> segItems = List<Map<String, dynamic>>.from(seg['items'] as List);

// //     blocks.add(Positioned(
// //       left: left,
// //       top: top,
// //       width: width,
// //       height: height < 44 ? 44 : height,
// //       child: Material(
// //         color: Colors.transparent,
// //         child: InkWell(
// //           borderRadius: BorderRadius.circular(12),
// //           onTap: () => _openMergedSegmentSheet(seg),
// //           child: ClipRRect(
// //             borderRadius: BorderRadius.circular(12),
// //             child: Container(
// //               color: bg,
// //               padding: const EdgeInsets.all(10),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                 children: [
// //                   // top block
// //                   Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         customerName,
// //                         maxLines: 1,
// //                         overflow: TextOverflow.ellipsis,
// //                         style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
// //                       ),
// //                       Text(
// //                         moreCount > 0 ? '$headService + $moreCount more' : headService,
// //                         maxLines: 1,
// //                         overflow: TextOverflow.ellipsis,
// //                         style: const TextStyle(color: Colors.black87),
// //                       ),
// //                       if (priceText.isNotEmpty)
// //                         Text(priceText, style: const TextStyle(color: Colors.black87,)),
// //                     ],
// //                   ),
// //                   // bottom row
// //                   Column(
// //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                     children: [
// //                       Text(timeRange, style: const TextStyle(color: Colors.black87,fontSize: 10)),
// //                       Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87,fontSize: 10)),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     ));
// //   }

// //   return blocks;
// // }

// //   // Show bottom sheet with appointment details and actions
// // void _openAppointmentSheet(Map<String, dynamic> booking, Map<String, dynamic>? item) {
// //   showModalBottomSheet(
// //     context: context,
// //     isScrollControlled: true,
// //     backgroundColor: Colors.white,
// //     shape: const RoundedRectangleBorder(
// //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
// //     ),
// //     builder: (ctx) {
// //       return StatefulBuilder(
// //         builder: (context, setModalState) {
// //           final List items = (booking['items'] as List?) ?? const [];
// //           final Map? useItem = item ?? (items.isNotEmpty ? items.first as Map : null);

// //           final String services = useItem != null
// //               ? (useItem['branchService']?['displayName']?.toString() ?? '')
// //               : items
// //                   .map((e) => (e as Map)['branchService']?['displayName']?.toString() ?? '')
// //                   .where((s) => s.isNotEmpty)
// //                   .join(', ');

// //           final start = _parseLocal(useItem?['startAt']?.toString()) ?? _parseLocal(booking['startAt']);
// //           final end = _parseLocal(useItem?['endAt']?.toString()) ?? _parseLocal(booking['endAt']);
// //           final timeStr = start != null && end != null
// //               ? "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}"
// //               : '';

// //           final String statusUpper = (booking['status'] ?? '').toString().toUpperCase();
// //           final bool isPending = statusUpper == 'PENDING';

// //           final stylist = useItem?['assignedUserBranch']?['user']?['firstName'] ?? 'N/A';
// //           final duration = useItem?['durationMin'] != null ? '${useItem!['durationMin']} min' : '';
// //           final priceMinor = useItem?['branchService']?['priceMinor'];
// //           final price = priceMinor != null ? '₹$priceMinor' : '';

// //           // Separate loading states
// //           bool loadingConfirm = false;
// //           bool loadingCancel = false;

// //           Future<void> onConfirm() async {
// //             if (selectedBranchId == null) return;
// //             setModalState(() => loadingConfirm = true);
// //             final resp = await ApiService().confirmAppointment(
// //               branchId: selectedBranchId!,
// //               appointmentId: booking['id'] as int,
// //             );
// //             setModalState(() => loadingConfirm = false);

// //             if (resp['success'] == true) {
// //               Navigator.of(context).pop();
// //               getBookingsByDate(selectedBranchId!, selectedDate);
// //               ScaffoldMessenger.of(context).showSnackBar(
// //                 SnackBar(content: Text(resp['message']?.toString() ?? 'Confirmed')),
// //               );
// //             } else {
// //               ScaffoldMessenger.of(context).showSnackBar(
// //                 SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to confirm')),
// //               );
// //             }
// //           }

// //           Future<void> onCancel() async {
// //             if (selectedBranchId == null) return;
// //             setModalState(() => loadingCancel = true);
// //             final resp = await ApiService().cancelAppointment(
// //               branchId: selectedBranchId!,
// //               appointmentId: booking['id'] as int,
// //             );
// //             setModalState(() => loadingCancel = false);

// //             if (resp['success'] == true) {
// //               Navigator.of(context).pop();
// //               getBookingsByDate(selectedBranchId!, selectedDate);
// //               ScaffoldMessenger.of(context).showSnackBar(
// //                 SnackBar(content: Text(resp['message']?.toString() ?? 'Cancelled')),
// //               );
// //             } else {
// //               ScaffoldMessenger.of(context).showSnackBar(
// //                 SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to cancel')),
// //               );
// //             }
// //           }

// //           return FractionallySizedBox(
// //             heightFactor: 0.4,
// //             child: Padding(
// //               padding: const EdgeInsets.all(16.0),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: Text(
// //                           services.isEmpty ? 'Appointment' : services,
// //                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
// //                           overflow: TextOverflow.ellipsis,
// //                         ),
// //                       ),
// //                       IconButton(
// //                         icon: const Icon(Icons.close),
// //                         onPressed: () => Navigator.pop(context),
// //                       ),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 4),
// //                   if (timeStr.isNotEmpty)
// //                     Text(timeStr, style: const TextStyle(color: Colors.black54)),
// //                   const SizedBox(height: 4),
// //                   Text('Status: $statusUpper', style: const TextStyle(color: Colors.black54)),
// //                   const SizedBox(height: 4),
// //                   Text('Stylist: $stylist', style: const TextStyle(color: Colors.black54)),
// //                   const SizedBox(height: 4),
// //                   if (duration.isNotEmpty)
// //                     Text('Duration: $duration', style: const TextStyle(color: Colors.black54)),
// //                   const SizedBox(height: 4),
// //                   if (price.isNotEmpty)
// //                     Text('Price: $price', style: const TextStyle(color: Colors.black54)),
// //                   const Spacer(),
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: ElevatedButton(
// //                           onPressed: (loadingConfirm || !isPending) ? null : onConfirm,
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: Colors.blue,
// //                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                           ),
// //                           child: loadingConfirm
// //                               ? const SizedBox(
// //                                   height: 18,
// //                                   width: 18,
// //                                   child: CircularProgressIndicator(
// //                                     strokeWidth: 2,
// //                                     color: Colors.white,
// //                                   ),
// //                                 )
// //                               : const Text('Confirm'),
// //                         ),
// //                       ),
// //                       const SizedBox(width: 10),
// //                       Expanded(
// //                         child: ElevatedButton(
// //                           onPressed: (loadingCancel || !isPending) ? null : onCancel,
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: Colors.red,
// //                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                           ),
// //                           child: loadingCancel
// //                               ? const SizedBox(
// //                                   height: 18,
// //                                   width: 18,
// //                                   child: CircularProgressIndicator(
// //                                     strokeWidth: 2,
// //                                     color: Colors.white,
// //                                   ),
// //                                 )
// //                               : const Text('Cancel'),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 10),
// //                   SizedBox(
// //                     width: double.infinity,
// //                     child: OutlinedButton(
// //                       onPressed: () => Navigator.pop(context),
// //                       style: OutlinedButton.styleFrom(
// //                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                       ),
// //                       child: const Text('Close'),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           );
// //         },
// //       );
// //     },
// //   );
// // }

// //   // Function to handle branch selection
// //   void onBranchChanged(int branchId, int salonId) {
// //     setState(() {
// //       selectedBranchId = branchId;
// //       selectedSalonId = salonId;
// //     });

// //     // Fetch team members for the selected branch
// //     getTeamMembers(branchId);

// //     // Fetch bookings for the selected branch and date
// //     getBookingsByDate(branchId, selectedDate);
// //   }

// //   // Function to handle date change (previous and next)
// //   void changeDate(bool isNext) {
// //     setState(() {
// //       if (isNext) {
// //         selectedDate = selectedDate.add(Duration(days: 1)); // Move to the next day
// //       } else {
// //         selectedDate = selectedDate.subtract(Duration(days: 1)); // Move to the previous day
// //       }
// //     });

// //     // Fetch bookings for the updated date
// //     if (selectedBranchId != null) {
// //       getBookingsByDate(selectedBranchId!, selectedDate);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text('Bookings'),
// //         centerTitle: true,
// //         actions: [
// //           Padding(
// //             padding: const EdgeInsets.only(right: 16.0),
// //             child: TextButton(
// //               onPressed: () async {
// //                 if (selectedBranchId == null || selectedSalonId == null) {
// //                   ScaffoldMessenger.of(context).showSnackBar(
// //                     const SnackBar(content: Text('Please select a branch')),
// //                   );
// //                   return;
// //                 }
// //                 final result = await Navigator.push(
// //                   context,
// //                   MaterialPageRoute(
// //                     builder: (_) => AddBookingScreen(
// //                       salonId: selectedSalonId,
// //                       branchId: selectedBranchId,
// //                     ),
// //                   ),
// //                 );

// //                 if (result != null && selectedBranchId != null) {
// //                   getBookingsByDate(selectedBranchId!, selectedDate);
// //                 }
// //               },
// //               style: TextButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.white,
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //               ),
// //               child: Row(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: const [
// //                   Icon(Icons.add, size: 18),
// //                   SizedBox(width: 6),
// //                   Text('Add Booking'),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           Padding(
// //         padding: const EdgeInsets.all(8.0),
// //         child: salons.isEmpty
// //             ? isLoading
// //                 ? Center(child: CircularProgressIndicator()) // Show loader while fetching data
// //                 : Text("Please select a branch") // Show message when no data
// //             : Container(
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(10),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Colors.grey.withOpacity(0.2),
// //                       spreadRadius: 1,
// //                       blurRadius: 5,
// //                       offset: Offset(0, 3), // changes position of shadow
// //                     ),
// //                   ],
// //                 ),
// //                 child: DropdownButtonFormField<int>(
// //                   hint: Text("Select Salon Branch", style: TextStyle(fontWeight: FontWeight.w600)),
// //                   value: selectedBranchId,
// //                   onChanged: (newValue) {
// //                     if (newValue != null) {
// //                       final salon = salons.firstWhere((s) =>
// //                           (s['branches'] as List).any((b) => b['id'] == newValue));
// //                       final branch = (salon['branches'] as List)
// //                           .firstWhere((b) => b['id'] == newValue);
// //                       selectedBranch = {
// //                         'salonId': salon['id'],
// //                         'branchId': branch['id'],
// //                         'branchName': branch['name'],
// //                       };

// //                       onBranchChanged(branch['id'], salon['id']);  // Call the function to fetch team members and bookings
// //                     }
// //                   },
// //                   items: salons.expand((salon) {
// //                     final branches = salon['branches'] as List;
// //                     return branches.map<DropdownMenuItem<int>>((branch) {
// //                       return DropdownMenuItem(
// //                         value: branch['id'],
// //                         child: Text(branch['name']),
// //                       );
// //                     }).toList();
// //                   }).toList(),
// //                 ),
// //               ),
// //       ),
// //           const SizedBox(height: 16),
// // // Status counts display in 4 boxes with horizontal scroll
// // SingleChildScrollView(
// //   scrollDirection: Axis.horizontal,
// //   child: Row(
// //     children: [
// //       _statusBox('Pending', pendingCount, Colors.orange),
// //       _statusBox('Cancelled', cancelledCount, Colors.red),
// //       _statusBox('Completed', completedCount, Colors.green),
// //       _statusBox('Confirmed', confirmedCount, Colors.blue),
// //     ],
// //   ),
// // ),
// // const SizedBox(height: 16),
// // // Date selection and navigation
// // Row(
// //   children: [
// //     // Fixed left arrow icon
// //     IconButton(
// //       icon: Icon(Icons.chevron_left),
// //       onPressed: () => changeDate(false), // Previous date
// //     ),

// //     // Wrap the date selection part with Flexible to avoid overflow
// //     Flexible(
// //       child: SingleChildScrollView(
// //         scrollDirection: Axis.horizontal,
// //         child: Row(
// //           children: List.generate(7, (index) {
// //             // Ensure the date range starts from today, making it the center
// //             DateTime date = selectedDate.add(Duration(days: index - 3)); // Adjust to show a week range
// //             bool isSelected = isSameDay(date, selectedDate); // Check if this date is selected

// //             return Padding(
// //               padding: const EdgeInsets.symmetric(horizontal: 8.0),
// //               child: GestureDetector(
// //                 onTap: () {
// //                   setState(() {
// //                     selectedDate = date; // Set the selected date
// //                   });
// //                   if (selectedBranchId != null) {
// //                     getBookingsByDate(selectedBranchId!, selectedDate);
// //                   }
// //                 },
// //                 child: Container(
// //                   padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
// //                   decoration: BoxDecoration(
// //                     color: isSelected ? Colors.blue : Colors.grey[200],
// //                     borderRadius: BorderRadius.circular(8),
// //                   ),
// //                   child: Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       Text(
// //                         DateFormat('EEE').format(date), // Day of the week
// //                         style: TextStyle(
// //                           fontWeight: FontWeight.bold,
// //                           color: isSelected ? Colors.white : Colors.black,
// //                         ),
// //                       ),
// //                       Text(
// //                         DateFormat('d').format(date), // Day number
// //                         style: TextStyle(
// //                           color: isSelected ? Colors.white : Colors.black,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             );
// //           }),
// //         ),
// //       ),
// //     ),

// //     // Fixed right arrow icon
// //     IconButton(
// //       icon: Icon(Icons.chevron_right),
// //       onPressed: () => changeDate(true), // Next date
// //     ),
// //   ],
// // ),

// // const SizedBox(height: 16),
// // // Timetable grid (fixed time column + scrollable team columns)
// // SizedBox(height: 8),
// // Expanded(
// //   child: Container(
// //     color: const Color(0xFFF7F4F1),
// //     child: Column(
// //       children: [
// //         // Header row: Time + horizontally scrollable member headers
// //         Row(
// //           children: [
// //             Container(
// //               width: 100,
// //               height: 44,
// //               alignment: Alignment.center,
// //               decoration: BoxDecoration(
// //                 color: Colors.blueGrey.shade600,
// //                 border: Border.all(color: Colors.grey.shade300),
// //               ),
// //               child: const Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
// //             ),
// //             Expanded(
// //               child: SingleChildScrollView(
// //                 controller: _headerHController,
// //                 scrollDirection: Axis.horizontal,
// //                 primary: false,
// //                 physics: const ClampingScrollPhysics(),
// //                 child: Row(
// //                   children: List.generate(teamMembers.length, (index) {
// //                     final m = teamMembers[index];
// //                     return Container(
// //                       width: 140,
// //                       height: 44,
// //                       alignment: Alignment.centerLeft,
// //                       padding: const EdgeInsets.symmetric(horizontal: 12),
// //                       decoration: BoxDecoration(
// //                         color: Colors.grey.shade300,
// //                         border: Border(
// //                           top: BorderSide(color: Colors.grey.shade300),
// //                           right: BorderSide(color: Colors.grey.shade300),
// //                           bottom: BorderSide(color: Colors.grey.shade300),
// //                         ),
// //                       ),
// //                       child: Text(
// //                         '${m['firstName']} ${m['lastName']}',
// //                         style: const TextStyle(fontWeight: FontWeight.w600),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     );
// //                   }),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //         const Divider(height: 1, thickness: 1),
// //         // Body: left time column synced with grid rows on the right
// //         Expanded(
// //           child: Row(
// //             children: [
// //               // Time labels column (synced vertically)
// //               SizedBox(
// //                 width: 100,
// //                 child: timeSlots.isEmpty
// //                     ? const SizedBox()
// //                     : NotificationListener<ScrollNotification>(
// //                         onNotification: (notif) {
// //                           if (notif.metrics.axis == Axis.vertical) {
// //                             if (!_syncingV && _gridVController.hasClients) {
// //                               _syncingV = true;
// //                               final off = _timeColumnVController.offset;
// //                               if ((_gridVController.offset - off).abs() > 0.5) {
// //                                 _gridVController.jumpTo(off);
// //                               }
// //                               _syncingV = false;
// //                             }
// //                           }
// //                           return false;
// //                         },
// //                         child: ListView.builder(
// //                           controller: _timeColumnVController,
// //                           primary: false,
// //                           physics: const ClampingScrollPhysics(),
// //                           dragStartBehavior: DragStartBehavior.start,
// //                           itemExtent: 44,
// //                           itemCount: timeSlots.length,
// //                           itemBuilder: (context, i) {
// //                             return Container(
// //                               alignment: Alignment.centerLeft,
// //                               padding: const EdgeInsets.symmetric(horizontal: 8),
// //                               decoration: BoxDecoration(
// //                                 color: i % 2 == 0 ? Colors.white : const Color(0xFFF0F0F0),
// //                                 border: Border(
// //                                   right: BorderSide(color: Colors.grey.shade300),
// //                                   bottom: BorderSide(color: Colors.grey.shade300),
// //                                 ),
// //                               ),
// //                               child: Text(
// //                                 timeSlots[i],
// //                                 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
// //                               ),
// //                             );
// //                           },
// //                         ),
// //                       ),
// //               ),
// //               // Grid body (scrolls both ways)
// //               Expanded(
// //                 child: SingleChildScrollView(
// //                   controller: _gridHController,
// //                   scrollDirection: Axis.horizontal,
// //                   primary: false,
// //                   physics: const ClampingScrollPhysics(),
// //                   child: SizedBox(
// //                     width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
// //                     child: timeSlots.isEmpty
// //                         ? const Center(child: Text('No time slots available'))
// //                         : NotificationListener<ScrollNotification>(
// //                             onNotification: (notif) {
// //                               if (notif.metrics.axis == Axis.vertical) {
// //                                 if (!_syncingV && _timeColumnVController.hasClients) {
// //                                   _syncingV = true;
// //                                   final off = _gridVController.offset;
// //                                   if ((_timeColumnVController.offset - off).abs() > 0.5) {
// //                                     _timeColumnVController.jumpTo(off);
// //                                   }
// //                                   _syncingV = false;
// //                                 }
// //                               }
// //                               return false;
// //                             },
// //                             child: SingleChildScrollView(
// //                               controller: _gridVController,
// //                               primary: false,
// //                               physics: const ClampingScrollPhysics(),
// //                               child: SizedBox(
// //                                 width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
// //                                 height: timeSlots.length * _rowHeight,
// //                                 child: Stack(
// //                                   children: [
// //                                     // Background grid
// //                                     ..._buildBackgroundGrid(),
// //                                     // Booking overlays
// //                                     ..._buildBookingBlocks(),
// //                                   ],
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ],
// //     ),
// //   ),
// // ),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     _timeColumnVController.dispose();
// //     _gridVController.dispose();
// //     _headerHController.dispose();
// //     _gridHController.dispose();
// //     super.dispose();
// //   }
// //   // Helper function to create status box with count
// //   // Helper function to create status box with count and custom color
// // Widget _statusBox(String title, int count, Color color) {
// //   return Container(
// //     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// //     margin: const EdgeInsets.only(right: 8),
// //     decoration: BoxDecoration(
// //       color: color.withOpacity(0.12),
// //       borderRadius: BorderRadius.circular(12),
// //       border: Border.all(color: color.withOpacity(0.35)),
// //     ),
// //     child: Column(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: [
// //         Text(
// //           title,
// //           style: TextStyle(color: color, fontWeight: FontWeight.w600),
// //         ),
// //         const SizedBox(height: 4),
// //         Text(
// //           '$count',
// //           style: TextStyle(color: color, fontWeight: FontWeight.bold),
// //         ),
// //       ],
// //     ),
// //   );
// // }}

// //Md
// import 'package:flutter/material.dart';
// import 'package:flutter/gestures.dart';
// import 'package:intl/intl.dart';  // For date formatting
// import '../utils/api_service.dart';  // Import the correct api_service.dart file
// import 'AddBookings.dart';  // Add Booking screen

// class BookingsScreen extends StatefulWidget {
//   @override
//   _BookingsScreenState createState() => _BookingsScreenState();
// }

// class _BookingsScreenState extends State<BookingsScreen> {
//   List<Map<String, dynamic>> salons = [];
//   bool isLoading = true;
//   int? selectedSalonId;
//   int? selectedBranchId;  // Store branchId of the selected branch
//   Map<String, dynamic>? selectedBranch;  // Store branch details
//   List<Map<String, dynamic>> bookings = [];
//   DateTime selectedDate = DateTime.now();  // Initial date is today
//   List<Map<String, dynamic>> teamMembers = []; // Store team members for the selected branch
//   List<String> timeSlots = []; // Declare the timeSlots list
//   // Branch working hours for rendering grid/blocks
//   String? _branchStartTimeStr; // e.g. "08:00:00"
//   String? _branchEndTimeStr;   // e.g. "20:00:00"

//   // Layout constants for the grid
//   static const double _rowHeight = 44.0;   // 15-min slot height
//   static const double _colWidth = 140.0;   // staff column width

//   int pendingCount = 0;
//   int cancelledCount = 0;
//   int completedCount = 0;
//   int confirmedCount = 0;

//   // Timetable scroll controllers
//   final ScrollController _timeColumnVController = ScrollController();
//   final ScrollController _gridVController = ScrollController();
//   final ScrollController _headerHController = ScrollController();
//   final ScrollController _gridHController = ScrollController();
//   bool _syncingV = false;
//   bool _syncingH = false;

//   @override
//   void initState() {
//     super.initState();
//     getSalonListApi();
//     // Sync vertical scroll between time column and grid body
//     _timeColumnVController.addListener(() {
//       if (_syncingV) return;
//       _syncingV = true;
//       if (_gridVController.hasClients) {
//         final off = _timeColumnVController.offset;
//         if ((_gridVController.offset - off).abs() > 0.5) {
//           _gridVController.jumpTo(off);
//         }
//       }
//       _syncingV = false;
//     });
//     _gridVController.addListener(() {
//       if (_syncingV) return;
//       _syncingV = true;
//       if (_timeColumnVController.hasClients) {
//         final off = _gridVController.offset;
//         if ((_timeColumnVController.offset - off).abs() > 0.5) {
//           _timeColumnVController.jumpTo(off);
//         }
//       }
//       _syncingV = false;
//     });
//     // Sync horizontal scroll between header and grid body
//     _headerHController.addListener(() {
//       if (_syncingH) return;
//       _syncingH = true;
//       if (_gridHController.hasClients) {
//         final off = _headerHController.offset;
//         if ((_gridHController.offset - off).abs() > 0.5) {
//           _gridHController.jumpTo(off);
//         }
//       }
//       _syncingH = false;
//     });
//     _gridHController.addListener(() {
//       if (_syncingH) return;
//       _syncingH = true;
//       if (_headerHController.hasClients) {
//         final off = _gridHController.offset;
//         if ((_headerHController.offset - off).abs() > 0.5) {
//           _headerHController.jumpTo(off);
//         }
//       }
//       _syncingH = false;
//     });

//     // Ensure initial sync after first layout
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_timeColumnVController.hasClients && _gridVController.hasClients) {
//         _gridVController.jumpTo(_timeColumnVController.offset);
//       }
//       if (_headerHController.hasClients && _gridHController.hasClients) {
//         _gridHController.jumpTo(_headerHController.offset);
//       }
//     });
//   }

//   bool isSameDay(DateTime date1, DateTime date2) {
//     return date1.year == date2.year &&
//         date1.month == date2.month &&
//         date1.day == date2.day;
//   }

//   Future<void> getSalonListApi() async {
//     try {
//       final response = await ApiService().getSalonListApi(); // Call the method from ApiService

//       if (response['success'] == true) {
//         List salonsList = response['data'];
//         setState(() {
//           salons = salonsList.map<Map<String, dynamic>>((salon) {
//             return {
//               'id': salon['id'],
//               'name': salon['name'],
//               'branches': salon['branches'],
//             };
//           }).toList();  // Ensure this returns the expected List<Map<String, dynamic>>
//           isLoading = false; // Stop loading after data is fetched
//         });
//       } else {
//         throw Exception("Failed to fetch salon list");
//       }
//     } catch (e) {
//       print("Error fetching salon list: $e");
//       setState(() {
//         isLoading = false; // Stop loading in case of an error
//       });
//     }
//   }

//   List<String> generateTimeSlots(String startTime, String endTime) {
//     List<String> timeSlots = [];

//     // Convert startTime and endTime to DateTime objects
//     DateTime start = DateFormat("HH:mm:ss").parse(startTime);
//     DateTime end = DateFormat("HH:mm:ss").parse(endTime);

//     // Exclude the last 15 minutes from the range
//     DateTime effectiveEnd = end.subtract(const Duration(minutes: 15));

//     // Add time slots up to and including effectiveEnd
//     while (start.isBefore(effectiveEnd) || start.isAtSameMomentAs(effectiveEnd)) {
//       timeSlots.add(DateFormat("h:mm a").format(start));
//       start = start.add(const Duration(minutes: 15));
//     }

//     return timeSlots;
//   }

//   Future<void> getBookingsByDate(int branchId, DateTime date) async {
//     try {
//       String formattedDate = DateFormat('yyyy-MM-dd').format(date); // Format date
//       ApiService apiService = ApiService();

//       final response = await apiService.fetchAppointments(branchId, formattedDate);

//       if (response != null && response['success'] == true && response['data'] != null) {
//         List<dynamic> appointments = response['data'];

//         // Try to fetch branch working hours from the payload (fallback-safe)
//         String startTime = '08:00:00';
//         String endTime = '20:00:00';
//         if (appointments.isNotEmpty) {
//           final b = appointments.first;
//           if (b['branch'] != null) {
//             startTime = (b['branch']['startTime'] ?? startTime).toString();
//             endTime = (b['branch']['endTime'] ?? endTime).toString();
//           }
//         }

//         // Generate time slots and populate the timeSlots list
//         setState(() {
//           timeSlots = generateTimeSlots(startTime, endTime); // Populate timeSlots
//           _branchStartTimeStr = startTime;
//           _branchEndTimeStr = endTime;
//         });

//         setState(() {
//           bookings = List<Map<String, dynamic>>.from(appointments);
//         });
//         _recomputeStatusCounts();
//       } else {
//         setState(() {
//           bookings = [];
//           pendingCount = 0;
//           cancelledCount = 0;
//           completedCount = 0;
//           confirmedCount = 0;
//         });
//         print('No appointments available for this date.');
//       }
//     } catch (e) {
//       print('Error fetching bookings: $e');
//     }
//   }

//   // Count status by items (so counts match blocks in grid)
//   void _recomputeStatusCounts() {
//     int sumStatus(String status) {
//       int t = 0;
//       for (final b in bookings) {
//         final s = (b['status'] ?? '').toString().toUpperCase();
//         if (s == status) {
//           final items = (b['items'] as List?) ?? const [];
//           t += items.isNotEmpty ? items.length : 1;
//         }
//       }
//       return t;
//     }

//     setState(() {
//       pendingCount = sumStatus('PENDING');
//       cancelledCount = sumStatus('CANCELLED');
//       completedCount = sumStatus('COMPLETED');
//       confirmedCount = sumStatus('CONFIRMED');
//     });
//   }

//   // Fetch team members for the selected branch
//   Future<void> getTeamMembers(int branchId) async {
//     try {
//       final response = await ApiService.getTeamMembers(branchId);

//       // Check if the response is valid and contains team members data
//       if (response != null && response['success'] == true && response['data'] != null && response['data'].isNotEmpty) {
//         setState(() {
//           teamMembers = List<Map<String, dynamic>>.from(response['data']);
//         });
//       } else {
//         setState(() {
//           teamMembers = []; // Clear the list if no data
//         });
//         print('No team members available for this branch.');
//       }
//     } catch (e) {
//       print('Error fetching team members: $e');
//     }
//   }

//   // Combine selected date with a HH:mm[:ss] string to a local DateTime
//   DateTime _combineDateAndTime(DateTime date, String timeStr) {
//     int h = 0, m = 0, s = 0;
//     try {
//       final parts = timeStr.split(':');
//       if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
//       if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
//       if (parts.length > 2) s = int.tryParse(parts[2]) ?? 0;
//     } catch (_) {}
//     return DateTime(date.year, date.month, date.day, h, m, s);
//   }

//   // Safely parse ISO string to local DateTime
//   DateTime? _parseLocal(String? iso) {
//     if (iso == null) return null;
//     try {
//       return DateTime.parse(iso).toLocal();
//     } catch (_) {
//       return null;
//     }
//   }

//   // Find staff column index for a booking item by matching user id
//   int _findMemberColumnForItem(Map<String, dynamic> item) {
//     final dynamic userId = item['assignedUserBranch']?['user']?['id'] ??
//         item['assignedUserBranch']?['userId'] ??
//         item['user']?['id'] ??
//         item['userId'];
//     if (userId == null) return -1;
//     final idx = teamMembers.indexWhere((m) {
//       final mid = m['id'] ?? m['user']?['id'] ?? m['userId'];
//       return mid == userId;
//     });
//     return idx;
//   }

//   // Background grid rows + vertical separators for the timetable
//   List<Widget> _buildBackgroundGrid() {
//     final List<Widget> widgets = [];
//     // Row backgrounds
//     for (int r = 0; r < timeSlots.length; r++) {
//       widgets.add(Positioned(
//         top: r * _rowHeight,
//         left: 0,
//         right: 0,
//         height: _rowHeight,
//         child: Container(
//           decoration: BoxDecoration(
//             color: r % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
//             border: Border(
//               bottom: BorderSide(color: Colors.grey.shade300),
//             ),
//           ),
//         ),
//       ));
//     }
//     // Vertical separators between staff columns
//     for (int c = 1; c < (teamMembers.isEmpty ? 1 : teamMembers.length); c++) {
//       widgets.add(Positioned(
//         top: 0,
//         bottom: 0,
//         left: c * _colWidth - 1,
//         width: 1,
//         child: Container(color: Colors.grey.shade300),
//       ));
//     }
//     return widgets;
//   }

//   String _fmtTimeRange(DateTime s, DateTime e) {
//     final f = DateFormat('h:mma');
//     return '${f.format(s).toLowerCase()} - ${f.format(e).toLowerCase()}';
//   }

//   List<Map<String, dynamic>> _collectMergedSegments() {
//     if (bookings.isEmpty || _branchStartTimeStr == null || _branchEndTimeStr == null) {
//       return const [];
//     }

//     int? _toInt(dynamic v) {
//       if (v is int) return v;
//       if (v is num) return v.toInt();
//       if (v is String) return int.tryParse(v);
//       return null;
//     }

//     final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
//     final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

//     // Step 1: flatten items
//     final List<Map<String, dynamic>> flat = [];
//     for (final booking in bookings) {
//       final status = (booking['status'] ?? '').toString().toUpperCase();
//       final customer = booking['user'] as Map<String, dynamic>?;
//       final customerName = [
//         customer?['firstName']?.toString() ?? '',
//         customer?['lastName']?.toString() ?? ''
//       ].where((s) => s.isNotEmpty).join(' ').trim();

//       final items = (booking['items'] as List?) ?? const [];
//       for (final raw in items) {
//         final item = Map<String, dynamic>.from(raw as Map);

//         final int col = _findMemberColumnForItem(item);
//         if (col < 0) continue;

//         final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
//             item['assignedUserBranch']?['userId'] ??
//             item['user']?['id'] ??
//             item['userId'];

//         DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
//         DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
//         if (s == null || e == null) continue;

//         // clamp
//         if (s.isBefore(dayStart)) s = dayStart;
//         if (e.isAfter(dayEnd)) e = dayEnd;
//         if (!e.isAfter(s)) continue;

//         flat.add({
//           'booking': booking,
//           'item': item,
//           'appointmentId': booking['id'], // keep per-item appointment id
//           'col': col,
//           'customerId': booking['user']?['id'] ?? booking['userId'],
//           'customerName': customerName.isEmpty ? 'Customer' : customerName,
//           'staffUserId': staffUserId,
//           'status': status,
//           'start': s,
//           'end': e,
//           'service': item['branchService']?['displayName']?.toString() ?? 'Service',
//           'priceMinor': _toInt(item['branchService']?['priceMinor']),
//         });
//       }
//     }

//     if (flat.isEmpty) return const [];

//     // Step 2: group by col + customer + staff + status
//     final Map<String, List<Map<String, dynamic>>> groups = {};
//     for (final it in flat) {
//       final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
//       (groups[key] ??= <Map<String, dynamic>>[]).add(it);
//     }

//     // Step 3: within each group, sort by start and coalesce consecutive items
//     final List<Map<String, dynamic>> segments = [];
//     for (final g in groups.values) {
//       g.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
//       if (g.isEmpty) continue;

//       // seed
//       int col = g.first['col'] as int;
//       String status = g.first['status'] as String;
//       String customerName = g.first['customerName'] as String;
//       DateTime segStart = g.first['start'] as DateTime;
//       DateTime segEnd   = g.first['end'] as DateTime;
//       final List<String> services = [g.first['service'] as String];
//       int? priceTotal = _toInt(g.first['priceMinor']);
//       final List<Map<String, dynamic>> segItems = [
//         {
//           'booking': g.first['booking'],
//           'item': g.first['item'],
//           'appointmentId': g.first['appointmentId'],
//           'start': segStart,
//           'end': segEnd,
//           'service': g.first['service'],
//           'priceMinor': g.first['priceMinor'],
//         }
//       ];

//       for (int i = 1; i < g.length; i++) {
//         final curr = g[i];
//         final s = curr['start'] as DateTime;
//         final e = curr['end'] as DateTime;

//         // merge only if exactly consecutive
//         if (s.isAtSameMomentAs(segEnd)) {
//           segEnd = e;
//           services.add(curr['service'] as String);
//           final p = _toInt(curr['priceMinor']);
//           if (p != null) priceTotal = (priceTotal ?? 0) + p;

//           segItems.add({
//             'booking': curr['booking'],
//             'item': curr['item'],
//             'appointmentId': curr['appointmentId'],
//             'start': s,
//             'end': e,
//             'service': curr['service'],
//             'priceMinor': curr['priceMinor'],
//           });
//         } else {
//           // flush
//           segments.add({
//             'col': col,
//             'status': status,
//             'customerName': customerName,
//             'start': segStart,
//             'end': segEnd,
//             'services': List<String>.from(services),
//             'priceTotal': priceTotal,
//             'items': List<Map<String, dynamic>>.from(segItems),
//           });

//           // start new
//           col = curr['col'] as int;
//           status = curr['status'] as String;
//           customerName = curr['customerName'] as String;
//           segStart = s;
//           segEnd = e;
//           services
//             ..clear()
//             ..add(curr['service'] as String);
//           priceTotal = _toInt(curr['priceMinor']);
//           segItems
//             ..clear()
//             ..add({
//               'booking': curr['booking'],
//               'item': curr['item'],
//               'appointmentId': curr['appointmentId'],
//               'start': s,
//               'end': e,
//               'service': curr['service'],
//               'priceMinor': curr['priceMinor'],
//             });
//         }
//       }

//       // final flush
//       segments.add({
//         'col': col,
//         'status': status,
//         'customerName': customerName,
//         'start': segStart,
//         'end': segEnd,
//         'services': List<String>.from(services),
//         'priceTotal': priceTotal,
//         'items': List<Map<String, dynamic>>.from(segItems),
//       });
//     }

//     return segments;
//   }
//   // Show bottom sheet for a merged segment
//   void _openMergedSegmentSheet(Map<String, dynamic> seg) {
//   final DateTime s = seg['start'] as DateTime;
//   final DateTime e = seg['end'] as DateTime;
//   final String status = (seg['status'] as String).toUpperCase();
//   final String customerName = seg['customerName'] as String? ?? 'Customer';
//   final int? priceTotal = seg['priceTotal'] as int?;
//   final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

//   // Unique appointment IDs inside the block
//   final List<int> apptIds = items
//       .map((it) => (it['appointmentId'] as int?))
//       .where((id) => id != null)
//       .cast<int>()
//       .toSet()
//       .toList()
//     ..sort();

//   final String timeRange = _fmtTimeRange(s, e);

//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.white,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//     ),
//     builder: (ctx) {
//       bool loadingConfirm = false;
//       bool loadingStartAll = false;

//       Future<void> onConfirmAll() async {
//         if (selectedBranchId == null) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Please select a branch first.')),
//           );
//           return;
//         }
//         if (status != 'PENDING' || apptIds.isEmpty) return;

//         loadingConfirm = true;
//         (ctx as Element).markNeedsBuild();

//         int ok = 0, fail = 0;
//         for (final id in apptIds) {
//           try {
//             final resp = await ApiService().confirmAppointment(
//               branchId: selectedBranchId!,
//               appointmentId: id,
//             );
//             if (resp['success'] == true) {
//               ok++;
//             } else {
//               fail++;
//             }
//           } catch (_) {
//             fail++;
//           }
//         }

//         loadingConfirm = false;
//         (ctx as Element).markNeedsBuild();

//         Navigator.pop(context);
//         if (selectedBranchId != null) {
//           await getBookingsByDate(selectedBranchId!, selectedDate);
//         }

//         final msg = fail == 0
//             ? 'Confirmed $ok appointment(s).'
//             : 'Confirmed $ok, failed $fail.';
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//       }

//       Future<String?> _askOtp() async {
//         final controller = TextEditingController();
//         String? result;
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (dCtx) {
//             return AlertDialog(
//               title: const Text("Enter OTP"),
//               content: TextField(
//                 controller: controller,
//                 maxLength: 6,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   border: OutlineInputBorder(),
//                   hintText: "6-digit OTP",
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(dCtx);
//                   },
//                   child: const Text("Cancel"),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     final otp = controller.text.trim();
//                     if (otp.length != 6) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text("Enter valid 6-digit OTP")),
//                       );
//                       return;
//                     }
//                     result = otp;
//                     Navigator.pop(dCtx);
//                   },
//                   child: const Text("Submit"),
//                 ),
//               ],
//             );
//           },
//         );
//         return result;
//       }

//       Future<void> _startForIds(List<int> ids) async {
//         if (selectedBranchId == null || ids.isEmpty) return;
//         final otp = await _askOtp();
//         if (otp == null) return;

//         loadingStartAll = true;
//         (ctx as Element).markNeedsBuild();

//         int ok = 0, fail = 0;
//         for (final id in ids) {
//           try {
//             final resp = await ApiService.startAppointment(
//               branchId: selectedBranchId!,
//               appointmentId: id,
//               otp: otp,
//             );
//             if (resp['success'] == true) {
//               ok++;
//             } else {
//               fail++;
//             }
//           } catch (_) {
//             fail++;
//           }
//         }

//         loadingStartAll = false;
//         (ctx as Element).markNeedsBuild();

//         Navigator.pop(context);
//         await getBookingsByDate(selectedBranchId!, selectedDate);

//         final msg = fail == 0
//             ? 'Job started for $ok appointment(s).'
//             : 'Started $ok, failed $fail.';
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//       }

//       return FractionallySizedBox(
//         heightFactor: 0.60,
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
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
//               Text(timeRange, style: const TextStyle(color: Colors.black54)),
//               const SizedBox(height: 4),
//               Text('Status: $status', style: const TextStyle(color: Colors.black54)),
//               if (priceTotal != null) ...[
//                 const SizedBox(height: 4),
//                 Text('Total Price: ₹$priceTotal', style: const TextStyle(color: Colors.black87)),
//               ],
//               const SizedBox(height: 12),

//               // Services list
//               const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
//               const SizedBox(height: 6),
//               Expanded(
//                 child: ListView.separated(
//                   itemCount: items.length,
//                   separatorBuilder: (_, __) => const Divider(height: 1),
//                   itemBuilder: (context, i) {
//                     final it = items[i];
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
//                           // Quick “View” to open the single item sheet (shows Start Job too)
//                           // TextButton(
//                           //   onPressed: () {
//                           //     Navigator.pop(context);
//                           //     _openAppointmentSheet(
//                           //       it['booking'] as Map<String, dynamic>,
//                           //       it['item'] as Map<String, dynamic>,
//                           //     );
//                           //   },
//                           //   child: const Text('View'),
//                           // ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),

//               // Actions (bottom)
//               if (status == 'PENDING') ...[
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: loadingConfirm ? null : onConfirmAll,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                     ),
//                     child: loadingConfirm
//                         ? const SizedBox(
//                             height: 18, width: 18,
//                             child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                           )
//                         : Text(apptIds.length <= 1 ? 'Confirm' : 'Confirm All (${apptIds.length})'),
//                   ),
//                 ),
//               ] else if (status == 'CONFIRMED') ...[
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: loadingStartAll ? null : () => _startForIds(apptIds),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                     ),
//                     child: loadingStartAll
//                         ? const SizedBox(
//                             height: 18, width: 18,
//                             child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                           )
//                         : Text(apptIds.length <= 1 ? 'Start Job' : 'Start All (${apptIds.length})'),
//                   ),
//                 ),
//               ] else ...[
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: null,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                     ),
//                     child: Text(status),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }

// List<Widget> _buildBookingBlocks() {
//   if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

//   final startStr = _branchStartTimeStr ?? '08:00:00';
//   final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);

//   final merged = _collectMergedSegments();
//   final List<Widget> blocks = [];

//   for (final seg in merged) {
//     final int col = seg['col'] as int;
//     final String status = (seg['status'] as String).toUpperCase();
//     final DateTime s = seg['start'] as DateTime;
//     final DateTime e = seg['end'] as DateTime;
//     final int minutesFromStart = s.difference(dayStart).inMinutes;
//     final int totalMin = e.difference(s).inMinutes;

//     final double top = (minutesFromStart / 15.0) * _rowHeight;
//     final double height = (totalMin / 15.0) * _rowHeight; // seamless
//     final double left = col * _colWidth + 6;
//     final double width = _colWidth - 12;

//     Color bg = Colors.blue.shade300;         // CONFIRMED
//     if (status == 'PENDING')   bg = Colors.orange.shade300;
//     if (status == 'IN_PROGRESS') bg = Colors.green.shade300;
//     if (status == 'COMPLETED') bg = Colors.green.shade300;

//     final String customerName = seg['customerName'] as String? ?? 'Customer';
//     final List<String> services = List<String>.from(seg['services'] as List);
//     final int moreCount = (services.length > 1) ? services.length - 1 : 0;
//     final String headService = services.isNotEmpty ? services.first : 'Service';
//     final int? priceTotal = seg['priceTotal'] as int?;
//     final String priceText = priceTotal != null ? '₹$priceTotal' : '';
//     final String timeRange = _fmtTimeRange(s, e);

//     final List<Map<String, dynamic>> segItems =
//         List<Map<String, dynamic>>.from(seg['items'] as List);

//     blocks.add(Positioned(
//       left: left,
//       top: top,
//       width: width,
//       height: height < 44 ? 44 : height,
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () {
//             // ✅ If the block has a single underlying item, go straight to the per-appointment sheet
//             if (segItems.length == 1) {
//               final b = segItems.first['booking'] as Map<String, dynamic>;
//               final it = segItems.first['item'] as Map<String, dynamic>;
//               _openAppointmentSheet(b, it);
//             } else {
//               // Otherwise open merged sheet (now supports Start Job / Start All too)
//               _openMergedSegmentSheet(seg);
//             }
//           },
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: Container(
//               color: bg,
//               padding: const EdgeInsets.all(10),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         customerName,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
//                       ),
//                       Text(
//                         moreCount > 0 ? '$headService + $moreCount more' : headService,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(color: Colors.black87),
//                       ),
//                       if (priceText.isNotEmpty)
//                         Text(priceText, style: const TextStyle(color: Colors.black87)),
//                     ],
//                   ),
//                   Column(
//                     children: [
//                       Text(timeRange, style: const TextStyle(color: Colors.black87, fontSize: 10)),
//                       Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 10)),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     ));
//   }

//   return blocks;
// }

//   /// Per-appointment sheet:
//   /// - If PENDING: Confirm / Cancel
//   /// - After Confirm success: swaps to "Start Job"
//   /// - Start Job -> 6-digit OTP dialog -> startAppointment -> refresh & close
//   void _openAppointmentSheet(Map<String, dynamic> booking, Map<String, dynamic>? item) {
//     // Mutable state captured by StatefulBuilder
//     String statusUpper = (booking['status'] ?? '').toString().toUpperCase();
//     bool loadingConfirm = false;
//     bool loadingCancel = false;
//     bool loadingStart = false;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             final List items = (booking['items'] as List?) ?? const [];
//             final Map? useItem = item ?? (items.isNotEmpty ? items.first as Map : null);

//             final String services = useItem != null
//                 ? (useItem['branchService']?['displayName']?.toString() ?? '')
//                 : items
//                     .map((e) => (e as Map)['branchService']?['displayName']?.toString() ?? '')
//                     .where((s) => s.isNotEmpty)
//                     .join(', ');

//             final start = _parseLocal(useItem?['startAt']?.toString()) ?? _parseLocal(booking['startAt']);
//             final end = _parseLocal(useItem?['endAt']?.toString()) ?? _parseLocal(booking['endAt']);
//             final timeStr = start != null && end != null
//                 ? "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}"
//                 : '';

//             final bool isPending = statusUpper == 'PENDING';
//             final bool isConfirmed = statusUpper == 'CONFIRMED';

//             final stylist = useItem?['assignedUserBranch']?['user']?['firstName'] ?? 'N/A';
//             final duration = useItem?['durationMin'] != null ? '${useItem!['durationMin']} min' : '';
//             final priceMinor = useItem?['branchService']?['priceMinor'];
//             final price = priceMinor != null ? '₹$priceMinor' : '';

//             Future<void> onConfirm() async {
//               if (selectedBranchId == null) return;
//               setModalState(() => loadingConfirm = true);
//               final resp = await ApiService().confirmAppointment(
//                 branchId: selectedBranchId!,
//                 appointmentId: booking['id'] as int,
//               );
//               setModalState(() => loadingConfirm = false);

//               if (resp['success'] == true) {
//                 // Update the local status from API response if present
//                 final newStatus = (resp['data']?['status'] ?? 'CONFIRMED').toString().toUpperCase();
//                 setModalState(() {
//                   statusUpper = newStatus;
//                 });
//                 // Refresh grid
//                 if (selectedBranchId != null) {
//                   await getBookingsByDate(selectedBranchId!, selectedDate);
//                 }
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text(resp['message']?.toString() ?? 'Confirmed')),
//                 );
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to confirm')),
//                 );
//               }
//             }

//             Future<void> onStartJob() async {
//               if (selectedBranchId == null) return;

//               final otpController = TextEditingController();

//               await showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (dialogCtx) {
//                   return StatefulBuilder(
//                     builder: (dialogCtx, setDialogState) {
//                       return AlertDialog(
//                         title: const Text("Enter OTP"),
//                         content: TextField(
//                           controller: otpController,
//                           maxLength: 6,
//                           keyboardType: TextInputType.number,
//                           decoration: const InputDecoration(
//                             border: OutlineInputBorder(),
//                             hintText: "6-digit OTP",
//                           ),
//                         ),
//                         actions: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(dialogCtx),
//                             child: const Text("Cancel"),
//                           ),
//                           ElevatedButton(
//                             onPressed: () async {
//                               final otp = otpController.text.trim();
//                               if (otp.length != 6) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   const SnackBar(content: Text("Enter valid 6-digit OTP")),
//                                 );
//                                 return;
//                               }
//                               // Start loading on main sheet button (optional)
//                               setModalState(() => loadingStart = true);
//                               Navigator.pop(dialogCtx); // close OTP dialog

//                               final resp = await ApiService.startAppointment(
//                                 branchId: selectedBranchId!,
//                                 appointmentId: booking['id'] as int,
//                                 otp: otp,
//                               );

//                               setModalState(() => loadingStart = false);

//                               if (resp['success'] == true) {
//                                 // Update local status from API response if provided
//                                 final newStatus = (resp['data']?['status'] ?? 'IN_PROGRESS').toString().toUpperCase();
//                                 setModalState(() {
//                                   statusUpper = newStatus;
//                                 });

//                                 // Refresh and close sheet
//                                 await getBookingsByDate(selectedBranchId!, selectedDate);
//                                 Navigator.of(context).pop(); // close sheet

//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(content: Text(resp['message']?.toString() ?? 'Job started')),
//                                 );
//                               } else {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to start job')),
//                                 );
//                               }
//                             },
//                             child: const Text("Submit"),
//                           ),
//                         ],
//                       );
//                     },
//                   );
//                 },
//               );
//             }

//             Future<void> onCancel() async {
//               if (selectedBranchId == null) return;
//               setModalState(() => loadingCancel = true);
//               final resp = await ApiService().cancelAppointment(
//                 branchId: selectedBranchId!,
//                 appointmentId: booking['id'] as int,
//               );
//               setModalState(() => loadingCancel = false);

//               if (resp['success'] == true) {
//                 // If API returns status, reflect it locally too
//                 final newStatus = (resp['data']?['status'] ?? 'CANCELLED').toString().toUpperCase();
//                 setModalState(() {
//                   statusUpper = newStatus;
//                 });
//                 Navigator.of(context).pop();
//                 await getBookingsByDate(selectedBranchId!, selectedDate);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text(resp['message']?.toString() ?? 'Cancelled')),
//                 );
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to cancel')),
//                 );
//               }
//             }

//             return FractionallySizedBox(
//               heightFactor: 0.42,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             services.isEmpty ? 'Appointment' : services,
//                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.close),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     if (timeStr.isNotEmpty)
//                       Text(timeStr, style: const TextStyle(color: Colors.black54)),
//                     const SizedBox(height: 4),
//                     Text('Status: $statusUpper', style: const TextStyle(color: Colors.black54)),
//                     const SizedBox(height: 4),
//                     Text('Stylist: $stylist', style: const TextStyle(color: Colors.black54)),
//                     const SizedBox(height: 4),
//                     if (duration.isNotEmpty)
//                       Text('Duration: $duration', style: const TextStyle(color: Colors.black54)),
//                     const SizedBox(height: 4),
//                     if (price.isNotEmpty)
//                       Text('Price: $price', style: const TextStyle(color: Colors.black54)),
//                     const Spacer(),

//                     // ACTIONS:
//                     if (isPending) ...[
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: loadingConfirm ? null : onConfirm,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blue,
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                               ),
//                               child: loadingConfirm
//                                   ? const SizedBox(
//                                       height: 18,
//                                       width: 18,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         color: Colors.white,
//                                       ),
//                                     )
//                                   : const Text('Confirm'),
//                             ),
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: loadingCancel ? null : onCancel,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.red,
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                               ),
//                               child: loadingCancel
//                                   ? const SizedBox(
//                                       height: 18,
//                                       width: 18,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         color: Colors.white,
//                                       ),
//                                     )
//                                   : const Text('Cancel'),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ] else if (isConfirmed) ...[
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: loadingStart ? null : onStartJob,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                           ),
//                           child: loadingStart
//                               ? const SizedBox(
//                                   height: 18, width: 18,
//                                   child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                                 )
//                               : const Text('Start Job'),
//                         ),
//                       ),
//                     ] else ...[
//                       // Other statuses (IN_PROGRESS, COMPLETED, CANCELLED): show a disabled info button
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: null,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                           ),
//                           child: Text(statusUpper),
//                         ),
//                       ),
//                     ],

//                     const SizedBox(height: 10),
//                     SizedBox(
//                       width: double.infinity,
//                       child: OutlinedButton(
//                         onPressed: () => Navigator.pop(context),
//                         style: OutlinedButton.styleFrom(
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                         ),
//                         child: const Text('Close'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // Function to handle branch selection
//   void onBranchChanged(int branchId, int salonId) {
//     setState(() {
//       selectedBranchId = branchId;
//       selectedSalonId = salonId;
//     });

//     // Fetch team members for the selected branch
//     getTeamMembers(branchId);

//     // Fetch bookings for the selected branch and date
//     getBookingsByDate(branchId, selectedDate);
//   }

//   // Function to handle date change (previous and next)
//   void changeDate(bool isNext) {
//     setState(() {
//       if (isNext) {
//         selectedDate = selectedDate.add(Duration(days: 1)); // Move to the next day
//       } else {
//         selectedDate = selectedDate.subtract(Duration(days: 1)); // Move to the previous day
//       }
//     });

//     // Fetch bookings for the updated date
//     if (selectedBranchId != null) {
//       getBookingsByDate(selectedBranchId!, selectedDate);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Bookings'),
//         centerTitle: true,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: TextButton(
//               onPressed: () async {
//                 if (selectedBranchId == null || selectedSalonId == null) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a branch')),
//                   );
//                   return;
//                 }
//                 final result = await Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => AddBookingScreen(
//                       salonId: selectedSalonId,
//                       branchId: selectedBranchId,
//                     ),
//                   ),
//                 );

//                 if (result != null && selectedBranchId != null) {
//                   getBookingsByDate(selectedBranchId!, selectedDate);
//                 }
//               },
//               style: TextButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: const [
//                   Icon(Icons.add, size: 18),
//                   SizedBox(width: 6),
//                   Text('Add Booking'),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: salons.isEmpty
//                 ? isLoading
//                     ? Center(child: CircularProgressIndicator()) // Show loader while fetching data
//                     : Text("Please select a branch") // Show message when no data
//                 : Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(10),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey.withOpacity(0.2),
//                           spreadRadius: 1,
//                           blurRadius: 5,
//                           offset: Offset(0, 3), // changes position of shadow
//                         ),
//                       ],
//                     ),
//                     child: DropdownButtonFormField<int>(
//                       hint: Text("Select Salon Branch", style: TextStyle(fontWeight: FontWeight.w600)),
//                       value: selectedBranchId,
//                       onChanged: (newValue) {
//                         if (newValue != null) {
//                           final salon = salons.firstWhere((s) =>
//                               (s['branches'] as List).any((b) => b['id'] == newValue));
//                           final branch = (salon['branches'] as List)
//                               .firstWhere((b) => b['id'] == newValue);
//                           selectedBranch = {
//                             'salonId': salon['id'],
//                             'branchId': branch['id'],
//                             'branchName': branch['name'],
//                           };

//                           onBranchChanged(branch['id'], salon['id']);  // Fetch team members and bookings
//                         }
//                       },
//                       items: salons.expand((salon) {
//                         final branches = salon['branches'] as List;
//                         return branches.map<DropdownMenuItem<int>>((branch) {
//                           return DropdownMenuItem(
//                             value: branch['id'],
//                             child: Text(branch['name']),
//                           );
//                         }).toList();
//                       }).toList(),
//                     ),
//                   ),
//           ),
//           const SizedBox(height: 16),

//           // Status counts display in 4 boxes with horizontal scroll
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: [
//                 _statusBox('Pending', pendingCount, Colors.orange),
//                 _statusBox('Cancelled', cancelledCount, Colors.red),
//                 _statusBox('Completed', completedCount, Colors.green),
//                 _statusBox('Confirmed', confirmedCount, Colors.blue),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Date selection and navigation
//           Row(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.chevron_left),
//                 onPressed: () => changeDate(false), // Previous date
//               ),
//               Flexible(
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: List.generate(7, (index) {
//                       DateTime date = selectedDate.add(Duration(days: index - 3));
//                       bool isSelected = isSameDay(date, selectedDate);

//                       return Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                         child: GestureDetector(
//                           onTap: () {
//                             setState(() {
//                               selectedDate = date;
//                             });
//                             if (selectedBranchId != null) {
//                               getBookingsByDate(selectedBranchId!, selectedDate);
//                             }
//                           },
//                           child: Container(
//                             padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//                             decoration: BoxDecoration(
//                               color: isSelected ? Colors.blue : Colors.grey[200],
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   DateFormat('EEE').format(date),
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: isSelected ? Colors.white : Colors.black,
//                                   ),
//                                 ),
//                                 Text(
//                                   DateFormat('d').format(date),
//                                   style: TextStyle(
//                                     color: isSelected ? Colors.white : Colors.black,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     }),
//                   ),
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(Icons.chevron_right),
//                 onPressed: () => changeDate(true), // Next date
//               ),
//             ],
//           ),

//           const SizedBox(height: 16),

//           // Timetable grid
//           SizedBox(height: 8),
//           Expanded(
//             child: Container(
//               color: const Color(0xFFF7F4F1),
//               child: Column(
//                 children: [
//                   // Header row: Time + horizontally scrollable member headers
//                   Row(
//                     children: [
//                       Container(
//                         width: 100,
//                         height: 44,
//                         alignment: Alignment.center,
//                         decoration: BoxDecoration(
//                           color: Colors.blueGrey.shade600,
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: const Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//                       ),
//                       Expanded(
//                         child: SingleChildScrollView(
//                           controller: _headerHController,
//                           scrollDirection: Axis.horizontal,
//                           primary: false,
//                           physics: const ClampingScrollPhysics(),
//                           child: Row(
//                             children: List.generate(teamMembers.length, (index) {
//                               final m = teamMembers[index];
//                               return Container(
//                                 width: 140,
//                                 height: 44,
//                                 alignment: Alignment.centerLeft,
//                                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade300,
//                                   border: Border(
//                                     top: BorderSide(color: Colors.grey.shade300),
//                                     right: BorderSide(color: Colors.grey.shade300),
//                                     bottom: BorderSide(color: Colors.grey.shade300),
//                                   ),
//                                 ),
//                                 child: Text(
//                                   '${m['firstName']} ${m['lastName']}',
//                                   style: const TextStyle(fontWeight: FontWeight.w600),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               );
//                             }),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const Divider(height: 1, thickness: 1),

//                   // Body: left time column synced with grid rows on the right
//                   Expanded(
//                     child: Row(
//                       children: [
//                         // Time labels column (synced vertically)
//                         SizedBox(
//                           width: 100,
//                           child: timeSlots.isEmpty
//                               ? const SizedBox()
//                               : NotificationListener<ScrollNotification>(
//                                   onNotification: (notif) {
//                                     if (notif.metrics.axis == Axis.vertical) {
//                                       if (!_syncingV && _gridVController.hasClients) {
//                                         _syncingV = true;
//                                         final off = _timeColumnVController.offset;
//                                         if ((_gridVController.offset - off).abs() > 0.5) {
//                                           _gridVController.jumpTo(off);
//                                         }
//                                         _syncingV = false;
//                                       }
//                                     }
//                                     return false;
//                                   },
//                                   child: ListView.builder(
//                                     controller: _timeColumnVController,
//                                     primary: false,
//                                     physics: const ClampingScrollPhysics(),
//                                     dragStartBehavior: DragStartBehavior.start,
//                                     itemExtent: 44,
//                                     itemCount: timeSlots.length,
//                                     itemBuilder: (context, i) {
//                                       return Container(
//                                         alignment: Alignment.centerLeft,
//                                         padding: const EdgeInsets.symmetric(horizontal: 8),
//                                         decoration: BoxDecoration(
//                                           color: i % 2 == 0 ? Colors.white : const Color(0xFFF0F0F0),
//                                           border: Border(
//                                             right: BorderSide(color: Colors.grey.shade300),
//                                             bottom: BorderSide(color: Colors.grey.shade300),
//                                           ),
//                                         ),
//                                         child: Text(
//                                           timeSlots[i],
//                                           style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
//                                         ),
//                                       );
//                                     },
//                                   ),
//                                 ),
//                         ),

//                         // Grid body (scrolls both ways)
//                         Expanded(
//                           child: SingleChildScrollView(
//                             controller: _gridHController,
//                             scrollDirection: Axis.horizontal,
//                             primary: false,
//                             physics: const ClampingScrollPhysics(),
//                             child: SizedBox(
//                               width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
//                               child: timeSlots.isEmpty
//                                   ? const Center(child: Text('No time slots available'))
//                                   : NotificationListener<ScrollNotification>(
//                                       onNotification: (notif) {
//                                         if (notif.metrics.axis == Axis.vertical) {
//                                           if (!_syncingV && _timeColumnVController.hasClients) {
//                                             _syncingV = true;
//                                             final off = _gridVController.offset;
//                                             if ((_timeColumnVController.offset - off).abs() > 0.5) {
//                                               _timeColumnVController.jumpTo(off);
//                                             }
//                                             _syncingV = false;
//                                           }
//                                         }
//                                         return false;
//                                       },
//                                       child: SingleChildScrollView(
//                                         controller: _gridVController,
//                                         primary: false,
//                                         physics: const ClampingScrollPhysics(),
//                                         child: SizedBox(
//                                           width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
//                                           height: timeSlots.length * _rowHeight,
//                                           child: Stack(
//                                             children: [
//                                               // Background grid
//                                               ..._buildBackgroundGrid(),
//                                               // Booking overlays
//                                               ..._buildBookingBlocks(),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _timeColumnVController.dispose();
//     _gridVController.dispose();
//     _headerHController.dispose();
//     _gridHController.dispose();
//     super.dispose();
//   }

//   // Helper function to create status box with count and custom color
//   Widget _statusBox(String title, int count, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       margin: const EdgeInsets.only(right: 8),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.12),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.35)),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             title,
//             style: TextStyle(color: color, fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             '$count',
//             style: TextStyle(color: color, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }
// }
//Md
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';  // For date formatting
import '../utils/api_service.dart';  // Import the correct api_service.dart file
import 'AddBookings.dart';  // Add Booking screen
import '../utils/colors.dart'; // Custom colors
import 'package:shared_preferences/shared_preferences.dart';
class BookingsScreen extends StatefulWidget {
  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> salons = [];
  bool isLoading = true;
  int? selectedSalonId;
  int? selectedBranchId;  // Store branchId of the selected branch
   String? salonName;
  String? salonAddress;
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
    _loadCachedSelection();
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
Future<void> _loadCachedSelection() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    selectedSalonId  = prefs.getInt('selected_salon_id');
    selectedBranchId = prefs.getInt('selected_branch_id');
    salonName        = prefs.getString('salon_name');
    salonAddress     = prefs.getString('salon_address');
  });
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
          'appointmentId': g.first['appointmentId'],
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

  void _openMergedSegmentSheet(Map<String, dynamic> seg) {
    final DateTime s = seg['start'] as DateTime;
    final DateTime e = seg['end'] as DateTime;
    final String status = (seg['status'] as String).toUpperCase();
    final String customerName = seg['customerName'] as String? ?? 'Customer';
    final int? priceTotal = seg['priceTotal'] as int?;
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

    // Unique appointment IDs inside the block
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
        bool loadingStartAll = false;

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

        Future<String?> _askOtp() async {
          final controller = TextEditingController();
          String? result;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dCtx) {
              return AlertDialog(
                title: const Text("Enter OTP"),
                content: TextField(
                  controller: controller,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "6-digit OTP",
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dCtx);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final otp = controller.text.trim();
                      if (otp.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Enter valid 6-digit OTP")),
                        );
                        return;
                      }
                      result = otp;
                      Navigator.pop(dCtx);
                    },
                    child: const Text("Submit"),
                  ),
                ],
              );
            },
          );
          return result;
        }

        Future<void> _startForIds(List<int> ids) async {
          if (selectedBranchId == null || ids.isEmpty) return;
          final otp = await _askOtp();
          if (otp == null) return;

          loadingStartAll = true;
          (ctx as Element).markNeedsBuild();

          int ok = 0, fail = 0;
          for (final id in ids) {
            try {
              final resp = await ApiService.startAppointment(
                branchId: selectedBranchId!,
                appointmentId: id,
                otp: otp,
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

          loadingStartAll = false;
          (ctx as Element).markNeedsBuild();

          Navigator.pop(context);
          await getBookingsByDate(selectedBranchId!, selectedDate);

          final msg = fail == 0
              ? 'Job started for $ok appointment(s).'
              : 'Started $ok, failed $fail.';
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

                // Services list
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (priceText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            // Quick “View”
                            // TextButton(
                            //   onPressed: () {
                            //     Navigator.pop(context);
                            //     _openAppointmentSheet(
                            //       it['booking'] as Map<String, dynamic>,
                            //       it['item'] as Map<String, dynamic>,
                            //     );
                            //   },
                            //   child: const Text('View'),
                            // ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Actions (bottom)
                if (status == 'PENDING') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loadingConfirm ? null : onConfirmAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: loadingConfirm
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(apptIds.length <= 1 ? 'Confirm' : 'Confirm All (${apptIds.length})'),
                    ),
                  ),
                ] else if (status == 'CONFIRMED') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loadingStartAll ? null : () => _startForIds(apptIds),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: loadingStartAll
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(apptIds.length <= 1 ? 'Start Job' : 'Start All (${apptIds.length})'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(status),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

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
      final double height = (totalMin / 15.0) * _rowHeight; // seamless
      final double left = col * _colWidth + 6;
      final double width = _colWidth - 12;

      // ✅ Color mapping (green for IN_PROGRESS)
      Color bg = Colors.blue.shade300; // default (CONFIRMED)
      if (status == 'PENDING')   bg = Colors.orange.shade300;
      if (status == 'CONFIRMED') bg = Colors.blue.shade300;
      if (status == 'IN_PROGRESS') bg = Colors.green.shade400;  // << green after Start Job
      if (status == 'COMPLETED') bg = Colors.green.shade700;
      if (status == 'CANCELLED') bg = Colors.red.shade300;

      final String customerName = seg['customerName'] as String? ?? 'Customer';
      final List<String> services = List<String>.from(seg['services'] as List);
      final int moreCount = (services.length > 1) ? services.length - 1 : 0;
      final String headService = services.isNotEmpty ? services.first : 'Service';
      final int? priceTotal = seg['priceTotal'] as int?;
      final String priceText = priceTotal != null ? '₹$priceTotal' : '';
      final String timeRange = _fmtTimeRange(s, e);

      final List<Map<String, dynamic>> segItems =
          List<Map<String, dynamic>>.from(seg['items'] as List);

      blocks.add(Positioned(
        left: left,
        top: top,
        width: width,
        height: height < 44 ? 44 : height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (segItems.length == 1) {
                final b = segItems.first['booking'] as Map<String, dynamic>;
                final it = segItems.first['item'] as Map<String, dynamic>;
                _openAppointmentSheet(b, it);
              } else {
                _openMergedSegmentSheet(seg);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: bg,
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
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        Text(
                          moreCount > 0 ? '$headService + $moreCount more' : headService,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87),
                        ),
                        if (priceText.isNotEmpty)
                          Text(priceText, style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(timeRange, style: const TextStyle(color: Colors.black87, fontSize: 10)),
                        Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 10)),
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
Future<Map<String, dynamic>?> _getFeedbackFromUser(BuildContext context) async {
  int rating = 0;
  final commentCtrl = TextEditingController();

  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
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
                ),
                onPressed: () => setFBState(() => rating = i),
              );

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('Rating (required)'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(5, (i) => _star(i + 1)),
                ),
                const SizedBox(height: 8),
                const Text('Comment (required)'),
                const SizedBox(height: 6),
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  onChanged: (_) => setFBState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Write your feedback...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit
                        ? () {
                            Navigator.pop<Map<String, dynamic>>(c, {
                              'rating': rating,
                              'comment': commentCtrl.text.trim(),
                            });
                          }
                        : null,
                    child: const Text('Submit & Complete'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  /// Per-appointment sheet:
  /// - If PENDING: Confirm
  /// - After Confirm success: shows "Start Job" (green)
  /// - Start Job -> OTP -> IN_PROGRESS -> shows "Complete Job" (green)
  /// - Complete Job -> opens feedback modal (no API call for now)
  void _openAppointmentSheet(Map<String, dynamic> booking, Map<String, dynamic>? item) {
    // Mutable state captured by StatefulBuilder
    String statusUpper = (booking['status'] ?? '').toString().toUpperCase();
    bool loadingConfirm = false;
    bool loadingCancel = false;
    bool loadingStart = false;
    bool loadingComplete = false;

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

            final bool isPending = statusUpper == 'PENDING';
            final bool isConfirmed = statusUpper == 'CONFIRMED';

            final stylist = useItem?['assignedUserBranch']?['user']?['firstName'] ?? 'N/A';
            final duration = useItem?['durationMin'] != null ? '${useItem!['durationMin']} min' : '';
            final priceMinor = useItem?['branchService']?['priceMinor'];
            final price = priceMinor != null ? '₹$priceMinor' : '';

            Future<void> onConfirm() async {
              if (selectedBranchId == null) return;
              setModalState(() => loadingConfirm = true);
              final resp = await ApiService().confirmAppointment(
                branchId: selectedBranchId!,
                appointmentId: booking['id'] as int,
              );
              setModalState(() => loadingConfirm = false);

              if (resp['success'] == true) {
                final newStatus = (resp['data']?['status'] ?? 'CONFIRMED').toString().toUpperCase();
                setModalState(() {
                  statusUpper = newStatus;
                });
                if (selectedBranchId != null) {
                  await getBookingsByDate(selectedBranchId!, selectedDate);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(resp['message']?.toString() ?? 'Confirmed')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to confirm')),
                );
              }
            }

            Future<void> onStartJob() async {
              if (selectedBranchId == null) return;

              final otpController = TextEditingController();

              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (dialogCtx) {
                  return StatefulBuilder(
                    builder: (dialogCtx, setDialogState) {
                      return AlertDialog(
                        title: const Text("Enter OTP"),
                        content: TextField(
                          controller: otpController,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "6-digit OTP",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final otp = otpController.text.trim();
                              if (otp.length != 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Enter valid 6-digit OTP")),
                                );
                                return;
                              }
                              setModalState(() => loadingStart = true);
                              Navigator.pop(dialogCtx); // close OTP dialog

                              final resp = await ApiService.startAppointment(
                                branchId: selectedBranchId!,
                                appointmentId: booking['id'] as int,
                                otp: otp,
                              );

                              setModalState(() => loadingStart = false);

                              if (resp['success'] == true) {
                                final newStatus = (resp['data']?['status'] ?? 'IN_PROGRESS').toString().toUpperCase();
                                setModalState(() {
                                  statusUpper = newStatus; // will show "Complete Job"
                                });

                                await getBookingsByDate(selectedBranchId!, selectedDate);
                                Navigator.of(context).pop(); // close sheet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(resp['message']?.toString() ?? 'Job started')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to start job')),
                                );
                              }
                            },
                            child: const Text("Submit"),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            // 👉 For now, just open feedback modal (no API call)
            Future<void> onCompleteJob() async {
  if (selectedBranchId == null) return;

  // 1) Ask user for rating + comment (both required)
  final feedback = await _getFeedbackFromUser(context);
  if (feedback == null) return; // user cancelled

  final int rating  = feedback['rating'] as int;
  final String comment = feedback['comment'] as String;

  // 2) Call COMPLETE API
  setModalState(() => loadingComplete = true);
  final resp = await ApiService().completeAppointment(
    branchId: selectedBranchId!,
    appointmentId: booking['id'] as int,
    rating: rating,
    comment: comment,
  );
  setModalState(() => loadingComplete = false);

  // 3) Handle result
  if (resp['success'] == true) {
    final newStatus =
        (resp['data']?['status'] ?? 'COMPLETED').toString().toUpperCase();
    setModalState(() {
      statusUpper = newStatus; // Sheet will now show “Feedback” button if you keep that branch
    });

    // Refresh grid so block color updates
    await getBookingsByDate(selectedBranchId!, selectedDate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp['message']?.toString() ?? 'Appointment completed')),
    );
  } else {
    final msg = (resp['message']?.toString().isNotEmpty ?? false)
        ? resp['message'].toString()
        : 'Failed to complete appointment';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}


            return FractionallySizedBox(
              heightFactor: 0.42,
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

                    // ACTIONS:
                    if (isPending) ...[
                      // Pending → Confirm
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loadingConfirm ? null : onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: loadingConfirm
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Confirm'),
                        ),
                      ),
                    ] else if (isConfirmed) ...[
                      // Confirmed → Start Job
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loadingStart ? null : onStartJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: loadingStart
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Start Job'),
                        ),
                      ),
                    ] else if (statusUpper == 'IN_PROGRESS') ...[
                      // In Progress → Complete (green)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loadingComplete ? null : onCompleteJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: loadingComplete
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Complete Job'),
                        ),
                      ),
                    ] else ...[
                      // Completed / Cancelled / etc → Grey disabled
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(statusUpper),
                        ),
                      ),
                    ],

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

  // Simple feedback modal (no API call yet)
  Future<void> _openFeedbackModal(BuildContext context) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => setSheet(() => rating = i + 1),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feedback captured')),
                        );
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                ],
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.starColor,
        title: Text('Bookings',style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),),
        centerTitle: false,
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
                backgroundColor: AppColors.getStartedButton,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Add Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
         Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: DropdownButtonFormField<int>(
    decoration: const InputDecoration(
      border: InputBorder.none, // removes the ugly underline
    ),
    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
    dropdownColor: Colors.white,
    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
    hint: const Text(
      "Select Salon Branch",
      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
    ),
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
        onBranchChanged(branch['id'], salon['id']);
      }
    },
    items: salons.expand((salon) {
      final branches = salon['branches'] as List;
      return branches.map<DropdownMenuItem<int>>((branch) {
        return DropdownMenuItem(
          value: branch['id'],
          child: Row(
            children: [
              const Icon(Icons.store, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(branch['name']),
            ],
          ),
        );
      }).toList();
    }).toList(),
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
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () => changeDate(false), // Previous date
              ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(7, (index) {
                      DateTime date = selectedDate.add(Duration(days: index - 3));
                      bool isSelected = isSameDay(date, selectedDate);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = date;
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
                                  DateFormat('EEE').format(date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  DateFormat('d').format(date),
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
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () => changeDate(true), // Next date
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Timetable grid
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
  }
}
