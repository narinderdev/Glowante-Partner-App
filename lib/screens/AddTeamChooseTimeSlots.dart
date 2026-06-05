import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting date/time
import 'SalonTeams.dart'; // Import TeamMember screen to navigate to
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'AddTeamSelectServices.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';

class _OperatingSlot {
  const _OperatingSlot({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

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
  bool _isLoadingOperatingSchedule = false;
  final Set<String> _closedDays = <String>{};
  final Map<String, List<_OperatingSlot>> _operatingSlotsByDay =
      <String, List<_OperatingSlot>>{};

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
    _prefillSchedules();
    _loadOperatingSchedule();
  }

  String _dayKey(String day) => day.trim().toLowerCase();

  bool _isClosedDay(String day) => _closedDays.contains(_dayKey(day));

  List<String> get _weekDays => weeklySchedule.keys.toList();

  Future<void> _loadOperatingSchedule() async {
    final directSchedule = widget.formData['operatingSchedule'] ??
        widget.formData['branchSchedule'] ??
        widget.formData['salonSchedule'];
    if (_applyOperatingSchedule(directSchedule)) return;

    final branchId = widget.formData['branchId'];
    final salonId = widget.formData['salonId'];
    if (branchId == null && salonId == null) return;

    setState(() => _isLoadingOperatingSchedule = true);
    try {
      final salonListResponse = await ApiService().getSalonListApi();
      final fromSalonList =
          _findScheduleInSalonList(salonListResponse, branchId, salonId);
      if (!_applyOperatingSchedule(fromSalonList) && branchId is int) {
        final branchResponse = await ApiService().getBranchDetail(branchId);
        _applyOperatingSchedule(_extractSchedule(branchResponse));
      }
    } catch (error) {
      debugPrint('Failed to load branch operating schedule: $error');
    } finally {
      if (mounted) setState(() => _isLoadingOperatingSchedule = false);
    }
  }

  dynamic _findScheduleInSalonList(
    Map<String, dynamic> response,
    dynamic branchId,
    dynamic salonId,
  ) {
    final rawSalons = response['data'];
    if (rawSalons is! List) return null;

    for (final rawSalon in rawSalons.whereType<Map>()) {
      final salon = Map<String, dynamic>.from(rawSalon);
      final branches = salon['branches'];
      if (branches is List) {
        for (final rawBranch in branches.whereType<Map>()) {
          final branch = Map<String, dynamic>.from(rawBranch);
          if (branch['id']?.toString() == branchId?.toString()) {
            return _extractSchedule(branch) ?? _extractSchedule(salon);
          }
        }
      }

      if (salon['id']?.toString() == salonId?.toString()) {
        return _extractSchedule(salon);
      }
    }

    return null;
  }

  dynamic _extractSchedule(dynamic value) {
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    for (final key in const ['schedule', 'schedules', 'workingHours']) {
      if (map[key] != null) return map[key];
    }
    for (final key in const ['data', 'branch', 'salon']) {
      final nested = map[key];
      if (nested is Map) {
        final schedule = _extractSchedule(nested);
        if (schedule != null) return schedule;
      }
    }
    return null;
  }

  bool _applyOperatingSchedule(dynamic rawSchedule) {
    final schedule = _extractSchedule(rawSchedule);
    final operatingSlots = _operatingSlotsFromSchedule(schedule);
    if (operatingSlots == null) return false;
    final closedDays = _weekDays
        .map(_dayKey)
        .where((day) => !operatingSlots.containsKey(day))
        .toSet();

    if (!mounted) {
      _operatingSlotsByDay
        ..clear()
        ..addAll(operatingSlots);
      _closedDays
        ..clear()
        ..addAll(closedDays);
      for (final day in _closedDays) {
        weeklySchedule[_displayDay(day)]?.clear();
      }
      _fillEmptyDaysFromOperatingSlots(operatingSlots);
      return true;
    }

    setState(() {
      _operatingSlotsByDay
        ..clear()
        ..addAll(operatingSlots);
      _closedDays
        ..clear()
        ..addAll(closedDays);
      for (final day in _closedDays) {
        weeklySchedule[_displayDay(day)]?.clear();
      }
      _fillEmptyDaysFromOperatingSlots(operatingSlots);
    });
    return true;
  }

  Map<String, List<_OperatingSlot>>? _operatingSlotsFromSchedule(
    dynamic schedule,
  ) {
    if (schedule is Map) {
      final result = <String, List<_OperatingSlot>>{};
      var foundAnyDay = false;
      for (final day in _weekDays) {
        final key = _dayKey(day);
        final value = schedule[key] ?? schedule[day];
        if (value == null) continue;
        foundAnyDay = true;
        final slots = _slotsFromValue(value);
        if (slots.isNotEmpty) {
          result[key] = slots;
        }
      }
      return foundAnyDay ? result : null;
    }

    if (schedule is List) {
      final result = <String, List<_OperatingSlot>>{};
      var foundAnyDay = false;
      for (final item in schedule.whereType<Map>()) {
        final day = item['day']?.toString().trim().toLowerCase();
        if (day == null || day.isEmpty) continue;
        foundAnyDay = true;
        final slots = _slotsFromValue(item);
        if (slots.isNotEmpty) {
          result[day] = slots;
        }
      }
      return foundAnyDay ? result : null;
    }

    return null;
  }

  List<_OperatingSlot> _slotsFromValue(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(_slotFromMap)
          .whereType<_OperatingSlot>()
          .toList();
    }

    if (value is Map) {
      final slots = value['slots'];
      if (slots is List) {
        return slots
            .whereType<Map>()
            .map(_slotFromMap)
            .whereType<_OperatingSlot>()
            .toList();
      }
      final directSlot = _slotFromMap(value);
      return directSlot == null ? const [] : [directSlot];
    }

    return const [];
  }

  _OperatingSlot? _slotFromMap(Map value) {
    final start = _parseTimeToMinutes(
      (value['startTime'] ?? value['start'] ?? '').toString(),
    );
    final end = _parseTimeToMinutes(
      (value['endTime'] ?? value['end'] ?? '').toString(),
    );
    if (start == null || end == null || end <= start) return null;
    return _OperatingSlot(startMinutes: start, endMinutes: end);
  }

  void _fillEmptyDaysFromOperatingSlots(
    Map<String, List<_OperatingSlot>> operatingSlots,
  ) {
    for (final entry in operatingSlots.entries) {
      final displayDay = _displayDay(entry.key);
      if ((weeklySchedule[displayDay] ?? const []).isNotEmpty) {
        weeklySchedule[displayDay] = weeklySchedule[displayDay]!
            .map((slot) => _normalizeSlotWithinDay(displayDay, slot))
            .toList();
        continue;
      }
      weeklySchedule[displayDay] = entry.value
          .map(
            (slot) => {
              'start': _formatMinutes(slot.startMinutes),
              'end': _formatMinutes(slot.endMinutes),
            },
          )
          .toList();
    }
  }

  Map<String, String> _normalizeSlotWithinDay(
    String day,
    Map<String, String> slot,
  ) {
    final options = _timeOptionsForDay(day);
    if (options.isEmpty) return slot;

    var start = slot['start'] ?? options.first;
    var end = slot['end'] ?? options.last;
    if (!options.contains(start)) start = options.first;
    if (!options.contains(end)) end = options.last;

    final startMinutes = _parseTimeToMinutes(start);
    final endMinutes = _parseTimeToMinutes(end);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return {'start': options.first, 'end': options.last};
    }
    return {'start': start, 'end': end};
  }

  String _displayDay(String dayKey) {
    return _weekDays.firstWhere(
      (day) => _dayKey(day) == dayKey,
      orElse: () => dayKey[0].toUpperCase() + dayKey.substring(1),
    );
  }

  String _normalizeDisplayTime(String input) {
    return _formatMinutes(_parseTimeToMinutes(input) ?? 8 * 60);
  }

  int? _parseTimeToMinutes(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final twelveMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (twelveMatch != null) {
      var hour = int.parse(twelveMatch.group(1)!);
      final minute = int.parse(twelveMatch.group(2)!);
      final suffix = twelveMatch.group(3)!.toUpperCase();
      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }

    final twentyFourWithSeconds =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (twentyFourWithSeconds != null) {
      final hour = int.parse(twentyFourWithSeconds.group(1)!);
      final minute = int.parse(twentyFourWithSeconds.group(2)!);
      return hour * 60 + minute;
    }
    return null;
  }

  String _formatMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = ((hour + 11) % 12) + 1;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  List<String> _timeOptionsForDay(String day) {
    final slots = _operatingSlotsByDay[_dayKey(day)];
    if (slots == null || slots.isEmpty) return const [];
    final values = <String>[];
    for (final slot in slots) {
      for (var minute = slot.startMinutes;
          minute <= slot.endMinutes;
          minute += 15) {
        values.add(_formatMinutes(minute));
      }
    }
    return values.toSet().toList();
  }

  List<String> _timeOptionsForField(
    String day,
    int index,
    String timeType,
  ) {
    final options = _timeOptionsForDay(day);
    if (options.isEmpty) return const [];
    final slot = weeklySchedule[day]?[index];
    final pairedTime = slot == null
        ? null
        : (timeType == 'start' ? slot['end'] : slot['start']);
    final pairedMinutes =
        pairedTime == null ? null : _parseTimeToMinutes(pairedTime);

    return options.where((option) {
      final minutes = _parseTimeToMinutes(option);
      if (minutes == null || pairedMinutes == null) return true;
      return timeType == 'start'
          ? minutes < pairedMinutes
          : minutes > pairedMinutes;
    }).toList();
  }

  void _prefillSchedules() {
    final rawSchedules = widget.formData['schedules'];
    if (rawSchedules is! List || rawSchedules.isEmpty) return;

    for (final raw in rawSchedules.whereType<Map>()) {
      final day = (raw['day'] ?? '').toString().trim().toLowerCase();
      if (day.isEmpty) continue;
      final normalizedDay = '${day[0].toUpperCase()}${day.substring(1)}';
      if (!weeklySchedule.containsKey(normalizedDay)) continue;
      weeklySchedule[normalizedDay] = [
        {
          'start': _normalizeDisplayTime(
            (raw['startTime'] ?? raw['start'] ?? '').toString(),
          ),
          'end': _normalizeDisplayTime(
            (raw['endTime'] ?? raw['end'] ?? '').toString(),
          ),
        },
      ];
    }
  }

  // Method to add a slot to a specific day
  void addSlot(String day) {
    if (_isClosedDay(day)) {
      _showClosedDayMessage(day);
      return;
    }
    final operatingSlots = _operatingSlotsByDay[_dayKey(day)];
    final start = operatingSlots?.isNotEmpty == true
        ? _formatMinutes(operatingSlots!.first.startMinutes)
        : '08:00 AM';
    final end = operatingSlots?.isNotEmpty == true
        ? _formatMinutes(operatingSlots!.first.endMinutes)
        : '08:00 PM';
    setState(() {
      weeklySchedule[day]?.add({
        'start': start,
        'end': end,
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
      final slot = weeklySchedule[day]?[index];
      if (slot == null) return;
      final start = _parseTimeToMinutes(slot['start'] ?? '');
      final end = _parseTimeToMinutes(slot['end'] ?? '');
      final options = _timeOptionsForDay(day);
      if (start == null || end == null || options.isEmpty || end > start) {
        return;
      }
      if (timeType == 'start') {
        final nextEnd = options.firstWhere(
          (option) => (_parseTimeToMinutes(option) ?? 0) > start,
          orElse: () => options.last,
        );
        slot['end'] = nextEnd;
      } else {
        final previousStart = options.lastWhere(
          (option) => (_parseTimeToMinutes(option) ?? 0) < end,
          orElse: () => options.first,
        );
        slot['start'] = previousStart;
      }
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
          if (day != 'Monday' && !_isClosedDay(day)) {
            slots
              ..clear()
              ..addAll(
                mondaySlots.map(
                  (slot) => _normalizeSlotWithinDay(
                    day,
                    Map<String, String>.from(slot),
                  ),
                ),
              );
          }
        });
      });
    }
  }

  void _showClosedDayMessage(String day) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translateText('$day is closed for appointments.'),
        ),
      ),
    );
  }

  Widget _closedDayNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEADCCD)),
      ),
      child: Text(
        translateText('Branch closed for appointments'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF9A8E84),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _timeDropdownField(
    String day,
    int index,
    String timeType,
  ) {
    final currentValue = weeklySchedule[day]?[index][timeType];
    final options = _timeOptionsForField(day, index, timeType);
    final safeValue = options.contains(currentValue) ? currentValue : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
      hint: Text(
        currentValue ?? translateText('Select time'),
        style: const TextStyle(fontSize: 14),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        updateTime(day, index, timeType, value);
      },
    );
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
          if (_isClosedDay(day)) return;
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
          if (_isClosedDay(day)) return;
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
        "isEdit": widget.formData['isEdit'] == true,
        "userId": widget.formData['userId'],
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
        "allowOnlineBooking": widget.formData['allowOnlineBooking'] ?? true,
        "branchServiceIds": widget.formData['branchServiceIds'] ?? const [],
        "userBranchServices": widget.formData['userBranchServices'] ?? const [],
        "address": widget.formData['address'],
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
                MultiStepFlowHeader(
                  currentStep: 2,
                  steps: const [
                    FlowStepItem(stepNumber: 1, label: 'Personal Details'),
                    FlowStepItem(stepNumber: 2, label: 'Schedule'),
                    FlowStepItem(stepNumber: 3, label: 'Services'),
                    FlowStepItem(
                      stepNumber: 4,
                      label: 'Online Availability',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  translateText('Set Weekly Working Hours'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold, // Added font weight
                  ),
                ),
                if (_isLoadingOperatingSchedule) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.starColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        translateText('Checking branch closed days...'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
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
                            if (_isClosedDay('Monday'))
                              _closedDayNotice()
                            else ...[
                              // Display message if Monday has no time slots
                              if (weeklySchedule['Monday']?.isEmpty ?? true)
                                Text(translateText('No time slots added')),

                              // Display slots for Monday
                              for (var i = 0;
                                  i < (weeklySchedule['Monday']?.length ?? 0);
                                  i++)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _timeDropdownField(
                                              'Monday',
                                              i,
                                              'start',
                                            ),
                                          ),
                                          // To text
                                          Text(' to '),
                                          // End time
                                          Expanded(
                                            child: _timeDropdownField(
                                              'Monday',
                                              i,
                                              'end',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () => deleteSlot('Monday', i),
                                    ),
                                  ],
                                ),
                              ElevatedButton(
                                onPressed: () => addSlot('Monday'),
                                child: Text(translateText('+ Add Slot')),
                              ),
                            ],
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
                                    if (_isClosedDay(day))
                                      _closedDayNotice()
                                    else ...[
                                      // Display slots for each day
                                      if (weeklySchedule[day]!.isEmpty)
                                        Text(translateText(
                                            'No time slots added')),
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
                                                    child: _timeDropdownField(
                                                      day,
                                                      i,
                                                      'start',
                                                    ),
                                                  ),
                                                  // To text
                                                  Text(' to '),
                                                  // End time
                                                  Expanded(
                                                    child: _timeDropdownField(
                                                      day,
                                                      i,
                                                      'end',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Delete button
                                            IconButton(
                                              icon: Icon(Icons.delete),
                                              onPressed: () =>
                                                  deleteSlot(day, i),
                                            ),
                                          ],
                                        ),
                                      SizedBox(height: 8),
                                      // Add Slot button
                                      ElevatedButton(
                                        onPressed: () => addSlot(day),
                                        child:
                                            Text(translateText('+ Add Slot')),
                                      ),
                                    ],
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
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: const Color(0xFFE5E7EB),
                            foregroundColor: const Color(0xFF374151),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(translateText('Previous')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  await _goToSelectServices();
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: AppColors.starColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  translateText('Next'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
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
      ),
    );
  }
}
