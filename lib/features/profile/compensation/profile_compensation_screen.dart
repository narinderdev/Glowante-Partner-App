import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/navigation_service.dart';
import '../../../services/stylist_branch_selection.dart';
import '../../../utils/localization_helper.dart';
import '../../../utils/price_formatter.dart';
import '../../salon/widgets/owner_branch_header_selector.dart';
import '../widgets/profile_subpage_app_bar.dart';
import '../../../utils/colors.dart';
import 'profile_compensation_models.dart';
import 'profile_compensation_repository.dart';
import 'package:fluttertoast/fluttertoast.dart';

part 'owner_payroll.dart';
part 'owner_commission.dart';
part 'owner_advance.dart';
part 'owner_leave_calendar.dart';

enum CompensationModule {
  payroll,
  commission,
  advance,
  attendance,
  leaves,
  holidays,
  leaveCalendar,
}

enum _CommissionTab { services, overrides }

String _formatCurrency(num minorAmount) {
  return '₹${(minorAmount / 100).toStringAsFixed(2)}';
}

String _formatCommissionPercentText(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class ProfileCompensationScreen extends StatefulWidget {
  const ProfileCompensationScreen({
    super.key,
    this.initialModule = CompensationModule.payroll,
  });

  final CompensationModule initialModule;

  @override
  State<ProfileCompensationScreen> createState() =>
      _ProfileCompensationScreenState();
}

class _ProfileCompensationScreenState extends State<ProfileCompensationScreen> {
  final ProfileCompensationRepository _repository =
      ProfileCompensationRepository();
  final TextEditingController _serviceSearchController =
      TextEditingController();
  final TextEditingController _advanceSearchController =
      TextEditingController();
  CompensationModule _module = CompensationModule.payroll;
  _CommissionTab _commissionTab = _CommissionTab.services;

  List<ProfileBranchOption> _branchOptions = const <ProfileBranchOption>[];
  ProfileBranchOption? _selectedBranch;

  List<ProfileTeamMember> _teamMembers = const <ProfileTeamMember>[];
  List<PayrollSetupRecord> _payrollSetups = const <PayrollSetupRecord>[];
  List<PayrollRunRecord> _payrollRuns = const <PayrollRunRecord>[];
  List<PayrollAdvanceRecord> _advances = const <PayrollAdvanceRecord>[];
  List<BranchServiceSummary> _services = const <BranchServiceSummary>[];
  List<CommissionServiceRule> _serviceRules = const <CommissionServiceRule>[];
  List<StaffCommissionOverride> _staffOverrides =
      const <StaffCommissionOverride>[];
  BranchAttendanceOverview? _attendanceOverview;
  BranchPaidLeaveConfig? _branchPaidLeaveConfig;
  PayrollPaidLeavesReview? _paidLeavesReview;
  HolidayCalendarOverview? _holidayCalendar;

  bool _isLoadingBranches = true;
  bool _isLoadingContent = false;
  bool _isRefreshingContent = false;
  bool _isActionInProgress = false;
  bool _isOpeningPayrollSetup = false;
  String? _branchError;
  String? _contentError;
  int? _selectedServiceId;
  DateTime _advanceMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _leaveMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedLeavePayrollId;

  String get _moduleLogLabel => switch (_module) {
        CompensationModule.payroll => 'payroll',
        CompensationModule.commission => 'commission',
        CompensationModule.advance => 'advance',
        CompensationModule.attendance => 'attendance',
        CompensationModule.leaves => 'leaves',
        CompensationModule.holidays => 'holidays',
        CompensationModule.leaveCalendar => 'leave_calendar',
      };

  bool get _usesLeaveCalendarData => switch (_module) {
        CompensationModule.attendance ||
        CompensationModule.leaves ||
        CompensationModule.holidays ||
        CompensationModule.leaveCalendar =>
          true,
        _ => false,
      };

  void _logCompensation(String event, {Object? details}) {
    debugPrint(
      '[OwnerCompensation:$_moduleLogLabel] $event${details == null ? '' : ' | $details'}',
    );
  }

  @override
  void initState() {
    super.initState();
    _module = widget.initialModule;
    _logCompensation('init', details: 'initialModule=$_moduleLogLabel');
    _serviceSearchController.addListener(() {
      _logCompensation(
        'service_search_changed',
        details: _serviceSearchController.text.trim(),
      );
      setState(() {});
    });
    _advanceSearchController.addListener(() {
      _logCompensation(
        'advance_search_changed',
        details: _advanceSearchController.text.trim(),
      );
      setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _advanceSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _logCompensation('load_initial_data_started');
    setState(() {
      _isLoadingBranches = true;
      _branchError = null;
    });

    try {
      final branchOptions = await _repository.loadBranchOptions();
      ProfileBranchOption? selectedBranch;
      final selection = await StylistBranchSelectionStore.load();
      if (selection.branchId != null) {
        selectedBranch = branchOptions.cast<ProfileBranchOption?>().firstWhere(
              (item) => item?.branchId == selection.branchId,
              orElse: () => null,
            );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _branchOptions = branchOptions;
        _selectedBranch = selectedBranch;
        _isLoadingBranches = false;
      });
      _logCompensation(
        'load_initial_data_success',
        details:
            'branches=${branchOptions.length}, selectedBranch=${selectedBranch?.branchId}',
      );

      if (selectedBranch != null) {
        await _reloadContent();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingBranches = false;
        _branchError = _errorText(error);
      });
      _logCompensation(
        'load_initial_data_failed',
        details: _errorText(error),
      );
    }
  }

  Future<void> _reloadContent({bool showLoader = true}) async {
    final selectedBranch = _selectedBranch;
    _logCompensation(
      'reload_content_started',
      details:
          'branchId=${selectedBranch?.branchId}, showLoader=$showLoader, module=$_moduleLogLabel',
    );
    if (selectedBranch == null) {
      setState(() {
        _contentError = null;
        _isLoadingContent = false;
        _isRefreshingContent = false;
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _isLoadingContent = true;
        _isRefreshingContent = false;
        _contentError = null;
      });
    } else {
      setState(() {
        _isRefreshingContent = true;
        _contentError = null;
      });
    }

    try {
      if (_module == CompensationModule.payroll) {
        await _loadPayrollData(selectedBranch.branchId);
      } else if (_module == CompensationModule.advance) {
        await _loadAdvanceData(selectedBranch.branchId);
      } else if (_usesLeaveCalendarData) {
        await _loadLeaveData(selectedBranch);
      } else {
        await _loadCommissionData(selectedBranch.branchId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingContent = false;
        _isRefreshingContent = false;
      });
      _logCompensation(
        'reload_content_success',
        details:
            'branchId=${selectedBranch.branchId}, team=${_teamMembers.length}, runs=${_payrollRuns.length}, services=${_services.length}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingContent = false;
        _isRefreshingContent = false;
        _contentError = _errorText(error);
      });
      _logCompensation(
        'reload_content_failed',
        details: _errorText(error),
      );
    }
  }

  Future<void> _loadPayrollData(int branchId) async {
    _logCompensation('load_payroll_data_started',
        details: 'branchId=$branchId');
    final teamMembers = await _repository.loadTeamMembers(branchId);
    final payrollSetups = await _repository.loadPayrollSetups(branchId);
    final payrollRuns = await _repository.loadPayrollRuns(
      branchId,
      teamMembers: teamMembers,
      setups: payrollSetups,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(teamMembers);
      _payrollSetups = List<PayrollSetupRecord>.from(payrollSetups);
      _payrollRuns = List<PayrollRunRecord>.from(payrollRuns);
    });
    _logCompensation(
      'load_payroll_data_success',
      details:
          'branchId=$branchId, team=${_teamMembers.length}, setups=${_payrollSetups.length}, runs=${_payrollRuns.length}',
    );
  }

  Future<void> _loadCommissionData(int branchId) async {
    _logCompensation(
      'load_commission_data_started',
      details: 'branchId=$branchId',
    );
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _repository.loadTeamMembers(branchId),
      _repository.loadServices(branchId),
      _repository.loadCommissionRules(branchId),
      _repository.loadCommissionOverrides(branchId),
    ]);

    final services = List<BranchServiceSummary>.from(results[1] as List);
    int? selectedServiceId = _selectedServiceId;
    if (services.isEmpty) {
      selectedServiceId = null;
    } else if (!services.any((item) => item.id == selectedServiceId)) {
      selectedServiceId = services.first.id;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(results[0] as List);
      _services = services;
      _serviceRules = List<CommissionServiceRule>.from(results[2] as List);
      _staffOverrides = List<StaffCommissionOverride>.from(results[3] as List);
      _selectedServiceId = selectedServiceId;
    });
    _logCompensation(
      'load_commission_data_success',
      details:
          'branchId=$branchId, team=${_teamMembers.length}, services=${_services.length}, rules=${_serviceRules.length}, overrides=${_staffOverrides.length}, selectedServiceId=$_selectedServiceId',
    );
  }

  Future<void> _loadAdvanceData(int branchId) async {
    _logCompensation(
      'load_advance_data_started',
      details: 'branchId=$branchId, month=${_advanceMonth.toIso8601String()}',
    );
    final teamMembers = await _repository.loadTeamMembers(branchId);
    final advances = await _repository.loadBranchAdvances(
      branchId: branchId,
      month: _advanceMonth,
      teamMembers: teamMembers,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(teamMembers);
      _advances = List<PayrollAdvanceRecord>.from(advances);
    });
    _logCompensation(
      'load_advance_data_success',
      details:
          'branchId=$branchId, team=${_teamMembers.length}, advances=${_advances.length}',
    );
  }

  Future<void> _loadLeaveData(ProfileBranchOption branch) async {
    _logCompensation(
      'load_leave_data_started',
      details:
          'branchId=${branch.branchId}, salonId=${branch.salonId}, month=${_leaveMonth.toIso8601String()}, payrollId=$_selectedLeavePayrollId',
    );
    if (_module == CompensationModule.attendance) {
      final attendanceOverview = await _repository.loadBranchAttendanceOverview(
        branchId: branch.branchId,
        month: _leaveMonth,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _teamMembers = const <ProfileTeamMember>[];
        _attendanceOverview = attendanceOverview;
      });
      _logCompensation(
        'load_leave_data_success',
        details:
            'branchId=${branch.branchId}, attendanceEmployees=${attendanceOverview.employees.length}, month=${DateFormat('yyyy-MM').format(_leaveMonth)}',
      );
      return;
    }

    if (_module == CompensationModule.leaves) {
      final branchPaidLeaveConfig = await _repository.loadBranchPaidLeaveConfig(
        branchId: branch.branchId,
        branchName: branch.label,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _teamMembers = const <ProfileTeamMember>[];
        _branchPaidLeaveConfig = branchPaidLeaveConfig;
      });
      _logCompensation(
        'load_leave_data_success',
        details:
            'branchId=${branch.branchId}, paidLeaveDays=${branchPaidLeaveConfig.paidLeaveDays}',
      );
      return;
    }

    if (_module == CompensationModule.holidays) {
      final holidayCalendar = await _repository.loadHolidayCalendar(
        salonId: branch.salonId,
        month: _leaveMonth,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _teamMembers = const <ProfileTeamMember>[];
        _holidayCalendar = holidayCalendar;
      });
      _logCompensation(
        'load_leave_data_success',
        details:
            'branchId=${branch.branchId}, holidays=${holidayCalendar.holidays.length}, month=${DateFormat('yyyy-MM').format(_leaveMonth)}',
      );
      return;
    }

    final teamMembers = await _repository.loadTeamMembers(branch.branchId);
    final payrollSetups = await _repository.loadPayrollSetups(branch.branchId);
    final payrollRuns = await _repository.loadPayrollRuns(
      branch.branchId,
      teamMembers: teamMembers,
      setups: payrollSetups,
    );

    PayrollRunRecord? selectedRun;
    if (_selectedLeavePayrollId != null) {
      selectedRun = payrollRuns.cast<PayrollRunRecord?>().firstWhere(
            (item) => item?.id == _selectedLeavePayrollId,
            orElse: () => null,
          );
    }
    selectedRun ??= payrollRuns.cast<PayrollRunRecord?>().firstWhere(
          (item) =>
              item?.periodKey == DateFormat('yyyy-MM').format(_leaveMonth),
          orElse: () => null,
        );
    selectedRun ??= payrollRuns.isEmpty ? null : payrollRuns.first;

    final effectiveMonth = selectedRun == null
        ? _leaveMonth
        : DateTime.tryParse('${selectedRun.periodKey}-01') ?? _leaveMonth;
    final attendanceOverview = await _repository.loadBranchAttendanceOverview(
      branchId: branch.branchId,
      month: effectiveMonth,
    );
    final branchPaidLeaveConfig = await _repository.loadBranchPaidLeaveConfig(
      branchId: branch.branchId,
      branchName: branch.label,
    );
    final paidLeavesReview = await _repository.loadPayrollPaidLeavesReview(
      branchId: branch.branchId,
      payrollId: selectedRun?.id,
      attendanceOverview: attendanceOverview,
    );
    final holidayCalendar = await _repository.loadHolidayCalendar(
      salonId: branch.salonId,
      month: effectiveMonth,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(teamMembers);
      _payrollSetups = List<PayrollSetupRecord>.from(payrollSetups);
      _payrollRuns = List<PayrollRunRecord>.from(payrollRuns);
      _attendanceOverview = attendanceOverview;
      _branchPaidLeaveConfig = branchPaidLeaveConfig;
      _paidLeavesReview = paidLeavesReview;
      _holidayCalendar = holidayCalendar;
      _selectedLeavePayrollId = selectedRun?.id;
      _leaveMonth = effectiveMonth;
    });
    _logCompensation(
      'load_leave_data_success',
      details:
          'branchId=${branch.branchId}, attendanceEmployees=${attendanceOverview.employees.length}, paidLeaveEmployees=${paidLeavesReview.employees.length}, holidays=${holidayCalendar.holidays.length}',
    );
  }

  Future<void> _switchBranch(ProfileBranchOption option) async {
    if (_selectedBranch?.branchId == option.branchId) {
      return;
    }
    _logCompensation(
      'switch_branch',
      details: 'from=${_selectedBranch?.branchId} to=${option.branchId}',
    );

    setState(() {
      _selectedBranch = option;
      _selectedServiceId = null;
    });
    await _repository.saveBranchSelection(option);
    await _reloadContent();
  }

  Future<void> _savePayrollSetup(PayrollSetupRecord setup) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'save_payroll_setup_started',
      details:
          'branchId=$branchId, userId=${setup.userId}, payrollType=${setup.payrollType}',
    );
    await _repository.savePayrollSetup(branchId, setup);
    await _loadPayrollData(branchId);
    _logCompensation(
      'save_payroll_setup_success',
      details: 'branchId=$branchId, userId=${setup.userId}',
    );
    _showToast('Payroll setup saved successfully');
  }

  Future<void> _createAdvance(PayrollAdvanceRecord advance) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'create_advance_started',
      details:
          'branchId=$branchId, employeeId=${advance.employeeId}, amount=${advance.amount}',
    );
    await _repository.createAdvance(
      branchId: branchId,
      advance: advance,
    );
    await _loadAdvanceData(branchId);
    _logCompensation(
      'create_advance_success',
      details: 'branchId=$branchId, employeeId=${advance.employeeId}',
    );
    _showToast('Advance saved successfully');
  }

  Future<void> _generatePayroll(DateTime period) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'generate_payroll_requested',
      details: 'branchId=$branchId, period=${period.toIso8601String()}',
    );
    await _performAction(() async {
      await _repository.generatePayroll(
        branchId: branchId,
        period: period,
        teamMembers: _activeTeamMembers,
      );
      await _loadPayrollData(branchId);
      if (!mounted) {
        return;
      }
      _logCompensation(
        'generate_payroll_success',
        details: 'branchId=$branchId, period=${period.toIso8601String()}',
      );
      _showToast('Payroll generated successfully');
    });
  }

  Future<void> _cancelPayroll(PayrollRunRecord payrollRun) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    _logCompensation(
      'cancel_payroll_requested',
      details: 'branchId=${branch.branchId}, payrollId=${payrollRun.id}',
    );
    await _performAction(() async {
      final didCancel = await _repository.cancelPayroll(
        branchId: branch.branchId,
        payrollId: payrollRun.id,
        periodKey: payrollRun.periodKey,
        teamMembers: _activeTeamMembers,
      );
      await _loadPayrollData(branch.branchId);
      _showToast(
        didCancel
            ? 'Payroll cancelled successfully'
            : 'Payroll is already cancelled',
      );
    });
  }

  Future<void> _setPaidLeaveDays({
    required int payrollEmployeeId,
    required int paidLeaveDays,
  }) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    await _performAction(() async {
      if (paidLeaveDays <= 0) {
        await _repository.deletePayrollEmployeePaidLeave(
          payrollEmployeeId: payrollEmployeeId,
        );
      } else {
        await _repository.setPayrollEmployeePaidLeave(
          payrollEmployeeId: payrollEmployeeId,
          paidLeaveDays: paidLeaveDays,
        );
      }
      await _loadLeaveData(branch);
      _showToast('Paid leaves updated successfully');
    });
  }

  Future<void> _setBranchPaidLeaveDays({
    required int branchId,
    required int paidLeaveDays,
  }) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    await _performAction(() async {
      await _repository.setBranchPaidLeaveConfig(
        branchId: branchId,
        paidLeaveDays: paidLeaveDays,
      );
      await _loadLeaveData(branch);
      _showToast('Default paid leaves updated successfully');
    });
  }

  Future<void> _changeLeaveMonth(DateTime month) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    setState(() {
      _leaveMonth = DateTime(month.year, month.month);
      _selectedLeavePayrollId = null;
    });
    await _reloadContent(showLoader: false);
  }

  Future<void> _changeLeavePayroll(String? payrollId) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    final selectedRun = _payrollRuns.cast<PayrollRunRecord?>().firstWhere(
          (item) => item?.id == payrollId,
          orElse: () => null,
        );
    setState(() {
      _selectedLeavePayrollId = payrollId;
      if (selectedRun != null) {
        _leaveMonth =
            DateTime.tryParse('${selectedRun.periodKey}-01') ?? _leaveMonth;
      }
    });
    await _reloadContent(showLoader: false);
  }

  Future<void> _saveHoliday({
    required DateTime holidayDate,
    required String title,
    required String description,
    int? holidayId,
  }) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    await _performAction(() async {
      if (holidayId == null) {
        await _repository.createHoliday(
          salonId: branch.salonId,
          holidayDate: holidayDate,
          title: title,
          description: description,
        );
      } else {
        await _repository.updateHoliday(
          salonId: branch.salonId,
          holidayId: holidayId,
          holidayDate: holidayDate,
          title: title,
          description: description,
        );
      }
      await _loadLeaveData(branch);
      _showToast(
        holidayId == null
            ? 'Holiday added successfully'
            : 'Holiday updated successfully',
      );
    });
  }

  Future<void> _deleteHoliday(int holidayId) async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    await _performAction(() async {
      await _repository.deleteHoliday(
        salonId: branch.salonId,
        holidayId: holidayId,
      );
      await _loadLeaveData(branch);
      _showToast('Holiday deleted successfully');
    });
  }

  Future<void> _saveCommissionRule({
    required BranchServiceSummary service,
    required CommissionServiceRule rule,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'save_commission_rule_started',
      details:
          'branchId=$branchId, serviceId=${service.id}, ruleType=${rule.ruleType}, active=${rule.active}',
    );
    await _performAction(() async {
      await _repository.saveCommissionRule(
        branchId: branchId,
        service: service,
        rule: rule,
      );
      await _loadCommissionData(branchId);
      _logCompensation(
        'save_commission_rule_success',
        details: 'branchId=$branchId, serviceId=${service.id}',
      );
      _showToast('Commission rule saved successfully');
    });
  }

  Future<void> _saveOverrides(
    int serviceId,
    List<StaffCommissionOverride> overrides,
  ) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'save_commission_overrides_started',
      details:
          'branchId=$branchId, serviceId=$serviceId, overrides=${overrides.length}',
    );
    if (_isActionInProgress) {
      return;
    }
    setState(() {
      _isActionInProgress = true;
    });
    try {
      final currentForService = _staffOverrides
          .where((item) => item.serviceId == serviceId)
          .where(
            (item) =>
                !overrides.any((override) => override.staffId == item.staffId),
          )
          .toList();
      await _repository.saveStaffOverrides(
        branchId: branchId,
        serviceId: serviceId,
        overrides: <StaffCommissionOverride>[
          ...currentForService,
          ...overrides,
        ],
      );
      await _loadCommissionData(branchId);
      _logCompensation(
        'save_commission_overrides_success',
        details: 'branchId=$branchId, serviceId=$serviceId',
      );
      _showToast('Commission override saved successfully');
    } catch (error) {
      _logCompensation(
        'save_commission_overrides_failed',
        details: _errorText(error),
      );
      _showToast(_errorText(error), isError: true);
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<void> _deleteOverride(String overrideId) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'delete_commission_override_started',
      details: 'branchId=$branchId, overrideId=$overrideId',
    );
    await _performAction(() async {
      await _repository.deleteStaffOverride(
        branchId: branchId,
        overrideId: overrideId,
      );
      await _loadCommissionData(branchId);
      _logCompensation(
        'delete_commission_override_success',
        details: 'branchId=$branchId, overrideId=$overrideId',
      );
      _showToast('Override removed successfully');
    });
  }

  Future<void> _performAction(Future<void> Function() action) async {
    if (_isActionInProgress) {
      _logCompensation('perform_action_skipped',
          details: 'already_in_progress');
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });

    try {
      await action();
    } catch (error) {
      _logCompensation('perform_action_failed', details: _errorText(error));
      _showToast(_errorText(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  List<ProfileTeamMember> get _activeTeamMembers =>
      _teamMembers.where((item) => item.isActive).toList();

  Map<int, PayrollSetupRecord> get _setupByUserId {
    return <int, PayrollSetupRecord>{
      for (final item in _payrollSetups) item.userId: item,
    };
  }

  bool get _isPayrollConfiguredForAllTeam {
    final activeMembers = _activeTeamMembers;
    if (activeMembers.isEmpty) {
      return false;
    }
    return activeMembers.every((item) => _setupByUserId.containsKey(item.id));
  }

  BranchServiceSummary? get _selectedService {
    for (final service in _services) {
      if (service.id == _selectedServiceId) {
        return service;
      }
    }
    return _services.isEmpty ? null : _services.first;
  }

  CommissionServiceRule? get _selectedServiceRule {
    final service = _selectedService;
    if (service == null) {
      return null;
    }
    return _repository.ruleForService(
      service: service,
      storedRules: _serviceRules,
    );
  }

  List<BranchServiceSummary> get _filteredServices {
    final query = _serviceSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _services;
    }
    return _services.where((service) {
      final haystack =
          '${service.name} ${service.categoryName} ${service.description}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<StaffCommissionOverride> get _selectedServiceOverrides {
    final serviceId = _selectedService?.id;
    if (serviceId == null) {
      return const <StaffCommissionOverride>[];
    }
    final items =
        _staffOverrides.where((item) => item.serviceId == serviceId).toList();
    items.sort((a, b) =>
        a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase()));
    return items;
  }

  void _showToast(String message, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = appNavigatorKey.currentContext ?? context;
      final messenger = ScaffoldMessenger.maybeOf(targetContext);
      if (messenger == null) {
        return;
      }
      Fluttertoast.showToast(msg: message);
    });
  }

  void _setCommissionTabValue(_CommissionTab tab) {
    setState(() => _commissionTab = tab);
  }

  void _selectCommissionService(int serviceId) {
    setState(() => _selectedServiceId = serviceId);
  }

  String _errorText(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }

  String _formatCurrency(num amount) {
    return formatMinorAmount(amount, trimZeroDecimals: true);
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  List<PayrollAdvanceRecord> get _filteredAdvances {
    final query = _advanceSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _advances;
    }
    return _advances.where((item) {
      final haystack =
          '${item.employeeName} ${item.paymentMode} ${item.paymentReference} ${item.remarks}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFFB45309);
      case 'paid':
        return const Color(0xFF157347);
      case 'cancelled':
        return const Color(0xFF6B7280);
      case 'reviewed':
      case 'approved':
        return const Color(0xFF0D6EFD);
      default:
        return const Color(0xFFB26A00);
    }
  }

  Future<void> _openGeneratePayrollDialog() async {
    _logCompensation('open_generate_payroll_dialog');
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => const _GeneratePayrollDialog(),
    );
    if (selected == null) {
      _logCompensation('generate_payroll_dialog_cancelled');
      return;
    }
    _logCompensation(
      'generate_payroll_dialog_selected',
      details: selected.toIso8601String(),
    );
    await _generatePayroll(selected);
  }

  Future<void> _openPayrollSetupScreen() async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null || _isOpeningPayrollSetup) {
      return;
    }
    _logCompensation(
      'open_payroll_setup_screen',
      details: 'branchId=$branchId',
    );
    setState(() => _isOpeningPayrollSetup = true);
    try {
      await _loadPayrollData(branchId);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) {
            return Scaffold(
              backgroundColor: const Color(0xFFFBF9F8),
              appBar:
                  buildProfileSubpageAppBar(title: context.t('Setup Payroll')),
              body: _PayrollSetupView(
                teamMembers: _activeTeamMembers,
                existingSetups: _setupByUserId,
                onSave: _savePayrollSetup,
                onContinue: () {
                  _openPayrollSetupReviewScreen(routeContext);
                },
              ),
            );
          },
        ),
      );
    } catch (error) {
      _logCompensation(
        'open_payroll_setup_screen_failed',
        details: _errorText(error),
      );
      _showToast(_errorText(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isOpeningPayrollSetup = false);
      }
    }
  }

  Future<void> _openPayrollSetupReviewScreen(BuildContext setupContext) async {
    final included = _activeTeamMembers
        .where((member) => _setupByUserId.containsKey(member.id))
        .toList();
    final excluded = _activeTeamMembers
        .where((member) => !_setupByUserId.containsKey(member.id))
        .toList();
    final totalSalary = included.fold<int>(0, (sum, member) {
      final setup = _setupByUserId[member.id];
      return sum + (setup?.salaryMinor ?? 0);
    });

    await Navigator.of(setupContext).push(
      MaterialPageRoute<void>(
        builder: (reviewContext) {
          return Scaffold(
            backgroundColor: const Color(0xFFFBF9F8),
            appBar: buildProfileSubpageAppBar(title: 'Review Payroll'),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _PayrollSetupStepHeader(currentStep: 2),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 190,
                        child: _MetricCard(
                          label: 'Total Salary',
                          value: _formatCurrency(totalSalary),
                          subtitle: 'configured salary',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 190,
                        child: _MetricCard(
                          label: 'Total Team Member',
                          value: '${_activeTeamMembers.length}',
                          subtitle: 'active members',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 190,
                        child: _MetricCard(
                          label: 'Payroll Setup',
                          value: '${included.length}',
                          subtitle: '${excluded.length} pending',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildPayrollSetupReviewCard(
                  title: 'Team Members Included (${included.length})',
                  subtitle:
                      'These team members will be included in this payroll.',
                  members: included,
                  showReason: false,
                ),
                const SizedBox(height: 16),
                _buildPayrollSetupReviewCard(
                  title: 'Team Members Not Included (${excluded.length})',
                  subtitle:
                      'These team members do not have salary or commission set.',
                  members: excluded,
                  showReason: true,
                  onSetupTap: () {
                    Navigator.of(reviewContext).pop();
                  },
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(reviewContext).pop();
                      Navigator.of(setupContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go to Payroll Dashboard'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPayrollReview(PayrollRunRecord initialRun) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'open_payroll_review',
      details: 'branchId=$branchId, runId=${initialRun.id}',
    );

    PayrollRunRecord currentRun = initialRun;
    try {
      _logCompensation(
        'load_payroll_review_started',
        details: 'branchId=$branchId, runId=${initialRun.id}',
      );
      currentRun = await _repository.fetchPayrollReviewDetails(
        branchId: branchId,
        payrollId: initialRun.id,
        fallbackRun: initialRun,
      );
      _logCompensation(
        'load_payroll_review_success',
        details:
            'branchId=$branchId, runId=${currentRun.id}, employees=${currentRun.employees.length}',
      );
    } catch (error) {
      _logCompensation(
        'load_payroll_review_failed',
        details: _errorText(error),
      );
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) {
          String searchQuery = '';
          String selectedStatus = 'All Status';
          bool isReviewBusy = false;
          String? reviewBusyAction;

          Future<void> refreshRun(PayrollRunRecord updatedRun) async {
            currentRun = updatedRun;
            await _loadPayrollData(branchId);
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              final reviewStatus = currentRun.statusLabel.toLowerCase();
              final paidEmployeesCount = currentRun.employees
                  .where((employee) =>
                      employee.statusLabel.toLowerCase() == 'paid')
                  .length;
              final unpaidEmployeesCount = currentRun.employees
                  .where((employee) =>
                      employee.statusLabel.toLowerCase() != 'paid')
                  .length;
              return Scaffold(
                backgroundColor: const Color(0xFFFBF9F8),
                appBar: buildProfileSubpageAppBar(title: 'Payroll'),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 190,
                            child: _MetricCard(
                              label: 'Total employees',
                              value: '${currentRun.employeeCount}',
                              subtitle: 'included',
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 190,
                            child: _MetricCard(
                              label: 'Total net payable',
                              value: _formatCurrency(
                                currentRun.totalAmountMinor,
                              ),
                              subtitle: currentRun.periodLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 190,
                            child: _MetricCard(
                              label: 'Paid',
                              value: _formatCurrency(
                                currentRun.paidAmountMinor,
                              ),
                              subtitle: '($paidEmployeesCount)',
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 190,
                            child: _MetricCard(
                              label: reviewStatus == 'cancelled'
                                  ? 'Cancelled'
                                  : 'Pending',
                              value: _formatCurrency(
                                currentRun.outstandingAmountMinor,
                              ),
                              subtitle: reviewStatus == 'cancelled'
                                  ? '($unpaidEmployeesCount) unpaid'
                                  : '($unpaidEmployeesCount)',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isReviewBusy) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF6D7B8),
                                ),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Updating payroll review...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  LinearProgressIndicator(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentRun.periodLabel,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                              ),
                              _StatusPill(
                                label: currentRun.statusLabel,
                                color: _statusColor(currentRun.statusLabel),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review the payroll entries and manage payments for this period.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _ActionChipButton(
                                label: 'Refresh Review',
                                isLoading: reviewBusyAction == 'refresh_review',
                                onTap: () async {
                                  if (isReviewBusy) {
                                    return;
                                  }
                                  setSheetState(() {
                                    isReviewBusy = true;
                                    reviewBusyAction = 'refresh_review';
                                  });
                                  try {
                                    final refreshed = await _repository
                                        .fetchPayrollReviewDetails(
                                      branchId: branchId,
                                      payrollId: currentRun.id,
                                      fallbackRun: currentRun,
                                    );
                                    await refreshRun(refreshed);
                                    if (context.mounted) {
                                      setSheetState(
                                          () => currentRun = refreshed);
                                    }
                                  } catch (error) {
                                    _showToast(
                                      _errorText(error),
                                      isError: true,
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() {
                                        isReviewBusy = false;
                                        reviewBusyAction = null;
                                      });
                                    }
                                  }
                                },
                                filled: true,
                              ),
                              if (reviewStatus != 'cancelled')
                                _ActionChipButton(
                                  label: 'Cancel Payroll',
                                  isLoading:
                                      reviewBusyAction == 'cancel_payroll',
                                  onTap: () async {
                                    if (isReviewBusy) {
                                      return;
                                    }
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) {
                                        return AlertDialog(
                                          title: const Text('Cancel payroll'),
                                          content: const Text(
                                            'This will cancel the payroll run for this period.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('No'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFB02A37),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Yes, cancel'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirmed != true) {
                                      return;
                                    }
                                    setSheetState(() {
                                      isReviewBusy = true;
                                      reviewBusyAction = 'cancel_payroll';
                                    });
                                    try {
                                      await _cancelPayroll(currentRun);
                                      if (screenContext.mounted) {
                                        Navigator.of(screenContext).pop();
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setSheetState(() {
                                          isReviewBusy = false;
                                          reviewBusyAction = null;
                                        });
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            maxLength: 60,
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: (value) {
                              setSheetState(() => searchQuery = value.trim());
                            },
                            decoration: InputDecoration(
                              hintText: 'Search employee...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            isDense: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All Status',
                                child: Text('All Status'),
                              ),
                              DropdownMenuItem(
                                value: 'Paid',
                                child: Text('Paid'),
                              ),
                              DropdownMenuItem(
                                value: 'Pending',
                                child: Text('Pending'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setSheetState(() => selectedStatus = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    currentRun.employees.isEmpty
                        ? const _EmptyStateCard(
                            title: 'No payroll rows found',
                            subtitle:
                                'Generate a payroll run to review employee payouts.',
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = constraints.maxWidth < 760
                                    ? 760.0
                                    : constraints.maxWidth;
                                final filteredEmployees =
                                    currentRun.employees.where((employee) {
                                  final matchesSearch = searchQuery.isEmpty ||
                                      employee.userName.toLowerCase().contains(
                                            searchQuery.toLowerCase(),
                                          );
                                  final matchesStatus =
                                      selectedStatus == 'All Status' ||
                                          employee.statusLabel.toLowerCase() ==
                                              selectedStatus.toLowerCase();
                                  return matchesSearch && matchesStatus;
                                }).toList();

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: filteredEmployees.length + 1,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 24),
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return const Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'Employee',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Role',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Net Payable (₹)',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Status',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 96,
                                                child: Text(
                                                  'Action',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }

                                        final employee =
                                            filteredEmployees[index - 1];
                                        final status = employee.statusLabel;
                                        return Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                employee.userName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1C1917),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                employee.role.isEmpty
                                                    ? 'Team Member'
                                                    : employee.role,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatCurrency(
                                                  employee.netPayableMinor,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: _StatusPill(
                                                  label: status,
                                                  color: _statusColor(status),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 96,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: OutlinedButton(
                                                  onPressed: () async {
                                                    final updated =
                                                        await _openEmployeeReview(
                                                      run: currentRun,
                                                      employee: employee,
                                                    );
                                                    if (updated != null &&
                                                        screenContext.mounted) {
                                                      await refreshRun(updated);
                                                      setSheetState(
                                                        () => currentRun =
                                                            updated,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    status.toLowerCase() ==
                                                            'paid'
                                                        ? 'View'
                                                        : 'Review',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<PayrollRunRecord?> _openEmployeeReview({
    required PayrollRunRecord run,
    required PayrollRunEmployeeRecord employee,
  }) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return null;
    }
    _logCompensation(
      'open_employee_review',
      details: 'branchId=$branchId, runId=${run.id}, userId=${employee.userId}',
    );

    try {
      run = await _repository.refreshEmployeeAdjustments(
        branchId: branchId,
        runId: run.id,
        userId: employee.userId,
        payrollEmployeeId: employee.payrollEmployeeId > 0
            ? employee.payrollEmployeeId
            : employee.userId,
      );
      employee =
          run.employees.firstWhere((item) => item.userId == employee.userId);
    } catch (error) {
      _logCompensation(
        'load_employee_adjustments_failed',
        details: _errorText(error),
      );
    }

    PayrollRunRecord currentRun = run;
    PayrollRunEmployeeRecord currentEmployee = employee;
    final paymentModeController = TextEditingController(text: 'Bank Transfer');
    final paymentReferenceController = TextEditingController();
    final paymentNotesController = TextEditingController();
    final adjustmentAmountController = TextEditingController();
    final adjustmentRemarksController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    String adjustmentType = AdjustmentTypes.addition;

    if (!mounted) {
      return null;
    }

    final result = await showGeneralDialog<PayrollRunRecord>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Payroll employee review',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      pageBuilder: (_, __, ___) {
        return const SizedBox.shrink();
      },
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (dialogContext, animation, _, __) {
        bool isBusy = false;

        Future<void> refreshEmployee(PayrollRunRecord updatedRun) async {
          currentRun = updatedRun;
          currentEmployee = updatedRun.employees.firstWhere(
            (item) => item.userId == employee.userId,
          );
          await _loadPayrollData(branchId);
        }

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> addAdjustmentInline() async {
              if (isBusy) {
                return;
              }
              final amount =
                  int.tryParse(adjustmentAmountController.text.trim()) ?? 0;
              if (amount <= 0) {
                _showToast('Enter a valid amount', isError: true);
                return;
              }
              if (adjustmentRemarksController.text.trim().isEmpty) {
                _showToast('Remarks are required', isError: true);
                return;
              }
              final adjustment = PayrollAdjustmentRecord(
                id: '',
                payrollEmployeeId: currentEmployee.payrollEmployeeId > 0
                    ? currentEmployee.payrollEmployeeId
                    : currentEmployee.userId,
                type: adjustmentType,
                amountMinor: rupeesToMinorAmount(amount),
                remarks: adjustmentRemarksController.text.trim(),
                createdAt: DateTime.now(),
              );
              setSheetState(() => isBusy = true);
              try {
                _logCompensation(
                  'add_adjustment_started',
                  details:
                      'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, type=$adjustmentType',
                );
                final updated = await _repository.addEmployeeAdjustment(
                  branchId: branchId,
                  runId: currentRun.id,
                  userId: currentEmployee.userId,
                  adjustment: adjustment,
                );
                await refreshEmployee(updated);
                if (sheetContext.mounted) {
                  setSheetState(() {});
                }
                adjustmentAmountController.clear();
                adjustmentRemarksController.clear();
                _logCompensation(
                  'add_adjustment_success',
                  details:
                      'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, type=$adjustmentType',
                );
                _showToast('Adjustment saved successfully');
              } catch (error) {
                _logCompensation(
                  'add_adjustment_failed',
                  details: _errorText(error),
                );
                _showToast(_errorText(error), isError: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isBusy = false);
                }
              }
            }

            Future<void> editAdjustment(
              PayrollAdjustmentRecord existing,
            ) async {
              if (isBusy) {
                return;
              }
              final updatedAdjustment = await _showAdjustmentDialog(
                existing.type,
                payrollEmployeeId: existing.payrollEmployeeId,
                initialAdjustment: existing,
                onSubmit: (updatedAdjustment) async {
                  setSheetState(() => isBusy = true);
                  try {
                    _logCompensation(
                      'edit_adjustment_started',
                      details:
                          'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, adjustmentId=${existing.id}',
                    );
                    final updated = await _repository.updateEmployeeAdjustment(
                      branchId: branchId,
                      runId: currentRun.id,
                      userId: currentEmployee.userId,
                      adjustment: updatedAdjustment,
                    );
                    await refreshEmployee(updated);
                    if (sheetContext.mounted) {
                      setSheetState(() {});
                    }
                    _logCompensation(
                      'edit_adjustment_success',
                      details:
                          'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, adjustmentId=${existing.id}',
                    );
                    _showToast('Adjustment updated successfully');
                  } catch (error) {
                    _logCompensation(
                      'edit_adjustment_failed',
                      details: _errorText(error),
                    );
                    _showToast(_errorText(error), isError: true);
                    rethrow;
                  } finally {
                    if (sheetContext.mounted) {
                      setSheetState(() => isBusy = false);
                    }
                  }
                },
              );
              if (updatedAdjustment == null) {
                _logCompensation(
                  'edit_adjustment_cancelled',
                  details:
                      'id=${existing.id}, userId=${currentEmployee.userId}',
                );
                return;
              }
            }

            Future<void> deleteAdjustment(
              PayrollAdjustmentRecord existing,
            ) async {
              if (isBusy) {
                return;
              }
              final deleted = await showDialog<bool>(
                context: sheetContext,
                builder: (context) {
                  bool isDeleting = false;
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      Future<void> confirmDelete() async {
                        if (isDeleting) {
                          return;
                        }
                        setDialogState(() => isDeleting = true);
                        setSheetState(() => isBusy = true);
                        try {
                          _logCompensation(
                            'delete_adjustment_started',
                            details:
                                'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, adjustmentId=${existing.id}',
                          );
                          final updated =
                              await _repository.deleteEmployeeAdjustment(
                            branchId: branchId,
                            runId: currentRun.id,
                            userId: currentEmployee.userId,
                            adjustment: existing,
                          );
                          await refreshEmployee(updated);
                          if (sheetContext.mounted) {
                            setSheetState(() {});
                          }
                          _logCompensation(
                            'delete_adjustment_success',
                            details:
                                'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, adjustmentId=${existing.id}',
                          );
                          _showToast('Adjustment deleted successfully');
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          _logCompensation(
                            'delete_adjustment_failed',
                            details: _errorText(error),
                          );
                          _showToast(_errorText(error), isError: true);
                          if (dialogContext.mounted) {
                            setDialogState(() => isDeleting = false);
                          }
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => isBusy = false);
                          }
                        }
                      }

                      return AlertDialog(
                        title: const Text('Delete adjustment'),
                        content: const Text(
                          'This will remove the adjustment from payroll calculations.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: confirmDelete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB02A37),
                              foregroundColor: Colors.white,
                            ),
                            child: isDeleting
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Deleting...'),
                                    ],
                                  )
                                : const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              if (deleted != true) {
                _logCompensation(
                  'delete_adjustment_cancelled',
                  details:
                      'id=${existing.id}, userId=${currentEmployee.userId}',
                );
                return;
              }
            }

            Future<void> recordEmployeePayment() async {
              if (isBusy) {
                return;
              }
              if (paymentModeController.text.trim().isEmpty) {
                _showToast('Payment method is required', isError: true);
                return;
              }
              setSheetState(() => isBusy = true);
              try {
                _logCompensation(
                  'record_employee_payment_started',
                  details:
                      'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}',
                );
                final updated = await _repository.recordEmployeePayment(
                  branchId: branchId,
                  runId: currentRun.id,
                  userId: currentEmployee.userId,
                  payment: PaymentRecord(
                    mode: paymentModeController.text.trim(),
                    reference: paymentReferenceController.text.trim(),
                    paidDate: paymentDate,
                    notes: paymentNotesController.text.trim(),
                  ),
                );
                await refreshEmployee(updated);
                if (sheetContext.mounted) {
                  setSheetState(() {});
                }
                _logCompensation(
                  'record_employee_payment_success',
                  details:
                      'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}',
                );
                _showToast('Employee payment recorded successfully');
              } catch (error) {
                _logCompensation(
                  'record_employee_payment_failed',
                  details: _errorText(error),
                );
                _showToast(_errorText(error), isError: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isBusy = false);
                }
              }
            }

            final status = currentEmployee.statusLabel;
            final isPaid = status.toLowerCase() == 'paid';
            final panelWidth = MediaQuery.of(dialogContext).size.width >= 900
                ? 420.0
                : MediaQuery.of(dialogContext).size.width * 0.92;

            final panel = DefaultTabController(
              length: isPaid ? 1 : 2,
              child: Material(
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentEmployee.userName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1C1917),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentEmployee.role.isEmpty
                                        ? 'Team Member'
                                        : currentEmployee.role,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(sheetContext, currentRun);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (!isPaid)
                        const TabBar(
                          labelColor: Color(0xFFB45309),
                          unselectedLabelColor: Color(0xFF6B7280),
                          indicatorColor: Color(0xFFB45309),
                          tabs: [
                            Tab(text: 'Pay Summary'),
                            Tab(text: 'Deductions & Additions'),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Pay Summary',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          physics: isPaid
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Pay Breakdown',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Amount (₹)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _SummaryLine(
                                          label: 'Base Salary',
                                          value: _formatCurrency(
                                            currentEmployee.salaryMinor,
                                          ),
                                        ),
                                        _SummaryLine(
                                          label:
                                              'Commission (${currentEmployee.commissionPercent.toStringAsFixed(0)}%)',
                                          value: _formatCurrency(
                                            currentEmployee
                                                .commissionAmountMinor,
                                          ),
                                        ),
                                        _SummaryLine(
                                          label: 'Gross Pay',
                                          value: _formatCurrency(
                                            currentEmployee.grossPayMinor,
                                          ),
                                        ),
                                        _SummaryLine(
                                          label: 'Additions',
                                          value: _formatCurrency(
                                            currentEmployee
                                                .additionsDisplayMinor,
                                          ),
                                        ),
                                        _SummaryLine(
                                          label: 'Advances',
                                          value: _formatCurrency(
                                            currentEmployee
                                                .advancesDisplayMinor,
                                          ),
                                        ),
                                        _SummaryLine(
                                          label: 'Deductions',
                                          value: _formatCurrency(
                                            currentEmployee
                                                .deductionsDisplayMinor,
                                          ),
                                        ),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'Net Payable',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFB45309),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(
                                                  currentEmployee
                                                      .netPayableMinor,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isPaid) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Record Payment',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                paymentModeController.text,
                                            decoration: const InputDecoration(
                                              labelText: 'Payment Method',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'Bank Transfer',
                                                child: Text('Bank Transfer'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Cash',
                                                child: Text('Cash'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'UPI',
                                                child: Text('UPI'),
                                              ),
                                            ],
                                            onChanged: isBusy
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      paymentModeController
                                                          .text = value;
                                                    }
                                                  },
                                          ),
                                          const SizedBox(height: 10),
                                          _LabeledTextField(
                                            label: 'Reference / Transaction ID',
                                            controller:
                                                paymentReferenceController,
                                            enabled: !isBusy,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _DateFieldButton(
                                                  label: 'Paid On',
                                                  value: paymentDate,
                                                  onTap: isBusy
                                                      ? () {}
                                                      : () async {
                                                          final picked =
                                                              await showDatePicker(
                                                            context:
                                                                sheetContext,
                                                            initialDate:
                                                                paymentDate,
                                                            firstDate:
                                                                DateTime(2022),
                                                            lastDate:
                                                                DateTime(2100),
                                                          );
                                                          if (picked != null) {
                                                            setSheetState(() =>
                                                                paymentDate =
                                                                    picked);
                                                          }
                                                        },
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _LabeledTextField(
                                                  label: 'Notes (Optional)',
                                                  controller:
                                                      paymentNotesController,
                                                  enabled: !isBusy,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      sheetContext,
                                                      currentRun,
                                                    );
                                                  },
                                                  child: const Text('Cancel'),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: isBusy
                                                      ? null
                                                      : recordEmployeePayment,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.starColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  child: Text(
                                                    isBusy
                                                        ? 'Saving...'
                                                        : 'Save Payment',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isPaid)
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: adjustmentType,
                                      decoration: const InputDecoration(
                                        labelText: 'Type',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: AdjustmentTypes.addition,
                                          child: Text('Addition'),
                                        ),
                                        DropdownMenuItem(
                                          value: AdjustmentTypes.deduction,
                                          child: Text('Deduction'),
                                        ),
                                      ],
                                      onChanged: isBusy
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                setSheetState(() =>
                                                    adjustmentType = value);
                                              }
                                            },
                                    ),
                                    const SizedBox(height: 12),
                                    _LabeledTextField(
                                      label: 'Amount',
                                      controller: adjustmentAmountController,
                                      enabled: !isBusy,
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 12),
                                    _LabeledTextField(
                                      label: 'Remarks',
                                      controller: adjustmentRemarksController,
                                      enabled: !isBusy,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            isBusy ? null : addAdjustmentInline,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.starColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: isBusy
                                            ? const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Saving...'),
                                                ],
                                              )
                                            : const Text('Save Adjustment'),
                                      ),
                                    ),
                                    if (currentEmployee.adjustments.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: currentEmployee
                                              .adjustments.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final adjustment = currentEmployee
                                                .adjustments[index];
                                            final isAddition =
                                                adjustment.type ==
                                                    AdjustmentTypes.addition;
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFE5E7EB),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          adjustment.remarks
                                                                  .isEmpty
                                                              ? 'No remarks'
                                                              : adjustment
                                                                  .remarks,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          _formatDate(
                                                            adjustment
                                                                .createdAt,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFF6B7280,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  _StatusPill(
                                                    label: isAddition
                                                        ? 'Addition'
                                                        : 'Deduction',
                                                    color: isAddition
                                                        ? const Color(
                                                            0xFF157347,
                                                          )
                                                        : const Color(
                                                            0xFFB02A37,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  PopupMenuButton<String>(
                                                    onSelected: (value) {
                                                      if (value == 'edit') {
                                                        editAdjustment(
                                                          adjustment,
                                                        );
                                                        return;
                                                      }
                                                      if (value == 'delete') {
                                                        deleteAdjustment(
                                                          adjustment,
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (context) =>
                                                        const [
                                                      PopupMenuItem<String>(
                                                        value: 'edit',
                                                        child: Text('Edit'),
                                                      ),
                                                      PopupMenuItem<String>(
                                                        value: 'delete',
                                                        child: Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: panelWidth,
                    height: double.infinity,
                    child: panel,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      paymentModeController.dispose();
      paymentReferenceController.dispose();
      paymentNotesController.dispose();
      adjustmentAmountController.dispose();
      adjustmentRemarksController.dispose();
    });
    return result;
  }

  Future<PayrollAdjustmentRecord?> _showAdjustmentDialog(
    String type, {
    required int payrollEmployeeId,
    PayrollAdjustmentRecord? initialAdjustment,
    Future<void> Function(PayrollAdjustmentRecord adjustment)? onSubmit,
  }) async {
    final typeController = TextEditingController(text: type);
    final amountController = TextEditingController(
      text: initialAdjustment == null
          ? ''
          : (minorAmountToRupees(initialAdjustment.amountMinor)
                  ?.toStringAsFixed(0) ??
              ''),
    );
    final remarksController = TextEditingController(
      text: initialAdjustment?.remarks ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final result = await showDialog<PayrollAdjustmentRecord>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (isSaving || !formKey.currentState!.validate()) {
                return;
              }
              final adjustment = PayrollAdjustmentRecord(
                id: initialAdjustment?.id ??
                    '${DateTime.now().millisecondsSinceEpoch}',
                payrollEmployeeId: payrollEmployeeId,
                type: type,
                amountMinor: rupeesToMinorAmount(
                  int.parse(amountController.text.trim()),
                ),
                remarks: remarksController.text.trim(),
                createdAt: initialAdjustment?.createdAt ?? DateTime.now(),
              );

              if (onSubmit == null) {
                Navigator.pop(dialogContext, adjustment);
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                await onSubmit(adjustment);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, adjustment);
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: Text(
                initialAdjustment == null
                    ? (type == AdjustmentTypes.addition
                        ? 'Add Addition'
                        : 'Add Deduction')
                    : (type == AdjustmentTypes.addition
                        ? 'Edit Addition'
                        : 'Edit Deduction'),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LabeledTextField(
                      label: 'Type',
                      controller: typeController,
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    _LabeledTextField(
                      label: 'Amount',
                      controller: amountController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _LabeledTextField(
                      label: 'Remarks',
                      controller: remarksController,
                      enabled: !isSaving,
                      maxLines: 1,
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Remarks are required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Saving...'),
                          ],
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      typeController.dispose();
      amountController.dispose();
      remarksController.dispose();
    });
    return result;
  }

  Future<void> _openAddOverrideDialog() async {
    final service = _selectedService;
    if (service == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _AddOverrideDialog(
        title: context.t('Add Override'),
        submitLabel: context.t('Save Override'),
        serviceId: service.id,
        staff: _activeTeamMembers,
        onSubmit: (overrides) => _saveOverrides(service.id, overrides),
      ),
    );
  }

  Future<void> _openEditOverrideDialog(StaffCommissionOverride override) async {
    final service = _selectedService;
    if (service == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _AddOverrideDialog(
        title: context.t('Edit Override'),
        submitLabel: context.t('Update Override'),
        serviceId: service.id,
        staff: _activeTeamMembers,
        initialOverride: override,
        onSubmit: (overrides) => _saveOverrides(service.id, overrides),
      ),
    );
  }

  Widget _buildPayrollSetupReviewCard({
    required String title,
    required String subtitle,
    required List<ProfileTeamMember> members,
    required bool showReason,
    VoidCallback? onSetupTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Team Member',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reason',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Action',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'No team members found.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else
            ...members.map((member) {
              final setup = _setupByUserId[member.id];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFFFF3D5),
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : 'T',
                              style: const TextStyle(
                                color: AppColors.starColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  member.role.isEmpty
                                      ? 'Team Member'
                                      : member.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showReason) ...[
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'ⓘ Not setup yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: onSetupTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEA580C),
                              side: const BorderSide(color: Color(0xFFEA580C)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: const Size(58, 30),
                            ),
                            child: const Text(
                              'Set up',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        flex: 2,
                        child: Text(
                          PayrollTypes.label(
                            setup?.payrollType ?? PayrollTypes.salaryOnly,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          _formatCurrency(setup?.salaryMinor ?? 0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          if (!showReason && members.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total Salary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    _formatCurrency(
                      members.fold<int>(0, (sum, member) {
                        final setup = _setupByUserId[member.id];
                        return sum + (setup?.salaryMinor ?? 0);
                      }),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_module) {
      CompensationModule.payroll => context.t('Payroll'),
      CompensationModule.commission => context.t('Commission Setup'),
      CompensationModule.advance => context.t('Advance'),
      CompensationModule.attendance => context.t('Attendance'),
      CompensationModule.leaves => context.t('Leaves'),
      CompensationModule.holidays => context.t('Holidays Calendar'),
      CompensationModule.leaveCalendar => context.t('Leaves & Holidays'),
    };
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: title),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (!_isLoadingBranches &&
        _branchOptions.length <= 1 &&
        !_isRefreshingContent &&
        !_isActionInProgress) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF9F8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1EBE6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingBranches)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.starColor,
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OwnerBranchHeaderSelector<int>(
                label: _selectedBranch?.label ?? context.t('Select Branch'),
                options: _branchOptions
                    .map(
                      (item) => OwnerBranchHeaderSelectorOption<int>(
                        value: item.branchId,
                        label: item.label,
                        subtitle: item.subtitle,
                      ),
                    )
                    .toList(),
                selectedValue: _selectedBranch?.branchId,
                placeholder: context.t('Select Branch'),
                isInteractive: _branchOptions.length > 1,
                onSelected: (branchId) {
                  final next = _branchOptions.firstWhere(
                    (item) => item.branchId == branchId,
                  );
                  _switchBranch(next);
                },
              ),
            ),
          if (!_isLoadingBranches &&
              (_isRefreshingContent || _isActionInProgress)) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.starColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingBranches && _branchOptions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.starColor),
      );
    }

    if (_branchError != null && _branchOptions.isEmpty) {
      return _ErrorStateCard(
        title: 'Unable to load branches',
        subtitle: _branchError!,
        onRetry: () => _loadInitialData(),
      );
    }

    if (_selectedBranch == null) {
      return const _EmptyStateCard(
        title: 'Select a branch to continue',
        subtitle:
            'Payroll and commission setup become available after a branch is selected.',
      );
    }

    if (_isLoadingContent) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.starColor),
      );
    }

    if (_contentError != null) {
      return _ErrorStateCard(
        title: 'Unable to load this module',
        subtitle: _contentError!,
        onRetry: () => _reloadContent(),
      );
    }

    if (_module == CompensationModule.payroll) {
      return _buildPayrollDashboard();
    }

    if (_module == CompensationModule.advance) {
      return _buildAdvanceScreen();
    }

    if (_module == CompensationModule.attendance) {
      return _buildAttendanceScreen();
    }

    if (_module == CompensationModule.leaves) {
      return _buildLeavesScreen();
    }

    if (_module == CompensationModule.holidays) {
      return _buildHolidaysScreen();
    }

    if (_module == CompensationModule.leaveCalendar) {
      return _buildLeaveCalendarScreen();
    }

    return _buildCommissionScreen();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE8DED6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6F665E),
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F1B18),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6F665E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollRunTile extends StatelessWidget {
  const _PayrollRunTile({
    required this.run,
    required this.statusColor,
    required this.onOpen,
  });

  final PayrollRunRecord run;
  final Color statusColor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final metricWidth = isCompact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 40) / 4;
        final metrics = <Widget>[
          _RunMetricCard(
            label: 'Employees',
            value: '${run.employeeCount}',
            width: metricWidth,
          ),
          _RunMetricCard(
            label: 'Net',
            value: _formatCurrency(run.totalAmountMinor),
            width: metricWidth,
          ),
          _RunMetricCard(
            label: 'Paid',
            value: _formatCurrency(run.paidAmountMinor),
            width: metricWidth,
          ),
          _RunMetricCard(
            label: 'Pending',
            value: _formatCurrency(run.outstandingAmountMinor),
            width: metricWidth,
          ),
        ];
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onOpen,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color.alphaBlend(
                      statusColor.withValues(alpha: 0.07),
                      const Color(0xFFFFFCF8),
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0E5DA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: statusColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _RunTitleBlock(run: run),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _StatusPill(
                                    label: run.statusLabel,
                                    color: statusColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: onOpen,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFCFAF8),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 18,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: metrics,
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
      },
    );
  }
}

class _RunTitleBlock extends StatelessWidget {
  const _RunTitleBlock({required this.run});

  final PayrollRunRecord run;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          run.periodLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Payroll run summary',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _RunMetricCard extends StatelessWidget {
  const _RunMetricCard({
    required this.label,
    required this.value,
    this.width = 126,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8DED6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6F665E),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1917),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    this.onTap,
    this.filled = false,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = filled ? Colors.white : const Color(0xFF1C1917);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.starColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? AppColors.starColor : const Color(0xFFE9DFD1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            else if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: foregroundColor,
              ),
            ],
            if (isLoading || icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1917),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1EBE6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 38,
                color: Color(0xFFB45309),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.red,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.maxLength = 120,
    this.inputFormatters = const <TextInputFormatter>[],
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLength: maxLength,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      inputFormatters: [
        ...inputFormatters,
        if (maxLength > 0) LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8F5F2) : const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(value),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
