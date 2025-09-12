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
        // Compute status counts
        pendingCount = bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
        cancelledCount = bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'CANCELLED').length;
        completedCount = bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'COMPLETED').length;
        confirmedCount = bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'CONFIRMED').length;
      });
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
  List<Widget> _buildBookingBlocks() {
    if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

    final startStr = _branchStartTimeStr ?? '08:00:00';
    final endStr = _branchEndTimeStr ?? '20:00:00';
    final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);
    final DateTime dayEnd = _combineDateAndTime(selectedDate, endStr);

    final List<Widget> blocks = [];

    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toUpperCase();
      final items = (booking['items'] as List?) ?? const [];

      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw as Map);
        final col = _findMemberColumnForItem(item);
        if (col < 0) continue;

        final DateTime? rawStart = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
        final DateTime? rawEnd = _parseLocal(item['endAt']) ?? _parseLocal(booking['endAt']);
        if (rawStart == null || rawEnd == null) continue;

        // Clamp within branch working hours
        DateTime start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
        DateTime end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
        if (!end.isAfter(start)) continue;

        final int minutesFromStart = start.difference(dayStart).inMinutes;
        final int durationMin = item['durationMin'] is int
            ? item['durationMin'] as int
            : end.difference(start).inMinutes;

        final double top = (minutesFromStart / 15.0) * _rowHeight;
        final double height = (durationMin / 15.0) * _rowHeight - 2;
        final double left = col * _colWidth + 6;
        final double width = _colWidth - 12;

        Color bg = Colors.blue.shade300;
        if (status == 'PENDING') bg = Colors.orange.shade300;
        if (status == 'CANCELLED') bg = Colors.red.shade300;
        if (status == 'COMPLETED') bg = Colors.green.shade300;

        final serviceName = item['branchService']?['displayName']?.toString() ?? 'Service';
        final priceMinor = item['branchService']?['priceMinor'];
        final priceText = priceMinor != null ? '₹$priceMinor' : '';

        blocks.add(Positioned(
          left: left,
          top: top,
          width: width,
          height: height < 30 ? 30 : height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openAppointmentSheet(booking, item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: bg,
                  padding: const EdgeInsets.all(10),
                  child: Builder(builder: (_) {
                    final bool compact = height < 72;
                    if (compact) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        if (priceText.isNotEmpty)
                          Text('Price: $priceText', style: const TextStyle(color: Colors.black87)),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            status,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ));
      }
    }

    return blocks;
  }

  void _openAppointmentSheet(Map<String, dynamic> booking, Map<String, dynamic>? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool loading = false;
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

            Future<void> onConfirm() async {
              if (selectedBranchId == null) return;
              setModalState(() => loading = true);
              final resp = await ApiService().confirmAppointment(
                branchId: selectedBranchId!,
                appointmentId: booking['id'] as int,
              );
              setModalState(() => loading = false);
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

            return FractionallySizedBox(
              heightFactor: 0.2,
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
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (timeStr.isNotEmpty)
                      Text(timeStr, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('Status: ' + (booking['status']?.toString() ?? ''),
                        style: const TextStyle(color: Colors.black54)),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (loading || !isPending) ? null : onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isPending ? 'Confirm' : 'Not Pending'),
                      ),
                    )
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





