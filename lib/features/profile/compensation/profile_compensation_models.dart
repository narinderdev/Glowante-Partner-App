import 'package:flutter/foundation.dart';

class PayrollTypes {
  static const String salaryCommission = 'salary_commission';
  static const String salaryOnly = 'salary_only';
  static const String commissionOnly = 'commission_only';

  static const List<String> values = <String>[
    salaryCommission,
    salaryOnly,
    commissionOnly,
  ];

  static String label(String value) {
    switch (value) {
      case salaryCommission:
        return 'Salary + Commission';
      case salaryOnly:
        return 'Salary Only';
      case commissionOnly:
        return 'Commission Only';
      default:
        return 'Salary Only';
    }
  }
}

class CommissionRuleTypes {
  static const String percentage = 'percentage';
  static const String fixed = 'fixed';
}

class AdjustmentTypes {
  static const String addition = 'ADDITION';
  static const String deduction = 'DEDUCTION';
}

class ProfileBranchOption {
  const ProfileBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get label => branchName.trim().isEmpty ? salonName : branchName;

  String get subtitle {
    if (salonName.trim().isEmpty) {
      return address;
    }
    if (address.trim().isEmpty) {
      return salonName;
    }
    return '$salonName • $address';
  }
}

class ProfileTeamMember {
  const ProfileTeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    required this.isActive,
  });

  final int id;
  final String name;
  final String role;
  final String phoneNumber;
  final bool isActive;
}

class BranchServiceSummary {
  const BranchServiceSummary({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.description,
    required this.durationMin,
    required this.priceMinor,
    required this.priceType,
    required this.isActive,
    required this.commissionEnabled,
    required this.commissionType,
    required this.commissionPercentage,
    required this.commissionFixedAmountMinor,
    required this.commissionMaxAmountMinor,
  });

  final int id;
  final String name;
  final String categoryName;
  final String description;
  final int durationMin;
  final int priceMinor;
  final String priceType;
  final bool isActive;
  final bool commissionEnabled;
  final String? commissionType;
  final double? commissionPercentage;
  final int? commissionFixedAmountMinor;
  final int? commissionMaxAmountMinor;
}

@immutable
class PayrollSetupRecord {
  const PayrollSetupRecord({
    required this.userId,
    required this.userName,
    required this.payrollType,
    required this.salaryMinor,
    required this.commissionPercent,
    required this.effectiveDate,
  });

  final int userId;
  final String userName;
  final String payrollType;
  final int salaryMinor;
  final double commissionPercent;
  final DateTime effectiveDate;

  PayrollSetupRecord copyWith({
    int? userId,
    String? userName,
    String? payrollType,
    int? salaryMinor,
    double? commissionPercent,
    DateTime? effectiveDate,
  }) {
    return PayrollSetupRecord(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      payrollType: payrollType ?? this.payrollType,
      salaryMinor: salaryMinor ?? this.salaryMinor,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      effectiveDate: effectiveDate ?? this.effectiveDate,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'payrollType': payrollType,
      'salaryMinor': salaryMinor,
      'commissionPercent': commissionPercent,
      'effectiveDate': effectiveDate.toIso8601String(),
    };
  }

  factory PayrollSetupRecord.fromJson(Map<String, dynamic> json) {
    return PayrollSetupRecord(
      userId: _asInt(json['userId']) ?? 0,
      userName: _asString(json['userName']),
      payrollType:
          _asString(json['payrollType'], fallback: PayrollTypes.salaryOnly),
      salaryMinor: _asInt(json['salaryMinor']) ?? 0,
      commissionPercent: _asDouble(json['commissionPercent']) ?? 0,
      effectiveDate: DateTime.tryParse(
            _asString(json['effectiveDate']),
          ) ??
          DateTime.now(),
    );
  }
}

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.mode,
    required this.reference,
    required this.paidDate,
    required this.notes,
  });

  final String mode;
  final String reference;
  final DateTime paidDate;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode,
      'reference': reference,
      'paidDate': paidDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      mode: _asString(json['mode']),
      reference: _asString(json['reference']),
      paidDate:
          DateTime.tryParse(_asString(json['paidDate'])) ?? DateTime.now(),
      notes: _asString(json['notes']),
    );
  }
}

@immutable
class PayrollAdjustmentRecord {
  const PayrollAdjustmentRecord({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.remarks,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amountMinor;
  final String remarks;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'amountMinor': amountMinor,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PayrollAdjustmentRecord.fromJson(Map<String, dynamic> json) {
    return PayrollAdjustmentRecord(
      id: _asString(json['id']),
      type: _asString(json['type'], fallback: AdjustmentTypes.addition),
      amountMinor: _asInt(json['amountMinor']) ?? 0,
      remarks: _asString(json['remarks']),
      createdAt:
          DateTime.tryParse(_asString(json['createdAt'])) ?? DateTime.now(),
    );
  }
}

@immutable
class PayrollRunEmployeeRecord {
  const PayrollRunEmployeeRecord({
    required this.userId,
    required this.userName,
    required this.payrollType,
    required this.salaryMinor,
    required this.commissionPercent,
    required this.commissionAmountMinor,
    required this.effectiveDate,
    required this.adjustments,
    this.payment,
  });

  final int userId;
  final String userName;
  final String payrollType;
  final int salaryMinor;
  final double commissionPercent;
  final int commissionAmountMinor;
  final DateTime effectiveDate;
  final List<PayrollAdjustmentRecord> adjustments;
  final PaymentRecord? payment;

  int get additionsTotalMinor => adjustments
      .where((item) => item.type == AdjustmentTypes.addition)
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  int get deductionsTotalMinor => adjustments
      .where((item) => item.type == AdjustmentTypes.deduction)
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  int get netPayableMinor =>
      salaryMinor +
      commissionAmountMinor +
      additionsTotalMinor -
      deductionsTotalMinor;

  PayrollRunEmployeeRecord copyWith({
    int? userId,
    String? userName,
    String? payrollType,
    int? salaryMinor,
    double? commissionPercent,
    int? commissionAmountMinor,
    DateTime? effectiveDate,
    List<PayrollAdjustmentRecord>? adjustments,
    PaymentRecord? payment,
    bool clearPayment = false,
  }) {
    return PayrollRunEmployeeRecord(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      payrollType: payrollType ?? this.payrollType,
      salaryMinor: salaryMinor ?? this.salaryMinor,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      commissionAmountMinor:
          commissionAmountMinor ?? this.commissionAmountMinor,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      adjustments:
          adjustments ?? List<PayrollAdjustmentRecord>.from(this.adjustments),
      payment: clearPayment ? null : (payment ?? this.payment),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'payrollType': payrollType,
      'salaryMinor': salaryMinor,
      'commissionPercent': commissionPercent,
      'commissionAmountMinor': commissionAmountMinor,
      'effectiveDate': effectiveDate.toIso8601String(),
      'adjustments': adjustments.map((item) => item.toJson()).toList(),
      'payment': payment?.toJson(),
    };
  }

  factory PayrollRunEmployeeRecord.fromJson(Map<String, dynamic> json) {
    return PayrollRunEmployeeRecord(
      userId: _asInt(json['userId']) ?? 0,
      userName: _asString(json['userName']),
      payrollType:
          _asString(json['payrollType'], fallback: PayrollTypes.salaryOnly),
      salaryMinor: _asInt(json['salaryMinor']) ?? 0,
      commissionPercent: _asDouble(json['commissionPercent']) ?? 0,
      commissionAmountMinor: _asInt(json['commissionAmountMinor']) ?? 0,
      effectiveDate: DateTime.tryParse(
            _asString(json['effectiveDate']),
          ) ??
          DateTime.now(),
      adjustments: ((json['adjustments'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => PayrollAdjustmentRecord.fromJson(
                Map<String, dynamic>.from(item)),
          )
          .toList(),
      payment: json['payment'] is Map
          ? PaymentRecord.fromJson(
              Map<String, dynamic>.from(json['payment'] as Map),
            )
          : null,
    );
  }
}

@immutable
class PayrollRunRecord {
  const PayrollRunRecord({
    required this.id,
    required this.periodKey,
    required this.periodLabel,
    required this.generatedAt,
    required this.employees,
    this.approvedAt,
    this.payment,
  });

  final String id;
  final String periodKey;
  final String periodLabel;
  final DateTime generatedAt;
  final DateTime? approvedAt;
  final List<PayrollRunEmployeeRecord> employees;
  final PaymentRecord? payment;

  bool get isApproved => approvedAt != null;

  bool get allEmployeesPaid =>
      employees.isNotEmpty && employees.every((item) => item.payment != null);

  String get statusLabel {
    if (payment != null || allEmployeesPaid) {
      return 'Paid';
    }
    if (isApproved) {
      return 'Approved';
    }
    return 'Pending';
  }

  int get totalAmountMinor =>
      employees.fold<int>(0, (sum, item) => sum + item.netPayableMinor);

  PayrollRunRecord copyWith({
    String? id,
    String? periodKey,
    String? periodLabel,
    DateTime? generatedAt,
    DateTime? approvedAt,
    List<PayrollRunEmployeeRecord>? employees,
    PaymentRecord? payment,
    bool clearPayment = false,
    bool clearApproval = false,
  }) {
    return PayrollRunRecord(
      id: id ?? this.id,
      periodKey: periodKey ?? this.periodKey,
      periodLabel: periodLabel ?? this.periodLabel,
      generatedAt: generatedAt ?? this.generatedAt,
      approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
      employees:
          employees ?? List<PayrollRunEmployeeRecord>.from(this.employees),
      payment: clearPayment ? null : (payment ?? this.payment),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'periodKey': periodKey,
      'periodLabel': periodLabel,
      'generatedAt': generatedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'employees': employees.map((item) => item.toJson()).toList(),
      'payment': payment?.toJson(),
    };
  }

  factory PayrollRunRecord.fromJson(Map<String, dynamic> json) {
    return PayrollRunRecord(
      id: _asString(json['id']),
      periodKey: _asString(json['periodKey']),
      periodLabel: _asString(json['periodLabel']),
      generatedAt:
          DateTime.tryParse(_asString(json['generatedAt'])) ?? DateTime.now(),
      approvedAt: DateTime.tryParse(_asString(json['approvedAt'])),
      employees: ((json['employees'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => PayrollRunEmployeeRecord.fromJson(
                Map<String, dynamic>.from(item)),
          )
          .toList(),
      payment: json['payment'] is Map
          ? PaymentRecord.fromJson(
              Map<String, dynamic>.from(json['payment'] as Map),
            )
          : null,
    );
  }
}

@immutable
class CommissionServiceRule {
  const CommissionServiceRule({
    required this.serviceId,
    required this.ruleType,
    required this.value,
    required this.effectiveFrom,
    required this.active,
    required this.notes,
  });

  final int serviceId;
  final String ruleType;
  final double value;
  final DateTime effectiveFrom;
  final bool active;
  final String notes;

  CommissionServiceRule copyWith({
    int? serviceId,
    String? ruleType,
    double? value,
    DateTime? effectiveFrom,
    bool? active,
    String? notes,
  }) {
    return CommissionServiceRule(
      serviceId: serviceId ?? this.serviceId,
      ruleType: ruleType ?? this.ruleType,
      value: value ?? this.value,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serviceId': serviceId,
      'ruleType': ruleType,
      'value': value,
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'active': active,
      'notes': notes,
    };
  }

  factory CommissionServiceRule.fromJson(Map<String, dynamic> json) {
    return CommissionServiceRule(
      serviceId: _asInt(json['serviceId']) ?? 0,
      ruleType:
          _asString(json['ruleType'], fallback: CommissionRuleTypes.percentage),
      value: _asDouble(json['value']) ?? 0,
      effectiveFrom: DateTime.tryParse(
            _asString(json['effectiveFrom']),
          ) ??
          DateTime.now(),
      active: _asBool(json['active'], fallback: true),
      notes: _asString(json['notes']),
    );
  }
}

@immutable
class StaffCommissionOverride {
  const StaffCommissionOverride({
    required this.id,
    required this.serviceId,
    required this.staffId,
    required this.staffName,
    required this.ruleType,
    required this.value,
    required this.effectiveFrom,
    required this.notes,
  });

  final String id;
  final int serviceId;
  final int staffId;
  final String staffName;
  final String ruleType;
  final double value;
  final DateTime effectiveFrom;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'serviceId': serviceId,
      'staffId': staffId,
      'staffName': staffName,
      'ruleType': ruleType,
      'value': value,
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'notes': notes,
    };
  }

  factory StaffCommissionOverride.fromJson(Map<String, dynamic> json) {
    return StaffCommissionOverride(
      id: _asString(json['id']),
      serviceId: _asInt(json['serviceId']) ?? 0,
      staffId: _asInt(json['staffId']) ?? 0,
      staffName: _asString(json['staffName']),
      ruleType:
          _asString(json['ruleType'], fallback: CommissionRuleTypes.percentage),
      value: _asDouble(json['value']) ?? 0,
      effectiveFrom: DateTime.tryParse(
            _asString(json['effectiveFrom']),
          ) ??
          DateTime.now(),
      notes: _asString(json['notes']),
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
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
  return int.tryParse(_asString(value));
}

double? _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_asString(value));
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final text = _asString(value).toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return fallback;
}
