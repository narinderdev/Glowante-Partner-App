import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'AssignUserSlots.dart';
import 'complete_profile_shared.dart';
import 'select_services_AssignUser.dart';
import 'team_member_compensation_setup_step.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../widgets/app_loader.dart';

Map<String, dynamic> _branchDetailPayload(dynamic response) {
  if (response is! Map) return const <String, dynamic>{};
  final root = Map<String, dynamic>.from(response);
  final data = root['data'];
  return data is Map ? Map<String, dynamic>.from(data) : root;
}

Map<String, dynamic> _mergeBranchSetupDetail(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  final merged = Map<String, dynamic>.from(base);
  overlay.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    if (value is List && value.isEmpty) return;
    if (value is Map && value.isEmpty) return;
    merged[key] = value;
  });
  return merged;
}

/// Single "Branch Setup" screen (Assign Branch, Assign Role(s), Services,
/// Working Hours, Joining Date, Online Booking) for an already-active
/// member — used by both "Edit" (branch locked to their current one) and
/// "Assign User" (branch open, picking an additional one). Services and
/// Working Hours are genuinely complex (a full catalog browser, a full
/// weekly schedule editor) so this screen doesn't reimplement them — it
/// pushes SelectServicesAssignUser and AssignUserSlot in `standalone` mode
/// as sub-pickers and just shows a summary + count here, matching how the
/// web reference itself presents them as a button and an "Open" row.
class TeamBranchSetupScreen extends StatefulWidget {
  const TeamBranchSetupScreen({
    super.key,
    required this.salonId,
    required this.userId,
    required this.member,
    required this.salons,
    this.lockedBranchId,
    this.chainIntoCompensation = false,
    this.initialDraft,
  });

  final int salonId;
  final int userId;
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> salons;

  /// Non-null (Edit): branch fixed to this id, dropdown disabled, prefilled
  /// from the member's current assignment on that branch. Null (Assign
  /// User): open dropdown of branches in this salon the member isn't
  /// already assigned to.
  final int? lockedBranchId;

  /// Setup Required's "Assign User" chain only — after a successful (Assign
  /// mode) save, continues into TeamMemberCompensationSetupStep before
  /// popping back, same as the flow this screen replaced. Save or Skip both
  /// just pop back here — compensation is a nice-to-have, not a hard
  /// blocker to finishing onboarding.
  final bool chainIntoCompensation;

  /// Assign mode only — restores an in-progress selection (branch, roles,
  /// services, schedule, joining date, online booking) the caller captured
  /// via the back-arrow's result when this screen was previously backed out
  /// of, so tapping back and then forward again doesn't lose it. Shaped
  /// like _currentDraftSnapshot()'s output; see that method and the
  /// back-arrow handler below.
  final Map<String, dynamic>? initialDraft;

  @override
  State<TeamBranchSetupScreen> createState() => _TeamBranchSetupScreenState();
}

class _TeamBranchSetupScreenState extends State<TeamBranchSetupScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingBranchServices = false;
  String? _loadError;

  List<Map<String, dynamic>> _branchOptions = const [];
  int? _selectedBranchId;

  List<Map<String, dynamic>> _allRoles = const [];
  Set<String> _selectedRoleCodes = {};
  Set<String> _draftRoleCodes = {};
  bool _rolesDropdownOpen = false;

  List<int> _selectedServiceIds = const [];
  List<Map<String, dynamic>> _schedules = const [];
  // _schedules alone can't tell a day that's explicitly marked off apart
  // from one that just has no entry yet — both are simply absent from that
  // list (that's also how the backend reads "day off"). This is only for
  // correctly reopening the working-hours modal in the same state; it isn't
  // sent to any save API itself.
  List<String> _markedOffDays = const [];
  String _scheduleMode = 'CUSTOM';
  // Whether working hours have actually been set (either loaded from an
  // existing assignment, or confirmed once through the modal) — separate
  // from _schedules being non-empty, since BRANCH_HOURS mode legitimately
  // has no custom schedule entries of its own but is still "configured".
  bool _workingHoursSet = false;

  DateTime? _joiningDate;
  bool _allowOnlineBooking = true;

  bool get _isEdit => widget.lockedBranchId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  String get _memberName {
    final firstName = (widget.member['firstName'] ?? '').toString().trim();
    final lastName = (widget.member['lastName'] ?? '').toString().trim();
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? translateText('Team Member') : full;
  }

  Set<int> _assignedBranchIds() {
    final ids = <int>{};
    final raw = widget.member['branches'] ?? widget.member['userBranches'];
    if (raw is! List) return ids;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final branch = entry['branch'];
      final rawId = branch is Map ? branch['id'] : entry['branchId'];
      final id = rawId is int
          ? rawId
          : rawId is num
              ? rawId.toInt()
              : int.tryParse('${rawId ?? ''}');
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Map<String, dynamic>? _branchEntryForSelected(Map<String, dynamic> detail) {
    final branchId = widget.lockedBranchId ?? _selectedBranchId;
    if (branchId == null) return null;

    for (final key in const ['branches', 'userBranches']) {
      final rawBranches = detail[key];
      if (rawBranches is! List) continue;

      for (final rawBranch in rawBranches) {
        if (rawBranch is! Map) continue;
        final branchEntry = Map<String, dynamic>.from(rawBranch);
        final branch = branchEntry['branch'];
        final nestedBranch = branch is Map
            ? Map<String, dynamic>.from(branch)
            : const <String, dynamic>{};
        final id = _asInt(branchEntry['branchId']) ??
            _asInt(branchEntry['id']) ??
            _asInt(nestedBranch['id']);
        if (id == branchId) return branchEntry;
      }
    }

    return null;
  }

  List<int> _serviceIdsFromSources(Iterable<dynamic> sources) {
    final ids = <int>[];
    final seen = <int>{};

    void addId(dynamic raw) {
      final id = _asInt(raw);
      if (id != null && seen.add(id)) ids.add(id);
    }

    void read(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final item in value) {
          read(item);
        }
        return;
      }
      if (value is! Map) {
        addId(value);
        return;
      }

      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'branchServiceId',
        'branch_service_id',
        'branchServiceID',
      ]) {
        addId(map[key]);
      }

      for (final key in const ['branchService', 'branch_service']) {
        final nested = map[key];
        if (nested is Map) addId(nested['id']);
      }

      for (final key in const [
        'branchServiceIds',
        'userBranchServices',
        'services',
        'branchServices',
        'assignedServices',
        'assignedBranchServices',
        'serviceIds',
        'assignedServiceIds',
        'assignedBranchServiceIds',
      ]) {
        read(map[key]);
      }
    }

    for (final source in sources) {
      read(source);
    }
    return ids;
  }

  List<int> _serviceIdsFromBranchCatalog(dynamic response) {
    final payload = _branchDetailPayload(response);
    final ids = <int>[];
    final seen = <int>{};

    void addId(dynamic raw) {
      final id = _asInt(raw);
      if (id != null && seen.add(id)) ids.add(id);
    }

    void readService(dynamic rawService) {
      if (rawService is! Map) return;
      final service = Map<String, dynamic>.from(rawService);
      addId(service['id'] ?? service['branchServiceId']);
    }

    void readCategory(dynamic rawCategory) {
      if (rawCategory is! Map) return;
      final category = Map<String, dynamic>.from(rawCategory);

      final services = category['services'];
      if (services is List) {
        for (final service in services) {
          readService(service);
        }
      }

      final subCategories =
          category['subCategories'] ?? category['subcategories'];
      if (subCategories is List) {
        for (final subCategory in subCategories) {
          readCategory(subCategory);
        }
      }
    }

    final categories = payload['categories'];
    if (categories is List) {
      for (final category in categories) {
        readCategory(category);
      }
    }

    return ids;
  }

  Future<void> _selectAssignBranch(int? value) async {
    if (_isEdit) return;

    setState(() {
      _selectedBranchId = value;
      _selectedServiceIds = const [];
      _schedules = const [];
      _markedOffDays = const [];
      _scheduleMode = value == null ? 'CUSTOM' : 'BRANCH_HOURS';
      _workingHoursSet = value != null;
    });

    if (value == null) return;

    setState(() => _isLoadingBranchServices = true);
    try {
      final response = await ApiService().getBranchService(branchId: value);
      if (!mounted || _selectedBranchId != value) return;
      setState(() {
        _selectedServiceIds = _serviceIdsFromBranchCatalog(response);
        _isLoadingBranchServices = false;
      });
    } catch (error) {
      if (!mounted || _selectedBranchId != value) return;
      setState(() => _isLoadingBranchServices = false);
      Fluttertoast.showToast(
        msg: extractErrorMessage(
          error,
          fallback: 'Failed to load services. Please try again.',
        ),
      );
    }

    // Role ids are branch-specific (confirmed by the API rejecting a save
    // with "Branch role IDs must belong to the target branch") — reloading
    // here keeps _allRoles matching whichever branch is actually selected,
    // not just the one _loadData() happened to bootstrap with. The role
    // *codes* in _selectedRoleCodes are left as-is; _selectedBranchRoleIds
    // looks them up against the freshly reloaded _allRoles, so it always
    // resolves to the current branch's own ids.
    try {
      final rolesData =
          await ApiService().getRolesAndSpecializations(branchId: value);
      if (!mounted || _selectedBranchId != value) return;
      final rawRoles = rolesData['roles'];
      setState(() {
        _allRoles = (rawRoles is List ? rawRoles : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((role) => role['branchId'] != null)
            .toList();
      });
    } catch (error) {
      if (!mounted || _selectedBranchId != value) return;
      Fluttertoast.showToast(
        msg: extractErrorMessage(
          error,
          fallback: 'Failed to load roles for this branch.',
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final salon = widget.salons.firstWhere(
        (s) =>
            (s['id'] is int ? s['id'] : int.tryParse('${s['id']}')) ==
            widget.salonId,
        orElse: () => const <String, dynamic>{},
      );
      final salonBranches = (salon['branches'] as List? ?? const [])
          .whereType<Map>()
          .map((b) => Map<String, dynamic>.from(b))
          .toList();

      if (_isEdit) {
        _branchOptions = salonBranches
            .where((b) => _asInt(b['id']) == widget.lockedBranchId)
            .toList();
        _selectedBranchId = widget.lockedBranchId;
      } else {
        final assigned = _assignedBranchIds();
        _branchOptions = salonBranches
            .where((b) => !assigned.contains(_asInt(b['id'])))
            .toList();

        // Restore the branch pick first so the roles bootstrap below fetches
        // for the right branch instead of falling back to the first option.
        final draftBranchId = _asInt(widget.initialDraft?['selectedBranchId']);
        if (draftBranchId != null &&
            _branchOptions.any((b) => _asInt(b['id']) == draftBranchId)) {
          _selectedBranchId = draftBranchId;
        }
      }

      // Branch-scoped roles (Salon Owner/Manager/Stylist/Receptionist/Staff)
      // only come back from this endpoint when a branchId is passed — without
      // one it returns just the platform-level roles (Super Admin, App
      // User), which is why the picker was showing the wrong short list.
      // Role ids are branch-specific (assignUserToBranch rejects ids that
      // belong to a different branch with a 400), so this is only a
      // bootstrap for Assign mode's role picker before a branch is chosen —
      // _selectAssignBranch reloads _allRoles for whichever branch actually
      // gets picked, which is what _selectedBranchRoleIds resolves against.
      final rolesBranchId = _isEdit
          ? widget.lockedBranchId
          : (_selectedBranchId ??
              (_branchOptions.isNotEmpty
                  ? _asInt(_branchOptions.first['id'])
                  : null));
      final rolesData = await ApiService()
          .getRolesAndSpecializations(branchId: rolesBranchId);
      final rawRoles = rolesData['roles'];
      _allRoles = (rawRoles is List ? rawRoles : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((role) => role['branchId'] != null)
          .toList();

      if (_isEdit) {
        var detail = Map<String, dynamic>.from(widget.member);

        final response = await ApiService.getTeamMemberDetails(
          widget.lockedBranchId!,
          widget.userId,
        );
        detail =
            _mergeBranchSetupDetail(detail, _branchDetailPayload(response));

        try {
          final salonResponse = await ApiService().getTeamMemberDetailV2(
            widget.salonId,
            widget.userId,
          );
          detail = _mergeBranchSetupDetail(
            detail,
            _branchDetailPayload(salonResponse),
          );
        } catch (error) {
          debugPrint('Failed to load salon team member detail: $error');
        }

        final selectedBranchDetail =
            _branchEntryForSelected(detail) ?? const <String, dynamic>{};

        final rawMemberRoles = selectedBranchDetail['roles'] ?? detail['roles'];
        if (rawMemberRoles is List) {
          _selectedRoleCodes = rawMemberRoles
              .map((r) => r is Map
                  ? (r['code'] ?? r['label'] ?? '').toString()
                  : r.toString())
              .where((code) => code.trim().isNotEmpty)
              .toSet();
        }

        _selectedServiceIds = _serviceIdsFromSources([
          selectedBranchDetail['branchServiceIds'],
          selectedBranchDetail['userBranchServices'],
          selectedBranchDetail['services'],
          selectedBranchDetail['branchServices'],
          selectedBranchDetail['assignedServices'],
          selectedBranchDetail['assignedBranchServices'],
          detail['branchServiceIds'],
          detail['userBranchServices'],
          detail['services'],
          detail['branchServices'],
          detail['assignedServices'],
          detail['assignedBranchServices'],
        ]);

        final rawSchedules =
            selectedBranchDetail['schedules'] ?? detail['schedules'];
        if (rawSchedules is List && rawSchedules.isNotEmpty) {
          _schedules = rawSchedules
              .whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
          _scheduleMode = 'CUSTOM';
          _workingHoursSet = true;

          // An existing CUSTOM assignment has a definite status for every
          // day — working (present in schedules) or off (absent) — there's
          // no "not yet decided" state like a fresh assignment has. Without
          // this, a day explicitly marked off elsewhere (web, an earlier
          // session) would show here as a plain unfilled day instead of
          // "Team member is off".
          const allDays = [
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
            'saturday',
            'sunday',
          ];
          final scheduledDays = _schedules
              .map((s) => _dayKey(s['day'] ?? ''))
              .where((d) => d.isNotEmpty)
              .toSet();
          _markedOffDays =
              allDays.where((d) => !scheduledDays.contains(d)).toList();
        } else {
          _scheduleMode = 'BRANCH_HOURS';
        }

        final rawScheduleMode =
            selectedBranchDetail['scheduleMode'] ?? detail['scheduleMode'];
        if (rawScheduleMode != null) {
          _scheduleMode = rawScheduleMode.toString().trim().isEmpty
              ? _scheduleMode
              : rawScheduleMode.toString();
          if (_scheduleMode == 'BRANCH_HOURS') {
            _workingHoursSet = true;
          }
        }

        final rawJoiningDate =
            (selectedBranchDetail['joiningDate'] ?? detail['joiningDate'])
                ?.toString();
        if (rawJoiningDate != null && rawJoiningDate.trim().isNotEmpty) {
          _joiningDate = DateTime.tryParse(rawJoiningDate.trim());
        }

        _allowOnlineBooking = (selectedBranchDetail['allowOnlineBooking'] ??
                detail['allowOnlineBooking']) !=
            false;
      } else {
        _allowOnlineBooking = true;

        final initialDraft = widget.initialDraft;
        if (initialDraft != null) {
          final draftRoleCodes = initialDraft['selectedRoleCodes'];
          if (draftRoleCodes is List) {
            _selectedRoleCodes =
                draftRoleCodes.map((c) => c.toString()).toSet();
          }

          final draftServiceIds = initialDraft['selectedServiceIds'];
          if (draftServiceIds is List) {
            _selectedServiceIds = draftServiceIds
                .map((v) => v is int ? v : int.tryParse('$v'))
                .whereType<int>()
                .toList();
          }

          final draftSchedules = initialDraft['schedules'];
          if (draftSchedules is List) {
            _schedules = draftSchedules
                .whereType<Map>()
                .map((s) => Map<String, dynamic>.from(s))
                .toList();
          }

          final draftMarkedOffDays = initialDraft['markedOffDays'];
          if (draftMarkedOffDays is List) {
            _markedOffDays = draftMarkedOffDays
                .map((d) => d.toString())
                .where((d) => d.trim().isNotEmpty)
                .toList();
          }

          final draftScheduleMode = initialDraft['scheduleMode'];
          if (draftScheduleMode is String && draftScheduleMode.isNotEmpty) {
            _scheduleMode = draftScheduleMode;
          }

          _workingHoursSet = initialDraft['workingHoursSet'] == true;

          final draftJoiningDate = initialDraft['joiningDate'];
          if (draftJoiningDate is String && draftJoiningDate.isNotEmpty) {
            _joiningDate = DateTime.tryParse(draftJoiningDate);
          }

          _allowOnlineBooking = initialDraft['allowOnlineBooking'] != false;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Assign mode, nothing already picked (fresh open, no restored
      // draft) — default to the first available branch instead of leaving
      // the dropdown on its empty placeholder.
      if (!_isEdit && _selectedBranchId == null && _branchOptions.isNotEmpty) {
        final defaultBranchId = _asInt(_branchOptions.first['id']);
        if (defaultBranchId != null) {
          unawaited(_selectAssignBranch(defaultBranchId));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = extractErrorMessage(
          e,
          fallback: 'Unable to load branch setup',
        );
        _isLoading = false;
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _roleCodeOf(Map<String, dynamic> option) =>
      (option['code'] ?? option['label'] ?? option['name'] ?? '').toString();

  String _roleLabelOf(Map<String, dynamic> option) =>
      (option['label'] ?? option['name'] ?? option['code'] ?? '').toString();

  List<Map<String, dynamic>> get _selectedRoleOptions => _allRoles
      .where((o) => _selectedRoleCodes.contains(_roleCodeOf(o)))
      .toList();

  List<int> get _selectedBranchRoleIds => _selectedRoleOptions
      .map((o) => _asInt(o['id']))
      .whereType<int>()
      .toList();

  Map<String, dynamic>? get _selectedBranchOption {
    final branchId = _selectedBranchId;
    if (branchId == null) return null;
    for (final branch in _branchOptions) {
      if (_asInt(branch['id']) == branchId) return branch;
    }
    return null;
  }

  dynamic _extractBranchSchedule(dynamic value) {
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);

    for (final key in const [
      'schedule',
      'schedules',
      'workingHours',
      'operatingHours',
      'businessHours',
      'hours',
    ]) {
      if (map[key] != null) return map[key];
    }

    for (final key in const ['data', 'branch', 'salon']) {
      final nested = map[key];
      if (nested is Map) {
        final schedule = _extractBranchSchedule(nested);
        if (schedule != null) return schedule;
      }
    }

    return null;
  }

  String _dayKey(dynamic value) =>
      value.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  String _dayLabel(String day) {
    switch (_dayKey(day)) {
      case 'monday':
        return translateText('Monday');
      case 'tuesday':
        return translateText('Tuesday');
      case 'wednesday':
        return translateText('Wednesday');
      case 'thursday':
        return translateText('Thursday');
      case 'friday':
        return translateText('Friday');
      case 'saturday':
        return translateText('Saturday');
      case 'sunday':
        return translateText('Sunday');
    }
    return day;
  }

  bool _isClosedValue(dynamic value) {
    if (value == null) return true;
    if (value is bool) return !value;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text.isEmpty ||
          text == 'closed' ||
          text == 'off' ||
          text == 'holiday';
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const ['closed', 'isClosed', 'isOff', 'off']) {
        if (map[key] == true) return true;
      }
      if (map['enabled'] == false || map['isOpen'] == false) return true;
    }
    return false;
  }

  int? _parseClockMinutes(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])$',
    ).firstMatch(text);
    if (amPmMatch != null) {
      var hour = int.tryParse(amPmMatch.group(1)!);
      final minute = int.tryParse(amPmMatch.group(2)!);
      final period = amPmMatch.group(3)!.toUpperCase();
      if (hour == null || minute == null) return null;
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  String _formatClock(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour24 < 12 ? 'AM' : 'PM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String _plainScheduleText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return translateText('Closed');
    return text;
  }

  String? _rangeFromScheduleValue(dynamic value) {
    if (_isClosedValue(value)) return translateText('Closed');

    if (value is String) return _plainScheduleText(value);

    if (value is List) {
      if (value.isEmpty) return translateText('Closed');
      final ranges = value
          .map(_rangeFromScheduleValue)
          .whereType<String>()
          .where((range) => range.trim().isNotEmpty)
          .toList();
      return ranges.isEmpty ? translateText('Closed') : ranges.join(', ');
    }

    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    final slots = map['slots'] ?? map['ranges'] ?? map['periods'];
    if (slots is List) return _rangeFromScheduleValue(slots);

    for (final key in const ['hours', 'workingHours', 'operatingHours']) {
      if (map[key] != null && map[key] != value) {
        final nested = _rangeFromScheduleValue(map[key]);
        if (nested != null) return nested;
      }
    }

    dynamic firstValue(List<String> keys) {
      for (final key in keys) {
        if (map[key] != null) return map[key];
      }
      return null;
    }

    final start = firstValue(const [
      'startTime',
      'start',
      'from',
      'openingTime',
      'openTime',
      'opensAt',
    ]);
    final end = firstValue(const [
      'endTime',
      'end',
      'to',
      'closingTime',
      'closeTime',
      'closesAt',
    ]);
    final startMinutes = _parseClockMinutes(start);
    final endMinutes = _parseClockMinutes(end);
    if (startMinutes != null && endMinutes != null) {
      return '${_formatClock(startMinutes)} - ${_formatClock(endMinutes)}';
    }

    return null;
  }

  List<_BranchHoursRow> _branchHoursRows(dynamic source) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final rawSchedule = _extractBranchSchedule(source);
    final schedule = rawSchedule ?? source;
    final byDay = <String, String>{};

    void addDay(dynamic rawDay, dynamic rawValue) {
      final day = _dayKey(rawDay);
      if (!days.contains(day)) return;
      final range = _rangeFromScheduleValue(rawValue);
      if (range != null && range.trim().isNotEmpty) byDay[day] = range;
    }

    if (schedule is List) {
      for (final item in schedule.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final day =
            map['day'] ?? map['weekday'] ?? map['name'] ?? map['dayOfWeek'];
        if (day != null) addDay(day, map);
      }
    } else if (schedule is Map) {
      final map = Map<String, dynamic>.from(schedule);
      final day =
          map['day'] ?? map['weekday'] ?? map['name'] ?? map['dayOfWeek'];
      if (day != null) {
        addDay(day, map);
      } else {
        for (final day in days) {
          addDay(day, map[day] ?? map[_dayLabel(day)]);
        }
      }
    }

    if (byDay.isEmpty && source is Map) {
      final commonRange = _rangeFromScheduleValue(source);
      if (commonRange != null && commonRange != translateText('Closed')) {
        for (final day in days) {
          byDay[day] = commonRange;
        }
      }
    }

    return days
        .map(
          (day) => _BranchHoursRow(
            day: _dayLabel(day),
            hours: byDay[day] ?? translateText('Closed'),
          ),
        )
        .toList();
  }

  String _branchNameForId(dynamic rawBranchId) {
    final branchId = _asInt(rawBranchId);
    if (branchId == null) return '';

    for (final salon in widget.salons) {
      final branches = salon['branches'];
      if (branches is! List) continue;
      for (final rawBranch in branches.whereType<Map>()) {
        final branch = Map<String, dynamic>.from(rawBranch);
        if (_asInt(branch['id']) != branchId) continue;
        final name = branch['name'] ?? branch['branchName'];
        final text = name?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }

    return '${translateText('Branch')} $branchId';
  }

  void _applyRoleSelection() {
    setState(() {
      _selectedRoleCodes = Set<String>.from(_draftRoleCodes);
      _rolesDropdownOpen = false;
    });
  }

  Widget _buildRolesPicker() {
    final selectedText = _selectedRoleOptions.isEmpty
        ? translateText('Select roles')
        : _selectedRoleOptions.map(_roleLabelOf).join(', ');

    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<void>(
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: cpBorder),
          ),
          onOpened: () {
            setState(() {
              _draftRoleCodes = Set<String>.from(_selectedRoleCodes);
              _rolesDropdownOpen = true;
            });
          },
          onCanceled: () => setState(() => _rolesDropdownOpen = false),
          itemBuilder: (menuContext) => [
            PopupMenuItem<void>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: StatefulBuilder(
                builder: (context, setMenuState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: _allRoles.isEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  child: Text(
                                    translateText('No roles available'),
                                    style: const TextStyle(color: cpMuted),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _allRoles.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: cpBorder,
                                  ),
                                  itemBuilder: (_, index) {
                                    final option = _allRoles[index];
                                    final code = _roleCodeOf(option);
                                    final checked =
                                        _draftRoleCodes.contains(code);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: checked,
                                      activeColor: AppColors.starColor,
                                      checkColor: Colors.white,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        _roleLabelOf(option),
                                        style: const TextStyle(
                                          color: cpInk,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setMenuState(() {
                                          if (value == true) {
                                            _draftRoleCodes.add(code);
                                          } else {
                                            _draftRoleCodes.remove(code);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _applyRoleSelection();
                              Navigator.pop(menuContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              translateText('Done'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          child: InputDecorator(
            decoration:
                cpInputDecoration(translateText('Select roles')).copyWith(
              suffixIcon: Icon(
                _rolesDropdownOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: cpMuted,
              ),
            ),
            child: Text(
              selectedText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _selectedRoleOptions.isEmpty ? cpMuted : cpInk,
              ),
            ),
          ),
        );
      },
    );
  }

  // Services and Working Hours both open as a modal overlaying this screen
  // — not a page navigation away from it — reusing SelectServicesAssignUser
  // /AssignUserSlot's existing catalog/schedule UI unchanged inside a
  // Dialog, sized to most of the screen so it still has room to work in.
  Future<T?> _showAsModal<T>(Widget child) {
    final size = MediaQuery.of(context).size;
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: size.width,
          height: size.height * 0.9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _openSelectServices() async {
    final branchId = _selectedBranchId;
    if (branchId == null) {
      Fluttertoast.showToast(msg: translateText('Select a branch first'));
      return;
    }
    final joinedAt = _joiningDate == null
        ? ''
        : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}';
    // Nothing selected yet (first time opening) — SelectServicesAssignUser
    // auto-selects every service itself when initialSelected comes in
    // empty, so leaving this as {} for a fresh selection is exactly what
    // gets "all services selected" by default.
    final result = await _showAsModal<Map<String, dynamic>?>(
      SelectServicesAssignUser(
        salonId: widget.salonId,
        branchId: branchId,
        userId: widget.userId,
        joinedAt: joinedAt,
        member: widget.member,
        salons: widget.salons,
        initialSelected: {
          for (final id in _selectedServiceIds) id: true,
        },
        standalone: true,
      ),
    );
    if (result == null) return;
    final ids = result['selectedServiceIds'];
    if (ids is List) {
      setState(() {
        _selectedServiceIds = ids.whereType<int>().toList();
      });
    }
  }

  // sameAsBranchTimings true starts the modal with "Same as branch timings"
  // selected. The modal itself can toggle between branch timings and custom
  // hours, so edit mode only needs one visible Open action.
  Future<void> _openWorkingHours({
    required bool sameAsBranchTimings,
    bool showSameAsBranchToggle = true,
  }) async {
    final branchId = _selectedBranchId;
    if (branchId == null) {
      Fluttertoast.showToast(msg: translateText('Select a branch first'));
      return;
    }
    if (_selectedServiceIds.isEmpty) {
      Fluttertoast.showToast(
        msg: translateText('Select services before setting working hours'),
      );
      return;
    }
    final joinedAt = _joiningDate == null
        ? ''
        : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}';
    final result = await _showAsModal<Map<String, dynamic>?>(
      AssignUserSlot(
        salonId: widget.salonId,
        branchId: branchId,
        userId: widget.userId,
        selectedServiceIds: _selectedServiceIds,
        member: widget.member,
        salons: widget.salons,
        joinedAt: joinedAt,
        initialSchedules: _schedules,
        initialMarkedOffDays: _markedOffDays,
        standalone: true,
        initialSameAsBranchTimings: sameAsBranchTimings,
        showSameAsBranchToggle: showSameAsBranchToggle,
      ),
    );
    if (result == null) return;
    final schedules = result['schedules'];
    final markedOffDays = result['markedOffDays'];
    final scheduleMode = result['scheduleMode']?.toString();
    setState(() {
      if (schedules is List) {
        _schedules = schedules
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      }
      if (markedOffDays is List) {
        _markedOffDays = markedOffDays
            .map((d) => d.toString())
            .where((d) => d.trim().isNotEmpty)
            .toList();
      }
      if (scheduleMode != null) _scheduleMode = scheduleMode;
      _workingHoursSet = true;
    });
  }

  Future<void> _viewBranchHours() async {
    final branchId = _selectedBranchId;
    if (branchId == null) {
      Fluttertoast.showToast(msg: translateText('Select a branch first'));
      return;
    }

    var branchSource = _selectedBranchOption ?? const <String, dynamic>{};
    if (_extractBranchSchedule(branchSource) == null) {
      try {
        final response = await ApiService().getBranchDetail(branchId);
        branchSource = _branchDetailPayload(response);
      } catch (error) {
        debugPrint('Failed to load branch hours: $error');
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BranchHoursDialog(
        rows: _branchHoursRows(branchSource),
      ),
    );
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

  List<_BackendScheduleConflict> _scheduleConflictsFrom(
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

    return conflicts.whereType<Map>().map((entry) {
      final conflict = Map<String, dynamic>.from(entry);
      return _BackendScheduleConflict(
        day: _dayLabel(conflict['day']?.toString() ?? ''),
        startTime: conflict['startTime']?.toString() ?? '',
        endTime: conflict['endTime']?.toString() ?? '',
        branchName: _branchNameForId(conflict['branchId']),
      );
    }).toList();
  }

  Future<bool> _showScheduleConflictDialogIfNeeded(Object error) async {
    final conflicts = _scheduleConflictsFrom(_decodedErrorBody(error));
    if (conflicts.isEmpty) return false;
    if (!mounted) return true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleConflictDialog(conflicts: conflicts),
    );
    return true;
  }

  // "Keep branch timings" is a direct choice, not a modal step — selecting
  // it is itself the confirmation (Open is optional, separate). Schedules
  // aren't sent to the API when scheduleMode is BRANCH_HOURS, so there's
  // no real day data to hold here.
  void _selectBranchHoursSchedule() {
    if (_selectedBranchId == null) {
      Fluttertoast.showToast(msg: translateText('Select a branch first'));
      return;
    }
    setState(() {
      _scheduleMode = 'BRANCH_HOURS';
      _workingHoursSet = true;
      _schedules = const [];
      _markedOffDays = const [];
    });
  }

  Future<void> _pickJoiningDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.starColor,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _save() async {
    final branchId = _selectedBranchId;
    if (branchId == null) {
      Fluttertoast.showToast(msg: translateText('Select a branch'));
      return;
    }
    if (_selectedRoleCodes.isEmpty) {
      Fluttertoast.showToast(msg: translateText('Select at least one role'));
      return;
    }
    if (_selectedServiceIds.isEmpty) {
      Fluttertoast.showToast(msg: translateText('Select at least one service'));
      return;
    }
    if (!_workingHoursSet) {
      Fluttertoast.showToast(msg: translateText('Set working hours'));
      return;
    }
    if (_joiningDate == null) {
      Fluttertoast.showToast(msg: translateText('Select a joining date'));
      return;
    }

    final joiningDateStr =
        '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}';

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> response;
      if (_isEdit) {
        final payload = <String, dynamic>{
          'scheduleMode': _scheduleMode,
          if (_scheduleMode != 'BRANCH_HOURS') 'schedules': _schedules,
          'roles': _selectedRoleCodes.toList(),
          'branchRoleIds': _selectedBranchRoleIds,
          'joiningDate': joiningDateStr,
          'branchServiceIds': _selectedServiceIds,
          'allowOnlineBooking': _allowOnlineBooking,
        };
        response = await ApiService().updateTeamMember(
          branchId: branchId,
          userId: widget.userId,
          payload: payload,
        );
      } else {
        response = await ApiService().assignUserToBranch(
          branchId,
          widget.userId,
          joiningDateStr,
          _schedules,
          _selectedServiceIds,
          _allowOnlineBooking,
          branchRoleIds: _selectedBranchRoleIds,
          roles: _selectedRoleCodes.toList(),
          scheduleMode: _scheduleMode,
        );
      }

      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Branch setup saved'));
        if (!_isEdit && widget.chainIntoCompensation) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamMemberCompensationSetupStep(
                salonId: widget.salonId,
                userId: widget.userId,
                memberName: _memberName,
              ),
            ),
          );
          if (!mounted) return;
        }
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(response, fallback: 'Unable to save'),
        );
      }
    } catch (e) {
      final handled = await _showScheduleConflictDialogIfNeeded(e);
      if (handled) return;
      Fluttertoast.showToast(
        msg: extractErrorMessage(e, fallback: 'Unable to save'),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Shaped to match what _loadData() restores from widget.initialDraft.
  Map<String, dynamic> _currentDraftSnapshot() {
    return {
      'selectedBranchId': _selectedBranchId,
      'selectedRoleCodes': _selectedRoleCodes.toList(),
      'selectedServiceIds': _selectedServiceIds,
      'schedules': _schedules,
      'markedOffDays': _markedOffDays,
      'scheduleMode': _scheduleMode,
      'workingHoursSet': _workingHoursSet,
      'joiningDate': _joiningDate?.toIso8601String(),
      'allowOnlineBooking': _allowOnlineBooking,
    };
  }

  void _popWithDraft() => Navigator.pop(
        context,
        _isEdit ? null : _currentDraftSnapshot(),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithDraft();
      },
      child: Scaffold(
        backgroundColor: cpSurface,
        appBar: buildProfileSubpageAppBar(
          title: 'Branch Setup',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _popWithDraft,
          ),
        ),
        body: _isLoading
            ? AppLoader.page()
            : _loadError != null
                ? CpErrorState(message: _loadError!, onRetry: _loadData)
                : _buildForm(context),
        bottomNavigationBar: (_isLoading || _loadError != null)
            ? null
            : CpBottomButton(
                label: translateText('Save & Continue'),
                isBusy: _isSaving,
                onPressed: _save,
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        CpStepHeading(
          title: translateText('Branch Setup'),
          subtitle: translateText(
              'Assign branch, roles, services and working hours.'),
        ),
        const SizedBox(height: 20),
        CpSectionCard(
          title: '${translateText('Assign Branch')} *',
          icon: Icons.storefront_outlined,
          children: [
            if (_isEdit) ...[
              CpLockedValueChip(
                value: _branchOptions.isEmpty
                    ? translateText('Branch')
                    : (_branchOptions.first['name']?.toString() ?? ''),
              ),
              const SizedBox(height: 6),
              Text(
                translateText(
                  "Branch can't be changed while editing. Use \"Assign User\" to add this member to a different branch.",
                ),
                style: const TextStyle(fontSize: 11.5, color: cpMuted),
              ),
            ] else if (_branchOptions.isEmpty)
              Text(
                translateText(
                  'This member is already assigned to every branch in this salon.',
                ),
                style: const TextStyle(fontSize: 12.5, color: cpMuted),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedBranchId,
                decoration: cpInputDecoration(translateText('Select branch')),
                items: _branchOptions
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: _asInt(b['id']),
                        child: Text(b['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: _selectAssignBranch,
              ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: '${translateText('Assign Role(s)')} *',
          icon: Icons.badge_outlined,
          children: [
            _buildRolesPicker(),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: '${translateText('Services')} *',
          icon: Icons.content_cut_rounded,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cpAccentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isLoadingBranchServices ? null : _openSelectServices,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B6500),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        translateText(
                          _isLoadingBranchServices
                              ? 'Loading services'
                              : _selectedServiceIds.isEmpty
                                  ? 'Select Services'
                                  : 'View/Edit Services',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoadingBranchServices
                        ? translateText('Loading services')
                        : translateText(
                            '{n} services selected',
                            params: {'n': '${_selectedServiceIds.length}'},
                          ),
                    style: const TextStyle(color: cpMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: '${translateText('Working Hours')} *',
          icon: Icons.schedule_outlined,
          children: _isEdit
              ? [
                  _WorkingHoursChoice(
                    title: translateText('Edit schedule'),
                    subtitle: translateText(
                      "Update this member's working hours",
                    ),
                    selected: _workingHoursSet,
                    onTap: () => _openWorkingHours(
                      sameAsBranchTimings: _scheduleMode == 'BRANCH_HOURS',
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => _openWorkingHours(
                        sameAsBranchTimings: _scheduleMode == 'BRANCH_HOURS',
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.starColor),
                        foregroundColor: AppColors.starColor,
                      ),
                      child: Text(translateText('Open')),
                    ),
                  ),
                ]
              : [
                  _WorkingHoursChoice(
                    title: translateText('Keep branch timings'),
                    subtitle:
                        translateText('Use branch working hours for all days'),
                    selected: _scheduleMode == 'BRANCH_HOURS',
                    onTap: _selectBranchHoursSchedule,
                    trailing: _scheduleMode == 'BRANCH_HOURS'
                        ? OutlinedButton(
                            onPressed: _viewBranchHours,
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.starColor),
                              foregroundColor: AppColors.starColor,
                            ),
                            child: Text(translateText('View')),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _WorkingHoursChoice(
                    title: translateText('Custom schedule'),
                    subtitle: translateText('Open custom working hours setup'),
                    selected: _scheduleMode == 'CUSTOM' && _workingHoursSet,
                    onTap: () => _openWorkingHours(
                      sameAsBranchTimings: false,
                      showSameAsBranchToggle: false,
                    ),
                    trailing: _scheduleMode == 'CUSTOM' && _workingHoursSet
                        ? OutlinedButton(
                            onPressed: () => _openWorkingHours(
                              sameAsBranchTimings: false,
                              showSameAsBranchToggle: false,
                            ),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.starColor),
                              foregroundColor: AppColors.starColor,
                            ),
                            child: Text(translateText('View')),
                          )
                        : null,
                  ),
                  if (_scheduleMode == 'BRANCH_HOURS' && _workingHoursSet) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cpAccentLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8C774)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translateText('Branch timings selected'),
                            style: const TextStyle(
                              color: Color(0xFF8B6500),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            translateText(
                              'Branch hours will be applied to all days.',
                            ),
                            style:
                                const TextStyle(color: cpMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: '${translateText('Joining Date')} *',
          icon: Icons.event_outlined,
          children: [
            InkWell(
              onTap: _pickJoiningDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration:
                    cpInputDecoration(translateText('Select date')).copyWith(
                  prefixIcon: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: cpMuted),
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: cpMuted),
                ),
                child: Text(
                  _joiningDate == null
                      ? translateText('Select date')
                      : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                  style:
                      TextStyle(color: _joiningDate == null ? cpMuted : cpInk),
                ),
              ),
            ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: '${translateText('Online Booking')} *',
          icon: Icons.event_available_outlined,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cpBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      translateText(
                        'Allow customers to book {name} online',
                        params: {'name': _memberName},
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: _allowOnlineBooking,
                    activeColor: AppColors.starColor,
                    onChanged: (v) => setState(() => _allowOnlineBooking = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Radio-style row used by Assign flow choices and the edit flow's single
// schedule action.
class _WorkingHoursChoice extends StatelessWidget {
  const _WorkingHoursChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? cpAccent : cpBorder),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? cpAccent : cpMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: cpMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchHoursRow {
  const _BranchHoursRow({
    required this.day,
    required this.hours,
  });

  final String day;
  final String hours;
}

class _BackendScheduleConflict {
  const _BackendScheduleConflict({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.branchName,
  });

  final String day;
  final String startTime;
  final String endTime;
  final String branchName;
}

class _BranchHoursDialog extends StatelessWidget {
  const _BranchHoursDialog({required this.rows});

  final List<_BranchHoursRow> rows;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translateText('Branch Working Hours'),
                            style: const TextStyle(
                              color: cpInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translateText(
                              "This branch's working hours, applied to all days.",
                            ),
                            style: const TextStyle(
                              color: cpMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: cpMuted,
                      tooltip: translateText('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: cpBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cpSurface,
                          border: Border.all(color: cpBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.day,
                                style: const TextStyle(
                                  color: cpInk,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Text(
                              row.hours,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: cpMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cpInk,
                        side: const BorderSide(color: cpBorder),
                      ),
                      child: Text(translateText('Cancel')),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(translateText('Close')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleConflictDialog extends StatelessWidget {
  const _ScheduleConflictDialog({required this.conflicts});

  final List<_BackendScheduleConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        translateText('Schedule conflict'),
                        style: const TextStyle(
                          color: cpInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: cpMuted,
                      tooltip: translateText('Close'),
                    ),
                  ],
                ),
                Text(
                  translateText(
                    'This team member already has an active assignment during these times:',
                  ),
                  style: const TextStyle(
                    color: cpMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: conflicts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final conflict = conflicts[index];
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${conflict.day} - ${conflict.startTime} - ${conflict.endTime}',
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (conflict.branchName.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${translateText('Branch')}: ${conflict.branchName}',
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(translateText('Close')),
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
