import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/stylist_branch_selection.dart';
import '../../../utils/api_service.dart';
import 'profile_compensation_models.dart';

class ProfileCompensationRepository {
  ProfileCompensationRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String _payrollSetupsPrefix = 'profile_payroll_setups_';
  static const String _payrollRunsPrefix = 'profile_payroll_runs_';
  static const String _commissionRulesPrefix = 'profile_commission_rules_';
  static const String _commissionOverridesPrefix =
      'profile_commission_overrides_';

  Future<List<ProfileBranchOption>> loadBranchOptions() async {
    final response = await _apiService.getSalonListApi();
    final rawSalons = (response['data'] as List?) ?? const <dynamic>[];
    final options = <ProfileBranchOption>[];

    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) {
        continue;
      }
      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _asInt(salon['id']);
      if (salonId == null) {
        continue;
      }
      final salonName = _cleanText(salon['name']);
      final branches = (salon['branches'] as List?) ?? const <dynamic>[];
      for (final branchEntry in branches) {
        if (branchEntry is! Map) {
          continue;
        }
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asInt(branch['id']);
        if (branchId == null) {
          continue;
        }
        final addressMap = branch['address'] is Map
            ? Map<String, dynamic>.from(branch['address'] as Map)
            : null;
        options.add(
          ProfileBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _composeAddress(addressMap),
          ),
        );
      }
    }

    return options;
  }

  Future<void> saveBranchSelection(ProfileBranchOption option) {
    return StylistBranchSelectionStore.save(
      salonId: option.salonId,
      branchId: option.branchId,
      salonName: option.salonName,
      branchName: option.branchName,
    );
  }

  Future<List<ProfileTeamMember>> loadTeamMembers(int branchId) async {
    final response = await ApiService.getTeamMembers(branchId);
    final raw = (response['data'] as List?) ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((item) => _teamMemberFromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.id != 0)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<BranchServiceSummary>> loadServices(int branchId) async {
    final response = await _apiService.getService(branchId: branchId);
    final items = <BranchServiceSummary>[];
    final seenIds = <int>{};

    void visit(dynamic node, {String categoryName = ''}) {
      if (node is List) {
        for (final item in node) {
          visit(item, categoryName: categoryName);
        }
        return;
      }

      if (node is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(node);

      if (_looksLikeService(map)) {
        final service = _serviceFromMap(map, categoryName: categoryName);
        if (!seenIds.contains(service.id)) {
          seenIds.add(service.id);
          items.add(service);
        }
      }

      final nextCategoryName = _looksLikeService(map)
          ? categoryName
          : _cleanText(map['displayName']).isNotEmpty
              ? _cleanText(map['displayName'])
              : _cleanText(map['name']);

      for (final key in const <String>[
        'data',
        'categories',
        'subCategories',
        'subcategories',
        'services',
        'items',
      ]) {
        if (map.containsKey(key)) {
          visit(
            map[key],
            categoryName:
                nextCategoryName.isEmpty ? categoryName : nextCategoryName,
          );
        }
      }
    }

    visit(response);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<List<PayrollSetupRecord>> loadPayrollSetups(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readList(
      prefs.getString(_payrollSetupsKey(branchId)),
      (json) => PayrollSetupRecord.fromJson(json),
    );

    final response = await _apiService.getPayrollSetupTeamMembers(
      branchId: branchId,
    );
    if (response['success'] != true) {
      return cached;
    }

    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final teamMembers = (map['teamMembers'] as List?) ?? const <dynamic>[];
    final setups = teamMembers
        .whereType<Map>()
        .map((item) {
          final raw = Map<String, dynamic>.from(item);
          return PayrollSetupRecord(
            userId: _asInt(raw['teamMemberId'] ?? raw['employeeId']) ?? 0,
            userName: _cleanText(raw['teamMemberName'] ?? raw['name']),
            payrollType: PayrollTypes.normalize(
              _cleanText(raw['payrollType']).isEmpty
                  ? PayrollTypes.salaryOnly
                  : _cleanText(raw['payrollType']),
            ),
            salaryMinor: _asInt(raw['salaryAmount']) ?? 0,
            commissionPercent: _asDouble(raw['commissionPercentage']) ?? 0,
            effectiveDate:
                DateTime.tryParse(_cleanText(raw['effectiveFrom'])) ??
                    DateTime.now(),
            salaryConfigId: _asInt(raw['salaryConfigId'] ?? raw['salaryId']),
          );
        })
        .where((item) => item.userId != 0 && item.salaryConfigId != null)
        .toList()
      ..sort((a, b) =>
          a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));

    await prefs.setString(
      _payrollSetupsKey(branchId),
      jsonEncode(setups.map((item) => item.toJson()).toList()),
    );
    return setups;
  }

  Future<void> savePayrollSetup(int branchId, PayrollSetupRecord setup) async {
    final prefs = await SharedPreferences.getInstance();
    if (setup.salaryConfigId != null && setup.salaryConfigId! > 0) {
      final response = await _apiService.updateEmployeeSalaryConfig(
        employeeId: setup.userId,
        salaryId: setup.salaryConfigId!,
        payload: <String, dynamic>{
          'salaryType': setup.payrollType,
          'baseSalary': setup.salaryMinor,
          'commissionPercentage': setup.commissionPercent,
          'effectiveFrom': DateFormat('yyyy-MM-dd').format(setup.effectiveDate),
          'effectiveTo': null,
          'notes': 'Updated from mobile payroll setup',
        },
      );
      _requireSuccess(response);
    }

    final setups = await loadPayrollSetups(branchId);
    final next = setups.where((item) => item.userId != setup.userId).toList()
      ..add(setup);
    next.sort(
      (a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()),
    );
    await prefs.setString(
      _payrollSetupsKey(branchId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<PayrollAdvanceRecord>> loadBranchAdvances({
    required int branchId,
    required DateTime month,
    required List<ProfileTeamMember> teamMembers,
  }) async {
    final response = await _apiService.getBranchAdvances(
      branchId: branchId,
      month: month.month,
      year: month.year,
    );
    _requireSuccess(response);

    final data = response['data'];
    final rawItems = <Map<String, dynamic>>[];

    void collectItems(dynamic node, {Map<String, dynamic>? employeeContext}) {
      if (node is List) {
        for (final item in node) {
          collectItems(item, employeeContext: employeeContext);
        }
        return;
      }

      if (node is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(node);

      if (map['advances'] is List) {
        final employeeMap = <String, dynamic>{
          ...map,
          if (employeeContext != null) ...employeeContext,
        };
        collectItems(
          map['advances'],
          employeeContext: employeeMap,
        );
        return;
      }

      if (_asInt(map['id']) != null &&
          (_asInt(map['employeeId']) != null ||
              _asInt(map['teamMemberId']) != null) &&
          (_asInt(map['amount']) != null ||
              _asInt(map['remainingAmount']) != null)) {
        final inheritedEmployeeName = _cleanText(
          employeeContext?['employeeName'] ??
              employeeContext?['teamMemberName'],
        );
        final nestedEmployeeName =
            '${_cleanText(map['employee']?['firstName'])} ${_cleanText(map['employee']?['lastName'])}'
                .trim();
        final directEmployeeName =
            _cleanText(map['employeeName'] ?? map['teamMemberName']);
        final resolvedEmployeeName = directEmployeeName.isNotEmpty
            ? directEmployeeName
            : inheritedEmployeeName.isNotEmpty
                ? inheritedEmployeeName
                : nestedEmployeeName;

        rawItems.add(<String, dynamic>{
          ...map,
          if (employeeContext != null) ...employeeContext,
          'employeeName': resolvedEmployeeName,
        });
        return;
      }

      if (map['employees'] is List) {
        collectItems(map['employees']);
        return;
      }

      for (final key in const <String>[
        'items',
        'rows',
        'data',
        'results',
      ]) {
        if (map[key] != null) {
          collectItems(map[key], employeeContext: employeeContext);
        }
      }
    }

    collectItems(data);

    final memberNameById = <int, String>{
      for (final member in teamMembers) member.id: member.name,
    };

    return rawItems
        .map((raw) {
          final employeeId =
              _asInt(raw['employeeId'] ?? raw['teamMemberId']) ?? 0;
          return PayrollAdvanceRecord.fromJson(<String, dynamic>{
            ...raw,
            if (_cleanText(raw['employeeName']).isEmpty &&
                _cleanText(raw['teamMemberName']).isEmpty)
              'employeeName': memberNameById[employeeId] ?? '',
          });
        })
        .where((item) => item.id != 0)
        .toList()
      ..sort((a, b) => b.givenDate.compareTo(a.givenDate));
  }

  Future<void> createAdvance({
    required int branchId,
    required PayrollAdvanceRecord advance,
  }) async {
    final response = await _apiService.createEmployeeAdvance(
      branchId: branchId,
      employeeId: advance.employeeId,
      payload: <String, dynamic>{
        'amount': advance.amount,
        'givenDate': DateFormat('yyyy-MM-dd').format(advance.givenDate),
        'paymentMode': advance.paymentMode,
        'paymentReference': advance.paymentReference,
        'remarks': advance.remarks.isEmpty ? null : advance.remarks,
      },
    );
    _requireSuccess(response);
  }

  Future<List<PayrollRunRecord>> loadPayrollRuns(
    int branchId, {
    List<ProfileTeamMember> teamMembers = const <ProfileTeamMember>[],
    List<PayrollSetupRecord> setups = const <PayrollSetupRecord>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localRuns = _readList(
      prefs.getString(_payrollRunsKey(branchId)),
      (json) => PayrollRunRecord.fromJson(json),
    );
    localRuns.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

    final dashboardResponse = await _apiService.getBranchDashboard(
      branchId: branchId,
    );
    if (dashboardResponse['success'] != true) {
      debugPrint(
        '[ProfileCompensationRepository] loadPayrollRuns dashboard_failed | '
        'branchId=$branchId message=${dashboardResponse['message']}',
      );
      return localRuns;
    }

    final data = dashboardResponse['data'];
    final dashboardMap = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final completedMonths =
        (dashboardMap['completedMonths'] as List?) ?? const <dynamic>[];
    if (completedMonths.isEmpty) {
      return localRuns;
    }

    final setupByUser = <int, PayrollSetupRecord>{
      for (final item in setups) item.userId: item,
    };
    final activeMembers = teamMembers.where((item) => item.isActive).toList();

    final mergedRuns = completedMonths.whereType<Map>().map((entry) {
      final raw = Map<String, dynamic>.from(entry);
      final periodStart =
          DateTime.tryParse(_cleanText(raw['periodStart'])) ?? DateTime.now();
      final payrollId = _asInt(raw['payrollId']);
      final periodKey = DateFormat('yyyy-MM').format(periodStart);
      final localMatch = localRuns.cast<PayrollRunRecord?>().firstWhere(
            (item) =>
                item?.periodKey == periodKey ||
                (payrollId != null && item?.id == '$payrollId'),
            orElse: () => null,
          );
      return _dashboardPayrollRunFromMap(
        raw,
        localMatch: localMatch,
        activeMembers: activeMembers,
        setupByUser: setupByUser,
      );
    }).toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

    debugPrint(
      '[ProfileCompensationRepository] loadPayrollRuns dashboard_success | '
      'branchId=$branchId dashboardRuns=${mergedRuns.length} '
      'localRuns=${localRuns.length}',
    );
    await _persistPayrollRuns(branchId, mergedRuns);
    return mergedRuns;
  }

  Future<PayrollRunRecord> generatePayroll({
    required int branchId,
    required DateTime period,
    required List<ProfileTeamMember> teamMembers,
  }) async {
    final activeMembers = teamMembers.where((item) => item.isActive).toList();
    if (activeMembers.isEmpty) {
      throw Exception('No active team members available for payroll.');
    }

    final setups = await loadPayrollSetups(branchId);
    final setupByUser = <int, PayrollSetupRecord>{
      for (final item in setups) item.userId: item,
    };

    final missingMembers = activeMembers
        .where((item) => !setupByUser.containsKey(item.id))
        .map((item) => item.name)
        .toList();
    if (missingMembers.isNotEmpty) {
      throw Exception('Complete payroll setup for all active team members.');
    }

    final periodKey = DateFormat('yyyy-MM').format(period);
    final periodLabel = DateFormat('MMMM yyyy').format(period);
    final runs = await loadPayrollRuns(branchId);
    if (runs.any((item) => item.periodKey == periodKey)) {
      throw Exception('Payroll already generated for $periodLabel.');
    }

    final employees = activeMembers.map((member) {
      final setup = setupByUser[member.id]!;
      return PayrollRunEmployeeRecord(
        userId: member.id,
        payrollEmployeeId: member.id,
        userName: member.name,
        role: member.role.isEmpty ? 'Team Member' : member.role,
        payrollType: setup.payrollType,
        salaryMinor: setup.payrollType == PayrollTypes.commissionOnly
            ? 0
            : setup.salaryMinor,
        commissionPercent: setup.commissionPercent,
        commissionAmountMinor: 0,
        effectiveDate: setup.effectiveDate,
        adjustments: const <PayrollAdjustmentRecord>[],
      );
    }).toList();

    final run = PayrollRunRecord(
      id: '${periodKey}_${DateTime.now().millisecondsSinceEpoch}',
      periodKey: periodKey,
      periodLabel: periodLabel,
      generatedAt: DateTime.now(),
      employees: employees,
    );

    final next = <PayrollRunRecord>[run, ...runs];
    await _persistPayrollRuns(branchId, next);
    return run;
  }

  Future<PayrollRunRecord> approvePayroll({
    required int branchId,
    required String runId,
  }) async {
    final runs = await loadPayrollRuns(branchId);
    final updated = runs.map((run) {
      if (run.id != runId) {
        return run;
      }
      return run.copyWith(approvedAt: DateTime.now());
    }).toList();
    await _persistPayrollRuns(branchId, updated);
    return updated.firstWhere((item) => item.id == runId);
  }

  Future<PayrollRunRecord> recordPayrollPayment({
    required int branchId,
    required String runId,
    required PaymentRecord payment,
  }) async {
    final runs = await loadPayrollRuns(branchId);
    final updated = runs.map((run) {
      if (run.id != runId) {
        return run;
      }
      final employees = run.employees.map((employee) {
        return employee.payment == null
            ? employee.copyWith(payment: payment)
            : employee;
      }).toList();
      return run.copyWith(
        approvedAt: run.approvedAt ?? DateTime.now(),
        employees: employees,
        payment: payment,
      );
    }).toList();
    await _persistPayrollRuns(branchId, updated);
    return updated.firstWhere((item) => item.id == runId);
  }

  Future<PayrollRunRecord> addEmployeeAdjustment({
    required int branchId,
    required String runId,
    required int userId,
    required PayrollAdjustmentRecord adjustment,
  }) async {
    final payrollEmployeeId = adjustment.payrollEmployeeId > 0
        ? adjustment.payrollEmployeeId
        : userId;
    final response = adjustment.type == AdjustmentTypes.deduction
        ? await _apiService.createPayrollDeduction(
            payload: <String, dynamic>{
              'payrollEmployeeId': payrollEmployeeId,
              'amount': adjustment.amountMinor,
              'remarks': adjustment.remarks,
            },
          )
        : await _apiService.createPayrollAdditionalCharge(
            payload: <String, dynamic>{
              'payrollEmployeeId': payrollEmployeeId,
              'amount': adjustment.amountMinor,
              'remarks': adjustment.remarks,
            },
          );
    _requireSuccess(response);
    return refreshEmployeeAdjustments(
      branchId: branchId,
      runId: runId,
      userId: userId,
      payrollEmployeeId: payrollEmployeeId,
    );
  }

  Future<PayrollRunRecord> updateEmployeeAdjustment({
    required int branchId,
    required String runId,
    required int userId,
    required PayrollAdjustmentRecord adjustment,
  }) async {
    final response = adjustment.type == AdjustmentTypes.deduction
        ? await _apiService.updatePayrollDeduction(
            deductionId: adjustment.id,
            payload: <String, dynamic>{
              'amount': adjustment.amountMinor,
              'remarks': adjustment.remarks,
            },
          )
        : await _apiService.updatePayrollAdditionalCharge(
            chargeId: adjustment.id,
            payload: <String, dynamic>{
              'amount': adjustment.amountMinor,
              'remarks': adjustment.remarks,
            },
          );
    _requireSuccess(response);
    return refreshEmployeeAdjustments(
      branchId: branchId,
      runId: runId,
      userId: userId,
      payrollEmployeeId: adjustment.payrollEmployeeId > 0
          ? adjustment.payrollEmployeeId
          : userId,
    );
  }

  Future<PayrollRunRecord> deleteEmployeeAdjustment({
    required int branchId,
    required String runId,
    required int userId,
    required PayrollAdjustmentRecord adjustment,
  }) async {
    final response = adjustment.type == AdjustmentTypes.deduction
        ? await _apiService.deletePayrollDeduction(deductionId: adjustment.id)
        : await _apiService.deletePayrollAdditionalCharge(
            chargeId: adjustment.id,
          );
    _requireSuccess(response);
    return refreshEmployeeAdjustments(
      branchId: branchId,
      runId: runId,
      userId: userId,
      payrollEmployeeId: adjustment.payrollEmployeeId > 0
          ? adjustment.payrollEmployeeId
          : userId,
    );
  }

  Future<List<PayrollAdjustmentRecord>> loadEmployeeAdjustments({
    required int userId,
    required int payrollEmployeeId,
  }) async {
    final responses = await Future.wait<Map<String, dynamic>>([
      _apiService.getPayrollAdditionalCharges(),
      _apiService.getPayrollDeductions(),
    ]);
    final additions = _extractPayrollAdjustments(
      responses[0],
      type: AdjustmentTypes.addition,
      userId: userId,
      payrollEmployeeId: payrollEmployeeId,
    );
    final deductions = _extractPayrollAdjustments(
      responses[1],
      type: AdjustmentTypes.deduction,
      userId: userId,
      payrollEmployeeId: payrollEmployeeId,
    );
    final all = <PayrollAdjustmentRecord>[
      ...additions,
      ...deductions,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<PayrollRunRecord> refreshEmployeeAdjustments({
    required int branchId,
    required String runId,
    required int userId,
    required int payrollEmployeeId,
  }) async {
    final adjustments = await loadEmployeeAdjustments(
      userId: userId,
      payrollEmployeeId: payrollEmployeeId,
    );
    final resolvedPayrollEmployeeId = adjustments.isNotEmpty
        ? adjustments.first.payrollEmployeeId
        : payrollEmployeeId;
    final runs = await loadPayrollRuns(branchId);
    final updated = runs.map((run) {
      if (run.id != runId) {
        return run;
      }
      final employees = run.employees.map((employee) {
        if (employee.userId != userId) {
          return employee;
        }
        return employee.copyWith(
          payrollEmployeeId: resolvedPayrollEmployeeId,
          adjustments: adjustments,
        );
      }).toList();
      return run.copyWith(employees: employees);
    }).toList();
    await _persistPayrollRuns(branchId, updated);
    return updated.firstWhere((item) => item.id == runId);
  }

  Future<PayrollRunRecord> recordEmployeePayment({
    required int branchId,
    required String runId,
    required int userId,
    required PaymentRecord payment,
  }) async {
    final runs = await loadPayrollRuns(branchId);
    final updated = runs.map((run) {
      if (run.id != runId) {
        return run;
      }
      final employees = run.employees.map((employee) {
        if (employee.userId != userId) {
          return employee;
        }
        return employee.copyWith(payment: payment);
      }).toList();
      return run.copyWith(
        approvedAt: run.approvedAt ?? DateTime.now(),
        employees: employees,
      );
    }).toList();
    await _persistPayrollRuns(branchId, updated);
    return updated.firstWhere((item) => item.id == runId);
  }

  Future<List<CommissionServiceRule>> loadCommissionRules(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readList(
      prefs.getString(_commissionRulesKey(branchId)),
      (json) => CommissionServiceRule.fromJson(json),
    );
  }

  Future<List<StaffCommissionOverride>> loadCommissionOverrides(
    int branchId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return _readList(
      prefs.getString(_commissionOverridesKey(branchId)),
      (json) => StaffCommissionOverride.fromJson(json),
    );
  }

  Future<void> saveCommissionRule({
    required int branchId,
    required BranchServiceSummary service,
    required CommissionServiceRule rule,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rules = await loadCommissionRules(branchId);
    final next = rules
        .where((item) => item.serviceId != rule.serviceId)
        .toList()
      ..add(rule);
    await prefs.setString(
      _commissionRulesKey(branchId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );

    try {
      await _apiService.updateService(
        branchId: branchId,
        branchServiceId: service.id,
        body: <String, dynamic>{
          'displayName': service.name,
          'description': service.description,
          'durationMin': service.durationMin,
          'priceType': service.priceType,
          'priceMinor': service.priceMinor,
          'isActive': service.isActive,
          'commissionEnabled': rule.active,
          'commissionType': rule.active ? rule.ruleType : null,
          'commissionPercentage':
              rule.active && rule.ruleType == CommissionRuleTypes.percentage
                  ? rule.value
                  : null,
          'commissionFixedAmountMinor':
              rule.active && rule.ruleType == CommissionRuleTypes.fixed
                  ? rule.value.round()
                  : null,
          'commissionMaxAmountMinor': null,
        },
      );
    } catch (_) {
      // Keep the local source of truth available for the profile module.
    }
  }

  Future<void> saveStaffOverrides({
    required int branchId,
    required int serviceId,
    required List<StaffCommissionOverride> overrides,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCommissionOverrides(branchId);
    final retained =
        existing.where((item) => item.serviceId != serviceId).toList();
    final next = <StaffCommissionOverride>[...retained, ...overrides];
    await prefs.setString(
      _commissionOverridesKey(branchId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteStaffOverride({
    required int branchId,
    required String overrideId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCommissionOverrides(branchId);
    final next = existing.where((item) => item.id != overrideId).toList();
    await prefs.setString(
      _commissionOverridesKey(branchId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  CommissionServiceRule ruleForService({
    required BranchServiceSummary service,
    required List<CommissionServiceRule> storedRules,
  }) {
    final stored = storedRules.where((item) => item.serviceId == service.id);
    if (stored.isNotEmpty) {
      return stored.first;
    }

    final isPercentage =
        service.commissionType == CommissionRuleTypes.percentage;
    return CommissionServiceRule(
      serviceId: service.id,
      ruleType: isPercentage
          ? CommissionRuleTypes.percentage
          : CommissionRuleTypes.fixed,
      value: isPercentage
          ? (service.commissionPercentage ?? 0)
          : (service.commissionFixedAmountMinor ?? 0).toDouble(),
      effectiveFrom: DateTime.now(),
      active: service.commissionEnabled,
      notes: '',
    );
  }

  Future<void> _persistPayrollRuns(
    int branchId,
    List<PayrollRunRecord> runs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _payrollRunsKey(branchId),
      jsonEncode(runs.map((item) => item.toJson()).toList()),
    );
  }

  PayrollRunRecord _dashboardPayrollRunFromMap(
    Map<String, dynamic> raw, {
    required PayrollRunRecord? localMatch,
    required List<ProfileTeamMember> activeMembers,
    required Map<int, PayrollSetupRecord> setupByUser,
  }) {
    final periodStart =
        DateTime.tryParse(_cleanText(raw['periodStart'])) ?? DateTime.now();
    final periodEnd = DateTime.tryParse(_cleanText(raw['periodEnd']));
    final generatedAt = DateTime.tryParse(
          _cleanText(
            raw['generatedAt'] ?? raw['reviewedAt'] ?? raw['runDate'],
          ),
        ) ??
        periodEnd ??
        periodStart;
    final paidAt = DateTime.tryParse(_cleanText(raw['paidAt']));
    final reviewedAt = DateTime.tryParse(_cleanText(raw['reviewedAt']));
    final backendStatus = _cleanText(raw['status']);
    final payrollId = _asInt(raw['payrollId']);
    final periodKey = DateFormat('yyyy-MM').format(periodStart);
    final employees = localMatch?.employees.isNotEmpty == true
        ? localMatch!.employees
        : _buildDashboardRunEmployees(
            activeMembers: activeMembers,
            setupByUser: setupByUser,
            effectiveDate: periodStart,
            paidAt: paidAt,
          );

    return PayrollRunRecord(
      id: payrollId != null ? '$payrollId' : periodKey,
      periodKey: periodKey,
      periodLabel: _cleanText(raw['payrollName']).isNotEmpty
          ? _cleanText(raw['payrollName'])
          : periodEnd != null
              ? '${DateFormat('d MMM yyyy').format(periodStart)} - ${DateFormat('d MMM yyyy').format(periodEnd)}'
              : DateFormat('MMMM yyyy').format(periodStart),
      generatedAt: generatedAt,
      approvedAt: reviewedAt ??
          (backendStatus.toLowerCase() == 'reviewed' ||
                  backendStatus.toLowerCase() == 'paid'
              ? generatedAt
              : localMatch?.approvedAt),
      payment: paidAt != null
          ? PaymentRecord(
              mode: '',
              reference: '',
              paidDate: paidAt,
              notes: _cleanText(raw['noteDescription']),
            )
          : localMatch?.payment,
      employees: employees,
      backendStatus: backendStatus,
      summaryNetPayableMinor:
          _asInt(raw['netPayableMinor'] ?? raw['estimatedPayableMinor']),
      summaryPaidMinor: _asInt(raw['totalPaidMinor']),
      summaryOutstandingMinor: _asInt(raw['outstandingMinor']),
      summaryEmployeeCount: _asInt(raw['employeeCount']),
      noteTitle: _cleanText(raw['noteTitle']),
      noteDescription: _cleanText(raw['noteDescription']),
    );
  }

  List<PayrollRunEmployeeRecord> _buildDashboardRunEmployees({
    required List<ProfileTeamMember> activeMembers,
    required Map<int, PayrollSetupRecord> setupByUser,
    required DateTime effectiveDate,
    required DateTime? paidAt,
  }) {
    return activeMembers.map((member) {
      final setup = setupByUser[member.id];
      final payrollType = setup?.payrollType ?? PayrollTypes.salaryOnly;
      return PayrollRunEmployeeRecord(
        userId: member.id,
        payrollEmployeeId: member.id,
        userName: member.name,
        role: member.role.isEmpty ? 'Team Member' : member.role,
        payrollType: payrollType,
        salaryMinor: payrollType == PayrollTypes.commissionOnly
            ? 0
            : (setup?.salaryMinor ?? 0),
        commissionPercent: setup?.commissionPercent ?? 0,
        commissionAmountMinor: 0,
        effectiveDate: setup?.effectiveDate ?? effectiveDate,
        adjustments: const <PayrollAdjustmentRecord>[],
        payment: paidAt == null
            ? null
            : PaymentRecord(
                mode: '',
                reference: '',
                paidDate: paidAt,
                notes: '',
              ),
      );
    }).toList();
  }

  Future<PayrollRunRecord> fetchPayrollReviewDetails({
    required int branchId,
    required String payrollId,
    required PayrollRunRecord fallbackRun,
  }) async {
    final response = await _apiService.getPayrollReviewDetails(
      branchId: branchId,
      payrollId: payrollId,
    );
    _requireSuccess(response);
    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final payroll = map['payroll'] is Map
        ? Map<String, dynamic>.from(map['payroll'] as Map)
        : const <String, dynamic>{};
    final summary = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'] as Map)
        : const <String, dynamic>{};
    final includedTeamMembers =
        (map['includedTeamMembers'] as List?) ?? const <dynamic>[];

    final employees = includedTeamMembers.whereType<Map>().map((item) {
      final employeeMap = Map<String, dynamic>.from(item);
      final userId =
          _asInt(employeeMap['teamMemberId'] ?? employeeMap['userId']) ?? 0;
      final localEmployee =
          fallbackRun.employees.cast<PayrollRunEmployeeRecord?>().firstWhere(
                (employee) => employee?.userId == userId,
                orElse: () => null,
              );
      return PayrollRunEmployeeRecord.fromJson(<String, dynamic>{
        'userId': userId,
        'payrollEmployeeId':
            employeeMap['salaryConfigId'] ?? employeeMap['salaryId'] ?? userId,
        'teamMemberName': employeeMap['teamMemberName'],
        'name': employeeMap['name'],
        'role': employeeMap['role'] ?? localEmployee?.role ?? 'Team Member',
        'payrollType': employeeMap['payrollType'] ?? localEmployee?.payrollType,
        'salaryAmount':
            employeeMap['salaryAmount'] ?? localEmployee?.salaryMinor,
        'commissionPercentage': employeeMap['commissionPercentage'] ??
            localEmployee?.commissionPercent,
        'commissionAmount': employeeMap['commissionAmount'] ??
            localEmployee?.commissionAmountMinor,
        'grossPay': employeeMap['grossPay'],
        'additionsAmount': employeeMap['additionsAmount'],
        'deductionsAmount': employeeMap['deductionsAmount'],
        'advanceAmount': employeeMap['advanceAmount'],
        'effectiveFrom':
            employeeMap['effectiveFrom'] ?? localEmployee?.effectiveDate,
        'netPayable': employeeMap['netPayable'],
        'status': employeeMap['status'],
        'payment': localEmployee?.payment?.toJson(),
        'adjustments':
            localEmployee?.adjustments.map((e) => e.toJson()).toList() ??
                const <dynamic>[],
      });
    }).toList();

    final reviewRun = fallbackRun.copyWith(
      id: _asInt(payroll['payrollId'])?.toString() ?? fallbackRun.id,
      periodLabel: _cleanText(payroll['payrollName']).isNotEmpty
          ? _cleanText(payroll['payrollName'])
          : fallbackRun.periodLabel,
      generatedAt: DateTime.tryParse(_cleanText(payroll['generatedAt'])) ??
          fallbackRun.generatedAt,
      approvedAt: DateTime.tryParse(_cleanText(payroll['reviewedAt'])) ??
          fallbackRun.approvedAt,
      payment: DateTime.tryParse(_cleanText(payroll['paidAt'])) == null
          ? fallbackRun.payment
          : PaymentRecord(
              mode: '',
              reference: '',
              paidDate: DateTime.parse(_cleanText(payroll['paidAt'])),
              notes: '',
            ),
      employees: employees,
      backendStatus: _cleanText(payroll['status']),
      summaryEmployeeCount: _asInt(summary['includedTeamMembersCount']) ??
          _asInt(summary['totalTeamMembersCount']) ??
          employees.length,
      summaryNetPayableMinor: _asInt(summary['totalSalary']),
      summaryPaidMinor: employees
          .where((employee) => employee.statusLabel.toLowerCase() == 'paid')
          .fold<int>(0, (sum, employee) => sum + employee.netPayableMinor),
      summaryOutstandingMinor: employees
          .where((employee) => employee.statusLabel.toLowerCase() != 'paid')
          .fold<int>(0, (sum, employee) => sum + employee.netPayableMinor),
    );

    debugPrint(
      '[ProfileCompensationRepository] fetchPayrollReviewDetails success | '
      'branchId=$branchId payrollId=$payrollId employees=${employees.length}',
    );
    return reviewRun;
  }

  List<PayrollAdjustmentRecord> _extractPayrollAdjustments(
    Map<String, dynamic> response, {
    required String type,
    required int userId,
    required int payrollEmployeeId,
  }) {
    _requireSuccess(response);
    final data = response['data'];
    final rawItems = data is List
        ? data
        : data is Map<String, dynamic>
            ? (data['items'] as List?) ??
                (data['data'] as List?) ??
                (data['rows'] as List?) ??
                (data['results'] as List?) ??
                (data.isEmpty ? const <dynamic>[] : <dynamic>[data])
            : const <dynamic>[];
    return rawItems
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final itemPayrollEmployeeId =
              _asInt(map['payrollEmployeeId'] ?? map['payroll_employee_id']) ??
                  0;
          final itemEmployeeId = _asInt(
                  map['employeeId'] ?? map['employee_id'] ?? map['userId']) ??
              0;
          if (itemPayrollEmployeeId != payrollEmployeeId &&
              itemEmployeeId != userId) {
            return null;
          }
          return PayrollAdjustmentRecord.fromJson(<String, dynamic>{
            ...map,
            'type': type,
          });
        })
        .whereType<PayrollAdjustmentRecord>()
        .toList();
  }

  void _requireSuccess(Map<String, dynamic> response) {
    if (response['success'] == false) {
      throw Exception(
        _cleanText(response['message']).isNotEmpty
            ? _cleanText(response['message'])
            : 'Request failed',
      );
    }
  }

  List<T> _readList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <T>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <T>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _payrollSetupsKey(int branchId) => '$_payrollSetupsPrefix$branchId';

  String _payrollRunsKey(int branchId) => '$_payrollRunsPrefix$branchId';

  String _commissionRulesKey(int branchId) =>
      '$_commissionRulesPrefix$branchId';

  String _commissionOverridesKey(int branchId) =>
      '$_commissionOverridesPrefix$branchId';

  ProfileTeamMember _teamMemberFromMap(Map<String, dynamic> map) {
    final user = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'] as Map)
        : const <String, dynamic>{};
    final id =
        _asInt(map['id']) ?? _asInt(map['userId']) ?? _asInt(user['id']) ?? 0;
    final firstName = _cleanText(map['firstName']).isNotEmpty
        ? _cleanText(map['firstName'])
        : _cleanText(user['firstName']);
    final lastName = _cleanText(map['lastName']).isNotEmpty
        ? _cleanText(map['lastName'])
        : _cleanText(user['lastName']);
    final explicitName = _cleanText(map['name']).isNotEmpty
        ? _cleanText(map['name'])
        : _cleanText(user['name']);
    final fullName =
        explicitName.isNotEmpty ? explicitName : '$firstName $lastName'.trim();

    return ProfileTeamMember(
      id: id,
      name: fullName.isEmpty ? 'Team Member #$id' : fullName,
      role: _cleanText(map['role']).isNotEmpty
          ? _cleanText(map['role'])
          : _cleanText(user['role']),
      phoneNumber: _cleanText(
        map['phoneNumber'] ??
            map['fullPhoneNumber'] ??
            user['phoneNumber'] ??
            user['fullPhoneNumber'],
      ),
      isActive: _asBool(map['active'], fallback: true),
    );
  }

  bool _looksLikeService(Map<String, dynamic> map) {
    final hasName = _cleanText(map['displayName']).isNotEmpty ||
        _cleanText(map['name']).isNotEmpty;
    final hasPricingField =
        map.containsKey('priceMinor') || map.containsKey('durationMin');
    return hasName && hasPricingField;
  }

  BranchServiceSummary _serviceFromMap(
    Map<String, dynamic> map, {
    required String categoryName,
  }) {
    return BranchServiceSummary(
      id: _asInt(map['id']) ?? 0,
      name: _cleanText(map['displayName']).isNotEmpty
          ? _cleanText(map['displayName'])
          : _cleanText(map['name']),
      categoryName: categoryName,
      description: _cleanText(map['description']),
      durationMin: _asInt(map['durationMin']) ?? 0,
      priceMinor: _asInt(map['priceMinor']) ?? 0,
      priceType: _cleanText(map['priceType'], fallback: 'fixed'),
      isActive: _asBool(map['isActive'], fallback: true),
      commissionEnabled: _asBool(map['commissionEnabled'], fallback: false),
      commissionType: _cleanText(map['commissionType']).isEmpty
          ? null
          : _cleanText(map['commissionType']),
      commissionPercentage: _asDouble(map['commissionPercentage']),
      commissionFixedAmountMinor: _asInt(map['commissionFixedAmountMinor']),
      commissionMaxAmountMinor: _asInt(map['commissionMaxAmountMinor']),
    );
  }

  String _composeAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) {
      return '';
    }
    final parts = <String>[];
    for (final key in const <String>[
      'line1',
      'line2',
      'village',
      'district',
      'city',
      'state',
      'country',
      'postalCode',
    ]) {
      final text = _cleanText(address[key]);
      if (text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    return parts.join(', ');
  }

  String _cleanText(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(_cleanText(value));
  }

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(_cleanText(value));
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    final text = _cleanText(value).toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
    return fallback;
  }
}
