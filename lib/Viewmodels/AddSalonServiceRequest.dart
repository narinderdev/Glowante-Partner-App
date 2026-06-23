class AddSalonServiceRequest {
  final int? branchCategoryId; // Optional — use when attaching under a category
  final int?
      branchSubCategoryId; // Optional — use when attaching under a subcategory
  final String displayName; // Required
  final String description; // Required (can be empty string)
  final int durationMin; // Required
  final int? priceMinor;
  final String? priceType;
  final bool isActive; // Required
  final bool? passiveWaitEnabled;
  final int? initialBusyMinutes;
  final int? passiveWaitMinutes;
  final int? finalBusyMinutes;
  final bool? commissionEnabled;
  final String? commissionType;
  final int? commissionFixedAmountMinor;
  final double? commissionPercentage;
  final int? commissionMaxAmountMinor;

  AddSalonServiceRequest({
    this.branchCategoryId,
    this.branchSubCategoryId,
    required this.displayName,
    required this.description,
    required this.durationMin,
    required this.priceMinor,
    required this.priceType,
    required this.isActive,
    this.passiveWaitEnabled,
    this.initialBusyMinutes,
    this.passiveWaitMinutes,
    this.finalBusyMinutes,
    this.commissionEnabled,
    this.commissionType,
    this.commissionFixedAmountMinor,
    this.commissionPercentage,
    this.commissionMaxAmountMinor,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      "displayName": displayName,
      "description": description,
      "durationMin": durationMin,
      "priceType": priceType,
      "priceMinor": priceMinor,
      "isActive": isActive,
    };

    if (passiveWaitEnabled != null) {
      data["passiveWaitEnabled"] = passiveWaitEnabled;
    }
    if (initialBusyMinutes != null) {
      data["initialBusyMinutes"] = initialBusyMinutes;
    }
    if (passiveWaitMinutes != null) {
      data["passiveWaitMinutes"] = passiveWaitMinutes;
    }
    if (finalBusyMinutes != null) {
      data["finalBusyMinutes"] = finalBusyMinutes;
    }
    if (commissionEnabled != null) {
      data["commissionEnabled"] = commissionEnabled;
    }
    if (commissionType != null && commissionType!.trim().isNotEmpty) {
      data["commissionType"] = commissionType;
    }
    if (commissionFixedAmountMinor != null) {
      data["commissionFixedAmountMinor"] = commissionFixedAmountMinor;
    }
    if (commissionPercentage != null) {
      data["commissionPercentage"] = commissionPercentage;
    }
    if (commissionMaxAmountMinor != null) {
      data["commissionMaxAmountMinor"] = commissionMaxAmountMinor;
    }

    // Allow exactly one of category or subcategory
    if (branchCategoryId != null) {
      data["branchCategoryId"] = branchCategoryId;
    }

    if (branchSubCategoryId != null) {
      data["branchSubCategoryId"] = branchSubCategoryId;
    }

    // if (branchCategoryId != null) {
    //   data["branchCategoryId"] = branchCategoryId;
    // } else if (branchSubCategoryId != null) {
    //   data["branchSubCategoryId"] = branchSubCategoryId;
    // }

    return data;
  }
}
