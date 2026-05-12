import 'dart:convert';

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
    return _readList(
      prefs.getString(_payrollSetupsKey(branchId)),
      (json) => PayrollSetupRecord.fromJson(json),
    );
  }

  Future<void> savePayrollSetup(int branchId, PayrollSetupRecord setup) async {
    final prefs = await SharedPreferences.getInstance();
    final setups = await loadPayrollSetups(branchId);
    final next = setups.where((item) => item.userId != setup.userId).toList()
      ..add(setup);
    next.sort(
        (a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));
    await prefs.setString(
      _payrollSetupsKey(branchId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<PayrollRunRecord>> loadPayrollRuns(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final runs = _readList(
      prefs.getString(_payrollRunsKey(branchId)),
      (json) => PayrollRunRecord.fromJson(json),
    );
    runs.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return runs;
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
        userName: member.name,
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
    final runs = await loadPayrollRuns(branchId);
    final updated = runs.map((run) {
      if (run.id != runId) {
        return run;
      }
      final employees = run.employees.map((employee) {
        if (employee.userId != userId) {
          return employee;
        }
        final adjustments = <PayrollAdjustmentRecord>[
          ...employee.adjustments,
          adjustment,
        ];
        return employee.copyWith(adjustments: adjustments);
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
