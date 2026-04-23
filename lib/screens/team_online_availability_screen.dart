import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../widgets/multi_step_flow_header.dart';

class TeamOnlineAvailabilityScreen extends StatefulWidget {
  const TeamOnlineAvailabilityScreen.addMember({
    super.key,
    required this.branchId,
    required this.payload,
  })  : mode = TeamAvailabilityMode.addMember,
        userId = null,
        assignUserId = null,
        assignBranchServiceIds = null,
        assignSchedules = null,
        initialJoiningDate = null;

  const TeamOnlineAvailabilityScreen.assignUser({
    super.key,
    required this.branchId,
    required this.assignUserId,
    required this.assignBranchServiceIds,
    required this.assignSchedules,
    required this.initialJoiningDate,
  })  : mode = TeamAvailabilityMode.assignUser,
        userId = null,
        payload = null;

  const TeamOnlineAvailabilityScreen.editMember({
    super.key,
    required this.branchId,
    required this.userId,
    required this.payload,
  })  : mode = TeamAvailabilityMode.editMember,
        assignUserId = null,
        assignBranchServiceIds = null,
        assignSchedules = null,
        initialJoiningDate = null;

  final TeamAvailabilityMode mode;
  final int branchId;
  final Map<String, dynamic>? payload;
  final int? userId;
  final int? assignUserId;
  final List<int>? assignBranchServiceIds;
  final List<Map<String, dynamic>>? assignSchedules;
  final String? initialJoiningDate;

  @override
  State<TeamOnlineAvailabilityScreen> createState() =>
      _TeamOnlineAvailabilityScreenState();
}

enum TeamAvailabilityMode { addMember, assignUser, editMember }

class _TeamOnlineAvailabilityScreenState
    extends State<TeamOnlineAvailabilityScreen> {
  bool _allowOnlineBooking = true;
  bool _isSubmitting = false;
  DateTime? _joiningDate;

  @override
  void initState() {
    super.initState();
    if (widget.mode != TeamAvailabilityMode.assignUser) {
      _allowOnlineBooking =
          widget.payload?['allowOnlineBooking'] == true ? true : false;
    } else {
      _allowOnlineBooking = true;
      final raw = widget.initialJoiningDate;
      if (raw != null && raw.trim().isNotEmpty) {
        _joiningDate = DateTime.tryParse(raw.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAssign = widget.mode == TeamAvailabilityMode.assignUser;
    final isEdit = widget.mode == TeamAvailabilityMode.editMember;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText(
          isAssign ? 'Assign User' : 'Online Availability',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              MultiStepFlowHeader(
                currentStep: 4,
                useIcons: isAssign,
                steps: isAssign
                    ? const [
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
                      ]
                    : const [
                        FlowStepItem(
                          stepNumber: 1,
                          label: 'Personal Details',
                        ),
                        FlowStepItem(
                          stepNumber: 2,
                          label: 'Schedule',
                        ),
                        FlowStepItem(
                          stepNumber: 3,
                          label: 'Services',
                        ),
                        FlowStepItem(
                          stepNumber: 4,
                          label: 'Online Availability',
                        ),
                      ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 56,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 24),
                        if (isAssign) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${translateText('Joining Date')} *',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickJoiningDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFD1D5DB)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _joiningDate == null
                                          ? 'dd/mm/yyyy'
                                          : '${_joiningDate!.day.toString().padLeft(2, '0')}/${_joiningDate!.month.toString().padLeft(2, '0')}/${_joiningDate!.year}',
                                      style: TextStyle(
                                        color: _joiningDate == null
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                        Text(
                          translateText(
                            'Should this team member be available for online booking?',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ChoiceToggle(
                              label: 'Yes',
                              selected: _allowOnlineBooking,
                              onTap: () {
                                setState(() => _allowOnlineBooking = true);
                              },
                            ),
                            const SizedBox(width: 12),
                            _ChoiceToggle(
                              label: 'No',
                              selected: !_allowOnlineBooking,
                              onTap: () {
                                setState(() => _allowOnlineBooking = false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
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
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              translateText(
                                isAssign ? 'Submit' : (isEdit ? 'Save' : 'Add'),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickJoiningDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _submit() async {
    if (widget.mode == TeamAvailabilityMode.assignUser &&
        _joiningDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translateText('Please select a joining date')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (widget.mode == TeamAvailabilityMode.addMember) {
        final payload = Map<String, dynamic>.from(widget.payload ?? {});
        payload['allowOnlineBooking'] = _allowOnlineBooking;
        final response = await ApiService().addTeamMember(
          widget.branchId,
          payload,
        );
        if (!mounted) return;
        if (response['success'] == true) {
          Navigator.pop(context, true);
          return;
        }
        throw Exception(
          response['message']?.toString() ?? 'Failed to add team member',
        );
      }

      if (widget.mode == TeamAvailabilityMode.editMember) {
        final payload = Map<String, dynamic>.from(widget.payload ?? {});
        payload['allowOnlineBooking'] = _allowOnlineBooking;
        final response = await ApiService().updateTeamMember(
          branchId: widget.branchId,
          userId: widget.userId!,
          payload: payload,
        );
        if (!mounted) return;
        if (response['success'] == true) {
          Navigator.pop(context, true);
          return;
        }
        throw Exception(
          response['message']?.toString() ?? 'Failed to update team member',
        );
      }

      final joiningDate =
          '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}';
      final response = await ApiService().assignUserToBranch(
        widget.branchId,
        widget.assignUserId!,
        joiningDate,
        widget.assignSchedules!,
        widget.assignBranchServiceIds!,
        _allowOnlineBooking,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        Navigator.pop(context, true);
        return;
      }
      throw Exception(
        response['message']?.toString() ?? 'Failed to assign user',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ChoiceToggle extends StatelessWidget {
  const _ChoiceToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.starColor : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
