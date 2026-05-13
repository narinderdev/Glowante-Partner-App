import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/stylist_branch_selection.dart';
import '../../../utils/localization_helper.dart';
import '../../salon/widgets/owner_branch_header_selector.dart';
import '../widgets/profile_subpage_app_bar.dart';
import '../../../utils/colors.dart';
import 'profile_compensation_models.dart';
import 'profile_compensation_repository.dart';

part 'owner_payroll.dart';
part 'owner_commission.dart';

enum CompensationModule { payroll, commission }

enum _PayrollStage { dashboard, setup }

enum _CommissionTab { services, overrides }

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
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  CompensationModule _module = CompensationModule.payroll;
  _PayrollStage _payrollStage = _PayrollStage.dashboard;
  _CommissionTab _commissionTab = _CommissionTab.services;

  List<ProfileBranchOption> _branchOptions = const <ProfileBranchOption>[];
  ProfileBranchOption? _selectedBranch;

  List<ProfileTeamMember> _teamMembers = const <ProfileTeamMember>[];
  List<PayrollSetupRecord> _payrollSetups = const <PayrollSetupRecord>[];
  List<PayrollRunRecord> _payrollRuns = const <PayrollRunRecord>[];
  List<BranchServiceSummary> _services = const <BranchServiceSummary>[];
  List<CommissionServiceRule> _serviceRules = const <CommissionServiceRule>[];
  List<StaffCommissionOverride> _staffOverrides =
      const <StaffCommissionOverride>[];

  bool _isLoadingBranches = true;
  bool _isLoadingContent = false;
  bool _isActionInProgress = false;
  String? _branchError;
  String? _contentError;
  int? _selectedServiceId;

  String get _moduleLogLabel =>
      _module == CompensationModule.payroll ? 'payroll' : 'commission';

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
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
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _isLoadingContent = true;
        _contentError = null;
      });
    } else {
      setState(() {
        _contentError = null;
      });
    }

    try {
      if (_module == CompensationModule.payroll) {
        await _loadPayrollData(selectedBranch.branchId);
      } else {
        await _loadCommissionData(selectedBranch.branchId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingContent = false;
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
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _repository.loadTeamMembers(branchId),
      _repository.loadPayrollSetups(branchId),
      _repository.loadPayrollRuns(branchId),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _teamMembers = List<ProfileTeamMember>.from(results[0] as List);
      _payrollSetups = List<PayrollSetupRecord>.from(results[1] as List);
      _payrollRuns = List<PayrollRunRecord>.from(results[2] as List);
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
      _payrollStage = _PayrollStage.dashboard;
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
      _showPayrollDashboardStage();
      _logCompensation(
        'generate_payroll_success',
        details: 'branchId=$branchId, period=${period.toIso8601String()}',
      );
      _showToast('Payroll generated successfully');
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
    await _performAction(() async {
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
    });
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : const Color(0xFF1F7A4D),
      ),
    );
  }

  void _showPayrollSetupStage() {
    setState(() => _payrollStage = _PayrollStage.setup);
  }

  void _showPayrollDashboardStage() {
    setState(() => _payrollStage = _PayrollStage.dashboard);
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
    return _currencyFormatter.format(amount);
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF157347);
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isBusy = false;

        Future<void> refreshRun(PayrollRunRecord updatedRun) async {
          currentRun = updatedRun;
          await _loadPayrollData(branchId);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> approvePayroll() async {
              if (isBusy || currentRun.isApproved) {
                return;
              }
              setSheetState(() => isBusy = true);
              try {
                _logCompensation(
                  'approve_payroll_started',
                  details: 'branchId=$branchId, runId=${currentRun.id}',
                );
                final updated = await _repository.approvePayroll(
                  branchId: branchId,
                  runId: currentRun.id,
                );
                await refreshRun(updated);
                setSheetState(() => currentRun = updated);
                _logCompensation(
                  'approve_payroll_success',
                  details: 'branchId=$branchId, runId=${currentRun.id}',
                );
                _showToast('Payroll approved successfully');
              } catch (error) {
                _logCompensation(
                  'approve_payroll_failed',
                  details: _errorText(error),
                );
                _showToast(_errorText(error), isError: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isBusy = false);
                }
              }
            }

            Future<void> recordPayment() async {
              if (isBusy) {
                return;
              }
              final payment = await _showPaymentDialog(
                title: 'Record Payment',
                submitLabel: 'Mark payroll as paid',
              );
              if (payment == null) {
                _logCompensation('record_payroll_payment_cancelled');
                return;
              }
              setSheetState(() => isBusy = true);
              try {
                _logCompensation(
                  'record_payroll_payment_started',
                  details: 'branchId=$branchId, runId=${currentRun.id}',
                );
                final updated = await _repository.recordPayrollPayment(
                  branchId: branchId,
                  runId: currentRun.id,
                  payment: payment,
                );
                await refreshRun(updated);
                setSheetState(() => currentRun = updated);
                _logCompensation(
                  'record_payroll_payment_success',
                  details: 'branchId=$branchId, runId=${currentRun.id}',
                );
                _showToast('Payroll payment recorded successfully');
              } catch (error) {
                _logCompensation(
                  'record_payroll_payment_failed',
                  details: _errorText(error),
                );
                _showToast(_errorText(error), isError: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isBusy = false);
                }
              }
            }

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFBF9F8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7CEC5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            'Net payable ${_formatCurrency(currentRun.totalAmountMinor)} • ${currentRun.employees.length} employees',
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
                              if (!currentRun.isApproved)
                                _ActionChipButton(
                                  label: isBusy
                                      ? 'Approving...'
                                      : 'Approve Payroll',
                                  onTap: isBusy ? null : approvePayroll,
                                  filled: true,
                                ),
                              if (currentRun.isApproved &&
                                  !currentRun.allEmployeesPaid)
                                _ActionChipButton(
                                  label:
                                      isBusy ? 'Saving...' : 'Record Payment',
                                  onTap: isBusy ? null : recordPayment,
                                  filled: true,
                                ),
                              _ActionChipButton(
                                label: 'Close',
                                onTap: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: currentRun.employees.isEmpty
                          ? const _EmptyStateCard(
                              title: 'No payroll rows found',
                              subtitle:
                                  'Generate a payroll run to review employee payouts.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: currentRun.employees.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final employee = currentRun.employees[index];
                                final status = employee.payment != null
                                    ? 'Paid'
                                    : currentRun.isApproved
                                        ? 'Approved'
                                        : 'Pending';
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () async {
                                      final updated = await _openEmployeeReview(
                                        run: currentRun,
                                        employee: employee,
                                      );
                                      if (updated != null &&
                                          sheetContext.mounted) {
                                        await refreshRun(updated);
                                        setSheetState(
                                            () => currentRun = updated);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  employee.userName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1C1917),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Net payable ${_formatCurrency(employee.netPayableMinor)}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          _StatusPill(
                                            label: status,
                                            color: _statusColor(status),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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

    PayrollRunRecord currentRun = run;
    PayrollRunEmployeeRecord currentEmployee = employee;

    return showModalBottomSheet<PayrollRunRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isBusy = false;

        Future<void> refreshEmployee(PayrollRunRecord updatedRun) async {
          currentRun = updatedRun;
          currentEmployee = updatedRun.employees.firstWhere(
            (item) => item.userId == employee.userId,
          );
          await _loadPayrollData(branchId);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> addAdjustment(String type) async {
              if (isBusy) {
                return;
              }
              final adjustment = await _showAdjustmentDialog(type);
              if (adjustment == null) {
                _logCompensation(
                  'add_adjustment_cancelled',
                  details: 'type=$type, userId=${currentEmployee.userId}',
                );
                return;
              }
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
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isBusy = false);
                }
              }
            }

            Future<void> recordEmployeePayment() async {
              if (isBusy) {
                return;
              }
              final payment = await _showPaymentDialog(
                title: 'Record Employee Payment',
                submitLabel: 'Mark employee as paid',
              );
              if (payment == null) {
                _logCompensation(
                  'record_employee_payment_cancelled',
                  details: 'userId=${currentEmployee.userId}',
                );
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
                  payment: payment,
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

            final status = currentEmployee.payment != null
                ? 'Paid'
                : currentRun.isApproved
                    ? 'Approved'
                    : 'Pending';

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: DefaultTabController(
                length: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBF9F8),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7CEC5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    currentEmployee.userName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1C1917),
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  label: status,
                                  color: _statusColor(status),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext, currentRun);
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Net payable ${_formatCurrency(currentEmployee.netPayableMinor)}',
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
                                  label: 'Add Addition',
                                  onTap: isBusy
                                      ? null
                                      : () => addAdjustment(
                                          AdjustmentTypes.addition),
                                  filled: true,
                                ),
                                _ActionChipButton(
                                  label: 'Add Deduction',
                                  onTap: isBusy
                                      ? null
                                      : () => addAdjustment(
                                          AdjustmentTypes.deduction),
                                ),
                                _ActionChipButton(
                                  label: currentEmployee.payment == null
                                      ? 'Record Employee Payment'
                                      : 'Update Payment',
                                  onTap: isBusy ? null : recordEmployeePayment,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const TabBar(
                        labelColor: Color(0xFFB45309),
                        unselectedLabelColor: Color(0xFF6B7280),
                        indicatorColor: Color(0xFFB45309),
                        tabs: [
                          Tab(text: 'Summary'),
                          Tab(text: 'Adjustments'),
                          Tab(text: 'Payment'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                _SummaryLine(
                                  label: 'Payroll type',
                                  value: PayrollTypes.label(
                                    currentEmployee.payrollType,
                                  ),
                                ),
                                _SummaryLine(
                                  label: 'Salary',
                                  value: _formatCurrency(
                                    currentEmployee.salaryMinor,
                                  ),
                                ),
                                _SummaryLine(
                                  label: 'Commission %',
                                  value:
                                      '${currentEmployee.commissionPercent.toStringAsFixed(1)}%',
                                ),
                                _SummaryLine(
                                  label: 'Commission amount',
                                  value: _formatCurrency(
                                    currentEmployee.commissionAmountMinor,
                                  ),
                                ),
                                _SummaryLine(
                                  label: 'Effective date',
                                  value: _formatDate(
                                      currentEmployee.effectiveDate),
                                ),
                                _SummaryLine(
                                  label: 'Net payable',
                                  value: _formatCurrency(
                                    currentEmployee.netPayableMinor,
                                  ),
                                ),
                              ],
                            ),
                            currentEmployee.adjustments.isEmpty
                                ? const _EmptyStateCard(
                                    title: 'No adjustments added',
                                    subtitle:
                                        'Use addition or deduction to update this employee payout.',
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(20),
                                    itemCount:
                                        currentEmployee.adjustments.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final adjustment =
                                          currentEmployee.adjustments[index];
                                      final isAddition = adjustment.type ==
                                          AdjustmentTypes.addition;
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _StatusPill(
                                                  label: adjustment.type,
                                                  color: isAddition
                                                      ? const Color(0xFF157347)
                                                      : const Color(0xFFB02A37),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _formatCurrency(
                                                    adjustment.amountMinor,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              adjustment.remarks.isEmpty
                                                  ? 'No remarks'
                                                  : adjustment.remarks,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _formatDate(adjustment.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                _SummaryLine(
                                  label: 'Status',
                                  value: status,
                                ),
                                _SummaryLine(
                                  label: 'Payment mode',
                                  value: currentEmployee.payment?.mode ??
                                      'Not paid yet',
                                ),
                                _SummaryLine(
                                  label: 'Reference',
                                  value: currentEmployee
                                              .payment?.reference.isNotEmpty ==
                                          true
                                      ? currentEmployee.payment!.reference
                                      : 'Not provided',
                                ),
                                _SummaryLine(
                                  label: 'Paid date',
                                  value: currentEmployee.payment != null
                                      ? _formatDate(
                                          currentEmployee.payment!.paidDate)
                                      : 'Pending',
                                ),
                                _SummaryLine(
                                  label: 'Notes',
                                  value: currentEmployee
                                              .payment?.notes.isNotEmpty ==
                                          true
                                      ? currentEmployee.payment!.notes
                                      : 'No notes',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<PaymentRecord?> _showPaymentDialog({
    required String title,
    required String submitLabel,
  }) async {
    final modeController = TextEditingController(text: 'Bank Transfer');
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    DateTime paidDate = DateTime.now();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<PaymentRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.72,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _LabeledTextField(
                                  label: 'Payment mode',
                                  controller: modeController,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Payment mode is required'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                _LabeledTextField(
                                  label: 'Reference / Txn ID',
                                  controller: referenceController,
                                ),
                                const SizedBox(height: 14),
                                _DateFieldButton(
                                  label: 'Paid date',
                                  value: paidDate,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: paidDate,
                                      firstDate: DateTime(2022),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setSheetState(() => paidDate = picked);
                                    }
                                  },
                                ),
                                const SizedBox(height: 14),
                                _LabeledTextField(
                                  label: 'Notes',
                                  controller: notesController,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              Navigator.pop(
                                context,
                                PaymentRecord(
                                  mode: modeController.text.trim(),
                                  reference: referenceController.text.trim(),
                                  paidDate: paidDate,
                                  notes: notesController.text.trim(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(submitLabel),
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
      },
    );

    modeController.dispose();
    referenceController.dispose();
    notesController.dispose();
    return result;
  }

  Future<PayrollAdjustmentRecord?> _showAdjustmentDialog(String type) async {
    final amountController = TextEditingController();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<PayrollAdjustmentRecord>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(type == AdjustmentTypes.addition
              ? 'Add Addition'
              : 'Add Deduction'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabeledTextField(
                  label: 'Type',
                  controller: TextEditingController(text: type),
                  enabled: false,
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: 'Amount',
                  controller: amountController,
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
                  maxLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.pop(
                  context,
                  PayrollAdjustmentRecord(
                    id: '${DateTime.now().millisecondsSinceEpoch}',
                    type: type,
                    amountMinor: int.parse(amountController.text.trim()),
                    remarks: remarksController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    amountController.dispose();
    remarksController.dispose();
    return result;
  }

  Future<void> _openAddOverrideDialog() async {
    final service = _selectedService;
    if (service == null) {
      return;
    }
    final result = await showDialog<List<StaffCommissionOverride>>(
      context: context,
      builder: (context) => _AddOverrideDialog(
        serviceId: service.id,
        staff: _activeTeamMembers,
      ),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    await _saveOverrides(service.id, result);
  }

  @override
  Widget build(BuildContext context) {
    final title = _module == CompensationModule.payroll
        ? context.t('Payroll')
        : context.t('Commission Setup');

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
                isInteractive: true,
                onSelected: (branchId) {
                  final next = _branchOptions.firstWhere(
                    (item) => item.branchId == branchId,
                  );
                  _switchBranch(next);
                },
              ),
            ),
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
      if (_payrollStage == _PayrollStage.setup) {
        return _PayrollSetupView(
          teamMembers: _activeTeamMembers,
          existingSetups: _setupByUserId,
          onSave: _savePayrollSetup,
          onBack: _showPayrollDashboardStage,
          onContinue: _showPayrollDashboardStage,
        );
      }
      return _buildPayrollDashboard();
    }

    return _buildCommissionScreen();
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1C1917) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1C1917)
                  : const Color(0xFFE9DFD1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFFB45309),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1C1917),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2937), Color(0xFF111827)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD1D5DB),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFCD34D),
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
}

class _PayrollRunTile extends StatelessWidget {
  const _PayrollRunTile({
    required this.run,
    required this.amountLabel,
    required this.statusColor,
    required this.onOpen,
  });

  final PayrollRunRecord run;
  final String amountLabel;
  final Color statusColor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.periodLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${run.employees.length} employees • $amountLabel',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(label: run.statusLabel, color: statusColor),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
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
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.starColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? AppColors.starColor : const Color(0xFFE9DFD1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : const Color(0xFF1C1917),
          ),
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
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
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
