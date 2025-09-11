import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';  // For date formatting
import '../utils/api_service.dart';  // Import the correct api_service.dart file

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

      // Fetch start and end time from the response
      String startTime = response['data'][0]['branch']['startTime']; // Example response structure
      String endTime = response['data'][0]['branch']['endTime'];

      // Generate time slots and populate the timeSlots list
      setState(() {
        timeSlots = generateTimeSlots(startTime, endTime); // Populate timeSlots
        print("Generated Time Slots: $timeSlots"); // Debugging line to check the time slots
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
              onPressed: () {
                if (selectedBranchId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a branch')),
                  );
                } else {
                  print('Booking for Salon ID: $selectedSalonId, Branch ID: $selectedBranchId');
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
                    width: (teamMembers.isEmpty ? 1 : teamMembers.length) * 140,
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
                            child: ListView.builder(
                              controller: _gridVController,
                              primary: false,
                              physics: const ClampingScrollPhysics(),
                              dragStartBehavior: DragStartBehavior.start,
                              itemExtent: 44,
                              itemCount: timeSlots.length,
                              itemBuilder: (context, row) {
                                return Row(
                                  children: List.generate(teamMembers.length, (col) {
                                    return Container(
                                      width: 140,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: row % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
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

const SizedBox(height: 16),

          
//           Expanded(
//   child: bookings.isEmpty
//       ? Center(child: Text('No bookings available'))
//       : ListView.builder(
//           itemCount: bookings.length,
//           itemBuilder: (context, index) {
//             final booking = bookings[index];

//             // Get the status from the booking directly (top-level field)
//             final status = booking['status'] ?? 'Unknown Status';  // Default to 'Unknown Status'

//             // Display status with color styling
//             final displayStatus = status == 'CONFIRMED' ? 'Confirmed' : (status == 'PENDING' ? 'Pending' : status);

//             // Calculate the total price for the booking (sum of all service prices)
//             double totalPrice = 0;
//             booking['items']?.forEach((item) {
//               totalPrice += item['branchService']['priceMinor'] ?? 0;
//             });

//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               elevation: 3,
//               child: ListTile(
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Display each service with its price
//                     ...booking['items']?.map<Widget>((item) {
//                       final serviceName = item['branchService']['displayName'] ?? 'No Service';
//                       final servicePrice = item['branchService']['priceMinor'] ?? 0;
//                       // Get assigned user for the service
//                       final assignedUser = item['assignedUserBranch']?['user'];
//                       final assignedTo = assignedUser != null
//                           ? '${assignedUser['firstName']} ${assignedUser['lastName']}'
//                           : 'Unknown';

//                       return Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text('$serviceName - ₹$servicePrice'),
//                           Text('Assigned to: $assignedTo'),
//                         ],
//                       );
//                     }).toList() ?? [],
//                     SizedBox(height: 8),
//                     // Display total price for this booking
//                     Text(
//                       'Total Price: ₹$totalPrice',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Status: $displayStatus',  // Display the correct status
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: displayStatus == 'Confirmed' ? Colors.green : Colors.red,  // Color based on status
//                       ),
//                     ),
//                   ],
//                 ),
//                 trailing: Text(
//                   // Format start and end time correctly
//                   '${DateFormat('h:mm a').format(DateTime.parse(booking['startAt'] ?? '1970-01-01'))} - ${DateFormat('h:mm a').format(DateTime.parse(booking['endAt'] ?? '1970-01-01'))}',
//                 ),
//               ),
//             );
//           },
//         ),
// )

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
