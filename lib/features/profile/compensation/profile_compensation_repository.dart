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
    final payload = <String, dynamic>{
      'salaryType': setup.payrollType,
      'baseSalary': setup.salaryMinor,
      'commissionPercentage': setup.commissionPercent,
      'effectiveFrom': DateFormat('yyyy-MM-dd').format(setup.effectiveDate),
      'effectiveTo': null,
      'notes': setup.salaryConfigId != null && setup.salaryConfigId! > 0
          ? 'Updated from mobile payroll setup'
          : 'Initial salary from mobile payroll setup',
    };
    final response = setup.salaryConfigId != null && setup.salaryConfigId! > 0
        ? await _apiService.updateEmployeeSalaryConfig(
            employeeId: setup.userId,
            salaryId: setup.salaryConfigId!,
            payload: payload,
          )
        : await _apiService.createEmployeeSalaryConfig(
            employeeId: setup.userId,
            payload: payload,
          );
    _requireSuccess(response);

    final responseData = response['data'];
    final responseMap = responseData is Map<String, dynamic>
        ? responseData
        : responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : const <String, dynamic>{};
    final savedSetup = setup.copyWith(
      salaryConfigId: _asInt(
        responseMap['salaryConfigId'] ??
            responseMap['salaryId'] ??
            responseMap['id'],
      ),
    );

    final setups = await loadPayrollSetups(branchId);
    final next = setups.where((item) => item.userId != setup.userId).toList()
      ..add(savedSetup);
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

  Future<BranchAttendanceOverview> loadBranchAttendanceOverview({
    required int branchId,
    required DateTime month,
  }) async {
    final response = await _apiService.getBranchTeamAttendanceHistory(
      branchId: branchId,
      month: month.month,
      year: month.year,
    );
    _requireSuccess(response);
    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    return BranchAttendanceOverview.fromJson(map);
  }

  Future<BranchPaidLeaveConfig> loadBranchPaidLeaveConfig({
    required int branchId,
    String branchName = '',
  }) async {
    final response = await _apiService.getBranchPayrollPaidLeaveConfig(
      branchId: branchId,
    );
    if (response['success'] != true &&
        _looksLikeMissingPaidLeaveConfigResponse(response)) {
      return BranchPaidLeaveConfig(
        branchId: branchId,
        branchName: branchName,
        paidLeaveDays: 0,
      );
    }
    _requireSuccess(response);
    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final config = BranchPaidLeaveConfig.fromJson(map);
    return BranchPaidLeaveConfig(
      branchId: config.branchId == 0 ? branchId : config.branchId,
      branchName: config.branchName.isEmpty ? branchName : config.branchName,
      paidLeaveDays: config.paidLeaveDays,
    );
  }

  Future<void> setBranchPaidLeaveConfig({
    required int branchId,
    required int paidLeaveDays,
  }) async {
    if (paidLeaveDays <= 0) {
      final deleteResponse =
          await _apiService.deleteBranchPayrollPaidLeaveConfig(
        branchId: branchId,
      );
      if (deleteResponse['success'] != true &&
          !_looksLikeMissingPaidLeaveConfigResponse(deleteResponse)) {
        _requireSuccess(deleteResponse);
      }
      return;
    }

    var response = await _apiService.updateBranchPayrollPaidLeaveConfig(
      branchId: branchId,
      payload: <String, dynamic>{'paidLeaveDays': paidLeaveDays},
    );
    if (response['success'] != true &&
        _looksLikeMissingPaidLeaveConfigResponse(response)) {
      response = await _apiService.createBranchPayrollPaidLeaveConfig(
        branchId: branchId,
        payload: <String, dynamic>{'paidLeaveDays': paidLeaveDays},
      );
    }
    _requireSuccess(response);
  }

  Future<PayrollPaidLeavesReview> loadPayrollPaidLeavesReview({
    required int branchId,
    String? payrollId,
    BranchAttendanceOverview? attendanceOverview,
  }) async {
    final response = await _apiService.getPayrollPaidLeavesReview(
      branchId: branchId,
      payrollId: payrollId,
    );
    if (response['success'] != true &&
        _looksLikeMissingPaidLeavesEndpoint(response)) {
      return _buildPayrollPaidLeavesReviewFallback(
        branchId: branchId,
        payrollId: payrollId,
        attendanceOverview: attendanceOverview,
      );
    }
    _requireSuccess(response);
    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    return PayrollPaidLeavesReview.fromJson(map);
  }

  Future<void> setPayrollEmployeePaidLeave({
    required int payrollEmployeeId,
    required int paidLeaveDays,
  }) async {
    var response = await _apiService.setPayrollEmployeePaidLeave(
      payrollEmployeeId: payrollEmployeeId,
      payload: <String, dynamic>{'paidLeaveDays': paidLeaveDays},
    );
    if (response['success'] != true &&
        _looksLikeMissingPaidLeaveWriteEndpoint(response)) {
      response = await _apiService.createPayrollEmployeePaidLeave(
        payrollEmployeeId: payrollEmployeeId,
        payload: <String, dynamic>{'paidLeaveDays': paidLeaveDays},
      );
      if (response['success'] != true &&
          _looksLikeMissingPaidLeaveWriteEndpoint(response)) {
        throw Exception(
          'Paid leave update API is not available on the backend yet.',
        );
      }
    }
    _requireSuccess(response);
  }

  Future<void> deletePayrollEmployeePaidLeave({
    required int payrollEmployeeId,
  }) async {
    final response = await _apiService.deletePayrollEmployeePaidLeave(
      payrollEmployeeId: payrollEmployeeId,
    );
    _requireSuccess(response);
  }

  Future<PayrollPaidLeavesReview> _buildPayrollPaidLeavesReviewFallback({
    required int branchId,
    String? payrollId,
    BranchAttendanceOverview? attendanceOverview,
  }) async {
    if (payrollId == null || payrollId.trim().isEmpty) {
      return const PayrollPaidLeavesReview(
        branchId: 0,
        branchName: '',
        payrollId: null,
        payrollName: '',
        month: 0,
        year: 0,
        periodStart: null,
        periodEnd: null,
        payrollStatus: '',
        totalTeamMembersCount: 0,
        membersWithPayrollSetup: 0,
        totalPaidLeaveDays: 0,
        employees: <PayrollPaidLeaveEmployeeRecord>[],
      );
    }

    final reviewResponse = await _apiService.getPayrollReviewDetails(
      branchId: branchId,
      payrollId: payrollId,
    );
    _requireSuccess(reviewResponse);

    final data = reviewResponse['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final branch = map['branch'] is Map
        ? Map<String, dynamic>.from(map['branch'] as Map)
        : const <String, dynamic>{};
    final payroll = map['payroll'] is Map
        ? Map<String, dynamic>.from(map['payroll'] as Map)
        : const <String, dynamic>{};
    final summary = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'] as Map)
        : const <String, dynamic>{};
    final includedTeamMembers =
        (map['includedTeamMembers'] as List?) ?? const <dynamic>[];
    final attendanceByUserId = <int, BranchAttendanceEmployeeRecord>{
      for (final item in attendanceOverview?.employees ??
          const <BranchAttendanceEmployeeRecord>[])
        item.userId: item,
    };

    final employees = await Future.wait<PayrollPaidLeaveEmployeeRecord>(
      includedTeamMembers.whereType<Map>().map((item) async {
        final employeeMap = Map<String, dynamic>.from(item);
        final payrollEmployeeId = _asInt(employeeMap['payrollEmployeeId']) ?? 0;
        final employeeId = _asInt(
              employeeMap['employeeId'] ??
                  employeeMap['teamMemberId'] ??
                  employeeMap['userId'],
            ) ??
            0;
        final reviewPaidLeaveDays = _asInt(
          employeeMap['paidLeaveDays'] ?? employeeMap['paid_leave_days'],
        );
        final paidLeaveResponse =
            reviewPaidLeaveDays == null && payrollEmployeeId > 0
                ? await _apiService.getPayrollEmployeePaidLeave(
                    payrollEmployeeId: payrollEmployeeId,
                  )
                : const <String, dynamic>{
                    'success': true,
                    'data': <String, dynamic>{'paidLeaveDays': 0},
                  };
        final paidLeaveDays = reviewPaidLeaveDays ??
            (paidLeaveResponse['success'] == true
                ? _extractPaidLeaveDays(paidLeaveResponse)
                : 0);
        final reviewLeaveDays = _asInt(
          employeeMap['leaveDays'] ?? employeeMap['leave_days'],
        );
        final attendanceEmployee = attendanceByUserId[employeeId];
        return PayrollPaidLeaveEmployeeRecord(
          payrollEmployeeId: payrollEmployeeId,
          employeeId: employeeId,
          employeeName: _cleanText(
            employeeMap['employeeName'] ??
                employeeMap['teamMemberName'] ??
                employeeMap['name'],
          ),
          role: _cleanText(employeeMap['role'], fallback: 'Team Member'),
          profileImage: _cleanText(employeeMap['profileImage']).isEmpty
              ? null
              : _cleanText(employeeMap['profileImage']),
          salaryAmount: _asInt(employeeMap['salaryAmount']) ?? 0,
          commissionPercentage:
              _asDouble(employeeMap['commissionPercentage']) ?? 0,
          paidLeaveDays: paidLeaveDays,
          leaveDays: reviewLeaveDays ?? attendanceEmployee?.leaves ?? 0,
          status: _cleanText(employeeMap['status']),
        );
      }),
    );

    final totalPaidLeaveDays = employees.fold<int>(
      0,
      (sum, item) => sum + item.paidLeaveDays,
    );

    return PayrollPaidLeavesReview(
      branchId: _asInt(branch['id']) ?? branchId,
      branchName: _cleanText(branch['name']),
      payrollId: _cleanText(payroll['payrollId']).isEmpty
          ? payrollId
          : _cleanText(payroll['payrollId']),
      payrollName: _cleanText(payroll['payrollName']),
      month: _asInt(payroll['month']) ?? 0,
      year: _asInt(payroll['year']) ?? 0,
      periodStart: DateTime.tryParse(_cleanText(payroll['periodStart'])),
      periodEnd: DateTime.tryParse(_cleanText(payroll['periodEnd'])),
      payrollStatus: _cleanText(payroll['status']),
      totalTeamMembersCount: _asInt(summary['totalTeamMembersCount']) ?? 0,
      membersWithPayrollSetup:
          _asInt(summary['membersWithPayrollSetup']) ?? employees.length,
      totalPaidLeaveDays: totalPaidLeaveDays,
      employees: employees,
    );
  }

  Future<HolidayCalendarOverview> loadHolidayCalendar({
    required int salonId,
    required DateTime month,
  }) async {
    final response = await _apiService.getSalonHolidayCalendar(
      salonId: salonId,
      month: month.month,
      year: month.year,
    );
    _requireSuccess(response);
    final data = response['data'];
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    return HolidayCalendarOverview.fromJson(map);
  }

  Future<void> createHoliday({
    required int salonId,
    required DateTime holidayDate,
    required String title,
    required String description,
  }) async {
    final response = await _apiService.createSalonHoliday(
      salonId: salonId,
      payload: <String, dynamic>{
        'holidayDate': DateFormat('yyyy-MM-dd').format(holidayDate),
        'title': title,
        'description': description,
      },
    );
    _requireSuccess(response);
  }

  Future<void> updateHoliday({
    required int salonId,
    required int holidayId,
    required DateTime holidayDate,
    required String title,
    required String description,
  }) async {
    final response = await _apiService.updateSalonHoliday(
      salonId: salonId,
      holidayId: holidayId,
      payload: <String, dynamic>{
        'holidayDate': DateFormat('yyyy-MM-dd').format(holidayDate),
        'title': title,
        'description': description,
      },
    );
    _requireSuccess(response);
  }

  Future<void> deleteHoliday({
    required int salonId,
    required int holidayId,
  }) async {
    final response = await _apiService.deleteSalonHoliday(
      salonId: salonId,
      holidayId: holidayId,
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
      await _persistPayrollRuns(branchId, const <PayrollRunRecord>[]);
      return const <PayrollRunRecord>[];
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
    final runs = await loadPayrollRuns(
      branchId,
      teamMembers: activeMembers,
      setups: setups,
    );
    if (runs.any((item) => item.periodKey == periodKey)) {
      throw Exception('Payroll already generated for $periodLabel.');
    }

    final response = await _apiService.generatePayroll(
      branchId: branchId,
      month: period.month,
      year: period.year,
    );
    _requireSuccess(response);

    final refreshedRuns = await loadPayrollRuns(
      branchId,
      teamMembers: activeMembers,
      setups: setups,
    );
    final responseData = response['data'];
    final responseMap = responseData is Map<String, dynamic>
        ? responseData
        : responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : const <String, dynamic>{};
    final generatedPayrollId = _asInt(
      responseMap['payrollId'] ?? responseMap['id'],
    )?.toString();

    final generatedRun = refreshedRuns.cast<PayrollRunRecord?>().firstWhere(
          (item) =>
              item?.periodKey == periodKey ||
              (generatedPayrollId != null && item?.id == generatedPayrollId),
          orElse: () => null,
        );
    if (generatedRun == null) {
      throw Exception(
          'Payroll generated for $periodLabel but could not reload it.');
    }
    return generatedRun;
  }

  Future<bool> cancelPayroll({
    required int branchId,
    required String payrollId,
    String? periodKey,
    required List<ProfileTeamMember> teamMembers,
  }) async {
    final setups = await loadPayrollSetups(branchId);
    var response = await _apiService.cancelPayroll(
      branchId: branchId,
      payrollId: payrollId,
    );
    if (response['success'] == false &&
        _cleanText(response['message']).toLowerCase().contains('not found') &&
        _cleanText(periodKey).isNotEmpty) {
      final refreshedRuns = await loadPayrollRuns(
        branchId,
        teamMembers: teamMembers,
        setups: setups,
      );
      final refreshedRun = refreshedRuns.cast<PayrollRunRecord?>().firstWhere(
            (run) => run?.periodKey == periodKey || run?.id == payrollId,
            orElse: () => null,
          );
      if (refreshedRun?.isCancelled == true) {
        debugPrint(
          '[ProfileCompensationRepository] cancelPayroll already_cancelled | '
          'branchId=$branchId payrollId=$payrollId',
        );
        return false;
      }
      if (refreshedRun != null && refreshedRun.id != payrollId) {
        debugPrint(
          '[ProfileCompensationRepository] cancelPayroll retry_with_refreshed_id | '
          'branchId=$branchId stalePayrollId=$payrollId refreshedPayrollId=${refreshedRun.id}',
        );
        response = await _apiService.cancelPayroll(
          branchId: branchId,
          payrollId: refreshedRun.id,
        );
      }
    }
    _requireSuccess(response);
    await loadPayrollRuns(
      branchId,
      teamMembers: teamMembers,
      setups: setups,
    );
    return true;
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
    final response = await _apiService.createPayrollEmployeeAdjustment(
      payrollEmployeeId: payrollEmployeeId,
      payload: <String, dynamic>{
        'type': adjustment.type,
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
    final response = await _apiService.updatePayrollEmployeeAdjustment(
      payrollEmployeeId: adjustment.payrollEmployeeId > 0
          ? adjustment.payrollEmployeeId
          : userId,
      adjustmentId: adjustment.id,
      payload: <String, dynamic>{
        'type': adjustment.type,
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
    final response = await _apiService.deletePayrollEmployeeAdjustment(
      payrollEmployeeId: adjustment.payrollEmployeeId > 0
          ? adjustment.payrollEmployeeId
          : userId,
      adjustmentId: adjustment.id,
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
    final response = await _apiService.getPayrollEmployeeAdjustments(
      payrollEmployeeId: payrollEmployeeId,
    );
    _requireSuccess(response);
    final data = response['data'];
    final rawItems = data is List
        ? data
        : data is Map<String, dynamic>
            ? (data['items'] as List?) ??
                (data['data'] as List?) ??
                (data['rows'] as List?) ??
                (data['results'] as List?) ??
                (data['adjustments'] as List?) ??
                (data.isEmpty ? const <dynamic>[] : <dynamic>[data])
            : const <dynamic>[];
    final adjustments = rawItems
        .whereType<Map>()
        .map(
          (item) => PayrollAdjustmentRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.payrollEmployeeId == 0
            ? true
            : item.payrollEmployeeId == payrollEmployeeId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return adjustments;
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
        'payrollEmployeeId': employeeMap['payrollEmployeeId'] ??
            employeeMap['salaryConfigId'] ??
            employeeMap['salaryId'] ??
            userId,
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

  bool _looksLikeMissingPaidLeavesEndpoint(Map<String, dynamic> response) {
    final message = _cleanText(response['message']).toLowerCase();
    final data = response['data'];
    final nestedMessage =
        data is Map ? _cleanText(data['message']).toLowerCase() : '';
    final statusCode = _asInt(response['statusCode']) ??
        (data is Map ? _asInt(data['statusCode']) : null) ??
        (data is Map ? _asInt(data['status']) : null);
    return statusCode == 404 ||
        message.contains('cannot get') ||
        nestedMessage.contains('cannot get') ||
        message.contains('not found') ||
        nestedMessage.contains('not found');
  }

  bool _looksLikeMissingPaidLeaveConfigResponse(
    Map<String, dynamic> response,
  ) {
    final message = _cleanText(response['message']).toLowerCase();
    final data = response['data'];
    final nestedMessage =
        data is Map ? _cleanText(data['message']).toLowerCase() : '';
    final statusCode = _asInt(response['statusCode']) ??
        (data is Map ? _asInt(data['statusCode']) : null) ??
        (data is Map ? _asInt(data['status']) : null);
    return statusCode == 404 ||
        message.contains('cannot get') ||
        message.contains('cannot patch') ||
        message.contains('cannot post') ||
        message.contains('cannot delete') ||
        nestedMessage.contains('cannot get') ||
        nestedMessage.contains('cannot patch') ||
        nestedMessage.contains('cannot post') ||
        nestedMessage.contains('cannot delete') ||
        message.contains('not found') ||
        nestedMessage.contains('not found');
  }

  bool _looksLikeMissingPaidLeaveWriteEndpoint(Map<String, dynamic> response) {
    final message = _cleanText(response['message']).toLowerCase();
    final data = response['data'];
    final nestedMessage =
        data is Map ? _cleanText(data['message']).toLowerCase() : '';
    final statusCode = _asInt(response['statusCode']) ??
        (data is Map ? _asInt(data['statusCode']) : null) ??
        (data is Map ? _asInt(data['status']) : null);
    return statusCode == 404 ||
        message.contains('cannot patch') ||
        message.contains('cannot post') ||
        nestedMessage.contains('cannot patch') ||
        nestedMessage.contains('cannot post') ||
        message.contains('not found') ||
        nestedMessage.contains('not found');
  }

  int _extractPaidLeaveDays(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return _asInt(
            data['paidLeaveDays'] ??
                data['paid_leave_days'] ??
                data['days'] ??
                data['value'] ??
                (data['paidLeave'] is Map
                    ? (data['paidLeave'] as Map)['paidLeaveDays']
                    : null),
          ) ??
          0;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return _asInt(
            map['paidLeaveDays'] ??
                map['paid_leave_days'] ??
                map['days'] ??
                map['value'],
          ) ??
          0;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      final map = Map<String, dynamic>.from(data.first as Map);
      return _asInt(
            map['paidLeaveDays'] ??
                map['paid_leave_days'] ??
                map['days'] ??
                map['value'],
          ) ??
          0;
    }
    return 0;
  }
}
