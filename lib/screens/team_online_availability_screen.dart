import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import 'assign_user_flow_constants.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../widgets/multi_step_flow_header.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  String _friendlyErrorMessage(Object error) {
    var text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd > jsonStart) {
      final jsonText = text.substring(jsonStart, jsonEnd + 1);
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map && decoded['message'] != null) {
          final message = decoded['message'];
          if (message is List) return message.join('\n');
          return message.toString();
        }
      } catch (_) {}
    }

    text = text
        .replaceFirst(RegExp(r'^Failed to update team member:\s*'), '')
        .replaceFirst(RegExp(r'^Failed to add team member:\s*'), '')
        .replaceFirst(RegExp(r'^Failed to assign user:\s*'), '')
        .trim();
    return text.isEmpty ? translateText('Something went wrong') : text;
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
                      onPressed: _isSubmitting ? null : _submit,
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
                              translateText(
                                isAssign ? 'Submit' : (isEdit ? 'Save' : 'Add'),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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

  String _to24h(String input) {
    final s = input.trim();

    final reg24 = RegExp(r'^(\d{1,2}):([0-5]\d)(?::([0-5]\d))?$');
    final match24 = reg24.firstMatch(s);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1) ?? '');
      final min = int.tryParse(match24.group(2) ?? '');
      final second = int.tryParse(match24.group(3) ?? '') ?? 0;
      if (hour == null ||
          min == null ||
          hour < 0 ||
          hour > 23 ||
          min < 0 ||
          min > 59 ||
          second < 0 ||
          second > 59) {
        return s;
      }

      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
    }

    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
    final m = reg12.firstMatch(s);

    if (m != null) {
      int h = int.parse(m.group(1)!);
      final min = int.parse(m.group(2)!);
      final mer = m.group(3)!.toUpperCase();

      if (h == 12) h = 0;
      if (mer == 'PM') h += 12;

      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00';
    }

    return s;
  }

  Future<void> _pickJoiningDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _submit() async {
    debugPrint(
      '[TeamOnlineAvailability] Save tapped mode=${widget.mode.name} '
      'branchId=${widget.branchId} userId=${widget.userId} '
      'assignUserId=${widget.assignUserId} allowOnline=$_allowOnlineBooking',
    );

    if (widget.mode == TeamAvailabilityMode.assignUser &&
        _joiningDate == null) {
      debugPrint(
        '[TeamOnlineAvailability] Save blocked: joining date missing',
      );
      Fluttertoast.showToast(
          msg: translateText('Please select a joining date'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // if (widget.mode == TeamAvailabilityMode.editMember) {
      //   final payload = Map<String, dynamic>.from(widget.payload ?? {});
      //   payload['allowOnlineBooking'] = _allowOnlineBooking;
      //   final response = await ApiService().updateTeamMember(
      //     branchId: widget.branchId,
      //     userId: widget.userId!,
      //     payload: payload,
      //   );
      //   if (!mounted) return;
      //   if (response['success'] == true) {
      //     Navigator.pop(context, true);
      //     return;
      //   }
      //   throw Exception(
      //     response['message']?.toString() ?? 'Failed to update team member',
      //   );
      // }
      if (widget.mode == TeamAvailabilityMode.addMember) {
        final payload = Map<String, dynamic>.from(widget.payload ?? {});
        payload['allowOnlineBooking'] = _allowOnlineBooking;
        payload['experience'] = int.tryParse(
              payload['experience']?.toString() ?? '',
            ) ??
            0;
        debugPrint(
          '[TeamOnlineAvailability] Calling addTeamMember '
          'branchId=${widget.branchId} payload=${jsonEncode(payload)}',
        );
        final response = await ApiService().addTeamMember(
          widget.branchId,
          payload,
        );
        debugPrint(
          '[TeamOnlineAvailability] addTeamMember response=$response',
        );

        if (!mounted) return;

        if (response['success'] == true) {
          Fluttertoast.showToast(
              msg: translateText('Team member added successfully'));

          await Future.delayed(const Duration(milliseconds: 700));

          if (!mounted) return;
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
        debugPrint(
          '[TeamOnlineAvailability] Calling updateTeamMember '
          'branchId=${widget.branchId} userId=${widget.userId} '
          'payload=${jsonEncode(payload)}',
        );

        final response = await ApiService().updateTeamMember(
          branchId: widget.branchId,
          userId: widget.userId!,
          payload: payload,
        );
        debugPrint(
          '[TeamOnlineAvailability] updateTeamMember response=$response',
        );

        if (!mounted) return;

        if (response['success'] == true) {
          Fluttertoast.showToast(
              msg: translateText('Team member updated successfully'));

          await Future.delayed(const Duration(milliseconds: 700));

          if (!mounted) return;
          Navigator.pop(context, true);
          return;
        }

        throw Exception(
          response['message']?.toString() ?? 'Failed to update team member',
        );
      }

      final joiningDate =
          '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}';
      debugPrint('FINAL ASSIGN BRANCH ID: ${widget.branchId}');
      debugPrint('FINAL ASSIGN USER ID: ${widget.assignUserId}');
      debugPrint('FINAL ASSIGN SCHEDULES: ${widget.assignSchedules}');
      debugPrint('FINAL ASSIGN SERVICES: ${widget.assignBranchServiceIds}');
      final normalizedSchedules = widget.assignSchedules!.map((slot) {
        return {
          'day': slot['day'].toString().toLowerCase(),
          'startTime': _to24h(slot['startTime'].toString()),
          'endTime': _to24h(slot['endTime'].toString()),
        };
      }).toList();

      debugPrint('FINAL ASSIGN BRANCH ID: ${widget.branchId}');
      debugPrint('FINAL NORMALIZED ASSIGN SCHEDULES: $normalizedSchedules');
      debugPrint(
        '[TeamOnlineAvailability] Calling assignUserToBranch '
        'branchId=${widget.branchId} userId=${widget.assignUserId} '
        'joiningDate=$joiningDate services=${widget.assignBranchServiceIds} '
        'allowOnline=$_allowOnlineBooking',
      );

      final response = await ApiService().assignUserToBranch(
        widget.branchId,
        widget.assignUserId!,
        joiningDate,
        normalizedSchedules,
        widget.assignBranchServiceIds!,
        _allowOnlineBooking,
      );
      debugPrint(
        '[TeamOnlineAvailability] assignUserToBranch response=$response',
      );
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(
            msg: translateText('User assigned successfully'));

        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;
        final navigator = Navigator.of(context);
        var foundAssignRoot = false;
        navigator.popUntil((route) {
          final isAssignRoot = route.settings.name == kAssignUserRootRouteName;
          if (isAssignRoot) {
            foundAssignRoot = true;
          }
          return isAssignRoot || route.isFirst;
        });

        if (foundAssignRoot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigator.pop(true);
          });
          return;
        }

        navigator.pop(true);
        return;
      }
      throw Exception(
        response['message']?.toString() ?? 'Failed to assign user',
      );
    } catch (error) {
      debugPrint('[TeamOnlineAvailability] Save failed: $error');
      if (!mounted) return;
      Fluttertoast.showToast(msg: _friendlyErrorMessage(error));
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
