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
    switch (normalize(value)) {
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

  static String normalize(String value) {
    switch (value.trim().toUpperCase()) {
      case 'SALARY_PLUS_COMMISSION':
      case 'SALARY_COMMISSION':
      case 'SALARY+COMMISSION':
        return salaryCommission;
      case 'SALARY_ONLY':
      case 'SALARY':
        return salaryOnly;
      case 'COMMISSION_ONLY':
      case 'COMMISSION':
        return commissionOnly;
      default:
        return value;
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

class AdvancePaymentModes {
  static const String cash = 'CASH';
  static const String googlePay = 'GOOGLE_PAY';
  static const String phonePe = 'PHONE_PE';
  static const String paytm = 'PAYTM';
  static const String bankTransfer = 'BANK_TRANSFER';
  static const String upi = 'UPI';

  static const List<String> values = <String>[
    cash,
    googlePay,
    phonePe,
    paytm,
    bankTransfer,
    upi,
  ];

  static String label(String value) {
    switch (_asString(value).toUpperCase()) {
      case cash:
        return 'Cash';
      case googlePay:
        return 'Google Pay';
      case phonePe:
        return 'PhonePe';
      case paytm:
        return 'Paytm';
      case bankTransfer:
        return 'Bank Transfer';
      case upi:
        return 'UPI';
      default:
        return _asString(value)
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .where((item) => item.isNotEmpty)
            .map((item) => '${item[0].toUpperCase()}${item.substring(1)}')
            .join(' ');
    }
  }
}

class ProfileTeamMember {
  const ProfileTeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    required this.isActive,
    this.joiningDate,
  });

  final int id;
  final String name;
  final String role;
  final String phoneNumber;
  final bool isActive;
  final DateTime? joiningDate;
}

@immutable
class PayrollAdvanceRecord {
  const PayrollAdvanceRecord({
    required this.id,
    required this.branchId,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.remainingAmount,
    required this.givenDate,
    required this.paymentMode,
    required this.paymentReference,
    required this.status,
    required this.remarks,
    required this.createdAt,
  });

  final int id;
  final int branchId;
  final int employeeId;
  final String employeeName;
  final int amount;
  final int remainingAmount;
  final DateTime givenDate;
  final String paymentMode;
  final String paymentReference;
  final String status;
  final String remarks;
  final DateTime createdAt;

  PayrollAdvanceRecord copyWith({
    int? id,
    int? branchId,
    int? employeeId,
    String? employeeName,
    int? amount,
    int? remainingAmount,
    DateTime? givenDate,
    String? paymentMode,
    String? paymentReference,
    String? status,
    String? remarks,
    DateTime? createdAt,
  }) {
    return PayrollAdvanceRecord(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      givenDate: givenDate ?? this.givenDate,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentReference: paymentReference ?? this.paymentReference,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'branchId': branchId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'remainingAmount': remainingAmount,
      'givenDate': givenDate.toIso8601String(),
      'paymentMode': paymentMode,
      'paymentReference': paymentReference,
      'status': status,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PayrollAdvanceRecord.fromJson(Map<String, dynamic> json) {
    return PayrollAdvanceRecord(
      id: _asInt(json['id']) ?? 0,
      branchId: _asInt(json['branchId']) ?? 0,
      employeeId: _asInt(json['employeeId'] ?? json['teamMemberId']) ?? 0,
      employeeName: _asString(
        json['employeeName'] ??
            json['teamMemberName'] ??
            json['name'] ??
            json['employee']?['name'],
      ),
      amount: _asInt(json['amount']) ?? 0,
      remainingAmount:
          _asInt(json['remainingAmount'] ?? json['remaining_amount']) ??
              (_asInt(json['amount']) ?? 0),
      givenDate:
          DateTime.tryParse(_asString(json['givenDate'] ?? json['date'])) ??
              DateTime.now(),
      paymentMode: _asString(json['paymentMode']),
      paymentReference: _asString(
        json['paymentReference'] ?? json['reference'],
      ),
      status: _asString(json['status'], fallback: 'ACTIVE'),
      remarks: _asString(json['remarks']),
      createdAt: DateTime.tryParse(
              _asString(json['createdAt'] ?? json['updatedAt'])) ??
          DateTime.now(),
    );
  }
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
    this.salaryConfigId,
  });

  final int userId;
  final String userName;
  final String payrollType;
  final int salaryMinor;
  final double commissionPercent;
  final DateTime effectiveDate;
  final int? salaryConfigId;

  PayrollSetupRecord copyWith({
    int? userId,
    String? userName,
    String? payrollType,
    int? salaryMinor,
    double? commissionPercent,
    DateTime? effectiveDate,
    int? salaryConfigId,
  }) {
    return PayrollSetupRecord(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      payrollType: payrollType ?? this.payrollType,
      salaryMinor: salaryMinor ?? this.salaryMinor,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      salaryConfigId: salaryConfigId ?? this.salaryConfigId,
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
      'salaryConfigId': salaryConfigId,
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
      salaryConfigId: _asInt(json['salaryConfigId'] ?? json['salaryId']),
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
    required this.payrollEmployeeId,
    required this.type,
    required this.amountMinor,
    required this.remarks,
    required this.createdAt,
    this.isDeleted = false,
  });

  final String id;
  final int payrollEmployeeId;
  final String type;
  final int amountMinor;
  final String remarks;
  final DateTime createdAt;
  final bool isDeleted;

  PayrollAdjustmentRecord copyWith({
    String? id,
    int? payrollEmployeeId,
    String? type,
    int? amountMinor,
    String? remarks,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return PayrollAdjustmentRecord(
      id: id ?? this.id,
      payrollEmployeeId: payrollEmployeeId ?? this.payrollEmployeeId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'payrollEmployeeId': payrollEmployeeId,
      'type': type,
      'amountMinor': amountMinor,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory PayrollAdjustmentRecord.fromJson(Map<String, dynamic> json) {
    final resolvedType = _asString(json['type']).isNotEmpty
        ? _asString(json['type'])
        : json.containsKey('deductionId') ||
                json.containsKey('deduction_id') ||
                _asString(json['source']).toLowerCase().contains('deduction')
            ? AdjustmentTypes.deduction
            : AdjustmentTypes.addition;
    return PayrollAdjustmentRecord(
      id: _asString(
        json['id'] ??
            json['additionalChargeId'] ??
            json['additional_charge_id'] ??
            json['deductionId'] ??
            json['deduction_id'],
      ),
      payrollEmployeeId: _asInt(
            json['payrollEmployeeId'] ??
                json['payroll_employee_id'] ??
                json['employeeId'] ??
                json['employee_id'] ??
                json['userId'],
          ) ??
          0,
      type: resolvedType,
      amountMinor: _asInt(json['amountMinor'] ?? json['amount']) ?? 0,
      remarks: _asString(json['remarks'] ?? json['reason']),
      createdAt: DateTime.tryParse(
            _asString(
              json['createdAt'] ??
                  json['created_at'] ??
                  json['updatedAt'] ??
                  json['updated_at'],
            ),
          ) ??
          DateTime.now(),
      isDeleted: _asBool(
        json['isDeleted'] ?? json['deleted'] ?? json['is_deleted'],
      ),
    );
  }
}

@immutable
class PayrollRunEmployeeRecord {
  const PayrollRunEmployeeRecord({
    required this.userId,
    required this.payrollEmployeeId,
    required this.userName,
    required this.role,
    required this.payrollType,
    required this.salaryMinor,
    required this.commissionPercent,
    required this.commissionAmountMinor,
    required this.effectiveDate,
    required this.adjustments,
    this.servicesCount = 0,
    this.grossPayOverrideMinor,
    this.additionsOverrideMinor,
    this.deductionsOverrideMinor,
    this.advancesOverrideMinor,
    this.netPayableOverrideMinor,
    this.backendStatus,
    this.payment,
  });

  final int userId;
  final int payrollEmployeeId;
  final String userName;
  final String role;
  final String payrollType;
  final int salaryMinor;
  final double commissionPercent;
  final int commissionAmountMinor;
  final DateTime effectiveDate;
  final List<PayrollAdjustmentRecord> adjustments;
  final int servicesCount;
  final int? grossPayOverrideMinor;
  final int? additionsOverrideMinor;
  final int? deductionsOverrideMinor;
  final int? advancesOverrideMinor;
  final int? netPayableOverrideMinor;
  final String? backendStatus;
  final PaymentRecord? payment;

  int get additionsTotalMinor => adjustments
      .where((item) => item.type == AdjustmentTypes.addition)
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  int get deductionsTotalMinor => adjustments
      .where((item) => item.type == AdjustmentTypes.deduction)
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  int get additionsDisplayMinor =>
      additionsOverrideMinor ?? additionsTotalMinor;

  int get deductionsDisplayMinor =>
      deductionsOverrideMinor ?? deductionsTotalMinor;

  int get advancesDisplayMinor => advancesOverrideMinor ?? 0;

  int get grossPayMinor =>
      grossPayOverrideMinor ??
      salaryMinor + commissionAmountMinor + additionsDisplayMinor;

  int get netPayableMinor =>
      netPayableOverrideMinor ??
      salaryMinor +
          commissionAmountMinor +
          additionsDisplayMinor -
          deductionsDisplayMinor -
          advancesDisplayMinor;

  String get statusLabel {
    final normalizedStatus = _asString(backendStatus).trim().toLowerCase();
    if (payment != null) {
      return 'Paid';
    }
    if (normalizedStatus == 'paid' || normalizedStatus.contains('paid')) {
      return 'Paid';
    }
    return 'Pending';
  }

  PayrollRunEmployeeRecord copyWith({
    int? userId,
    int? payrollEmployeeId,
    String? userName,
    String? role,
    String? payrollType,
    int? salaryMinor,
    double? commissionPercent,
    int? commissionAmountMinor,
    DateTime? effectiveDate,
    List<PayrollAdjustmentRecord>? adjustments,
    int? servicesCount,
    int? grossPayOverrideMinor,
    int? additionsOverrideMinor,
    int? deductionsOverrideMinor,
    int? advancesOverrideMinor,
    int? netPayableOverrideMinor,
    String? backendStatus,
    PaymentRecord? payment,
    bool clearPayment = false,
  }) {
    return PayrollRunEmployeeRecord(
      userId: userId ?? this.userId,
      payrollEmployeeId: payrollEmployeeId ?? this.payrollEmployeeId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      payrollType: payrollType ?? this.payrollType,
      salaryMinor: salaryMinor ?? this.salaryMinor,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      commissionAmountMinor:
          commissionAmountMinor ?? this.commissionAmountMinor,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      adjustments:
          adjustments ?? List<PayrollAdjustmentRecord>.from(this.adjustments),
      servicesCount: servicesCount ?? this.servicesCount,
      grossPayOverrideMinor:
          grossPayOverrideMinor ?? this.grossPayOverrideMinor,
      additionsOverrideMinor:
          additionsOverrideMinor ?? this.additionsOverrideMinor,
      deductionsOverrideMinor:
          deductionsOverrideMinor ?? this.deductionsOverrideMinor,
      advancesOverrideMinor:
          advancesOverrideMinor ?? this.advancesOverrideMinor,
      netPayableOverrideMinor:
          netPayableOverrideMinor ?? this.netPayableOverrideMinor,
      backendStatus: backendStatus ?? this.backendStatus,
      payment: clearPayment ? null : (payment ?? this.payment),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'payrollEmployeeId': payrollEmployeeId,
      'userName': userName,
      'role': role,
      'payrollType': payrollType,
      'salaryMinor': salaryMinor,
      'commissionPercent': commissionPercent,
      'commissionAmountMinor': commissionAmountMinor,
      'effectiveDate': effectiveDate.toIso8601String(),
      'adjustments': adjustments.map((item) => item.toJson()).toList(),
      'servicesCount': servicesCount,
      'grossPayOverrideMinor': grossPayOverrideMinor,
      'additionsOverrideMinor': additionsOverrideMinor,
      'deductionsOverrideMinor': deductionsOverrideMinor,
      'advancesOverrideMinor': advancesOverrideMinor,
      'netPayableOverrideMinor': netPayableOverrideMinor,
      'backendStatus': backendStatus,
      'payment': payment?.toJson(),
    };
  }

  factory PayrollRunEmployeeRecord.fromJson(Map<String, dynamic> json) {
    final servicesPerformedCount =
        (json['servicesPerformed'] as List?)?.length ?? 0;
    final reportedServicesCount =
        _asInt(json['servicesCount'] ?? json['totalServicesCount']);
    final servicesCount =
        reportedServicesCount != null && reportedServicesCount > 0
            ? reportedServicesCount
            : servicesPerformedCount > 0
                ? servicesPerformedCount
                : 0;

    return PayrollRunEmployeeRecord(
      userId: _asInt(json['userId']) ?? 0,
      payrollEmployeeId: _asInt(
            json['payrollEmployeeId'] ??
                json['employeeId'] ??
                json['teamMemberId'] ??
                json['payroll_employee_id'] ??
                json['userId'],
          ) ??
          0,
      userName: _asString(
        json['userName'] ?? json['teamMemberName'] ?? json['name'],
      ),
      role: _asString(json['role'], fallback: 'Team Member'),
      payrollType: PayrollTypes.normalize(
        _asString(json['payrollType'], fallback: PayrollTypes.salaryOnly),
      ),
      salaryMinor: _asInt(json['salaryMinor'] ?? json['salaryAmount']) ?? 0,
      commissionPercent: _asDouble(
              json['commissionPercent'] ?? json['commissionPercentage']) ??
          0,
      commissionAmountMinor:
          _asInt(json['commissionAmountMinor'] ?? json['commissionAmount']) ??
              0,
      effectiveDate: DateTime.tryParse(
            _asString(json['effectiveDate'] ?? json['effectiveFrom']),
          ) ??
          DateTime.now(),
      adjustments: ((json['adjustments'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => PayrollAdjustmentRecord.fromJson(
                Map<String, dynamic>.from(item)),
          )
          .toList(),
      servicesCount: servicesCount,
      grossPayOverrideMinor:
          _asInt(json['grossPayOverrideMinor'] ?? json['grossPay']),
      additionsOverrideMinor:
          _asInt(json['additionsOverrideMinor'] ?? json['additionsAmount']),
      deductionsOverrideMinor:
          _asInt(json['deductionsOverrideMinor'] ?? json['deductionsAmount']),
      advancesOverrideMinor:
          _asInt(json['advancesOverrideMinor'] ?? json['advanceAmount']),
      netPayableOverrideMinor:
          _asInt(json['netPayableOverrideMinor'] ?? json['netPayable']),
      backendStatus: _asString(json['backendStatus'] ?? json['status']),
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
    this.backendStatus,
    this.summaryNetPayableMinor,
    this.summaryPaidMinor,
    this.summaryOutstandingMinor,
    this.summaryEmployeeCount,
    this.noteTitle,
    this.noteDescription,
  });

  final String id;
  final String periodKey;
  final String periodLabel;
  final DateTime generatedAt;
  final DateTime? approvedAt;
  final List<PayrollRunEmployeeRecord> employees;
  final PaymentRecord? payment;
  final String? backendStatus;
  final int? summaryNetPayableMinor;
  final int? summaryPaidMinor;
  final int? summaryOutstandingMinor;
  final int? summaryEmployeeCount;
  final String? noteTitle;
  final String? noteDescription;

  bool get isApproved => approvedAt != null;
  String get normalizedBackendStatus =>
      _asString(backendStatus).trim().toLowerCase();
  bool get isCancelled => normalizedBackendStatus == 'cancelled';

  int get employeeCount => summaryEmployeeCount ?? employees.length;

  bool get allEmployeesPaid =>
      employees.isNotEmpty && employees.every((item) => item.payment != null);

  String get statusLabel {
    final normalizedStatus = normalizedBackendStatus;
    if (normalizedStatus == 'draft') {
      return 'Draft';
    }
    if (normalizedStatus == 'cancelled') {
      return 'Cancelled';
    }
    if (normalizedStatus == 'reviewed') {
      return 'Reviewed';
    }
    if (normalizedStatus == 'approved') {
      return 'Approved';
    }
    if (payment != null || allEmployeesPaid) {
      return 'Paid';
    }
    if (normalizedStatus == 'paid') {
      return 'Paid';
    }
    return 'Pending';
  }

  int get totalAmountMinor =>
      summaryNetPayableMinor ??
      employees.fold<int>(0, (sum, item) => sum + item.netPayableMinor);

  int get paidAmountMinor => summaryPaidMinor ?? 0;

  int get outstandingAmountMinor =>
      summaryOutstandingMinor ??
      (totalAmountMinor - paidAmountMinor).clamp(0, totalAmountMinor);

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
    String? backendStatus,
    int? summaryNetPayableMinor,
    int? summaryPaidMinor,
    int? summaryOutstandingMinor,
    int? summaryEmployeeCount,
    String? noteTitle,
    String? noteDescription,
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
      backendStatus: backendStatus ?? this.backendStatus,
      summaryNetPayableMinor:
          summaryNetPayableMinor ?? this.summaryNetPayableMinor,
      summaryPaidMinor: summaryPaidMinor ?? this.summaryPaidMinor,
      summaryOutstandingMinor:
          summaryOutstandingMinor ?? this.summaryOutstandingMinor,
      summaryEmployeeCount: summaryEmployeeCount ?? this.summaryEmployeeCount,
      noteTitle: noteTitle ?? this.noteTitle,
      noteDescription: noteDescription ?? this.noteDescription,
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
      'backendStatus': backendStatus,
      'summaryNetPayableMinor': summaryNetPayableMinor,
      'summaryPaidMinor': summaryPaidMinor,
      'summaryOutstandingMinor': summaryOutstandingMinor,
      'summaryEmployeeCount': summaryEmployeeCount,
      'noteTitle': noteTitle,
      'noteDescription': noteDescription,
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
      backendStatus: _asString(json['backendStatus'] ?? json['status']),
      summaryNetPayableMinor:
          _asInt(json['summaryNetPayableMinor'] ?? json['netPayableMinor']),
      summaryPaidMinor:
          _asInt(json['summaryPaidMinor'] ?? json['totalPaidMinor']),
      summaryOutstandingMinor: _asInt(
        json['summaryOutstandingMinor'] ?? json['outstandingMinor'],
      ),
      summaryEmployeeCount:
          _asInt(json['summaryEmployeeCount'] ?? json['employeeCount']),
      noteTitle: _asString(json['noteTitle']),
      noteDescription: _asString(json['noteDescription']),
    );
  }
}

@immutable
class AttendanceDayRecord {
  const AttendanceDayRecord({
    required this.id,
    required this.branchId,
    required this.userId,
    required this.checkedInAt,
    required this.checkedInAtIndianTime,
    required this.checkedOutAt,
    required this.checkedOutAtIndianTime,
    required this.updatedByUserId,
  });

  final int id;
  final int branchId;
  final int userId;
  final DateTime? checkedInAt;
  final String checkedInAtIndianTime;
  final DateTime? checkedOutAt;
  final String checkedOutAtIndianTime;
  final int? updatedByUserId;

  factory AttendanceDayRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceDayRecord(
      id: _asInt(json['id']) ?? 0,
      branchId: _asInt(json['branchId']) ?? 0,
      userId: _asInt(json['userId']) ?? 0,
      checkedInAt: DateTime.tryParse(_asString(json['checkedInAt'])),
      checkedInAtIndianTime: _asString(json['checkedInAtIndianTime']),
      checkedOutAt: DateTime.tryParse(_asString(json['checkedOutAt'])),
      checkedOutAtIndianTime: _asString(json['checkedOutAtIndianTime']),
      updatedByUserId: _asInt(json['updatedByUserId']),
    );
  }
}

@immutable
class BranchAttendanceEmployeeRecord {
  const BranchAttendanceEmployeeRecord({
    required this.userId,
    required this.userName,
    required this.role,
    required this.active,
    required this.month,
    required this.year,
    required this.totalDays,
    required this.daysAttended,
    required this.leaves,
    required this.recordsCount,
    required this.records,
  });

  final int userId;
  final String userName;
  final String role;
  final bool active;
  final int month;
  final int year;
  final int totalDays;
  final int daysAttended;
  final int leaves;
  final int recordsCount;
  final List<AttendanceDayRecord> records;

  factory BranchAttendanceEmployeeRecord.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return BranchAttendanceEmployeeRecord(
      userId: _asInt(json['userId']) ?? 0,
      userName: _asString(json['userName'] ?? json['name']),
      role: _asString(json['role'], fallback: 'Team Member'),
      active: _asBool(json['active'], fallback: true),
      month: _asInt(summary['month']) ?? 0,
      year: _asInt(summary['year']) ?? 0,
      totalDays: _asInt(summary['totalDays']) ?? 0,
      daysAttended: _asInt(summary['daysAttended']) ?? 0,
      leaves: _asInt(summary['leaves']) ?? 0,
      recordsCount: _asInt(summary['recordsCount']) ?? 0,
      records: ((json['records'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AttendanceDayRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class BranchAttendanceOverview {
  const BranchAttendanceOverview({
    required this.month,
    required this.year,
    required this.totalDays,
    required this.totalEmployees,
    required this.employeesWithAttendance,
    required this.recordsCount,
    required this.daysAttended,
    required this.leaves,
    required this.employees,
  });

  final int month;
  final int year;
  final int totalDays;
  final int totalEmployees;
  final int employeesWithAttendance;
  final int recordsCount;
  final int daysAttended;
  final int leaves;
  final List<BranchAttendanceEmployeeRecord> employees;

  factory BranchAttendanceOverview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return BranchAttendanceOverview(
      month: _asInt(summary['month']) ?? 0,
      year: _asInt(summary['year']) ?? 0,
      totalDays: _asInt(summary['totalDays']) ?? 0,
      totalEmployees: _asInt(summary['totalEmployees']) ?? 0,
      employeesWithAttendance: _asInt(summary['employeesWithAttendance']) ?? 0,
      recordsCount: _asInt(summary['recordsCount']) ?? 0,
      daysAttended: _asInt(summary['daysAttended']) ?? 0,
      leaves: _asInt(summary['leaves']) ?? 0,
      employees: ((json['employees'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => BranchAttendanceEmployeeRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class BranchPaidLeaveConfig {
  const BranchPaidLeaveConfig({
    required this.branchId,
    required this.branchName,
    required this.paidLeaveDays,
  });

  final int branchId;
  final String branchName;
  final int paidLeaveDays;

  factory BranchPaidLeaveConfig.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    final config = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    return BranchPaidLeaveConfig(
      branchId: _asInt(
            branch['id'] ??
                json['branchId'] ??
                json['id'] ??
                config['branchId'],
          ) ??
          0,
      branchName: _asString(
        branch['name'] ?? json['branchName'] ?? config['branchName'],
      ),
      paidLeaveDays: _asInt(
            json['paidLeaveDays'] ??
                json['defaultPaidLeaveDays'] ??
                json['defaultPaidLeaves'] ??
                config['paidLeaveDays'] ??
                config['defaultPaidLeaveDays'] ??
                config['defaultPaidLeaves'] ??
                config['days'] ??
                json['days'] ??
                json['value'],
          ) ??
          0,
    );
  }
}

@immutable
class PayrollPaidLeaveEmployeeRecord {
  const PayrollPaidLeaveEmployeeRecord({
    required this.payrollEmployeeId,
    required this.employeeId,
    required this.employeeName,
    required this.role,
    required this.profileImage,
    required this.salaryAmount,
    required this.commissionPercentage,
    required this.paidLeaveDays,
    required this.leaveDays,
    required this.status,
  });

  final int payrollEmployeeId;
  final int employeeId;
  final String employeeName;
  final String role;
  final String? profileImage;
  final int salaryAmount;
  final double commissionPercentage;
  final int paidLeaveDays;
  final int leaveDays;
  final String status;

  factory PayrollPaidLeaveEmployeeRecord.fromJson(Map<String, dynamic> json) {
    return PayrollPaidLeaveEmployeeRecord(
      payrollEmployeeId: _asInt(json['payrollEmployeeId']) ?? 0,
      employeeId: _asInt(json['employeeId'] ?? json['teamMemberId']) ?? 0,
      employeeName: _asString(json['employeeName'] ?? json['teamMemberName']),
      role: _asString(json['role'], fallback: 'Team Member'),
      profileImage: _asString(json['profileImage']).isEmpty
          ? null
          : _asString(json['profileImage']),
      salaryAmount: _asInt(json['salaryAmount']) ?? 0,
      commissionPercentage: _asDouble(json['commissionPercentage']) ?? 0,
      paidLeaveDays: _asInt(json['paidLeaveDays']) ?? 0,
      leaveDays: _asInt(json['leaveDays']) ?? 0,
      status: _asString(json['status']),
    );
  }
}

@immutable
class PayrollPaidLeavesReview {
  const PayrollPaidLeavesReview({
    required this.branchId,
    required this.branchName,
    required this.payrollId,
    required this.payrollName,
    required this.month,
    required this.year,
    required this.periodStart,
    required this.periodEnd,
    required this.payrollStatus,
    required this.totalTeamMembersCount,
    required this.membersWithPayrollSetup,
    required this.totalPaidLeaveDays,
    required this.employees,
  });

  final int branchId;
  final String branchName;
  final String? payrollId;
  final String payrollName;
  final int month;
  final int year;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String payrollStatus;
  final int totalTeamMembersCount;
  final int membersWithPayrollSetup;
  final int totalPaidLeaveDays;
  final List<PayrollPaidLeaveEmployeeRecord> employees;

  factory PayrollPaidLeavesReview.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    final payroll = json['payroll'] is Map
        ? Map<String, dynamic>.from(json['payroll'] as Map)
        : const <String, dynamic>{};
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return PayrollPaidLeavesReview(
      branchId: _asInt(branch['id']) ?? 0,
      branchName: _asString(branch['name']),
      payrollId: _asString(payroll['payrollId']).isEmpty
          ? null
          : _asString(payroll['payrollId']),
      payrollName: _asString(payroll['payrollName']),
      month: _asInt(payroll['month']) ?? 0,
      year: _asInt(payroll['year']) ?? 0,
      periodStart: DateTime.tryParse(_asString(payroll['periodStart'])),
      periodEnd: DateTime.tryParse(_asString(payroll['periodEnd'])),
      payrollStatus: _asString(payroll['status']),
      totalTeamMembersCount: _asInt(summary['totalTeamMembersCount']) ?? 0,
      membersWithPayrollSetup: _asInt(summary['membersWithPayrollSetup']) ?? 0,
      totalPaidLeaveDays: _asInt(summary['totalPaidLeaveDays']) ?? 0,
      employees: ((json['employees'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => PayrollPaidLeaveEmployeeRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class HolidayCalendarEntry {
  const HolidayCalendarEntry({
    required this.id,
    required this.salonId,
    required this.holidayDate,
    required this.title,
    required this.description,
    required this.createdByUserId,
  });

  final int id;
  final int salonId;
  final DateTime holidayDate;
  final String title;
  final String description;
  final int? createdByUserId;

  factory HolidayCalendarEntry.fromJson(Map<String, dynamic> json) {
    return HolidayCalendarEntry(
      id: _asInt(json['id']) ?? 0,
      salonId: _asInt(json['salonId']) ?? 0,
      holidayDate:
          DateTime.tryParse(_asString(json['holidayDate'])) ?? DateTime.now(),
      title: _asString(json['title']),
      description: _asString(json['description']),
      createdByUserId: _asInt(json['createdByUserId']),
    );
  }
}

@immutable
class HolidayCalendarOverview {
  const HolidayCalendarOverview({
    required this.salonId,
    required this.salonName,
    required this.month,
    required this.year,
    required this.totalHolidays,
    required this.totalDays,
    required this.holidays,
  });

  final int salonId;
  final String salonName;
  final int month;
  final int year;
  final int totalHolidays;
  final int totalDays;
  final List<HolidayCalendarEntry> holidays;

  factory HolidayCalendarOverview.fromJson(Map<String, dynamic> json) {
    final salon = json['salon'] is Map
        ? Map<String, dynamic>.from(json['salon'] as Map)
        : const <String, dynamic>{};
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return HolidayCalendarOverview(
      salonId: _asInt(salon['id']) ?? 0,
      salonName: _asString(salon['name']),
      month: _asInt(summary['month']) ?? 0,
      year: _asInt(summary['year']) ?? 0,
      totalHolidays: _asInt(summary['totalHolidays']) ?? 0,
      totalDays: _asInt(summary['totalDays']) ?? 0,
      holidays: ((json['holidays'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => HolidayCalendarEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
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
