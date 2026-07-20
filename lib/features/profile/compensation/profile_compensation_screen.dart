import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/navigation_service.dart';
import '../../../services/stylist_branch_selection.dart';
import '../../../utils/localization_helper.dart';
import '../../../utils/api_service.dart';
import '../../../utils/price_formatter.dart';
import '../../../utils/refresh_feedback.dart';
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

const String _commissionAllCategoriesValue = '__all_categories__';
const String _commissionUncategorizedValue = '__uncategorized__';

void _printPayrollSetupRefresh(String message) {
  // ignore: avoid_print
  print(message);
}

String _formatCurrency(num minorAmount) {
  return formatMinorAmount(minorAmount, trimZeroDecimals: true);
}

String _formatSalaryRupees(num minorAmount) {
  final rupees = minorAmount / 100;
  var text = rupees.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return '₹$text';
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
  final ScrollController _advanceTableScrollController = ScrollController();
  CompensationModule _module = CompensationModule.payroll;
  _CommissionTab _commissionTab = _CommissionTab.services;
  String _commissionCategoryFilter = _commissionAllCategoriesValue;

  List<ProfileBranchOption> _branchOptions = const <ProfileBranchOption>[];
  ProfileBranchOption? _selectedBranch;

  List<ProfileTeamMember> _teamMembers = const <ProfileTeamMember>[];
  List<PayrollSetupRecord> _payrollSetups = const <PayrollSetupRecord>[];
  List<PayrollRunRecord> _payrollRuns = const <PayrollRunRecord>[];
  List<PayrollAdvanceRecord> _advances = const <PayrollAdvanceRecord>[];
  List<BranchServiceSummary> _services = const <BranchServiceSummary>[];
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
  String? _openingPayrollReviewRunId;
  String? _branchError;
  String? _contentError;
  int? _selectedServiceId;
  int _commissionServicesPage = 0;
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

  bool get _isScreenBusy =>
      _isLoadingContent || _isRefreshingContent || _isActionInProgress;

  bool get _shouldShowContentLoader =>
      _isLoadingContent || _isRefreshingContent;

  bool _isCurrentBranch(int branchId) {
    return mounted && _selectedBranch?.branchId == branchId;
  }

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
      setState(() {
        _commissionServicesPage = 0;
      });
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
    _advanceTableScrollController.dispose();
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
    _logCompensation(
      'load_payroll_data_started',
      details: 'branchId=$branchId',
    );

    try {
      final teamMembers = await _repository.loadTeamMembers(branchId);

      final payrollSetups = await _repository.loadPayrollSetups(branchId);

      debugPrint('================ PAYROLL DEBUG ================');
      debugPrint('Branch ID: $branchId');
      debugPrint('Team members count: ${teamMembers.length}');
      debugPrint('Payroll setups count: ${payrollSetups.length}');

      for (final member in teamMembers) {
        debugPrint(
          'TEAM MEMBER -> '
          'id=${member.id}, '
          'name=${member.name}, '
          'role=${member.role}, '
          'active=${member.isActive}',
        );
      }

      for (final setup in payrollSetups) {
        debugPrint(
          'PAYROLL SETUP -> '
          'userId=${setup.userId}, '
          'salaryMinor=${setup.salaryMinor}, '
          'payrollType=${setup.payrollType}',
        );
      }

      final payrollRuns = await _repository.loadPayrollRuns(
        branchId,
        teamMembers: teamMembers,
        setups: payrollSetups,
      );

      if (!_isCurrentBranch(branchId)) {
        _logCompensation(
          'load_payroll_data_ignored_stale',
          details:
              'loadedBranchId=$branchId, selectedBranchId=${_selectedBranch?.branchId}',
        );
        return;
      }

      setState(() {
        _teamMembers = List<ProfileTeamMember>.from(teamMembers);

        _payrollSetups = List<PayrollSetupRecord>.from(payrollSetups);

        _payrollRuns = List<PayrollRunRecord>.from(payrollRuns);
      });

      debugPrint('Active members count: ${_activeTeamMembers.length}');
      debugPrint('Setup map keys: ${_setupByUserId.keys.toList()}');

      for (final member in _activeTeamMembers) {
        debugPrint(
          'MATCH CHECK -> '
          'memberId=${member.id}, '
          'name=${member.name}, '
          'hasSetup=${_setupByUserId.containsKey(member.id)}',
        );
      }

      debugPrint('================================================');

      _logCompensation(
        'load_payroll_data_success',
        details: 'branchId=$branchId, '
            'team=${_teamMembers.length}, '
            'activeTeam=${_activeTeamMembers.length}, '
            'setups=${_payrollSetups.length}, '
            'runs=${_payrollRuns.length}',
      );
    } catch (error, stackTrace) {
      debugPrint('PAYROLL LOAD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      _logCompensation(
        'load_payroll_data_failed',
        details: _errorText(error),
      );

      rethrow;
    }
  }

  Future<void> _loadCommissionData(int branchId) async {
    _logCompensation(
      'load_commission_data_started',
      details: 'branchId=$branchId',
    );
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _repository.loadCommissionStaff(branchId),
      _repository.loadServices(branchId),
      _repository.loadCommissionOverrides(branchId),
    ]);

    final services = List<BranchServiceSummary>.from(results[1] as List);
    int? selectedServiceId = _selectedServiceId;
    if (services.isEmpty) {
      selectedServiceId = null;
    } else if (!services.any((item) => item.id == selectedServiceId)) {
      selectedServiceId = services.first.id;
    }

    if (!_isCurrentBranch(branchId)) {
      _logCompensation(
        'load_commission_data_ignored_stale',
        details:
            'loadedBranchId=$branchId, selectedBranchId=${_selectedBranch?.branchId}',
      );
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(results[0] as List);
      _services = services;
      _staffOverrides = List<StaffCommissionOverride>.from(results[2] as List);
      _selectedServiceId = selectedServiceId;
    });
    _logCompensation(
      'load_commission_data_success',
      details:
          'branchId=$branchId, team=${_teamMembers.length}, services=${_services.length}, overrides=${_staffOverrides.length}, selectedServiceId=$_selectedServiceId',
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

    if (!_isCurrentBranch(branchId)) {
      _logCompensation(
        'load_advance_data_ignored_stale',
        details:
            'loadedBranchId=$branchId, selectedBranchId=${_selectedBranch?.branchId}',
      );
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

      if (!_isCurrentBranch(branch.branchId)) {
        _logCompensation(
          'load_leave_data_ignored_stale',
          details:
              'loadedBranchId=${branch.branchId}, selectedBranchId=${_selectedBranch?.branchId}',
        );
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

      if (!_isCurrentBranch(branch.branchId)) {
        _logCompensation(
          'load_leave_data_ignored_stale',
          details:
              'loadedBranchId=${branch.branchId}, selectedBranchId=${_selectedBranch?.branchId}',
        );
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

      if (!_isCurrentBranch(branch.branchId)) {
        _logCompensation(
          'load_leave_data_ignored_stale',
          details:
              'loadedBranchId=${branch.branchId}, selectedBranchId=${_selectedBranch?.branchId}',
        );
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

    if (!_isCurrentBranch(branch.branchId)) {
      _logCompensation(
        'load_leave_data_ignored_stale',
        details:
            'loadedBranchId=${branch.branchId}, selectedBranchId=${_selectedBranch?.branchId}',
      );
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
    if (_selectedBranch?.branchId == option.branchId || _isScreenBusy) {
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

  Future<void> _updateAdvance(PayrollAdvanceRecord advance) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    _logCompensation(
      'update_advance_started',
      details:
          'branchId=$branchId, advanceId=${advance.id}, employeeId=${advance.employeeId}, amount=${advance.amount}',
    );
    await _repository.updateAdvance(
      branchId: branchId,
      advance: advance,
    );
    await _loadAdvanceData(branchId);
    _logCompensation(
      'update_advance_success',
      details: 'branchId=$branchId, advanceId=${advance.id}',
    );
    _showToast('Advance updated successfully');
  }

  Future<void> _deleteAdvance(PayrollAdvanceRecord advance) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null || _isActionInProgress) {
      return;
    }
    final confirmed = await _confirmDeleteAdvance(advance);
    if (!confirmed) {
      return;
    }
    _logCompensation(
      'delete_advance_started',
      details: 'branchId=$branchId, advanceId=${advance.id}',
    );
    await _performAction(() async {
      await _repository.deleteAdvance(
        branchId: branchId,
        advanceId: advance.id,
      );
      await _loadAdvanceData(branchId);
      _logCompensation(
        'delete_advance_success',
        details: 'branchId=$branchId, advanceId=${advance.id}',
      );
      _showToast('Advance deleted successfully');
    });
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
      await _repository.saveStaffOverrides(
        branchId: branchId,
        serviceId: serviceId,
        overrides: overrides,
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
    if (branchId == null || _isActionInProgress) {
      return;
    }
    final override = _staffOverrideById(overrideId);
    final confirmed = await _confirmDeleteOverride(override);
    if (!confirmed) {
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

  StaffCommissionOverride? _staffOverrideById(String overrideId) {
    for (final override in _staffOverrides) {
      if (override.id == overrideId) {
        return override;
      }
    }
    return null;
  }

  Future<bool> _confirmDeleteOverride(
    StaffCommissionOverride? override,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final service = override == null ? null : _serviceForOverride(override);
    final target = override == null
        ? context.t('this staff override')
        : '${override.staffName}${service == null ? '' : ' - ${service.name}'}';
    final confirmed = await showDialog<bool>(
      context: context,
      requestFocus: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            context.t('Delete override?'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          content: Text(
            '${context.t('Are you sure you want to delete')} $target?',
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Color(0xFF6B625A),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.starColor,
              ),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(context.t('Delete')),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
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

  BranchServiceSummary? get _selectedService {
    for (final service in _services) {
      if (service.id == _selectedServiceId) {
        return service;
      }
    }
    return _services.isEmpty ? null : _services.first;
  }

  List<BranchServiceSummary> get _filteredServices {
    final query = _serviceSearchController.text.trim().toLowerCase();
    final categoryFilter =
        _commissionCategoryFilterOptions.contains(_commissionCategoryFilter)
            ? _commissionCategoryFilter
            : _commissionAllCategoriesValue;
    return _services.where((service) {
      if (categoryFilter == _commissionUncategorizedValue &&
          service.categoryName.trim().isNotEmpty) {
        return false;
      }
      if (categoryFilter != _commissionAllCategoriesValue &&
          categoryFilter != _commissionUncategorizedValue &&
          service.categoryName.trim() != categoryFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack =
          '${service.name} ${service.categoryName} ${service.description}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<String> get _commissionCategoryFilterOptions {
    final categories = _services
        .map((service) => service.categoryName.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final hasUncategorized =
        _services.any((service) => service.categoryName.trim().isEmpty);
    return <String>[
      _commissionAllCategoriesValue,
      ...categories,
      if (hasUncategorized) _commissionUncategorizedValue,
    ];
  }

  String _commissionCategoryFilterLabel(String value) {
    if (value == _commissionAllCategoriesValue) {
      return 'All Categories';
    }
    if (value == _commissionUncategorizedValue) {
      return 'Uncategorized';
    }
    return value;
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

  List<StaffCommissionOverride> get _filteredStaffOverrides {
    final query = _serviceSearchController.text.trim().toLowerCase();
    final items = _staffOverrides.where((override) {
      if (query.isEmpty) {
        return true;
      }
      final service = _serviceForOverride(override);
      final haystack =
          '${override.staffName} ${service?.name ?? ''} ${service?.categoryName ?? ''} ${override.ruleType}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
    items.sort((a, b) {
      final serviceA = _serviceForOverride(a)?.name.toLowerCase() ?? '';
      final serviceB = _serviceForOverride(b)?.name.toLowerCase() ?? '';
      final serviceCompare = serviceA.compareTo(serviceB);
      if (serviceCompare != 0) {
        return serviceCompare;
      }
      return a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase());
    });
    return items;
  }

  BranchServiceSummary? _serviceForOverride(StaffCommissionOverride override) {
    for (final service in _services) {
      if (service.id == override.serviceId) {
        return service;
      }
    }
    return null;
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

  void _selectCommissionService(int serviceId) {
    setState(() => _selectedServiceId = serviceId);
  }

  void _setCommissionTabValue(_CommissionTab tab) {
    setState(() {
      _commissionTab = tab;
      _commissionServicesPage = 0;
    });
  }

  void _setCommissionCategoryFilter(String value) {
    setState(() {
      _commissionCategoryFilter = value;
      _commissionServicesPage = 0;
    });
  }

  void _setCommissionServicesPage(int page) {
    final totalItems = _filteredServices.length;
    final maxPage = totalItems == 0
        ? 0
        : ((totalItems - 1) / _commissionServicesPageSize).floor();
    setState(() {
      _commissionServicesPage = page.clamp(0, maxPage).toInt();
    });
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
                onRefresh: () async {
                  _printPayrollSetupRefresh(
                    '[SetupPayrollRefresh] refresh started | branchId=$branchId',
                  );
                  _printPayrollSetupRefresh(
                    '[SetupPayrollRefresh] GET ${ApiService.baseUrl}${ApiService.getTeamMember(branchId)}',
                  );
                  _printPayrollSetupRefresh(
                    '[SetupPayrollRefresh] GET ${ApiService.baseUrl}${ApiService.payrollSetupTeamMembersAPI(branchId)}',
                  );
                  _printPayrollSetupRefresh(
                    '[SetupPayrollRefresh] GET ${ApiService.baseUrl}${ApiService.branchDashboardAPI(branchId)}',
                  );
                  await _loadPayrollData(branchId);
                  _printPayrollSetupRefresh(
                    '[SetupPayrollRefresh] refresh success | branchId=$branchId',
                  );
                  return _PayrollSetupRefreshData(
                    teamMembers: _activeTeamMembers,
                    existingSetups: _setupByUserId,
                  );
                },
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
    if (branchId == null || _openingPayrollReviewRunId != null) {
      return;
    }
    setState(() => _openingPayrollReviewRunId = initialRun.id);
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
    final payrollReviewTableScrollController = ScrollController();
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
              final hasPaidEmployee =
                  paidEmployeesCount > 0 || currentRun.paidAmountMinor > 0;
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
                              if (reviewStatus != 'cancelled' &&
                                  !hasPaidEmployee)
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
                            isExpanded: true,
                            menuMaxHeight: 220,
                            borderRadius: BorderRadius.circular(10),
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
                                child: Text(
                                  'All Status',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Paid',
                                child: Text(
                                  'Paid',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Pending',
                                child: Text(
                                  'Pending',
                                  overflow: TextOverflow.ellipsis,
                                ),
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

                                return RawScrollbar(
                                  controller:
                                      payrollReviewTableScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  thickness: 4,
                                  radius: const Radius.circular(10),
                                  thumbColor: AppColors.starColor
                                      .withValues(alpha: 0.72),
                                  trackColor: const Color(0xFFFFF3D5),
                                  trackBorderColor: const Color(0xFFE8C774),
                                  scrollbarOrientation:
                                      ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    controller:
                                        payrollReviewTableScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 12),
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                  alignment:
                                                      Alignment.centerLeft,
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
                                                    onPressed: isReviewBusy
                                                        ? null
                                                        : () async {
                                                            setSheetState(() {
                                                              isReviewBusy =
                                                                  true;
                                                              reviewBusyAction =
                                                                  'employee_review_${employee.userId}';
                                                            });
                                                            try {
                                                              final updated =
                                                                  await _openEmployeeReview(
                                                                run: currentRun,
                                                                employee:
                                                                    employee,
                                                              );
                                                              if (updated !=
                                                                      null &&
                                                                  context
                                                                      .mounted &&
                                                                  screenContext
                                                                      .mounted) {
                                                                await refreshRun(
                                                                  updated,
                                                                );
                                                                if (context
                                                                    .mounted) {
                                                                  setSheetState(
                                                                    () => currentRun =
                                                                        updated,
                                                                  );
                                                                }
                                                              }
                                                            } finally {
                                                              if (context
                                                                  .mounted) {
                                                                setSheetState(
                                                                  () {
                                                                    isReviewBusy =
                                                                        false;
                                                                    reviewBusyAction =
                                                                        null;
                                                                  },
                                                                );
                                                              }
                                                            }
                                                          },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          AppColors.starColor,
                                                      disabledForegroundColor:
                                                          AppColors.starColor
                                                              .withValues(
                                                        alpha: 0.55,
                                                      ),
                                                      side: BorderSide(
                                                        color:
                                                            AppColors.starColor,
                                                      ),
                                                      disabledBackgroundColor:
                                                          AppColors.starColor
                                                              .withValues(
                                                        alpha: 0.06,
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 16,
                                                        vertical: 10,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      textStyle:
                                                          const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    child: reviewBusyAction ==
                                                            'employee_review_${employee.userId}'
                                                        ? SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: AppColors
                                                                  .starColor,
                                                            ),
                                                          )
                                                        : const Text('View'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
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
    payrollReviewTableScrollController.dispose();
    if (mounted) {
      setState(() => _openingPayrollReviewRunId = null);
    }
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
        fallbackRun: run,
      );
      employee =
          run.employees.firstWhere((item) => item.userId == employee.userId);
    } catch (error) {
      _logCompensation(
        'load_employee_adjustments_failed',
        details: _errorText(error),
      );
      _showToast(_errorText(error), isError: true);
      return null;
    }

    PayrollRunRecord currentRun = run;
    PayrollRunEmployeeRecord currentEmployee = employee;
    final paymentModeController = TextEditingController(text: 'Bank Transfer');
    final paymentReferenceController = TextEditingController();
    final paymentNotesController = TextEditingController();
    final paySummaryScrollController = ScrollController();
    DateTime paymentDate = DateTime.now();

    if (!mounted) {
      return null;
    }

    final result = await Navigator.of(context).push<PayrollRunRecord>(
      MaterialPageRoute<PayrollRunRecord>(
        builder: (screenContext) {
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
              Future<void> addAdjustmentDialog(String type) async {
                if (isBusy) {
                  return;
                }
                await _showAdjustmentDialog(
                  type,
                  payrollEmployeeId: currentEmployee.payrollEmployeeId > 0
                      ? currentEmployee.payrollEmployeeId
                      : currentEmployee.userId,
                  onSubmit: (adjustment) async {
                    setSheetState(() => isBusy = true);
                    try {
                      _logCompensation(
                        'add_adjustment_started',
                        details:
                            'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, type=$type',
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
                      _logCompensation(
                        'add_adjustment_success',
                        details:
                            'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}, type=$type',
                      );
                      _showToast('Adjustment saved successfully');
                    } catch (error) {
                      _logCompensation(
                        'add_adjustment_failed',
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
                      final updated =
                          await _repository.updateEmployeeAdjustment(
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

              Future<bool> recordEmployeePayment() async {
                if (isBusy) {
                  return false;
                }
                if (paymentModeController.text.trim().isEmpty) {
                  _showToast('Payment method is required', isError: true);
                  return false;
                }
                if (paymentReferenceController.text.trim().isEmpty) {
                  _showToast(
                    'Reference / Transaction ID is required',
                    isError: true,
                  );
                  return false;
                }
                if (paymentNotesController.text.trim().isEmpty) {
                  _showToast('Notes are required', isError: true);
                  return false;
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
                    payrollEmployeeId: currentEmployee.payrollEmployeeId > 0
                        ? currentEmployee.payrollEmployeeId
                        : currentEmployee.userId,
                    payment: PaymentRecord(
                      mode: paymentModeController.text.trim(),
                      reference: paymentReferenceController.text.trim(),
                      paidDate: paymentDate,
                      notes: paymentNotesController.text.trim(),
                    ),
                    fallbackRun: currentRun,
                  );
                  await refreshEmployee(updated);
                  if (sheetContext.mounted) {
                    setSheetState(() {});
                  }
                  final refreshedEmployee = updated.employees.firstWhere(
                    (item) => item.userId == currentEmployee.userId,
                    orElse: () => currentEmployee,
                  );
                  final refreshedStatus =
                      refreshedEmployee.statusLabel.toLowerCase();
                  final paymentConfirmed = refreshedEmployee.payment != null ||
                      refreshedStatus.contains('paid') ||
                      (refreshedEmployee.backendStatus ?? '')
                          .trim()
                          .toLowerCase()
                          .contains('paid');
                  _logCompensation(
                    paymentConfirmed
                        ? 'record_employee_payment_success'
                        : 'record_employee_payment_not_confirmed',
                    details:
                        'branchId=$branchId, runId=${currentRun.id}, userId=${currentEmployee.userId}',
                  );
                  _showToast(
                    paymentConfirmed
                        ? 'Employee payment recorded successfully'
                        : 'Payment status was not updated by the API yet.',
                    isError: !paymentConfirmed,
                  );
                  return paymentConfirmed;
                } catch (error) {
                  _logCompensation(
                    'record_employee_payment_failed',
                    details: _errorText(error),
                  );
                  _showToast(_errorText(error), isError: true);
                  return false;
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isBusy = false);
                  }
                }
              }

              Future<void> openRecordPaymentDialog() async {
                if (isBusy) {
                  return;
                }

                final formKey = GlobalKey<FormState>();
                final referenceController = TextEditingController(
                  text: paymentReferenceController.text,
                );
                final notesController = TextEditingController(
                  text: paymentNotesController.text,
                );
                var selectedMode = paymentModeController.text.trim().isEmpty
                    ? 'Bank Transfer'
                    : paymentModeController.text.trim();
                var selectedDate = paymentDate;
                var isSavingPayment = false;
                var hasSubmittedPayment = false;

                try {
                  await showDialog<void>(
                    context: sheetContext,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      return StatefulBuilder(
                        builder: (dialogContext, setDialogState) {
                          Future<void> submitPayment() async {
                            if (isSavingPayment) {
                              return;
                            }
                            setDialogState(() => hasSubmittedPayment = true);
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            paymentModeController.text = selectedMode;
                            paymentReferenceController.text =
                                referenceController.text.trim();
                            paymentNotesController.text =
                                notesController.text.trim();
                            paymentDate = selectedDate;
                            setDialogState(() => isSavingPayment = true);
                            final saved = await recordEmployeePayment();
                            if (!dialogContext.mounted) {
                              return;
                            }
                            if (saved) {
                              Navigator.pop(dialogContext);
                            } else {
                              setDialogState(() => isSavingPayment = false);
                            }
                          }

                          return Dialog(
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 24,
                            ),
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 560,
                                maxHeight:
                                    MediaQuery.sizeOf(dialogContext).height *
                                        0.86,
                              ),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Form(
                                    key: formKey,
                                    autovalidateMode: hasSubmittedPayment
                                        ? AutovalidateMode.onUserInteraction
                                        : AutovalidateMode.disabled,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Record Payment',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: isSavingPayment
                                                  ? null
                                                  : () => Navigator.pop(
                                                        dialogContext,
                                                      ),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final compact =
                                                constraints.maxWidth < 440;
                                            final methodField =
                                                DropdownButtonFormField<String>(
                                              initialValue: selectedMode,
                                              isExpanded: true,
                                              menuMaxHeight: 220,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              decoration: InputDecoration(
                                                labelText: 'Payment Method *',
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFFCFAF8),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'Bank Transfer',
                                                  child: Text(
                                                    'Bank Transfer',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Cash',
                                                  child: Text(
                                                    'Cash',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'UPI',
                                                  child: Text(
                                                    'UPI',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                              validator: (value) => (value ??
                                                          '')
                                                      .trim()
                                                      .isEmpty
                                                  ? 'Payment method is required'
                                                  : null,
                                              onChanged: isSavingPayment
                                                  ? null
                                                  : (value) {
                                                      if (value != null) {
                                                        setDialogState(
                                                          () => selectedMode =
                                                              value,
                                                        );
                                                        if (hasSubmittedPayment) {
                                                          formKey.currentState
                                                              ?.validate();
                                                        }
                                                      }
                                                    },
                                            );
                                            final referenceField =
                                                _LabeledTextField(
                                              label:
                                                  'Reference / Transaction ID *',
                                              controller: referenceController,
                                              enabled: !isSavingPayment,
                                              maxLength: 120,
                                              onChanged: (_) {
                                                setDialogState(() {});
                                                if (hasSubmittedPayment) {
                                                  formKey.currentState
                                                      ?.validate();
                                                }
                                              },
                                              validator: (value) => (value
                                                              ?.trim() ??
                                                          '')
                                                      .isEmpty
                                                  ? 'Reference / Transaction ID is required'
                                                  : null,
                                            );
                                            final dateField = _DateFieldButton(
                                              label: 'Paid On *',
                                              value: selectedDate,
                                              onTap: isSavingPayment
                                                  ? () {}
                                                  : () async {
                                                      final picked =
                                                          await showDatePicker(
                                                        context: dialogContext,
                                                        initialDate:
                                                            selectedDate,
                                                        firstDate:
                                                            DateTime(2022),
                                                        lastDate:
                                                            DateTime(2100),
                                                        builder:
                                                            (context, child) {
                                                          return Theme(
                                                            data: Theme.of(
                                                              context,
                                                            ).copyWith(
                                                              colorScheme: Theme
                                                                      .of(
                                                                context,
                                                              )
                                                                  .colorScheme
                                                                  .copyWith(
                                                                    primary:
                                                                        AppColors
                                                                            .starColor,
                                                                  ),
                                                            ),
                                                            child: child!,
                                                          );
                                                        },
                                                      );
                                                      if (picked != null) {
                                                        setDialogState(
                                                          () => selectedDate =
                                                              picked,
                                                        );
                                                      }
                                                    },
                                            );
                                            final notesField =
                                                _LabeledTextField(
                                              label: 'Notes *',
                                              controller: notesController,
                                              enabled: !isSavingPayment,
                                              maxLines: 1,
                                              maxLength: 120,
                                              onChanged: (_) {
                                                setDialogState(() {});
                                                if (hasSubmittedPayment) {
                                                  formKey.currentState
                                                      ?.validate();
                                                }
                                              },
                                              validator: (value) =>
                                                  (value?.trim() ?? '').isEmpty
                                                      ? 'Notes are required'
                                                      : null,
                                            );

                                            if (compact) {
                                              return Column(
                                                children: [
                                                  methodField,
                                                  const SizedBox(height: 12),
                                                  referenceField,
                                                  const SizedBox(height: 12),
                                                  dateField,
                                                  const SizedBox(height: 12),
                                                  notesField,
                                                ],
                                              );
                                            }

                                            return Column(
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                        child: methodField),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: referenceField,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(child: dateField),
                                                    const SizedBox(width: 12),
                                                    Expanded(child: notesField),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: isSavingPayment
                                                  ? null
                                                  : () => Navigator.pop(
                                                        dialogContext,
                                                      ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.starColor,
                                                side: BorderSide(
                                                  color: AppColors.starColor,
                                                ),
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton(
                                              onPressed: isSavingPayment
                                                  ? null
                                                  : submitPayment,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.starColor,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: isSavingPayment
                                                  ? const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
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
                                                              Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Saving...'),
                                                      ],
                                                    )
                                                  : const Text('Save Payment'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                } finally {
                  referenceController.dispose();
                  notesController.dispose();
                }
              }

              final status = currentEmployee.statusLabel;
              final employeeBackendStatus =
                  (currentEmployee.backendStatus ?? '').trim().toLowerCase();
              final isPaid = currentEmployee.payment != null ||
                  status.toLowerCase().contains('paid') ||
                  employeeBackendStatus.contains('paid');
              final panel = _PayrollEmployeeCalculationScreen(
                run: currentRun,
                employee: currentEmployee,
                isBusy: isBusy,
                isPaid: isPaid,
                scrollController: paySummaryScrollController,
                onBack: () => Navigator.pop(sheetContext, currentRun),
                onRecordPayment: openRecordPaymentDialog,
                onAddAddition: () => addAdjustmentDialog(
                  AdjustmentTypes.addition,
                ),
                onAddDeduction: () => addAdjustmentDialog(
                  AdjustmentTypes.deduction,
                ),
                onEditAdjustment: editAdjustment,
                onDeleteAdjustment: deleteAdjustment,
              );

              return Scaffold(
                backgroundColor: const Color(0xFFFBF9F8),
                body: panel,
              );
            },
          );
        },
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      paymentModeController.dispose();
      paymentReferenceController.dispose();
      paymentNotesController.dispose();
      paySummaryScrollController.dispose();
    });
    return result;
  }

  Future<PayrollAdjustmentRecord?> _showAdjustmentDialog(
    String type, {
    required int payrollEmployeeId,
    PayrollAdjustmentRecord? initialAdjustment,
    Future<void> Function(PayrollAdjustmentRecord adjustment)? onSubmit,
  }) async {
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
    final isAddition = type == AdjustmentTypes.addition;
    final isEditing = initialAdjustment != null;
    final title = isEditing
        ? (isAddition ? 'Edit Addition' : 'Edit Deduction')
        : (isAddition ? 'Add Addition' : 'Add Deduction');
    final subtitle = isAddition
        ? 'Record an additional payroll amount for this employee.'
        : 'Record a payroll deduction for this employee.';
    bool isSaving = false;
    bool hasSubmitted = false;

    final result = await showDialog<PayrollAdjustmentRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (isSaving) {
                return;
              }
              setDialogState(() => hasSubmitted = true);
              if (!formKey.currentState!.validate()) {
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

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    autovalidateMode: hasSubmitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: IconButton.styleFrom(
                                foregroundColor: const Color(0xFF94A3B8),
                                side: const BorderSide(
                                  color: Color(0xFFE0E7FF),
                                ),
                                minimumSize: const Size(30, 30),
                                fixedSize: const Size(30, 30),
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Amount *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: amountController,
                          enabled: !isSaving,
                          cursorColor: AppColors.starColor,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Amount',
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.starColor,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${amountController.text.length}/6',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Remarks *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: remarksController,
                          enabled: !isSaving,
                          cursorColor: AppColors.starColor,
                          maxLines: 1,
                          onChanged: (_) => setDialogState(() {}),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: (value) {
                            if ((value?.trim() ?? '').isEmpty) {
                              return 'Remarks are required';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText:
                                isAddition ? 'Festival bonus' : 'Late penalty',
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.starColor,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${remarksController.text.length}/50',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: isSaving ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.starColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), () {
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
    FocusManager.instance.primaryFocus?.unfocus();
    await showDialog<void>(
      context: context,
      requestFocus: false,
      builder: (context) => _AddOverrideDialog(
        title: context.t('Add Override'),
        submitLabel: context.t('Save Override'),
        serviceId: service.id,
        services: _services,
        staff: _activeTeamMembers,
        existingOverrides: _staffOverrides,
        onSubmit: (serviceId, overrides) =>
            _saveOverrides(serviceId, overrides),
      ),
    );
  }

  Future<void> _openEditOverrideDialog(StaffCommissionOverride override) async {
    if (!_services.any((service) => service.id == override.serviceId)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await showDialog<void>(
      context: context,
      requestFocus: false,
      builder: (context) => _AddOverrideDialog(
        title: context.t('Edit override'),
        submitLabel: context.t('Save changes'),
        serviceId: override.serviceId,
        services: _services,
        staff: _activeTeamMembers,
        initialOverride: override,
        existingOverrides: _staffOverrides,
        onSubmit: (serviceId, overrides) =>
            _saveOverrides(serviceId, overrides),
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
    final emptyMessage = showReason
        ? 'No excluded team members found.'
        : 'No included team members found.';

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
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Team Member',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    showReason ? 'Reason' : 'Payroll Type',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                SizedBox(
                  width: showReason ? 80 : 90,
                  child: Text(
                    showReason ? 'Action' : 'Salary (₹)',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
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
                          _formatSalaryRupees(setup?.salaryMinor ?? 0),
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
                    _formatSalaryRupees(
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
      body: Stack(
        children: [
          Column(
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
          if (_shouldShowContentLoader)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: const Color(0x66FFFCF8),
                  alignment: Alignment.center,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      color: AppColors.starColor,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (!_isLoadingBranches && _branchOptions.length <= 1 && !_isScreenBusy) {
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
                isInteractive: _branchOptions.length > 1 && !_isScreenBusy,
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
      return const SizedBox.shrink();
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
  final VoidCallback? onOpen;

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

class _PayrollEmployeeCalculationScreen extends StatelessWidget {
  const _PayrollEmployeeCalculationScreen({
    required this.run,
    required this.employee,
    required this.isBusy,
    required this.isPaid,
    required this.scrollController,
    required this.onBack,
    required this.onRecordPayment,
    required this.onAddAddition,
    required this.onAddDeduction,
    required this.onEditAdjustment,
    required this.onDeleteAdjustment,
  });

  final PayrollRunRecord run;
  final PayrollRunEmployeeRecord employee;
  final bool isBusy;
  final bool isPaid;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final VoidCallback onRecordPayment;
  final VoidCallback onAddAddition;
  final VoidCallback onAddDeduction;
  final Future<void> Function(PayrollAdjustmentRecord adjustment)
      onEditAdjustment;
  final Future<void> Function(PayrollAdjustmentRecord adjustment)
      onDeleteAdjustment;

  @override
  Widget build(BuildContext context) {
    final additions = employee.adjustments
        .where((item) => item.type == AdjustmentTypes.addition)
        .toList();
    final deductions = employee.adjustments
        .where((item) => item.type == AdjustmentTypes.deduction)
        .toList();
    final totalEarningsMinor =
        employee.salaryMinor + employee.commissionAmountMinor;
    final totalDeductionsMinor =
        employee.deductionsDisplayMinor + employee.advancesDisplayMinor;

    return SafeArea(
      child: Stack(
        children: [
          RawScrollbar(
            controller: scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 4,
            radius: const Radius.circular(10),
            thumbColor: AppColors.starColor.withValues(alpha: 0.72),
            trackColor: const Color(0xFFFFF3D5),
            trackBorderColor: const Color(0xFFE8C774),
            padding: const EdgeInsets.only(top: 8, right: 4, bottom: 8),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 22, 28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useSidebar = constraints.maxWidth >= 820;
                  final mainContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PayrollEmployeeSummaryCard(
                        run: run,
                        employee: employee,
                      ),
                      const SizedBox(height: 14),
                      _PayrollSectionCard(
                        title: '1. Earnings',
                        child: _EarningsTable(
                          salaryMinor: employee.salaryMinor,
                          serviceDetails: _serviceCommissionDetails(employee),
                          commissionMinor: employee.commissionAmountMinor,
                          totalEarningsMinor: totalEarningsMinor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AdjustmentListSection(
                        title: '2. Additions',
                        emptyText: 'No additions added.',
                        adjustments: additions,
                        color: const Color(0xFF157347),
                        totalMinor: employee.additionsDisplayMinor,
                        totalLabel: 'Total Additions',
                        typeHeader: 'Addition',
                        addLabel: 'Add Addition',
                        onAdd: isPaid ? null : onAddAddition,
                        onEdit: onEditAdjustment,
                        onDelete: onDeleteAdjustment,
                        allowActions: !isPaid,
                      ),
                      const SizedBox(height: 14),
                      _AdjustmentListSection(
                        title: '3. Deductions',
                        emptyText: 'No deductions added.',
                        adjustments: deductions,
                        color: const Color(0xFFB02A37),
                        totalMinor: totalDeductionsMinor,
                        totalLabel: 'Total Deductions',
                        typeHeader: 'Deduction Type',
                        addLabel: 'Add Deduction',
                        onAdd: isPaid ? null : onAddDeduction,
                        onEdit: onEditAdjustment,
                        onDelete: onDeleteAdjustment,
                        allowActions: !isPaid,
                      ),
                      if (isPaid && employee.payment != null) ...[
                        const SizedBox(height: 14),
                        _PayrollSectionCard(
                          title: 'Payment',
                          child: Column(
                            children: [
                              _SummaryLine(
                                label: 'Method',
                                value: employee.payment!.mode,
                              ),
                              _SummaryLine(
                                label: 'Reference',
                                value: employee.payment!.reference.isEmpty
                                    ? '-'
                                    : employee.payment!.reference,
                              ),
                              _SummaryLine(
                                label: 'Paid On',
                                value: DateFormat('dd MMM yyyy')
                                    .format(employee.payment!.paidDate),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                  final sidebar = Column(
                    children: [
                      _PayrollCalculationSummaryCard(
                        totalEarningsMinor: totalEarningsMinor,
                        totalAdditionsMinor: employee.additionsDisplayMinor,
                        grossPayMinor: employee.grossPayMinor,
                        totalDeductionsMinor: totalDeductionsMinor,
                        netPayableMinor: employee.netPayableMinor,
                      ),
                      const SizedBox(height: 14),
                      const _PayrollCalculationNoteCard(),
                    ],
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton.icon(
                                  onPressed: isBusy ? null : onBack,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.starColor,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Back to Payroll Runs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Payroll Calculation',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Review all earnings, additions and deductions before marking as paid.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isPaid)
                            ElevatedButton(
                              onPressed: isBusy ? null : onRecordPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.starColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                isBusy ? 'Saving...' : 'Mark as Paid',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (useSidebar)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: mainContent),
                            const SizedBox(width: 18),
                            SizedBox(width: 260, child: sidebar),
                          ],
                        )
                      else ...[
                        mainContent,
                        const SizedBox(height: 14),
                        sidebar,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (isBusy)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: const Color(0x55FFFCF8),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: AppColors.starColor,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _serviceCommissionDetails(PayrollRunEmployeeRecord employee) {
    final details = <String>[];
    if (employee.servicesCount > 0) {
      details.add(
        '${employee.servicesCount} '
        '${employee.servicesCount == 1 ? 'service' : 'services'}',
      );
    }
    if (employee.commissionPercent > 0) {
      details.add(
          '${_formatCommissionPercentText(employee.commissionPercent)}% commission');
    }
    return details.isEmpty ? '-' : details.join(' • ');
  }
}

class _PayrollEmployeeSummaryCard extends StatelessWidget {
  const _PayrollEmployeeSummaryCard({
    required this.run,
    required this.employee,
  });

  final PayrollRunRecord run;
  final PayrollRunEmployeeRecord employee;

  @override
  Widget build(BuildContext context) {
    final status = employee.statusLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E1EE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final employeeInfo = Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFFFF1DC),
                child: Text(
                  employee.userName.trim().isEmpty
                      ? 'TM'
                      : employee.userName
                          .trim()
                          .substring(
                            0,
                            math.min(2, employee.userName.trim().length),
                          )
                          .toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusPill(
                      label:
                          employee.role.isEmpty ? 'Team Member' : employee.role,
                      color: AppColors.starColor,
                    ),
                  ],
                ),
              ),
            ],
          );
          final meta = [
            _PayrollMetaBlock(
              label: 'Payroll Type',
              value: PayrollTypes.label(employee.payrollType),
            ),
            _PayrollMetaBlock(label: 'Pay Period', value: run.periodLabel),
            _PayrollMetaBlock(
              label: 'Effective From',
              value: DateFormat('d MMM yyyy').format(employee.effectiveDate),
            ),
            _PayrollMetaBlock(
              label: 'Status',
              valueWidget: _StatusPill(
                label: status,
                color: status.toLowerCase().contains('paid')
                    ? const Color(0xFF157347)
                    : const Color(0xFFB45309),
              ),
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                employeeInfo,
                const SizedBox(height: 14),
                Wrap(spacing: 16, runSpacing: 12, children: meta),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: employeeInfo),
              for (final item in meta) ...[
                const SizedBox(width: 18),
                const SizedBox(
                  height: 54,
                  child: VerticalDivider(color: Color(0xFFE1E8F0)),
                ),
                const SizedBox(width: 18),
                Expanded(child: item),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PayrollMetaBlock extends StatelessWidget {
  const _PayrollMetaBlock({
    required this.label,
    this.value,
    this.valueWidget,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          valueWidget ??
              Text(
                value ?? '-',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
        ],
      ),
    );
  }
}

class _PayrollSectionCard extends StatelessWidget {
  const _PayrollSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EarningsTable extends StatelessWidget {
  const _EarningsTable({
    required this.salaryMinor,
    required this.serviceDetails,
    required this.commissionMinor,
    required this.totalEarningsMinor,
  });

  final int salaryMinor;
  final String serviceDetails;
  final int commissionMinor;
  final int totalEarningsMinor;

  @override
  Widget build(BuildContext context) {
    return _PayrollTable(
      headers: const ['Earning Type', 'Details', 'Amount (₹)'],
      minWidth: 640,
      rows: [
        _PayrollTableRowData(
          cells: [
            'Base Salary',
            'Monthly salary',
            _formatCurrency(salaryMinor),
          ],
        ),
        _PayrollTableRowData(
          cells: [
            'Service Commission',
            serviceDetails,
            _formatCurrency(commissionMinor),
          ],
        ),
      ],
      totalLabel: 'Total Earnings',
      totalValue: _formatCurrency(totalEarningsMinor),
      totalColor: const Color(0xFF157347),
    );
  }
}

class _PayrollCalculationSummaryCard extends StatelessWidget {
  const _PayrollCalculationSummaryCard({
    required this.totalEarningsMinor,
    required this.totalAdditionsMinor,
    required this.grossPayMinor,
    required this.totalDeductionsMinor,
    required this.netPayableMinor,
  });

  final int totalEarningsMinor;
  final int totalAdditionsMinor;
  final int grossPayMinor;
  final int totalDeductionsMinor;
  final int netPayableMinor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E1EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payroll Summary',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _SummaryLine(
            label: 'Total Earnings',
            value: _formatCurrency(totalEarningsMinor),
            valueColor: const Color(0xFF157347),
            compact: true,
          ),
          _SummaryLine(
            label: 'Total Additions',
            value: _formatCurrency(totalAdditionsMinor),
            valueColor: const Color(0xFF2563EB),
            compact: true,
          ),
          const Divider(height: 18),
          _SummaryLine(
            label: 'Gross Pay',
            value: _formatCurrency(grossPayMinor),
            compact: true,
          ),
          const Divider(height: 18),
          _SummaryLine(
            label: 'Total Deductions',
            value: _formatCurrency(totalDeductionsMinor),
            valueColor: const Color(0xFFB02A37),
            compact: true,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const Text(
                  'Net Payable',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(netPayableMinor),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD06A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollCalculationNoteCard extends StatelessWidget {
  const _PayrollCalculationNoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2D29A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB45309),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please review all details. Once marked as paid, this payroll entry should not be modified.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF7C6A55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollTableRowData {
  const _PayrollTableRowData({
    required this.cells,
    this.isReadOnly = false,
  });

  final List<String> cells;
  final bool isReadOnly;
}

class _PayrollTable extends StatefulWidget {
  const _PayrollTable({
    required this.headers,
    required this.rows,
    required this.totalLabel,
    required this.totalValue,
    required this.totalColor,
    this.emptyText,
    this.onEdit,
    this.onDelete,
    this.allowActions = false,
    this.minWidth = 720,
  });

  final List<String> headers;
  final List<_PayrollTableRowData> rows;
  final String totalLabel;
  final String totalValue;
  final Color totalColor;
  final String? emptyText;
  final Future<void> Function(int index)? onEdit;
  final Future<void> Function(int index)? onDelete;
  final bool allowActions;
  final double minWidth;

  @override
  State<_PayrollTable> createState() => _PayrollTableState();
}

class _PayrollTableState extends State<_PayrollTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columnCount = widget.headers.length;
    final hasActionColumn = widget.onEdit != null || widget.onDelete != null;
    final isDeductionTotal =
        widget.totalLabel.toLowerCase().contains('deduction');

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < widget.minWidth
            ? widget.minWidth
            : constraints.maxWidth;
        return Directionality(
          textDirection: ui.TextDirection.ltr,
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 4,
            radius: const Radius.circular(10),
            thumbColor: AppColors.starColor.withValues(alpha: 0.72),
            trackColor: const Color(0xFFFFF3D5),
            trackBorderColor: const Color(0xFFE8C774),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: tableWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE1E9F4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _PayrollTableLine(
                          cells: widget.headers,
                          backgroundColor: const Color(0xFFF8FAFC),
                          textColor: const Color(0xFF526783),
                          isHeader: true,
                          trailing: hasActionColumn
                              ? const Text(
                                  'Action',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF526783),
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                        if (widget.rows.isEmpty)
                          Container(
                            height: 64,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFE6EEF7)),
                              ),
                            ),
                            child: Text(
                              widget.emptyText ?? 'No records added.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else
                          ...widget.rows.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return _PayrollTableLine(
                              cells: row.cells,
                              showTopBorder: true,
                              trailing: hasActionColumn
                                  ? widget.allowActions && !row.isReadOnly
                                      ? PopupMenuButton<String>(
                                          tooltip: 'Actions',
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              widget.onEdit?.call(index);
                                            } else if (value == 'delete') {
                                              widget.onDelete?.call(index);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          '-',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                          ),
                                        )
                                  : null,
                            );
                          }),
                        _PayrollTableLine(
                          cells: [
                            widget.totalLabel,
                            ...List<String>.filled(
                              math.max(columnCount - 2, 0),
                              '',
                            ),
                            widget.totalValue,
                          ],
                          backgroundColor: isDeductionTotal
                              ? const Color(0xFFFFF5F5)
                              : widget.totalColor.withValues(alpha: 0.06),
                          textColor: widget.totalColor,
                          isTotal: true,
                          showTopBorder: true,
                          trailing:
                              hasActionColumn ? const SizedBox.shrink() : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PayrollTableLine extends StatelessWidget {
  const _PayrollTableLine({
    required this.cells,
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF111827),
    this.isHeader = false,
    this.isTotal = false,
    this.showTopBorder = false,
    this.trailing,
  });

  final List<String> cells;
  final Color backgroundColor;
  final Color textColor;
  final bool isHeader;
  final bool isTotal;
  final bool showTopBorder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: isHeader ? 36 : 44),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showTopBorder
            ? const Border(top: BorderSide(color: Color(0xFFE6EEF7)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++) ...[
            Expanded(
              flex: index == 1 ? 3 : 2,
              child: Text(
                cells[index],
                maxLines: isHeader ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: index == cells.length - 1 ? TextAlign.right : null,
                style: TextStyle(
                  fontSize: isHeader ? 11 : 12,
                  fontWeight:
                      isHeader || isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (index != cells.length - 1) const SizedBox(width: 12),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            SizedBox(width: 54, child: Center(child: trailing)),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF1C1917),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentListSection extends StatelessWidget {
  const _AdjustmentListSection({
    required this.title,
    required this.emptyText,
    required this.adjustments,
    required this.color,
    required this.totalMinor,
    required this.totalLabel,
    required this.typeHeader,
    required this.addLabel,
    this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.allowActions = true,
  });

  final String title;
  final String emptyText;
  final List<PayrollAdjustmentRecord> adjustments;
  final Color color;
  final int totalMinor;
  final String totalLabel;
  final String typeHeader;
  final String addLabel;
  final VoidCallback? onAdd;
  final Future<void> Function(PayrollAdjustmentRecord adjustment) onEdit;
  final Future<void> Function(PayrollAdjustmentRecord adjustment) onDelete;
  final bool allowActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              if (onAdd != null)
                OutlinedButton(
                  onPressed: onAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(addLabel),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PayrollTable(
            headers: [typeHeader, 'Details', 'Amount (₹)'],
            rows: adjustments.map((adjustment) {
              final isBackendAdvance = adjustment.id.startsWith('advance-');
              return _PayrollTableRowData(
                isReadOnly: isBackendAdvance,
                cells: [
                  isBackendAdvance
                      ? 'Advance'
                      : adjustment.type == AdjustmentTypes.addition
                          ? 'Addition'
                          : 'Deduction',
                  adjustment.remarks.isEmpty ? '-' : adjustment.remarks,
                  _formatCurrency(adjustment.amountMinor),
                ],
              );
            }).toList(),
            totalLabel: totalLabel,
            totalValue: _formatCurrency(totalMinor),
            totalColor: color,
            emptyText: emptyText,
            allowActions: allowActions,
            onEdit: (index) => onEdit(adjustments[index]),
            onDelete: (index) => onDelete(adjustments[index]),
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
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.maxLength = 120,
    this.inputFormatters = const <TextInputFormatter>[],
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLength: maxLength,
      controller: controller,
      validator: validator,
      cursorColor: AppColors.starColor,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      inputFormatters: [
        ...inputFormatters,
        if (maxLength > 0) LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8F5F2) : const Color(0xFFF2F2F2),
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Color(0xFFD32F2F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
