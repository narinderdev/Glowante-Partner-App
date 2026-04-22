import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting date/time
import 'AddTeam.dart'; // Import AddTeam screen to navigate back
import 'SalonTeams.dart'; // Import TeamMember screen to navigate to
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'AddTeamSelectServices.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class AddTeamChooseTimeSlot extends StatefulWidget {
  final Map<String, dynamic> formData;
  const AddTeamChooseTimeSlot({Key? key, required this.formData})
      : super(key: key);

  @override
  _ChooseTimeSlotState createState() => _ChooseTimeSlotState();
}

class _ChooseTimeSlotState extends State<AddTeamChooseTimeSlot> {
  // Map to store weekly schedule with day as key
  late Map<String, List<Map<String, String>>> weeklySchedule;
  late Map<String, List<Map<String, String>>>
      mondaySchedule; // For tracking Monday's schedule separately
  bool _isSubmitting = false;
  bool _useSalonHours = false;

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
        'start': '08:00 AM',
        'end': '08:00 PM',
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
  // void copyMondayScheduleToAll() {
  //   // Check if Monday has any slots added
  //   if (weeklySchedule['Monday']!.isEmpty) {
  //     // Show an alert if no time slots are added for Monday
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: Text('Alert'),
  //           content: Text('Please add time slots for monday first.'),
  //           actions: <Widget>[
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop(); // Close the dialog
  //               },
  //               child: Text('OK'),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   } else {
  //     setState(() {
  //       final mondaySchedule =
  //           List<Map<String, String>>.from(weeklySchedule['Monday']!);
  //       weeklySchedule.forEach((key, value) {
  //         if (key != 'Monday') {
  //           value.clear();
  //           value.addAll(
  //               mondaySchedule); // Ensure you're adding a List<Map<String, String>> type
  //         }
  //       });
  //     });
  //   }
  // }
  void copyMondayScheduleToAll() {
    if (weeklySchedule['Monday']!.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Alert'),
            content: const Text('Please add time slots for Monday first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        // ✅ Deep clone of Monday’s slots (each map is new)
        final mondaySlots = weeklySchedule['Monday']!
            .map((slot) => Map<String, String>.from(slot))
            .toList();

        weeklySchedule.forEach((day, slots) {
          if (day != 'Monday') {
            slots
              ..clear()
              ..addAll(
                // ✅ Each day gets its own *fresh copy* of each slot
                mondaySlots.map((slot) => Map<String, String>.from(slot)),
              );
          }
        });
      });
    }
  }

  // Function to show the time picker and update the time
  Future<void> _selectTime(
      BuildContext context, String day, int index, String timeType) async {
    TimeOfDay initialTime = TimeOfDay(hour: 9, minute: 0); // Default to 9:00 AM

    // Show the time picker dialog
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      String formattedTime =
          pickedTime.format(context); // Format the time as string
      updateTime(
          day, index, timeType, formattedTime); // Update the selected time
    }
  }

  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _addTeamMember() async {
    setState(() => _isSubmitting = true); // show loader

    try {
      // Gather schedule data
      final List<Map<String, String>> scheduleData = [];
      if (!_useSalonHours) {
        weeklySchedule.forEach((day, slots) {
          for (final slot in slots) {
            final start = slot['start']?.trim();
            final end = slot['end']?.trim();

            // Only include if both start and end times are set manually
            if (start != null &&
                end != null &&
                start.isNotEmpty &&
                end.isNotEmpty) {
              scheduleData.add({
                'day': day.toLowerCase(),
                'startTime': start,
                'endTime': end,
              });
            }
          }
        });
      }

      // Prepare payload
      final dynamic rawJoiningDate = widget.formData['joiningDate'];
      String? formattedJoiningDate;
      if (rawJoiningDate is DateTime) {
        formattedJoiningDate = DateFormat('yyyy-MM-dd').format(rawJoiningDate);
      } else if (rawJoiningDate is String && rawJoiningDate.isNotEmpty) {
        formattedJoiningDate = rawJoiningDate;
      }

      final List<dynamic> rawRoles =
          widget.formData['roles'] as List? ?? const [];
      final List<dynamic> rawSpecs = (widget.formData['specialities'] ??
              widget.formData['specializations']) as List? ??
          const [];

      Map<String, dynamic> teamMemberData = {
        "phoneNumber": widget.formData['phoneNumber'],
        "firstName": _capitalize(widget.formData['firstName']),
        "lastName": _capitalize(widget.formData['lastName']),
        "email": widget.formData['email']?.toString().toLowerCase(),
        "gender": (widget.formData['gender'] ?? '').toString().toLowerCase(),
        "joiningDate": formattedJoiningDate,
        "info": widget.formData['brief'],
        "roles": List<String>.from(rawRoles.map((e) => e.toString())),
        "specialities": List<String>.from(rawSpecs.map((e) => e.toString())),
        "schedules": scheduleData,
        "useSalonHours": _useSalonHours,
        "otp": widget.formData['otp']?.toString(),
      };

      // Call API
      ApiService apiService = ApiService();
      final int branchId = widget.formData['branchId'] as int;
      final Map<String, dynamic> response =
          await apiService.addTeamMember(branchId, teamMemberData);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team member added successfully')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TeamScreen()),
          (route) => false,
        );
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to add team member');
      }
    } catch (e) {
      print('Unexpected error: $e');
      _showErrorDialog('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false); // hide loader
    }
  }

  Future<void> _goToSelectServices() async {
    // show loader
    setState(() => _isSubmitting = true);

    try {
      // Build schedules just like before
      final List<Map<String, String>> scheduleData = [];
      if (!_useSalonHours) {
        weeklySchedule.forEach((day, slots) {
          for (final slot in slots) {
            final start = slot['start']?.trim();
            final end = slot['end']?.trim();
            if (start != null &&
                end != null &&
                start.isNotEmpty &&
                end.isNotEmpty) {
              scheduleData.add({
                'day': day.toLowerCase(),
                'startTime': start,
                'endTime': end,
              });
            }
          }
        });
      }

      // Format joining date like before
      final dynamic rawJoiningDate = widget.formData['joiningDate'];
      String? formattedJoiningDate;
      if (rawJoiningDate is DateTime) {
        formattedJoiningDate = DateFormat('yyyy-MM-dd').format(rawJoiningDate);
      } else if (rawJoiningDate is String && rawJoiningDate.isNotEmpty) {
        formattedJoiningDate = rawJoiningDate;
      }

      final List<dynamic> rawRoles =
          widget.formData['roles'] as List? ?? const [];
      final List<dynamic> rawSpecs = (widget.formData['specialities'] ??
              widget.formData['specializations']) as List? ??
          const [];

      // Build the same payload you used for the API
      final Map<String, dynamic> teamMemberData = {
        "phoneNumber": widget.formData['phoneNumber'],
        "firstName": widget.formData['firstName'],
        "lastName": widget.formData['lastName'],
        "email": widget.formData['email'],
        "gender": (widget.formData['gender'] ?? '').toString().toLowerCase(),
        "joiningDate": formattedJoiningDate,
        "info": widget.formData['brief'],
        "roles": List<String>.from(rawRoles.map((e) => e.toString())),
        "specialities": List<String>.from(rawSpecs.map((e) => e.toString())),
        "schedules": scheduleData,
        "useSalonHours": _useSalonHours,
        "otp": widget.formData['otp']?.toString(),
        "branchId": widget.formData['branchId'],
        // If you also need to pass the original form data (e.g., image file), include it:
        "profilePictureUrl": widget.formData['profilePictureUrl'],

        // Add anything else your next screen needs…
      };

      if (!mounted) return;
      print(
          '==================== TEAM MEMBER PAYLOAD SENT TO SELECT SERVICES ====================');
      teamMemberData.forEach((key, value) {
        print('$key: $value');
      });
      // Navigate to the services selection screen with the payload
      final refresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTeamSelectServices(teamMemberData: teamMemberData),
        ),
      );

      if (!mounted) return;
      if (refresh == true) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      // optional: surface a toast/dialog
      _showErrorDialog('Something went wrong while preparing data.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Response'), // Title of the dialog
          content: Text(
              message), // This will display the message from the API (e.g., "Invalid OTP")
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
    final specializations =
        widget.formData['specializations'] ?? widget.formData['specialities'];
    final joiningDate = widget.formData['joiningDate'];
    final brief = widget.formData['brief'];
    final profileImage = widget.formData['profileImage'];
    final branchId = widget.formData['branchId'];

    // Format the joiningDate
    String formattedJoiningDate = '';
    if (joiningDate is DateTime) {
      formattedJoiningDate = DateFormat('yyyy-MM-dd').format(joiningDate);
    } else if (joiningDate is String && joiningDate.isNotEmpty) {
      formattedJoiningDate = joiningDate;
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false; // Prevent the default back action
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: buildProfileSubpageAppBar(
          title: translateText('Add TimeSlots'),
        ),
        body: SingleChildScrollView(
          // Wrap the entire body in SingleChildScrollView for scrolling
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Set Weekly Working Hours'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold, // Added font weight
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useSalonHours,
                  onChanged: (value) {
                    setState(() {
                      _useSalonHours = value ?? false;
                    });
                  },
                  title: Text(translateText('Use salon open & close time')),
                  subtitle: Text(
                    translateText(
                        'Apply the salon\'s operating hours instead of defining custom time slots.'),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_useSalonHours)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Salon operating hours will be used for this team member. Uncheck to set custom slots.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                if (!_useSalonHours) ...[
                  const SizedBox(height: 16),

                  // Display Monday's working hours and slots as a card
                  Container(
                    width: double
                        .infinity, // Ensure consistent width across all cards
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
                              translateText('Monday'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w600, // Added font weight
                              ),
                            ),
                            SizedBox(height: 8),
                            // Display message if Monday has no time slots
                            if (weeklySchedule[translateText('Monday')]
                                    ?.isEmpty ??
                                true)
                              Text(translateText('No time slots added')),

                            // Display slots for Monday
                            for (var i = 0;
                                i <
                                    (weeklySchedule[translateText('Monday')]
                                            ?.length ??
                                        0);
                                i++)
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
                                              _selectTime(context, 'Monday', i,
                                                  'start');
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.grey),
                                              ),
                                              child: Text(
                                                weeklySchedule['Monday']![i]
                                                        ['start'] ??
                                                    '08:00 AM',
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
                                              _selectTime(
                                                  context, 'Monday', i, 'end');
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.grey),
                                              ),
                                              child: Text(
                                                weeklySchedule['Monday']![i]
                                                        ['end'] ??
                                                    '08:00 PM',
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
                              child: Text(translateText('+ Add Slot')),
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
                      child: Text(
                          translateText('Copy Monday schedule to all days')),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display each day's working hours and slots
                  for (var day in weeklySchedule.keys)
                    if (day !=
                        'Monday') // Skip Monday since it's already displayed above
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double
                                .infinity, // Ensure consistent width across all cards
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
                                        fontWeight: FontWeight
                                            .w600, // Added font weight
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    // Display slots for each day
                                    if (weeklySchedule[day]!.isEmpty)
                                      Text(
                                          translateText('No time slots added')),
                                    for (var i = 0;
                                        i < weeklySchedule[day]!.length;
                                        i++)
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
                                                      _selectTime(context, day,
                                                          i, 'start');
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 10,
                                                              horizontal: 8),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: Colors.grey),
                                                      ),
                                                      child: Text(
                                                        weeklySchedule[day]![i]
                                                                ['start'] ??
                                                            '08:00 AM',
                                                        style: TextStyle(
                                                            fontSize: 16),
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
                                                      _selectTime(context, day,
                                                          i, 'end');
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 10,
                                                              horizontal: 8),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: Colors.grey),
                                                      ),
                                                      child: Text(
                                                        weeklySchedule[day]![i]
                                                                ['end'] ??
                                                            '08:00 PM',
                                                        style: TextStyle(
                                                            fontSize: 16),
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
                                      child: Text(translateText('+ Add Slot')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            await _goToSelectServices(); // 🔁 was _addTeamMember()
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            translateText('Next'), // 🔁 changed label
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
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
