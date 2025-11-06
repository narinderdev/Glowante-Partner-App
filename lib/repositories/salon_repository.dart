import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/api_service.dart';
import '../Viewmodels/AddCategory.dart';
import '../Viewmodels/AddSalonBranchRequest.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';

class SalonRepository {
  SalonRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  // ------------------------------------------------------------
  // 1️⃣ Fetch all salons
  // ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchSalons() async {
    final response = await _apiService.getSalonListApi();

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to fetch salons');
    }

    final List items = response['data'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  // ------------------------------------------------------------
  // 2️⃣ Create salon
  // ------------------------------------------------------------
// Future<Map<String, dynamic>> createSalon({
//   required String name,
//   required String phone,
//   required String startTime,
//   required String endTime,
//   required String description,
//   required String buildingName,
//   required String city,
//   required String pincode,
//   required String state,
//   required double latitude,
//   required double longitude,
//   required List<String> serviceCodes,
//   List<String> selectedCategoryCodes = const [],
//   List<File> images = const [],
//   String? imageUrl, // ✅ new optional parameter
// }) async {
//   // ✅ If imageUrl is not passed but local files exist, upload them
//   if ((imageUrl == null || imageUrl.isEmpty) && images.isNotEmpty) {
//     final urls = await _apiService.uploadMultipleImages(images);
//     if (urls.isNotEmpty) imageUrl = urls.first;
//   }

//   final body = <String, dynamic>{
//     'name': name,
//     'phone': phone,
//     'startTime': startTime,
//     'endTime': endTime,
//     'description': description,
//     'image_url': imageUrl, // ✅ now correctly included
//     'address': {
//       'line1': '$buildingName, $city'.trim(),
//       'line2': pincode.isNotEmpty ? '$pincode, ' : '',
//       'village': '',
//       'district': '',
//       'city': city,
//       'state': state,
//       'country': 'India',
//       'postalCode': pincode,
//       'latitude': latitude,
//       'longitude': longitude,
//     },
//     'selectedCategoryCodes': selectedCategoryCodes,
//   };

//   // 🔍 Debug Log
//   final encoder = const JsonEncoder.withIndent('  ');
//   final payloadLog = encoder.convert(body);
//   debugPrint('[SalonRepository] createSalon payload ->\n$payloadLog');
//   FirebaseCrashlytics.instance
//       .log('[SalonRepository] createSalon payload -> $payloadLog');

//   final endpoint =
//       Uri.parse(ApiService.baseUrl + ApiService.createSalonEndpoint);
//   final token = await _apiService.getAuthToken();

//   final response = await http.post(
//     endpoint,
//     headers: {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     },
//     body: jsonEncode(body),
//   );

//   debugPrint(
//       '[SalonRepository] createSalon response ${response.statusCode}: ${response.body}');
//   FirebaseCrashlytics.instance.log(
//       '[SalonRepository] createSalon response ${response.statusCode}: ${response.body}');

//   if (response.statusCode < 200 || response.statusCode >= 300) {
//     throw HttpException(
//       'createSalon failed (${response.statusCode}): ${response.body}',
//       uri: endpoint,
//     );
//   }

//   final decoded = jsonDecode(response.body) as Map<String, dynamic>;
//   return decoded;
// }

Future<Map<String, dynamic>> createSalon({
  required String name,
  required String phone,
  required String startTime,
  required String endTime,
  required String description,

  // ⚠️ These are from the new flow:
  // buildingName => completeAddress
  // city         => sco/flat/house (optional)
  // pincode      => street/sector/area (optional)
  // state        => (unused for now)
  required String buildingName,
  required String city,
  required String pincode,
  required String state,
  required double latitude,
  required double longitude,
  required List<String> serviceCodes,
  List<String> selectedCategoryCodes = const [],
  List<File> images = const [],
  String? imageUrl,
}) async {
  // Upload if needed
  if ((imageUrl == null || imageUrl.isEmpty) && images.isNotEmpty) {
    final urls = await _apiService.uploadMultipleImages(images);
    if (urls.isNotEmpty) imageUrl = urls.first;
  }

  // Helper to join non-empty parts with ", "
  String _joinNonEmpty(List<String> parts) =>
      parts.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).join(', ');

  // 🔑 Re-interpret the incoming params from new flow
  final completeAddress = buildingName.trim(); // line1
  final scoFlatHouse    = city.trim();         // optional
  final streetSector    = pincode.trim();      // optional

  final line2 = _joinNonEmpty([scoFlatHouse, streetSector]);

  // We DO NOT guess city/state/postalCode to avoid wrong values
  final body = <String, dynamic>{
    'name': name,
    'phone': phone,
    'startTime': startTime,
    'endTime': endTime,
    'description': description,
    'image_url': imageUrl,
    'address': {
      'line1': completeAddress,
      'line2': line2,       // optional extras land here
      'village': '',
      'district': '',
      'city': '',           // leave blank unless you parse it
      'state': '',          // leave blank unless you parse it
      'country': 'India',
      'postalCode': '',     // leave blank unless you parse a real PIN
      'latitude': latitude,
      'longitude': longitude,
    },
    'selectedCategoryCodes': selectedCategoryCodes,
  };

  // Debug + Crashlytics logs
  final encoder = const JsonEncoder.withIndent('  ');
  final payloadLog = encoder.convert(body);
  debugPrint('[SalonRepository] createSalon payload ->\n$payloadLog');
  FirebaseCrashlytics.instance
      .log('[SalonRepository] createSalon payload -> $payloadLog');

  final endpoint = Uri.parse(ApiService.baseUrl + ApiService.createSalonEndpoint);
  final token = await _apiService.getAuthToken();

  final response = await http.post(
    endpoint,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );

  debugPrint('[SalonRepository] createSalon response ${response.statusCode}: ${response.body}');
  FirebaseCrashlytics.instance.log(
      '[SalonRepository] createSalon response ${response.statusCode}: ${response.body}');

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'createSalon failed (${response.statusCode}): ${response.body}',
      uri: endpoint,
    );
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}

  // ------------------------------------------------------------
  // 3️⃣ Add branch under a salon
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> addBranch({
    required int salonId,
    required String name,
    required String phone,
    required String startTime,
    required String endTime,
    required String description,
    
    required Map<String, dynamic> address,
    required double latitude,
    required double longitude,
    List<File> images = const [],
    List<String> selectedCategoryCodes = const [],
    String? imageUrl,
  }) async {
    String resolvedImageUrl = imageUrl?.trim() ?? '';

    if (resolvedImageUrl.isEmpty && images.isNotEmpty) {
      final urls = await _apiService.uploadMultipleImages(images);
      if (urls.isNotEmpty) resolvedImageUrl = urls.first;
    }

    final body = <String, dynamic>{
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'phone': phone,
      'description': description,
      'image_url': resolvedImageUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'selectedCategoryCodes': selectedCategoryCodes,
    };

    debugPrint('➡️ Creating Branch for Salon ID: $salonId');
    debugPrint('➡️ Payload: $body');

    return _apiService.addSalonBranch(salonId, body);
  }

  // ------------------------------------------------------------
  // 4️⃣ Fetch Branch Catalog (categories & services)
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> fetchSalonCatalog(int branchId) {
    return _apiService.getService(branchId: branchId);
  }

  // ------------------------------------------------------------
  // 5️⃣ Category CRUD
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> addCategory({
    required int branchId,
    required AddCategoryRequest request,
  }) {
    return _apiService.addCategory(branchId: branchId, request: request);
  }

  Future<Map<String, dynamic>> updateCategory({
    required int branchId,
    required int branchCategoryId,
    required AddCategoryRequest request,
  }) {
    return _apiService.updateCategory(
      branchId: branchId,
      branchCategoryId: branchCategoryId,
      request: request,
    );
  }

  Future<Map<String, dynamic>> deleteCategory({
    required int branchId,
    required int CategoryId,
  }) {
    return _apiService.deleteCategoryApi(
      branchId: branchId,
      CategoryId: CategoryId,
    );
  }

  // ------------------------------------------------------------
  // 6️⃣ SubCategory CRUD
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> addSubCategory({
    required int branchId,
    required int categoryId,
    required String displayName,
  }) {
    return _apiService.addSubCategoryApi(
      branchId: branchId,
      categoryId: categoryId,
      displayName: displayName,
    );
  }

  Future<Map<String, dynamic>> updateSubCategory({
    required int branchId,
    required int subCategoryId,
    required String displayName,
    required int sortOrder,
    required bool isActive,
  }) {
    return _apiService.updateSubCategoryApi(
      branchId: branchId,
      subCategoryId: subCategoryId,
      displayName: displayName,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<Map<String, dynamic>> deleteSubCategory({
    required int branchId,
    required int subCategoryId,
  }) {
    return _apiService.deleteSubCategoryApi(
      branchId: branchId,
      subCategoryId: subCategoryId,
    );
  }

  // ------------------------------------------------------------
  // 7️⃣ Service CRUD
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> addService({
    required int branchId,
    required AddSalonServiceRequest request,
  }) {
    return _apiService.addService(branchId: branchId, request: request);
  }

  Future<Map<String, dynamic>> updateService(
    int branchId,
    int branchServiceId,
    Map<String, dynamic> body,
  ) {
    return _apiService.updateService(
      branchId: branchId,
      branchServiceId: branchServiceId,
      body: body,
    );
  }

  Future<Map<String, dynamic>> deleteService({
    required int branchId,
    required int serviceId,
  }) {
    return _apiService.deleteServiceApi(
      branchId: branchId,
      serviceId: serviceId,
    );
  }

  // ------------------------------------------------------------
  // 8️⃣ Offers / Deals
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> createSalonBranchOffer({
    required int branchId,
    required Map<String, dynamic> offerData,
  }) {
    return _apiService.createSalonBranchOffer(branchId, offerData);
  }

  Future<Map<String, dynamic>> fetchSalonOffers(int branchId) {
    return ApiService.getBranchPackagesDeals(branchId);
  }

  Future<Map<String, dynamic>> deleteSalonOffer({
    required int branchId,
    required int offerId,
  }) {
    return _apiService.deleteSalonBranchOfferApi(
      branchId: branchId,
      offerId: offerId,
    );
  }
}
