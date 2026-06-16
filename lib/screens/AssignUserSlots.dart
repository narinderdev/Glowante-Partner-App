// lib/screens/AssignUserSlots.dart
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../widgets/multi_step_flow_header.dart';
import 'team_online_availability_screen.dart';

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

  Future<void> _pickTime(
      BuildContext context, String day, int index, String key) async {
    final picked = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) _updateTime(day, index, key, picked.format(context));
  }

  void _copyMondayToAll() {
    if (weeklySchedule['Monday']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(translateText('Please add time slots for Monday first.'))),
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
            Text(day,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (slots.isEmpty)
              Text(translateText('No time slots added'),
                  style: TextStyle(color: Colors.black54)),
            for (var i = 0; i < slots.length; i++)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(context, day, i, 'start'),
                      child: _timeBox(slots[i]['start'] ?? '09:00 AM'),
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(translateText('to'))),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(context, day, i, 'end'),
                      child: _timeBox(slots[i]['end'] ?? '05:00 PM'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSlot(day, i),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () => _addSlot(day),
                  child: Text(translateText('+ Add Slot'))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToCompleteStep() async {
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

    final payloadPreview = {
      'userId': widget.userId,
      'joiningDate': widget.joinedAt,
      'allowOnlineBooking': true,
      'schedules': schedules,
      'branchServiceIds': widget.selectedServiceIds,
    };
    print('➡️ Final Payload for API: $payloadPreview');

    setState(() => isSubmitting = true);
    try {
      final assigned = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TeamOnlineAvailabilityScreen.assignUser(
            branchId: widget.branchId,
            assignUserId: widget.userId,
            assignBranchServiceIds: widget.selectedServiceIds,
            assignSchedules: schedules,
            initialJoiningDate: widget.joinedAt,
          ),
        ),
      );
      if (assigned == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${translateText('Error')}: $e")),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildProfileSubpageAppBar(
        title: translateText('Assign User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MultiStepFlowHeader(
              currentStep: 3,
              useIcons: true,
              steps: const [
                FlowStepItem(
                  stepNumber: 1,
                  label: 'Select Branches',
                  icon: Icons.place_outlined,
                ),
                FlowStepItem(
                  stepNumber: 2,
                  label: 'Choose Services',
                  icon: Icons.handyman_outlined,
                ),
                FlowStepItem(
                  stepNumber: 3,
                  label: 'Schedule',
                  icon: Icons.calendar_today_outlined,
                ),
                FlowStepItem(
                  stepNumber: 4,
                  label: 'Complete',
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick context
            // Text('User ID: ${widget.userId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Joined At: ${widget.joinedAt}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Salon ID: ${widget.salonId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // Text('Branch ID: ${widget.branchId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            // SizedBox(height: 8),
            // const Text('Branch Service IDs:', style: TextStyle(fontWeight: FontWeight.w600)),
            // Text(widget.selectedServiceIds.toString()),
            SizedBox(height: 16),

            Text(translateText('Set Weekly Working Hours'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildDayCard('Monday'),
            ElevatedButton(
                onPressed: _copyMondayToAll,
                child: Text(translateText('Copy Monday to All Days'))),
            _buildDayCard('Tuesday'),
            _buildDayCard('Wednesday'),
            _buildDayCard('Thursday'),
            _buildDayCard('Friday'),
            _buildDayCard('Saturday'),
            _buildDayCard('Sunday'),
            SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFE5E7EB),
                    foregroundColor: const Color(0xFF374151),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(translateText('Previous')),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _goToCompleteStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(translateText('Next')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
