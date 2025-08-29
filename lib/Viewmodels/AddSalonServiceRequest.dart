import 'dart:convert'; 

// class AddSalonServiceRequest {
//   final int? masterSubCategoryId;
//   final int? salonCategoryId;
//   final int? salonSubCategoryId;
//   final String name;
//   final String description;
//   final int defaultDurationMin;
//   final int defaultPriceMinor;
//   final String priceType;
//   final String? code; // Optional
//   final String source;
//   final String scope;
//   final int ownerBranchId;
//   final bool isActive;

//   AddSalonServiceRequest({
//     this.masterSubCategoryId,
//     this.salonCategoryId,
//     this.salonSubCategoryId,
//     required this.name,
//     required this.description,
//     required this.defaultDurationMin,
//     required this.defaultPriceMinor,
//     required this.priceType,
//     this.code,
//     required this.source,
//     required this.scope,
//     required this.ownerBranchId,
//     required this.isActive,
//   });

//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = {
//       'name': name,
//       'description': description,
//       'defaultDurationMin': defaultDurationMin,
//       'defaultPriceMinor': defaultPriceMinor,
//       'priceType': priceType,
//       'source': source,
//       'scope': scope,
//       'ownerBranchId': ownerBranchId,
//       'isActive': isActive,
//     };

//     if (salonCategoryId != null && salonCategoryId != 0) {
//       data['salonCategoryId'] = salonCategoryId;
//     }
//     if (salonSubCategoryId != null && salonSubCategoryId != 0) {
//       data['salonSubCategoryId'] = salonSubCategoryId;
//     }
//     if (masterSubCategoryId != null && masterSubCategoryId != 0) {
//       data['masterSubCategoryId'] = masterSubCategoryId;
//     }
//     if (code != null) {
//       data['code'] = code;
//     }

//     return data;
//   }
// }

class AddSalonServiceRequest {
  final int masterSubCategoryId; // Master category is compulsory
  final int? salonCategoryId; // Optional
  final int? salonSubCategoryId; // Optional
  final String name;
  final String description;
  final int defaultDurationMin;
  final int defaultPriceMinor;
  final String priceType;
  final String? code; // Optional
  final String source;
  final String scope;
  final int ownerBranchId;
  final bool isActive;

  AddSalonServiceRequest({
    required this.masterSubCategoryId, // This is required
    this.salonCategoryId,  // Optional
    this.salonSubCategoryId,  // Optional
    required this.name,
    required this.description,
    required this.defaultDurationMin,
    required this.defaultPriceMinor,
    required this.priceType,
    this.code,
    required this.source,
    required this.scope,
    required this.ownerBranchId,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'defaultDurationMin': defaultDurationMin,
      'defaultPriceMinor': defaultPriceMinor,
      'priceType': priceType,
      'source': source,
      'scope': scope,
      'ownerBranchId': ownerBranchId,
      'isActive': isActive,
      'masterSubCategoryId': masterSubCategoryId, // Always include this
    };

    // Ensure exactly one of salonCategoryId or salonSubCategoryId is included.
    if (salonCategoryId != null && salonSubCategoryId != null) {
      throw Exception("Only one of salonCategoryId or salonSubCategoryId should be provided.");
    }

    if (salonCategoryId != null) {
      data['salonCategoryId'] = salonCategoryId;
    }

    if (salonSubCategoryId != null) {
      data['salonSubCategoryId'] = salonSubCategoryId;
    }

    // Include code only if it's not null
    if (code != null) {
      data['code'] = code;
    }

    return data;
  }
}
