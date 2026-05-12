import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/stylist_branch_selection.dart';
import '../../../utils/localization_helper.dart';
import '../../salon/widgets/owner_branch_header_selector.dart';
import '../widgets/profile_subpage_app_bar.dart';
import '../../../utils/colors.dart';
import 'profile_compensation_models.dart';
import 'profile_compensation_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _module = widget.initialModule;
    _serviceSearchController.addListener(() {
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
    }
  }

  Future<void> _reloadContent({bool showLoader = true}) async {
    final selectedBranch = _selectedBranch;
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingContent = false;
        _contentError = _errorText(error);
      });
    }
  }

  Future<void> _loadPayrollData(int branchId) async {
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
  }

  Future<void> _loadCommissionData(int branchId) async {
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
  }

  Future<void> _switchBranch(ProfileBranchOption option) async {
    if (_selectedBranch?.branchId == option.branchId) {
      return;
    }

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
    await _repository.savePayrollSetup(branchId, setup);
    await _loadPayrollData(branchId);
    _showToast('Payroll setup saved successfully');
  }

  Future<void> _generatePayroll(DateTime period) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
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
      setState(() {
        _payrollStage = _PayrollStage.dashboard;
      });
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
    await _performAction(() async {
      await _repository.saveCommissionRule(
        branchId: branchId,
        service: service,
        rule: rule,
      );
      await _loadCommissionData(branchId);
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
      _showToast('Commission override saved successfully');
    });
  }

  Future<void> _deleteOverride(String overrideId) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }
    await _performAction(() async {
      await _repository.deleteStaffOverride(
        branchId: branchId,
        overrideId: overrideId,
      );
      await _loadCommissionData(branchId);
      _showToast('Override removed successfully');
    });
  }

  Future<void> _performAction(Future<void> Function() action) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });

    try {
      await action();
    } catch (error) {
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
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => const _GeneratePayrollDialog(),
    );
    if (selected == null) {
      return;
    }
    await _generatePayroll(selected);
  }

  Future<void> _openPayrollReview(PayrollRunRecord initialRun) async {
    final branchId = _selectedBranch?.branchId;
    if (branchId == null) {
      return;
    }

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
                final updated = await _repository.approvePayroll(
                  branchId: branchId,
                  runId: currentRun.id,
                );
                await refreshRun(updated);
                setSheetState(() => currentRun = updated);
                _showToast('Payroll approved successfully');
              } catch (error) {
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
                return;
              }
              setSheetState(() => isBusy = true);
              try {
                final updated = await _repository.recordPayrollPayment(
                  branchId: branchId,
                  runId: currentRun.id,
                  payment: payment,
                );
                await refreshRun(updated);
                setSheetState(() => currentRun = updated);
                _showToast('Payroll payment recorded successfully');
              } catch (error) {
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
                return;
              }
              setSheetState(() => isBusy = true);
              try {
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
                _showToast('Adjustment saved successfully');
              } catch (error) {
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
                return;
              }
              setSheetState(() => isBusy = true);
              try {
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
                _showToast('Employee payment recorded successfully');
              } catch (error) {
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
                          maxLines: 3,
                        ),
                        const Spacer(),
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
                  maxLines: 3,
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
          onBack: () {
            setState(() => _payrollStage = _PayrollStage.dashboard);
          },
          onContinue: () {
            setState(() => _payrollStage = _PayrollStage.dashboard);
          },
        );
      }
      return _buildPayrollDashboard();
    }

    return _buildCommissionScreen();
  }

  Widget _buildPayrollDashboard() {
    final currentRun = _payrollRuns.isEmpty ? null : _payrollRuns.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Active team',
                value: '${_activeTeamMembers.length}',
                subtitle: 'members',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Configured',
                value: '${_payrollSetups.length}',
                subtitle: 'payroll setups',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Runs',
                value: '${_payrollRuns.length}',
                subtitle: 'generated',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (currentRun != null)
          _HighlightCard(
            title: 'Current run',
            subtitle: currentRun.periodLabel,
            amount: _formatCurrency(currentRun.totalAmountMinor),
            status: currentRun.statusLabel,
            onTap: () {
              _openPayrollReview(currentRun);
            },
          )
        else
          const _EmptyStateCard(
            title: 'No payroll generated yet',
            subtitle:
                'Finish payroll setup, then generate the first payroll period for this branch.',
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!_isPayrollConfiguredForAllTeam)
              _ActionChipButton(
                label: context.t('Setup Payroll'),
                filled: true,
                onTap: _isActionInProgress
                    ? null
                    : () {
                        setState(() => _payrollStage = _PayrollStage.setup);
                      },
              ),
            if (_isPayrollConfiguredForAllTeam)
              _ActionChipButton(
                label: _isActionInProgress
                    ? context.t('Generating...')
                    : context.t('Generate Payroll'),
                filled: true,
                onTap: _isActionInProgress
                    ? null
                    : () {
                        _openGeneratePayrollDialog();
                      },
              ),
            if (_payrollRuns.isNotEmpty)
              _ActionChipButton(
                label: context.t('Review & Pay'),
                onTap: _isActionInProgress
                    ? null
                    : () {
                        _openPayrollReview(_payrollRuns.first);
                      },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.t('Generated Payroll Periods'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const SizedBox(height: 12),
        if (_activeTeamMembers.isEmpty)
          const _EmptyStateCard(
            title: 'No staff found for this branch',
            subtitle: 'Add or activate team members before setting up payroll.',
          )
        else if (_payrollRuns.isEmpty)
          const _EmptyStateCard(
            title: 'No payroll history available',
            subtitle:
                'Once you generate payroll, each period will appear here for review and payment.',
          )
        else
          ..._payrollRuns.map(
            (run) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PayrollRunTile(
                run: run,
                amountLabel: _formatCurrency(run.totalAmountMinor),
                statusColor: _statusColor(run.statusLabel),
                onOpen: () {
                  _openPayrollReview(run);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommissionScreen() {
    if (_services.isEmpty) {
      return const _EmptyStateCard(
        title: 'No services found for this branch',
        subtitle:
            'Commission setup needs active branch services and staff members.',
      );
    }

    final selectedService = _selectedService;
    final selectedRule = _selectedServiceRule;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _ModuleButton(
                label: 'Services',
                icon: Icons.design_services_outlined,
                isSelected: _commissionTab == _CommissionTab.services,
                onTap: () {
                  setState(() => _commissionTab = _CommissionTab.services);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleButton(
                label: 'Staff Overrides',
                icon: Icons.groups_2_outlined,
                isSelected: _commissionTab == _CommissionTab.overrides,
                onTap: () {
                  setState(() => _commissionTab = _CommissionTab.overrides);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _serviceSearchController,
          decoration: InputDecoration(
            hintText: 'Search services',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 136,
          child: _filteredServices.isEmpty
              ? const _EmptyStateCard(
                  title: 'No matching services',
                  subtitle: 'Try a different service name or clear the search.',
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredServices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final service = _filteredServices[index];
                    final isSelected = selectedService?.id == service.id;
                    final rule = _repository.ruleForService(
                      service: service,
                      storedRules: _serviceRules,
                    );
                    return _ServiceSelectorCard(
                      service: service,
                      rule: rule,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _selectedServiceId = service.id);
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 18),
        if (selectedService == null || selectedRule == null)
          const _EmptyStateCard(
            title: 'Select a service',
            subtitle:
                'Choose a service to edit its default commission rule and staff overrides.',
          )
        else if (_commissionTab == _CommissionTab.services)
          _ServiceRuleEditorCard(
            service: selectedService,
            initialRule: selectedRule,
            isSaving: _isActionInProgress,
            onSave: (rule) => _saveCommissionRule(
              service: selectedService,
              rule: rule,
            ),
          )
        else
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedService.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1917),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedService.categoryName.isEmpty
                                    ? 'Staff override rules'
                                    : selectedService.categoryName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ActionChipButton(
                          label: _isActionInProgress
                              ? 'Saving...'
                              : 'Add Override',
                          onTap: _isActionInProgress
                              ? null
                              : () {
                                  _openAddOverrideDialog();
                                },
                          filled: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_selectedServiceOverrides.isEmpty)
                      const _EmptyStateCard(
                        title: 'No staff overrides found',
                        subtitle:
                            'Add override rules for one or more staff members on this service.',
                      )
                    else
                      ..._selectedServiceOverrides.map(
                        (override) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5F2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        override.staffName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C1917),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        override.ruleType ==
                                                CommissionRuleTypes.percentage
                                            ? '${override.value.toStringAsFixed(1)}%'
                                            : _formatCurrency(
                                                override.value.round()),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Effective from ${_formatDate(override.effectiveFrom)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () {
                                          _deleteOverride(override.id);
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _GeneratePayrollDialog extends StatefulWidget {
  const _GeneratePayrollDialog();

  @override
  State<_GeneratePayrollDialog> createState() => _GeneratePayrollDialogState();
}

class _GeneratePayrollDialogState extends State<_GeneratePayrollDialog> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final years =
        List<int>.generate(5, (index) => DateTime.now().year - 1 + index);

    return AlertDialog(
      title: Text(context.t('Generate Payroll')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _selectedMonth,
            decoration: const InputDecoration(labelText: 'Month'),
            items: List<DropdownMenuItem<int>>.generate(
              12,
              (index) => DropdownMenuItem<int>(
                value: index + 1,
                child:
                    Text(DateFormat('MMMM').format(DateTime(2026, index + 1))),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMonth = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(labelText: 'Year'),
            items: years
                .map(
                  (year) => DropdownMenuItem<int>(
                    value: year,
                    child: Text('$year'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(_selectedYear, _selectedMonth, 1),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: Text(context.t('Generate Payroll')),
        ),
      ],
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

class _PayrollSetupView extends StatefulWidget {
  const _PayrollSetupView({
    required this.teamMembers,
    required this.existingSetups,
    required this.onSave,
    required this.onBack,
    required this.onContinue,
  });

  final List<ProfileTeamMember> teamMembers;
  final Map<int, PayrollSetupRecord> existingSetups;
  final Future<void> Function(PayrollSetupRecord setup) onSave;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<_PayrollSetupView> createState() => _PayrollSetupViewState();
}

class _PayrollSetupViewState extends State<_PayrollSetupView> {
  final Set<int> _savingIds = <int>{};

  @override
  Widget build(BuildContext context) {
    if (widget.teamMembers.isEmpty) {
      return const _EmptyStateCard(
        title: 'No staff found for this branch',
        subtitle: 'Add or activate team members before configuring payroll.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back to Dashboard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Continue / Review'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.teamMembers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = widget.teamMembers[index];
              final initial = widget.existingSetups[member.id];
              return _PayrollSetupMemberCard(
                member: member,
                initialSetup: initial,
                isSaving: _savingIds.contains(member.id),
                onSave: (setup) async {
                  setState(() => _savingIds.add(member.id));
                  try {
                    await widget.onSave(setup);
                  } finally {
                    if (mounted) {
                      setState(() => _savingIds.remove(member.id));
                    }
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PayrollSetupMemberCard extends StatefulWidget {
  const _PayrollSetupMemberCard({
    required this.member,
    required this.initialSetup,
    required this.isSaving,
    required this.onSave,
  });

  final ProfileTeamMember member;
  final PayrollSetupRecord? initialSetup;
  final bool isSaving;
  final Future<void> Function(PayrollSetupRecord setup) onSave;

  @override
  State<_PayrollSetupMemberCard> createState() =>
      _PayrollSetupMemberCardState();
}

class _PayrollSetupMemberCardState extends State<_PayrollSetupMemberCard> {
  late String _payrollType;
  late TextEditingController _salaryController;
  late TextEditingController _commissionController;
  late DateTime _effectiveDate;

  @override
  void initState() {
    super.initState();
    _payrollType = widget.initialSetup?.payrollType ?? PayrollTypes.salaryOnly;
    _salaryController = TextEditingController(
      text: widget.initialSetup == null || widget.initialSetup!.salaryMinor == 0
          ? ''
          : '${widget.initialSetup!.salaryMinor}',
    );
    _commissionController = TextEditingController(
      text: widget.initialSetup == null ||
              widget.initialSetup!.commissionPercent == 0
          ? ''
          : widget.initialSetup!.commissionPercent.toStringAsFixed(1),
    );
    _effectiveDate = widget.initialSetup?.effectiveDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PayrollSetupMemberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSetup != widget.initialSetup &&
        widget.initialSetup != null) {
      _payrollType = widget.initialSetup!.payrollType;
      _salaryController.text = widget.initialSetup!.salaryMinor == 0
          ? ''
          : '${widget.initialSetup!.salaryMinor}';
      _commissionController.text = widget.initialSetup!.commissionPercent == 0
          ? ''
          : widget.initialSetup!.commissionPercent.toStringAsFixed(1);
      _effectiveDate = widget.initialSetup!.effectiveDate;
    }
  }

  bool get _requiresSalary =>
      _payrollType == PayrollTypes.salaryOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  bool get _requiresCommission =>
      _payrollType == PayrollTypes.commissionOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  Future<void> _submit() async {
    final salary = int.tryParse(_salaryController.text.trim()) ?? 0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0;

    if (_requiresSalary && salary <= 0) {
      _showRowToast('Salary is required for salary-based payroll types.');
      return;
    }
    if (_requiresCommission && (commission < 0 || commission > 100)) {
      _showRowToast('Commission must be between 0 and 100.');
      return;
    }

    final setup = PayrollSetupRecord(
      userId: widget.member.id,
      userName: widget.member.name,
      payrollType: _payrollType,
      salaryMinor: _requiresSalary ? salary : 0,
      commissionPercent: _requiresCommission ? commission : 0,
      effectiveDate: _effectiveDate,
    );
    await widget.onSave(setup);
  }

  void _showRowToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.member.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.member.role.isEmpty
                          ? 'Team member'
                          : widget.member.role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.initialSetup != null)
                const _StatusPill(
                  label: 'Configured',
                  color: Color(0xFF157347),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _payrollType,
            decoration: InputDecoration(
              labelText: 'Payroll type',
              filled: true,
              fillColor: const Color(0xFFF8F5F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: PayrollTypes.values
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(PayrollTypes.label(value)),
                  ),
                )
                .toList(),
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _payrollType = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledTextField(
                  label: 'Salary',
                  controller: _salaryController,
                  enabled: _requiresSalary && !widget.isSaving,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledTextField(
                  label: 'Commission %',
                  controller: _commissionController,
                  enabled: _requiresCommission && !widget.isSaving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DateFieldButton(
            label: 'Effective date',
            value: _effectiveDate,
            onTap: widget.isSaving
                ? () {}
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _effectiveDate,
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _effectiveDate = picked);
                    }
                  },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isSaving
                  ? null
                  : () {
                      _submit();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(widget.isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSelectorCard extends StatelessWidget {
  const _ServiceSelectorCard({
    required this.service,
    required this.rule,
    required this.isSelected,
    required this.onTap,
  });

  final BranchServiceSummary service;
  final CommissionServiceRule rule;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final valueLabel = rule.ruleType == CommissionRuleTypes.percentage
        ? '${rule.value.toStringAsFixed(1)}%'
        : '₹${rule.value.round()}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1C1917) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1C1917)
                  : const Color(0xFFE9DFD1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  service.categoryName.isEmpty
                      ? 'Service commission'
                      : service.categoryName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                rule.active ? valueLabel : 'Inactive',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFFFCD34D)
                      : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRuleEditorCard extends StatefulWidget {
  const _ServiceRuleEditorCard({
    required this.service,
    required this.initialRule,
    required this.isSaving,
    required this.onSave,
  });

  final BranchServiceSummary service;
  final CommissionServiceRule initialRule;
  final bool isSaving;
  final Future<void> Function(CommissionServiceRule rule) onSave;

  @override
  State<_ServiceRuleEditorCard> createState() => _ServiceRuleEditorCardState();
}

class _ServiceRuleEditorCardState extends State<_ServiceRuleEditorCard> {
  late String _ruleType;
  late TextEditingController _valueController;
  late TextEditingController _notesController;
  late DateTime _effectiveFrom;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _applyRule(widget.initialRule);
  }

  @override
  void didUpdateWidget(covariant _ServiceRuleEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.id != widget.service.id ||
        oldWidget.initialRule != widget.initialRule) {
      _applyRule(widget.initialRule);
    }
  }

  void _applyRule(CommissionServiceRule rule) {
    if (_isControllerReady) {
      _valueController.dispose();
      _notesController.dispose();
    }
    _ruleType = rule.ruleType;
    _valueController = TextEditingController(
      text: rule.value == 0 ? '' : rule.value.toStringAsFixed(1),
    );
    _notesController = TextEditingController(text: rule.notes);
    _effectiveFrom = rule.effectiveFrom;
    _active = rule.active;
  }

  bool get _isControllerReady {
    try {
      _valueController;
      _notesController;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _valueController.text = widget.initialRule.value == 0
          ? ''
          : widget.initialRule.value.toStringAsFixed(1);
      _notesController.text = widget.initialRule.notes;
      _ruleType = widget.initialRule.ruleType;
      _effectiveFrom = widget.initialRule.effectiveFrom;
      _active = widget.initialRule.active;
    });
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_valueController.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid commission value')),
      );
      return;
    }
    if (_ruleType == CommissionRuleTypes.percentage && parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission must be between 0 and 100')),
      );
      return;
    }

    await widget.onSave(
      CommissionServiceRule(
        serviceId: widget.service.id,
        ruleType: _ruleType,
        value: parsed,
        effectiveFrom: _effectiveFrom,
        active: _active,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.service.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Default commission rule',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _active,
                activeThumbColor: AppColors.starColor,
                onChanged: widget.isSaving
                    ? null
                    : (value) {
                        setState(() => _active = value);
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _ruleType,
            decoration: InputDecoration(
              labelText: 'Rule type',
              filled: true,
              fillColor: const Color(0xFFF8F5F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: CommissionRuleTypes.percentage,
                child: Text('Percentage'),
              ),
              DropdownMenuItem(
                value: CommissionRuleTypes.fixed,
                child: Text('Fixed'),
              ),
            ],
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _ruleType = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          _LabeledTextField(
            label: _ruleType == CommissionRuleTypes.percentage
                ? 'Value (%)'
                : 'Value (₹)',
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _DateFieldButton(
            label: 'Effective from',
            value: _effectiveFrom,
            onTap: widget.isSaving
                ? () {}
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _effectiveFrom,
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _effectiveFrom = picked);
                    }
                  },
          ),
          const SizedBox(height: 12),
          _LabeledTextField(
            label: 'Notes',
            controller: _notesController,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          _reset();
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          _save();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(widget.isSaving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddOverrideDialog extends StatefulWidget {
  const _AddOverrideDialog({
    required this.serviceId,
    required this.staff,
  });

  final int serviceId;
  final List<ProfileTeamMember> staff;

  @override
  State<_AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<_AddOverrideDialog> {
  final Set<int> _selectedStaffIds = <int>{};
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _ruleType = CommissionRuleTypes.percentage;
  DateTime _effectiveFrom = DateTime.now();

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_valueController.text.trim());
    if (_selectedStaffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one staff member')),
      );
      return;
    }
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid override value')),
      );
      return;
    }
    if (_ruleType == CommissionRuleTypes.percentage && parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission must be between 0 and 100')),
      );
      return;
    }

    final overrides = widget.staff
        .where((member) => _selectedStaffIds.contains(member.id))
        .map(
          (member) => StaffCommissionOverride(
            id: '${widget.serviceId}_${member.id}_${DateTime.now().millisecondsSinceEpoch}',
            serviceId: widget.serviceId,
            staffId: member.id,
            staffName: member.name,
            ruleType: _ruleType,
            value: parsed,
            effectiveFrom: _effectiveFrom,
            notes: _notesController.text.trim(),
          ),
        )
        .toList();

    Navigator.pop(context, overrides);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Override'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select staff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.staff.map((member) {
                  final isSelected = _selectedStaffIds.contains(member.id);
                  return FilterChip(
                    label: Text(member.name),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedStaffIds.add(member.id);
                        } else {
                          _selectedStaffIds.remove(member.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _ruleType,
                decoration: const InputDecoration(labelText: 'Rule type'),
                items: const [
                  DropdownMenuItem(
                    value: CommissionRuleTypes.percentage,
                    child: Text('Percentage'),
                  ),
                  DropdownMenuItem(
                    value: CommissionRuleTypes.fixed,
                    child: Text('Fixed'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _ruleType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _LabeledTextField(
                label: 'Value',
                controller: _valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _DateFieldButton(
                label: 'Effective from',
                value: _effectiveFrom,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _effectiveFrom,
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _effectiveFrom = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              _LabeledTextField(
                label: 'Notes',
                controller: _notesController,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Override'),
        ),
      ],
    );
  }
}
