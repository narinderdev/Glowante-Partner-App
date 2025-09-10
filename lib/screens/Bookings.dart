import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // For date formatting
import '../utils/api_service.dart';  // Import the correct api_service.dart file

class BookingsScreen extends StatefulWidget {
  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> salons = [];
  int? selectedSalonId;
  int? selectedBranchId;  // Store branchId of the selected branch
  Map<String, dynamic>? selectedBranch;  // Store branch details
  List<Map<String, dynamic>> bookings = [];
  DateTime selectedDate = DateTime.now();  // Initial date is today
  List<Map<String, dynamic>> teamMembers = []; // Store team members for the selected branch
  int pendingCount = 0;
  int cancelledCount = 0;
  int completedCount = 0;
  int confirmedCount = 0;

  @override
  void initState() {
    super.initState();
    getSalonListApi();
  }

  // Fetch salon list from API
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
        });
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("Error fetching salon list: $e");
    }
  }
Future<void> getBookingsByDate(int branchId, DateTime date) async {
  try {
    String formattedDate = DateFormat('yyyy-MM-dd').format(date); // Format date

    // Create an instance of ApiService
    ApiService apiService = ApiService();

    // Call the instance method to fetch appointments
    final response = await apiService.fetchAppointments(branchId, formattedDate);

    // Check if response is not null and contains the expected data
    if (response != null && response['success'] == true && response['data'] != null) {
      List<dynamic> appointments = response['data'];  // Safe access to 'data'
      
      // Initialize counts for each status
      pendingCount = 0;
      cancelledCount = 0;
      completedCount = 0;
      confirmedCount = 0;

      // Loop through appointments and count each status
      for (var booking in appointments) {
        String status = booking['status'] ?? 'Unknown Status';  // Default to 'Unknown Status'
        print('Status: $status');  // Debugging line to check status in console

        switch (status) {
          case 'PENDING':
            pendingCount++;
            break;
          case 'CANCELLED':
            cancelledCount++;
            break;
          case 'COMPLETED':
            completedCount++;
            break;
          case 'CONFIRMED':
            confirmedCount++;
            break;
          default:
            break;
        }
      }

      setState(() {
        bookings = List<Map<String, dynamic>>.from(appointments); // Convert to List<Map> if needed
      });
    } else {
      setState(() {
        bookings = []; // If no data, clear the list
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
              child: Text('Add Booking'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: salons.isEmpty
                ? CircularProgressIndicator() // Show loading indicator while data is being fetched
                : DropdownButton<int>(
                    hint: Text("Select Salon Branch"),
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
          const SizedBox(height: 16),
          // Status counts display in 4 boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statusBox('Pending', pendingCount),
              _statusBox('Cancelled', cancelledCount),
              _statusBox('Completed', completedCount),
              _statusBox('Confirmed', confirmedCount),
            ],
          ),
          const SizedBox(height: 16),
          // Team members list above the calendar
          teamMembers.isEmpty
              ? Text('No team members available')
              : Container(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: teamMembers.length,
                    itemBuilder: (context, index) {
                      final teamMember = teamMembers[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text('${teamMember['firstName']} ${teamMember['lastName']}'),
                              Text('ID: ${teamMember['id'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 16),
          // Date selection and navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => changeDate(false), // Previous date
              ),
              Text(
                DateFormat('EEE dd MMM yyyy').format(selectedDate), // Show formatted date
                style: TextStyle(fontSize: 18),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward),
                onPressed: () => changeDate(true), // Next date
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show bookings in a calendar-like format
          // Expanded(
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

          //             return Column(
          //               children: booking['items']?.map<Widget>((item) {
          //                 // Safely get assigned user
          //                 final assignedUser = item['assignedUserBranch']?['user'];

          //                 return Card(
          //                   margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          //                   shape: RoundedRectangleBorder(
          //                     borderRadius: BorderRadius.circular(12),
          //                   ),
          //                   elevation: 3,
          //                   child: ListTile(
          //                     title: Text(item['branchService']?['displayName'] ?? 'No Service'),
          //                     subtitle: Column(
          //                       crossAxisAlignment: CrossAxisAlignment.start,
          //                       children: [
          //                         Text('${item['branchService']?['durationMin']} minutes'),
          //                         assignedUser != null
          //                           ? Text('Assigned to: ${assignedUser['firstName']} ${assignedUser['lastName']}')

          //                             : Text('Assigned to: Unknown'),
          //                         Text(
          //                           'Status: $displayStatus',  // Display the correct status
          //                           style: TextStyle(
          //                             fontWeight: FontWeight.bold,
          //                             color: displayStatus == 'Confirmed' ? Colors.green : Colors.red,  // Color based on status
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                     trailing: Text(
          //                       // Format start and end time correctly
          //                       '${DateFormat('h:mm a').format(DateTime.parse(booking['startAt'] ?? '1970-01-01'))} - ${DateFormat('h:mm a').format(DateTime.parse(booking['endAt'] ?? '1970-01-01'))}',
          //                     ),
          //                   ),
          //                 );
          //               }).toList() ?? [],
          //             );
          //           },
          //         ),
          // ),
          Expanded(
  child: bookings.isEmpty
      ? Center(child: Text('No bookings available'))
      : ListView.builder(
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];

            // Get the status from the booking directly (top-level field)
            final status = booking['status'] ?? 'Unknown Status';  // Default to 'Unknown Status'

            // Display status with color styling
            final displayStatus = status == 'CONFIRMED' ? 'Confirmed' : (status == 'PENDING' ? 'Pending' : status);

            // Calculate the total price for the booking (sum of all service prices)
            double totalPrice = 0;
            booking['items']?.forEach((item) {
              totalPrice += item['branchService']['priceMinor'] ?? 0;
            });

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: ListTile(
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display each service with its price
                    ...booking['items']?.map<Widget>((item) {
                      final serviceName = item['branchService']['displayName'] ?? 'No Service';
                      final servicePrice = item['branchService']['priceMinor'] ?? 0;
                      // Get assigned user for the service
                      final assignedUser = item['assignedUserBranch']?['user'];
                      final assignedTo = assignedUser != null
                          ? '${assignedUser['firstName']} ${assignedUser['lastName']}'
                          : 'Unknown';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$serviceName - ₹$servicePrice'),
                          Text('Assigned to: $assignedTo'),
                        ],
                      );
                    }).toList() ?? [],
                    SizedBox(height: 8),
                    // Display total price for this booking
                    Text(
                      'Total Price: ₹$totalPrice',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Status: $displayStatus',  // Display the correct status
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: displayStatus == 'Confirmed' ? Colors.green : Colors.red,  // Color based on status
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  // Format start and end time correctly
                  '${DateFormat('h:mm a').format(DateTime.parse(booking['startAt'] ?? '1970-01-01'))} - ${DateFormat('h:mm a').format(DateTime.parse(booking['endAt'] ?? '1970-01-01'))}',
                ),
              ),
            );
          },
        ),
)

        ],
      ),
    );
  }

  // Helper function to create status box with count
  Widget _statusBox(String title, int count) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      width: 70,
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          Text(
            '$count',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
