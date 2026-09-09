import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import 'assign_user_flow_constants.dart';
import 'team_member_compensation_setup_step.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../widgets/app_loader.dart';
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
        initialJoiningDate = null,
        assignScheduleSameAsBranch = false,
        assignSalonId = null,
        assignMemberName = null,
        promptCompensationOnComplete = false;

  const TeamOnlineAvailabilityScreen.assignUser({
    super.key,
    required this.branchId,
    required this.assignUserId,
    required this.assignBranchServiceIds,
    required this.assignSchedules,
    required this.initialJoiningDate,
    this.assignScheduleSameAsBranch = false,
    this.assignSalonId,
    this.assignMemberName,
    this.promptCompensationOnComplete = false,
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
        initialJoiningDate = null,
        assignScheduleSameAsBranch = false,
        assignSalonId = null,
        assignMemberName = null,
        promptCompensationOnComplete = false;

  final TeamAvailabilityMode mode;
  final int branchId;
  final Map<String, dynamic>? payload;
  final int? userId;
  final int? assignUserId;
  final List<int>? assignBranchServiceIds;
  final List<Map<String, dynamic>>? assignSchedules;
  final String? initialJoiningDate;
  // Narinder, 2026-09-03: scheduleMode 'BRANCH_HOURS' vs 'CUSTOM' on
  // POST /branches/{branchId}/assign-user — true skips sending
  // `assignSchedules` and lets the backend copy branch timings instead.
  final bool assignScheduleSameAsBranch;
  // Only used in assignUser mode, and only when promptCompensationOnComplete
  // is true — needed to open the compensation step after this flow finishes.
  final int? assignSalonId;
  final String? assignMemberName;
  // Setup Required onboarding chain only: after this assign flow succeeds,
  // show a compensation step before returning to Team Members. False for
  // an active member just picking up an additional branch.
  final bool promptCompensationOnComplete;

  @override
  State<TeamOnlineAvailabilityScreen> createState() =>
      _TeamOnlineAvailabilityScreenState();
}

enum TeamAvailabilityMode { addMember, assignUser, editMember }

const Color _assignFieldBorder = AppColors.starColor;
const Color _assignFieldFocusedBorder = AppColors.starColor;

class _TeamOnlineAvailabilityScreenState
    extends State<TeamOnlineAvailabilityScreen> {
  bool _allowOnlineBooking = true;
  bool _isSubmitting = false;
  bool _isLoadingRoleOptions = false;
  DateTime? _joiningDate;
  List<Map<String, dynamic>> _allRoles = const [];
  Set<String> _selectedRoleCodes = {};

  // Required-field errors only ever show after a Submit attempt, and each
  // one is derived directly from whether that field is filled — so as
  // soon as the user picks a date / selects a role, its own error clears
  // immediately without needing to resubmit.
  bool _showValidationErrors = false;

  bool get _joiningDateHasError =>
      _showValidationErrors && _joiningDate == null;
  bool get _rolesHaveError =>
      _showValidationErrors && _selectedRoleCodes.isEmpty;
  bool get _isBusy => _isSubmitting || _isLoadingRoleOptions;

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String? get _selectedJoiningDate {
    final date = _joiningDate;
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<int> _intList(dynamic raw) {
    if (raw is! List) return const [];
    final ids = <int>{};
    for (final value in raw) {
      final id = _asInt(value);
      if (id != null) ids.add(id);
    }
    return ids.toList();
  }

  List<Map<String, dynamic>> _schedulePayload(dynamic rawSchedules) {
    if (rawSchedules is! List) return const [];
    final schedules = <Map<String, dynamic>>[];
    for (final raw in rawSchedules) {
      if (raw is! Map) continue;
      final slot = Map<String, dynamic>.from(raw);
      final day = (slot['day'] ?? '').toString().trim().toLowerCase();
      final startTime =
          (slot['startTime'] ?? slot['start'] ?? '').toString().trim();
      final endTime = (slot['endTime'] ?? slot['end'] ?? '').toString().trim();
      if (day.isEmpty || startTime.isEmpty || endTime.isEmpty) continue;
      schedules.add({
        'day': day,
        'startTime': _to24h(startTime),
        'endTime': _to24h(endTime),
      });
    }
    return schedules;
  }

  String _scheduleModeFromPayload(Map<String, dynamic> payload) {
    final explicit = payload['scheduleMode']?.toString().trim().toUpperCase();
    if (explicit == 'BRANCH_HOURS' || explicit == 'CUSTOM') {
      return explicit!;
    }
    return payload['useSalonHours'] == true ? 'BRANCH_HOURS' : 'CUSTOM';
  }

  Map<String, dynamic> _branchEditPayload(Map<String, dynamic> base) {
    final branchRoleIds = _selectedBranchRoleIds;
    final scheduleMode = _scheduleModeFromPayload(base);
    return <String, dynamic>{
      'scheduleMode': scheduleMode,
      // The backend rejects the request outright if `schedules` is present
      // at all when scheduleMode is BRANCH_HOURS ("schedules must be
      // omitted when scheduleMode is BRANCH_HOURS") — that mode means the
      // member just follows the branch's own hours, so there's nothing
      // custom to send.
      if (scheduleMode != 'BRANCH_HOURS')
        'schedules': _schedulePayload(base['schedules']),
      'roles': _selectedRoleCodes.toList(),
      'branchRoleIds': branchRoleIds.isEmpty
          ? _intList(base['branchRoleIds'])
          : branchRoleIds,
      'joiningDate': _selectedJoiningDate,
      'branchServiceIds': _intList(base['branchServiceIds']),
      'allowOnlineBooking': _allowOnlineBooking,
    }..removeWhere((key, value) => value == null);
  }

  Map<String, String> _branchNamesFromPayload() {
    final raw = widget.payload?['branchNamesById'];
    if (raw is! Map) return const {};

    final names = <String, String>{};
    raw.forEach((key, value) {
      final idText = key.toString().trim();
      final nameText = value?.toString().trim() ?? '';
      if (idText.isNotEmpty && nameText.isNotEmpty) {
        names[idText] = nameText;
      }
    });
    return names;
  }

  dynamic _previousResult() {
    if (widget.mode != TeamAvailabilityMode.assignUser) return false;
    return {
      'completed': false,
      'joiningDate': _selectedJoiningDate,
      'selectedServiceIds': widget.assignBranchServiceIds ?? const <int>[],
      'schedules': widget.assignSchedules ?? const <Map<String, dynamic>>[],
    };
  }

  dynamic _editScheduleResult() {
    if (widget.mode == TeamAvailabilityMode.assignUser) {
      return {
        ...Map<String, dynamic>.from(_previousResult() as Map),
        'editSchedule': true,
      };
    }
    return {'editSchedule': true};
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == TeamAvailabilityMode.addMember) {
      _allowOnlineBooking =
          widget.payload?['allowOnlineBooking'] == true ? true : false;
      return;
    }

    // Assign User and Edit share the same "Complete" fields (Joining
    // Date, Roles, Experience, online booking) — Assign always starts
    // blank/today since it's a brand-new assignment, while Edit prefills
    // from whatever AddTeam.dart forwarded in `payload` for the existing
    // member (that screen no longer has its own Joining Date/Roles/
    // Experience UI — see the commented-out block there).
    if (widget.mode == TeamAvailabilityMode.assignUser) {
      _allowOnlineBooking = true;
      final raw = widget.initialJoiningDate;
      if (raw != null && raw.trim().isNotEmpty) {
        _joiningDate = DateTime.tryParse(raw.trim());
      }
    } else {
      _allowOnlineBooking =
          widget.payload?['allowOnlineBooking'] == true ? true : false;
      final raw = widget.payload?['joiningDate']?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        _joiningDate = DateTime.tryParse(raw.trim());
      }
      final rawRoles = widget.payload?['roles'];
      if (rawRoles is List) {
        _selectedRoleCodes = rawRoles.map((e) => e.toString()).toSet();
      }
    }

    _isLoadingRoleOptions = true;
    unawaited(_loadAssignRoleOptions());
  }

  // Roles and branch-role ids both come from the same branch-scoped
  // constants list (users/constants?branchId=...) — each role option
  // there already carries both a display code (-> the "roles" string list)
  // and a numeric id (-> "branchRoleIds"), so one picker/selection covers
  // both payload fields instead of hitting two separate endpoints.
  Future<void> _loadAssignRoleOptions() async {
    try {
      // getRolesAndSpecializations already unwraps the response's outer
      // 'data' envelope and returns {roles: [...], specialities: [...]}
      // directly — indexing ['data'] again here always came back null,
      // which is why the Roles picker was silently empty.
      final data = await ApiService().getRolesAndSpecializations(
        branchId: widget.branchId,
      );
      if (!mounted) return;
      final rawRoles = data['roles'];
      setState(() {
        // Same filter AddTeam.dart's own role picker applies: drop
        // non-branch-scoped roles (Super Admin) and the owner role —
        // an owner is never something you assign a team member as here.
        _allRoles = (rawRoles is List ? rawRoles : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((role) => role['branchId'] != null)
            .where((role) => !_isOwnerRoleOption(role))
            .toList();
        _selectedRoleCodes = _normalizeRoleSelection(_selectedRoleCodes);
      });
    } catch (e) {
      debugPrint('[TeamOnlineAvailability] Failed to load role options: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoleOptions = false);
      }
    }
  }

  Set<String> _normalizeRoleSelection(Set<String> selected) {
    if (selected.isEmpty || _allRoles.isEmpty) return selected;
    final normalized = <String>{};
    for (final value in selected) {
      final match = _allRoles.cast<Map<String, dynamic>?>().firstWhere(
            (option) => option != null && _roleMatchesValue(option, value),
            orElse: () => null,
          );
      normalized.add(match == null ? value : _roleCodeOf(match));
    }
    return normalized;
  }

  bool _roleMatchesValue(Map<String, dynamic> option, String value) {
    final target = _normalizedRoleText(value);
    if (target.isEmpty) return false;
    for (final raw in [
      option['code'],
      option['label'],
      option['name'],
      option['displayName'],
      option['id'],
    ]) {
      if (_normalizedRoleText(raw?.toString() ?? '') == target) {
        return true;
      }
    }
    return false;
  }

  String _normalizedRoleText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  bool _isOwnerRoleOption(Map<String, dynamic> option) {
    final keys = [
      option['label'],
      option['name'],
      option['displayName'],
      option['code'],
    ]
        .map((value) => value?.toString().trim().toLowerCase() ?? '')
        .where((value) => value.isNotEmpty && value != 'null');
    return keys.any((value) {
      final normalized = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      return normalized
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .join(' ') ==
          'salon owner';
    });
  }

  String _roleCodeOf(Map<String, dynamic> option) {
    return (option['code'] ?? option['label'] ?? option['name'] ?? '')
        .toString();
  }

  String _optionLabelOf(Map<String, dynamic> option) {
    return (option['label'] ?? option['name'] ?? option['code'] ?? '')
        .toString();
  }

  List<Map<String, dynamic>> get _selectedRoleOptions {
    return _allRoles
        .where((o) => _selectedRoleCodes.contains(_roleCodeOf(o)))
        .toList();
  }

  String _selectedRolesText() {
    return _selectedRoleOptions
        .map(_optionLabelOf)
        .where((label) => label.isNotEmpty)
        .join(', ');
  }

  List<int> get _selectedBranchRoleIds {
    return _selectedRoleOptions
        .map((o) => _asInt(o['id']))
        .whereType<int>()
        .toList();
  }

  Future<List<T>?> _showMultiSelectSheet<T>({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<T> initiallySelected,
    required T Function(Map<String, dynamic> option) valueOf,
  }) {
    return showModalBottomSheet<List<T>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final temp = Set<T>.from(initiallySelected);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: options.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                translateText('No options available'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final option = options[i];
                                final value = valueOf(option);
                                final checked = temp.contains(value);
                                return CheckboxListTile(
                                  value: checked,
                                  activeColor: AppColors.starColor,
                                  checkColor: Colors.white,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(_optionLabelOf(option)),
                                  onChanged: (v) {
                                    setSheetState(() {
                                      if (v == true) {
                                        temp.add(value);
                                      } else {
                                        temp.remove(value);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, temp.toList()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(translateText('Done')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickRoles() async {
    if (_isLoadingRoleOptions) return;

    final result = await _showMultiSelectSheet<String>(
      title: translateText('Select Roles'),
      options: _allRoles,
      initiallySelected: _selectedRoleCodes,
      valueOf: _roleCodeOf,
    );
    if (result != null) setState(() => _selectedRoleCodes = result.toSet());
  }

  Widget _cardContainer({required Widget child}) {
    return Center(
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
        child: child,
      ),
    );
  }

  Widget _pickerRow({
    required String label,
    required String placeholder,
    required String valueText,
    required VoidCallback onTap,
    bool required = false,
    bool hasError = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError ? AppColors.red : _assignFieldBorder,
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueText.isEmpty ? placeholder : valueText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueText.isEmpty
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(color: AppColors.red, fontSize: 12),
          ),
        ],
      ],
    );
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

  Map<String, dynamic>? _decodedErrorBody(Object error) {
    final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd <= jsonStart) return null;

    try {
      final decoded = jsonDecode(text.substring(jsonStart, jsonEnd + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return null;
  }

  List<Map<String, dynamic>> _scheduleConflictsFrom(
    Map<String, dynamic>? body,
  ) {
    if (body == null) return const [];
    final error = body['error'];
    final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
    final code = (errorMap?['code'] ?? body['code'] ?? '').toString();
    if (code != 'MEMBER_SCHEDULE_CONFLICT') return const [];

    final details = errorMap?['details'] ?? body['details'];
    if (details is! Map) return const [];
    final conflicts = details['conflicts'];
    if (conflicts is! List) return const [];

    return conflicts
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  String _backendMessageFrom(Map<String, dynamic>? body) {
    if (body == null) return '';
    final error = body['error'];
    final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
    final message = body['message'] ?? errorMap?['message'];
    if (message is List) return message.join('\n').trim();
    return message?.toString().trim() ?? '';
  }

  String _displayDay(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return translateText('Selected day');
    return text[0].toUpperCase() + text.substring(1);
  }

  String _displayTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final parts = text.split(':');
    if (parts.length < 2) return text;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return text;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<Map<String, String>> _resolveConflictBranchNames(
    List<Map<String, dynamic>> conflicts,
  ) async {
    final names = Map<String, String>.from(_branchNamesFromPayload());
    final missingIds = <int>{};

    for (final conflict in conflicts) {
      final branchId = _asInt(conflict['branchId']);
      if (branchId != null && !names.containsKey(branchId.toString())) {
        missingIds.add(branchId);
      }
    }

    for (final branchId in missingIds) {
      try {
        final response = await ApiService().getBranchDetail(branchId);
        final data = response['data'];
        final branch = data is Map ? data : response;
        final name = branch['name'] ?? branch['branchName'];
        final text = name?.toString().trim() ?? '';
        if (text.isNotEmpty) names[branchId.toString()] = text;
      } catch (error) {
        debugPrint(
          '[TeamOnlineAvailability] Failed to resolve branch $branchId: $error',
        );
      }
    }

    return names;
  }

  Widget _scheduleConflictItem(
    Map<String, dynamic> conflict,
    Map<String, String> branchNames,
    int index,
  ) {
    final name = [
      conflict['firstName']?.toString().trim(),
      conflict['lastName']?.toString().trim(),
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    final branchId = conflict['branchId'];
    final branchName = branchNames[branchId?.toString() ?? ''] ??
        (branchId == null ? '' : 'Branch $branchId');

    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8DED6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_displayDay(conflict['day'])}, '
              '${_displayTime(conflict['startTime'])} - '
              '${_displayTime(conflict['endTime'])}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D2926),
              ),
            ),
            const SizedBox(height: 4),
            if (name.isNotEmpty) ...[
              _conflictDetailText(
                label: translateText('Team member'),
                value: name,
              ),
              const SizedBox(height: 2),
            ],
            if (branchName.isNotEmpty)
              _conflictDetailText(
                label: translateText('Conflicting branch'),
                value: branchName,
              ),
          ],
        ),
      ),
    );
  }

  Widget _conflictDetailText({required String label, required String value}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF756A61),
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF5F554D),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Future<bool> _showScheduleConflictDialogIfNeeded(Object error) async {
    final body = _decodedErrorBody(error);
    final conflicts = _scheduleConflictsFrom(body);
    if (conflicts.isEmpty) return false;

    final backendMessage = _backendMessageFrom(body);
    final branchNames = await _resolveConflictBranchNames(conflicts);
    if (!mounted) return true;

    final shouldEditSchedule = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final dialogWidth = (screenWidth - 32).clamp(320.0, 560.0).toDouble();
        final maxDialogHeight = screenHeight * 0.80;
        final uniqueConflictDays = conflicts
            .map((conflict) => conflict['day']?.toString().trim())
            .where((day) => day != null && day.isNotEmpty)
            .toSet()
            .length;
        final hasMultipleDays = uniqueConflictDays > 1;
        final calculatedListHeight = conflicts.length * 86.0;
        final availableListHeight = (maxDialogHeight - 125).clamp(
          120.0,
          maxDialogHeight,
        );
        final dataBasedListCap = hasMultipleDays ? availableListHeight : 180.0;
        final maxListHeight =
            calculatedListHeight.clamp(86.0, dataBasedListCap).toDouble();
        final canScroll = calculatedListHeight > maxListHeight;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          constraints: BoxConstraints(
            minWidth: dialogWidth,
            maxWidth: dialogWidth,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x33000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_busy_outlined,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  translateText('Schedule conflict'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2926),
                  ),
                ),
              ),
              Tooltip(
                message: translateText('Close'),
                child: InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF8F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF756A61),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backendMessage.isNotEmpty
                        ? backendMessage
                        : translateText(
                            'This team member is already assigned to another active branch at these times.',
                          ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: Color(0xFF756A61),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    translateText(
                      'Edit the selected schedule to avoid overlap.',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF756A61),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ScrollableConflictList(
                    maxHeight: maxListHeight,
                    showScrollbar: canScroll,
                    children: List.generate(
                      conflicts.length,
                      (index) => _scheduleConflictItem(
                        conflicts[index],
                        branchNames,
                        index,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(translateText('Edit schedule')),
              ),
            ),
          ],
        );
      },
    );

    if (shouldEditSchedule == true && mounted) {
      Navigator.pop(context, _editScheduleResult());
    }

    return true;
  }

  void _showWrappedToast(String message) {
    final toast = FToast()..init(context);
    final screenWidth = MediaQuery.of(context).size.width;

    toast.showToast(
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth - 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4B4B4B),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssign = widget.mode == TeamAvailabilityMode.assignUser;
    final isEdit = widget.mode == TeamAvailabilityMode.editMember;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isBusy) return;
        Navigator.pop(context, _previousResult());
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: buildProfileSubpageAppBar(
          title: translateText(
            isAssign ? 'Assign User' : 'Online Availability',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _isBusy
                ? null
                : () => Navigator.pop(context, _previousResult()),
          ),
        ),
        body: Stack(
          // Without this, the Stack shrink-wraps to the scrollable content's
          // height (StackFit.loose default) whenever that content is
          // shorter than the screen, so the busy overlay's Positioned.fill
          // below only covered down to the end of the content instead of
          // the actual bottom of the screen.
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: SingleChildScrollView(
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
                    Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 56,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isAssign || isEdit) ...[
                      _cardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  border: Border.all(
                                    color: _joiningDateHasError
                                        ? AppColors.red
                                        : _assignFieldBorder,
                                    width: _joiningDateHasError ? 1.5 : 1,
                                  ),
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
                            if (_joiningDateHasError) ...[
                              const SizedBox(height: 6),
                              Text(
                                translateText('Joining date is required'),
                                style: const TextStyle(
                                    color: AppColors.red, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 22),
                            _pickerRow(
                              label: translateText('Roles'),
                              placeholder: translateText('Select Roles'),
                              valueText: _selectedRolesText(),
                              onTap: _isLoadingRoleOptions ? () {} : _pickRoles,
                              required: true,
                              hasError: _rolesHaveError,
                              errorText:
                                  translateText('Select at least one role.'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _cardContainer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBusy
                                ? null
                                : () =>
                                    Navigator.pop(context, _previousResult()),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: const Color(0xFFE5E7EB),
                              foregroundColor: const Color(0xFF374151),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(translateText('Previous')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isBusy ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
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
            if (_isBusy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.28),
                    child: Center(
                      child: AppLoader.page(
                        message: _isLoadingRoleOptions
                            ? translateText('Loading roles...please wait')
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

    if (widget.mode != TeamAvailabilityMode.addMember) {
      setState(() => _showValidationErrors = true);
      if (_joiningDateHasError || _rolesHaveError) {
        debugPrint(
          '[TeamOnlineAvailability] Save blocked: required fields missing',
        );
        return;
      }
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
          _showWrappedToast(translateText('Team member added successfully'));

          await Future.delayed(const Duration(milliseconds: 700));

          if (!mounted) return;
          Navigator.pop(context, true);
          return;
        }

        throw Exception(
          extractErrorMessage(
            response['message'],
            fallback: 'Failed to add team member',
          ),
        );
      }

      if (widget.mode == TeamAvailabilityMode.editMember) {
        final payload = _branchEditPayload(
          Map<String, dynamic>.from(widget.payload ?? {}),
        );
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
          _showWrappedToast(translateText('Team member updated successfully'));

          await Future.delayed(const Duration(milliseconds: 700));

          if (!mounted) return;
          Navigator.pop(context, true);
          return;
        }

        throw Exception(
          extractErrorMessage(
            response['message'],
            fallback: 'Failed to update team member',
          ),
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
        branchRoleIds: _selectedBranchRoleIds,
        roles: _selectedRoleCodes.toList(),
        scheduleMode:
            widget.assignScheduleSameAsBranch ? 'BRANCH_HOURS' : 'CUSTOM',
      );
      debugPrint(
        '[TeamOnlineAvailability] assignUserToBranch response=$response',
      );
      if (!mounted) return;
      if (response['success'] == true) {
        _showWrappedToast(translateText('User assigned successfully'));

        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;

        if (widget.promptCompensationOnComplete &&
            widget.assignSalonId != null &&
            widget.assignUserId != null) {
          // Save or Skip both just pop back here — compensation is a
          // nice-to-have step, not a hard blocker to finishing onboarding.
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamMemberCompensationSetupStep(
                salonId: widget.assignSalonId!,
                userId: widget.assignUserId!,
                memberName: widget.assignMemberName ?? '',
              ),
            ),
          );
          if (!mounted) return;
        }

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
      if (await _showScheduleConflictDialogIfNeeded(error)) return;
      _showWrappedToast(_friendlyErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ScrollableConflictList extends StatefulWidget {
  const _ScrollableConflictList({
    required this.maxHeight,
    required this.showScrollbar,
    required this.children,
  });

  final double maxHeight;
  final bool showScrollbar;
  final List<Widget> children;

  @override
  State<_ScrollableConflictList> createState() =>
      _ScrollableConflictListState();
}

class _ScrollableConflictListState extends State<_ScrollableConflictList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: widget.showScrollbar,
        trackVisibility: widget.showScrollbar,
        thickness: widget.showScrollbar ? 5 : 0,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          controller: _controller,
          padding: EdgeInsets.only(right: widget.showScrollbar ? 12 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
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
          translateText(label),
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
