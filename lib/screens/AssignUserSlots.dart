// lib/screens/AssignUserSlots.dart
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/widgets/step_header.dart';
import '../utils/api_service.dart';                  // ✅ FIX: import ApiService
import 'TeamMemberDetails.dart';                    // for navigation after success
import 'SalonTeams.dart';
class AssignUserSlot extends StatefulWidget {
  final int salonId;
  final int branchId;
  final int userId;
  final String joinedAt;
  final List<int> selectedServiceIds;

  // ✅ you declared these as required earlier, so keep them and pass them in
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> salons;

  const AssignUserSlot({
    Key? key,
    required this.salonId,
    required this.branchId,
    required this.userId,
    required this.joinedAt,
    required this.selectedServiceIds,
    required this.member,
    required this.salons,
  }) : super(key: key);

  @override
  State<AssignUserSlot> createState() => _AssignUserSlotState();
}

class _AssignUserSlotState extends State<AssignUserSlot> {
  late Map<String, List<Map<String, String>>> weeklySchedule;
  bool isSubmitting = false; // ✅ loader flag

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
  }

  void _addSlot(String day) {
    setState(() {
      weeklySchedule[day]!.add({'start': '09:00 AM', 'end': '05:00 PM'});
    });
  }

  void _deleteSlot(String day, int index) {
    setState(() => weeklySchedule[day]!.removeAt(index));
  }

  void _updateTime(String day, int index, String key, String newTime) {
    setState(() => weeklySchedule[day]![index][key] = newTime);
  }

  Future<void> _pickTime(BuildContext context, String day, int index, String key) async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) _updateTime(day, index, key, picked.format(context));
  }

  void _copyMondayToAll() {
    if (weeklySchedule['Monday']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add time slots for Monday first.')),
      );
      return;
    }
    setState(() {
      final mon = List<Map<String, String>>.from(weeklySchedule['Monday']!);
      weeklySchedule.forEach((day, list) {
        if (day != 'Monday') {
          list
            ..clear()
            ..addAll(List<Map<String, String>>.from(mon));
        }
      });
    });
  }

  Widget _timeBox(String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text),
      );

  Widget _buildDayCard(String day) {
    final slots = weeklySchedule[day]!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (slots.isEmpty) const Text('No time slots added', style: TextStyle(color: Colors.black54)),
            for (var i = 0; i < slots.length; i++)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(context, day, i, 'start'),
                      child: _timeBox(slots[i]['start'] ?? '09:00 AM'),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('to')),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(context, day, i, 'end'),
                      child: _timeBox(slots[i]['end'] ?? '05:00 PM'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSlot(day, i),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => _addSlot(day), child: const Text('+ Add Slot')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAssign() async {
    // Build schedules for API
    final schedules = <Map<String, dynamic>>[];
    weeklySchedule.forEach((day, list) {
      for (final slot in list) {
        schedules.add({
          'day': day.toLowerCase(),
          'startTime': slot['start'] ?? '09:00 AM',
          'endTime': slot['end'] ?? '05:00 PM',
        });
      }
    });

    // 🔎 Log payload (optional)
    final payloadPreview = {
      'userId': widget.userId,
      'joiningDate': widget.joinedAt,
      'schedules': schedules,
      'branchServiceIds': widget.selectedServiceIds,
    };
    print('➡️ Final Payload for API: $payloadPreview');

    setState(() => isSubmitting = true);
    try {
      final resp = await ApiService().assignUserToBranch(
        widget.branchId,
        widget.userId,
        widget.joinedAt,
        schedules,
        widget.selectedServiceIds,
      );

      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User assigned successfully')),
        );

        // ✅ Keep the back button by pushing (not replacing) to TeamMemberDetails.
       Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TeamScreen(),
  ),
);
      } else {
        throw Exception(resp['message'] ?? 'Failed to assign user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Default AppBar shows a back arrow automatically
      appBar: AppBar(title: const Text('Assign User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepHeader(currentStep: 3),

            // Quick context
            // Text('User ID: ${widget.userId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Joined At: ${widget.joinedAt}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Salon ID: ${widget.salonId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Branch ID: ${widget.branchId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // const SizedBox(height: 8),
            // const Text('Branch Service IDs:', style: TextStyle(fontWeight: FontWeight.w600)),
            // Text(widget.selectedServiceIds.toString()),
            const SizedBox(height: 16),

            const Text('Set Weekly Working Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildDayCard('Monday'),
            ElevatedButton(onPressed: _copyMondayToAll, child: const Text('Copy Monday to All Days')),
            _buildDayCard('Tuesday'),
            _buildDayCard('Wednesday'),
            _buildDayCard('Thursday'),
            _buildDayCard('Friday'),
            _buildDayCard('Saturday'),
            _buildDayCard('Sunday'),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _onAssign, // ✅ loader disables button
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Assign User'),
          ),
        ),
      ),
    );
  }
}
