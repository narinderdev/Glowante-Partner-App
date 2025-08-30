import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting date/time
import 'AddTeam.dart'; // Import AddTeam screen to navigate back
import 'team_member_screen.dart'; // Import TeamMember screen to navigate to
import '../utils/api_service.dart';

class ChooseTimeSlot extends StatefulWidget {
  final Map<String, dynamic> formData;
  const ChooseTimeSlot({Key? key, required this.formData}) : super(key: key);

  @override
  _ChooseTimeSlotState createState() => _ChooseTimeSlotState();
}

class _ChooseTimeSlotState extends State<ChooseTimeSlot> {
  // Map to store weekly schedule with day as key
  late Map<String, List<Map<String, String>>> weeklySchedule;
  late Map<String, List<Map<String, String>>> mondaySchedule; // For tracking Monday's schedule separately

  @override
  void initState() {
    super.initState();
    weeklySchedule = {
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
      'Sunday': [],
    };
    mondaySchedule = {}; // Initializing Monday's schedule separately
  }

  // Method to add a slot to a specific day
  void addSlot(String day) {
    setState(() {
      weeklySchedule[day]?.add({
        'start': '09:00 AM',
        'end': '05:00 PM',
      });
    });
  }

  // Method to delete a slot
  void deleteSlot(String day, int index) {
    setState(() {
      weeklySchedule[day]?.removeAt(index);
    });
  }

  // Method to update the start or end time of a slot
  void updateTime(String day, int index, String timeType, String newTime) {
    setState(() {
      weeklySchedule[day]?[index][timeType] = newTime;
    });
  }

  // Method to copy Monday's schedule to all days
  void copyMondayScheduleToAll() {
    // Check if Monday has any slots added
    if (weeklySchedule['Monday']!.isEmpty) {
      // Show an alert if no time slots are added for Monday
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Alert'),
            content: Text('Please add time slots for monday first.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        final mondaySchedule = List<Map<String, String>>.from(weeklySchedule['Monday']!);
        weeklySchedule.forEach((key, value) {
          if (key != 'Monday') {
            value.clear();
            value.addAll(mondaySchedule); // Ensure you're adding a List<Map<String, String>> type
          }
        });
      });
    }
  }

  // Function to show the time picker and update the time
  Future<void> _selectTime(BuildContext context, String day, int index, String timeType) async {
    TimeOfDay initialTime = TimeOfDay(hour: 9, minute: 0); // Default to 9:00 AM

    // Show the time picker dialog
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      String formattedTime = pickedTime.format(context); // Format the time as string
      updateTime(day, index, timeType, formattedTime); // Update the selected time
    }
  }
Future<void> _addTeamMember() async {
  // Gather the schedule data in the required format
  List<Map<String, String>> scheduleData = [];
  for (var day in weeklySchedule.keys) {
    for (var slot in weeklySchedule[day]!) {
      scheduleData.add({
        'day': day.toLowerCase(),  // Ensure the day is lowercase
        'startTime': slot['start'] ?? '09:00 AM',
        'endTime': slot['end'] ?? '05:00 PM',
      });
    }
  }

  // Prepare the payload (data to be sent in the POST request)
  Map<String, dynamic> teamMemberData = {
    "phoneNumber": widget.formData['phoneNumber'],
    "firstName": widget.formData['firstName'],
    "lastName": widget.formData['lastName'],
    "email": widget.formData['email'],
    "gender": widget.formData['gender'].toLowerCase(),  // Ensure gender is lowercase
    "joiningDate": DateFormat('yyyy-MM-dd').format(widget.formData['joiningDate']),
    "info": widget.formData['brief'],
    "roles": widget.formData['roles'],
    "specialities": widget.formData['specializations'],
    "schedules": scheduleData,
    "otp": widget.formData['otp'].toString(),
  };

  try {
    // Call the API to add the team member
    ApiService apiService = ApiService();
    final branchId = widget.formData['branchId']; // Get branchId
    Map<String, dynamic> response = await apiService.addTeamMember(branchId, teamMemberData);

    // Handle the response
    if (response['success']) {
      // Successfully added the team member
      print('Team member added: ${response['data']}');
      // Optionally, navigate to the TeamMemberScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TeamMemberScreen(branchDetails: widget.formData)),
      );
    } else {
      // If the API returns an error, display the response message in an alert dialog
      print('API Response: ${response['message']}');
      _showErrorDialog(response['message']);  // Pass the API error message here (e.g., "Invalid OTP")
    }
  } catch (e) {
    // Handle unexpected errors (e.g., network issues)
    print('Unexpected error: $e');
    _showErrorDialog('An unexpected error occurred.');  // Display a generic message
  }
}

void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Response'),  // Title of the dialog
        content: Text(message),   // This will display the message from the API (e.g., "Invalid OTP")
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();  // Close the dialog
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    // Access the form data
    final phoneNumber = widget.formData['phoneNumber'];
    final firstName = widget.formData['firstName'];
    final lastName = widget.formData['lastName'];
    final email = widget.formData['email'];
    final otp = widget.formData['otp'];
    final gender = widget.formData['gender'];
    final roles = widget.formData['roles'];
    final specializations = widget.formData['specializations'];
    final joiningDate = widget.formData['joiningDate'];
    final brief = widget.formData['brief'];
    final profileImage = widget.formData['profileImage'];
    final branchId = widget.formData['branchId'];


    // Format the joiningDate
    String formattedJoiningDate = '';
    if (joiningDate != null) {
      formattedJoiningDate = DateFormat('yyyy-MM-dd').format(joiningDate);
    }

    return WillPopScope(
      onWillPop: () async {
        // Navigate back to AddTeamScreen using Navigator.pushReplacement
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddTeamScreen(branchId: widget.formData['branchId'])),  // Replace current screen with AddTeamScreen
        );
        return false;  // Prevent the default back action
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add Timeslots'),
        ),
        body: SingleChildScrollView( // Wrap the entire body in SingleChildScrollView for scrolling
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display profile image and details above Set Weekly Working Hours section
                profileImage != null
                    ? CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(profileImage), // Load the image from URL
                      )
                    : const Icon(Icons.camera_alt, size: 40), // Default camera icon if no image

                const SizedBox(height: 16),

                // Show the image URL as text
                if (profileImage != null)
                  Text('Profile Image URL: $profileImage'),

                const SizedBox(height: 16),
               Text('Branch ID: ${widget.formData['branchId']}'),
                Text('Phone Number: $phoneNumber'),
                Text('First Name: $firstName'),
                Text('Last Name: $lastName'),
                Text('Email: $email'),
                Text('OTP: $otp'),
                Text('Gender: $gender'),
                Text('Roles: $roles'),
                Text('Specializations: $specializations'),
                Text('Joining Date: $formattedJoiningDate'),
                Text('Brief About Member: $brief'),

                const SizedBox(height: 24), // Add space before "Set Weekly Working Hours" section

                // Now "Set Weekly Working Hours" section
                Text(
                  'Set Weekly Working Hours',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold, // Added font weight
                  ),
                ),
                SizedBox(height: 16),

                // Display Monday's working hours and slots as a card
                Container(
                  width: double.infinity,  // Ensure consistent width across all cards
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monday',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600, // Added font weight
                            ),
                          ),
                          SizedBox(height: 8),
                          // Display slots for Monday
                          if (weeklySchedule['Monday']!.isEmpty)
                            Text('No time slots added'),
                          for (var i = 0; i < weeklySchedule['Monday']!.length; i++)
                            Row(
                              children: [
                                // Time Slot
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Start time
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _selectTime(context, 'Monday', i, 'start');
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey),
                                            ),
                                            child: Text(
                                              weeklySchedule['Monday']![i]['start'] ?? '09:00 AM',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // To text
                                      Text(' to '),
                                      // End time
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _selectTime(context, 'Monday', i, 'end');
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey),
                                            ),
                                            child: Text(
                                              weeklySchedule['Monday']![i]['end'] ?? '05:00 PM',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete button
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => deleteSlot('Monday', i),
                                ),
                              ],
                            ),
                          // Add Slot button for Monday
                          ElevatedButton(
                            onPressed: () => addSlot('Monday'),
                            child: Text('+ Add Slot'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Copy Monday schedule button (immediately after Monday's section)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton(
                    onPressed: copyMondayScheduleToAll,
                    child: Text('Copy Monday schedule to all days'),
                  ),
                ),
                SizedBox(height: 16),

                // Display each day's working hours and slots
                for (var day in weeklySchedule.keys)
                  if (day != 'Monday') // Skip Monday since it's already displayed above
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,  // Ensure consistent width across all cards
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600, // Added font weight
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Display slots for each day
                                  if (weeklySchedule[day]!.isEmpty)
                                    Text('No time slots added'),
                                  for (var i = 0; i < weeklySchedule[day]!.length; i++)
                                    Row(
                                      children: [
                                        // Time Slot
                                        Expanded(
                                          child: Row(
                                            children: [
                                              // Start time
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    _selectTime(context, day, i, 'start');
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey),
                                                    ),
                                                    child: Text(
                                                      weeklySchedule[day]![i]['start'] ?? '09:00 AM',
                                                      style: TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // To text
                                              Text(' to '),
                                              // End time
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    _selectTime(context, day, i, 'end');
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey),
                                                    ),
                                                    child: Text(
                                                      weeklySchedule[day]![i]['end'] ?? '05:00 PM',
                                                      style: TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button
                                        IconButton(
                                          icon: Icon(Icons.delete),
                                          onPressed: () => deleteSlot(day, i),
                                        ),
                                      ],
                                    ),
                                  SizedBox(height: 8),
                                  // Add Slot button
                                  ElevatedButton(
                                    onPressed: () => addSlot(day),
                                    child: Text('+ Add Slot'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
       Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: ElevatedButton(
    onPressed: () async {
      await _addTeamMember(); // Make sure to call it when the button is clicked
    },
    child: Text('Add TeamMember'),
    style: ElevatedButton.styleFrom(
      minimumSize: Size(double.infinity, 50), // Button takes full width
      backgroundColor: Colors.orange, // Customize the color if needed
      foregroundColor: Colors.white,
    ),
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
