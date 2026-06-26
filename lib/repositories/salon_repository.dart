import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/network_listener.dart';
import '../utils/api_service.dart';
import '../Viewmodels/AddCategory.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';

class SalonRepository {
  SalonRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<Map<String, dynamic>> _openDaySchedulePayload(
    Map<String, List<Map<String, String>>> schedule,
  ) {
    const dayOrder = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final payload = <Map<String, dynamic>>[];

    for (final day in dayOrder) {
      final slots = schedule[day] ?? const <Map<String, String>>[];
      final openSlots = <Map<String, String>>[];
      for (final slot in slots) {
        final start = (slot['start'] ?? slot['startTime'] ?? '').trim();
        final end = (slot['end'] ?? slot['endTime'] ?? '').trim();
        if (start.isEmpty || end.isEmpty) continue;
        openSlots.add({'start': start, 'end': end});
      }
      if (openSlots.isEmpty) continue;
      payload.add({'day': day, 'slots': openSlots});
    }

    return payload;
  }

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

  Future<Map<String, dynamic>> createSalon({
    required String name,
    required String phone,
    required String startTime,
    required String endTime,
    required String description,
    required Map<String, List<Map<String, String>>> schedule,
    required int openingBufferMinutes,
    required int lastBookingBufferMinutes,
    required int lastSlotOverflowGraceMinutes,
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
    List<String> imageUrls = const [],
  }) async {
    final resolvedImageUrls = <String>[];
    void addImageUrl(String? value) {
      final url = value?.trim() ?? '';
      if (url.isNotEmpty && !resolvedImageUrls.contains(url)) {
        resolvedImageUrls.add(url);
      }
    }

    addImageUrl(imageUrl);
    for (final url in imageUrls) {
      addImageUrl(url);
    }
    if (images.isNotEmpty) {
      final uploadedUrls = await _apiService.uploadMultipleImages(images);
      for (final url in uploadedUrls) {
        addImageUrl(url);
      }
    }
    final resolvedImageUrl =
        resolvedImageUrls.isEmpty ? null : resolvedImageUrls.first;

    final completeAddress = buildingName.trim();
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'OPENING_BUFFER_MINUTES': openingBufferMinutes,
      'LAST_BOOKING_BUFFER_MINUTES': lastBookingBufferMinutes,
      'LAST_SLOT_OVERFLOW_GRACE_MINUTES': lastSlotOverflowGraceMinutes,
      'imageUrl': resolvedImageUrl,
      'imageUrls': resolvedImageUrls,
      'schedule': schedule,
      'address': {
        'line1': completeAddress,
        'line2': '',
        'village': '',
        'district': '',
        'city': city.trim(),
        'state': state.trim(),
        'country': 'India',
        'postalCode': pincode.trim(),
        'latitude': latitude,
        'longitude': longitude,
      },
      'selectedCategoryCodes': selectedCategoryCodes,
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final payloadLog = encoder.convert(body);
    debugPrint('[SalonRepository] createSalon payload ->\n$payloadLog');
    FirebaseCrashlytics.instance
        .log('[SalonRepository] createSalon payload -> $payloadLog');

    final endpoint =
        Uri.parse(ApiService.baseUrl + ApiService.createSalonEndpoint);
    final token = await _apiService.getAuthToken();

    late http.Response response;
    try {
      response = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      NetworkManager.reportSuccessfulRequest();
    } catch (error) {
      NetworkManager.reportNetworkIssue(error, uri: endpoint);
      rethrow;
    }

    debugPrint(
        '[SalonRepository] createSalon response ${response.statusCode}: ${response.body}');
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

  Future<Map<String, dynamic>> addBranch({
    required int salonId,
    required String name,
    required String phone,
    required String startTime,
    required String endTime,
    required String description,
    required Map<String, List<Map<String, String>>> schedule,
    required int openingBufferMinutes,
    required int lastBookingBufferMinutes,
    required int lastSlotOverflowGraceMinutes,
    required Map<String, dynamic> address,
    required double latitude,
    required double longitude,
    List<File> images = const [],
    List<String> selectedCategoryCodes = const [],
    String? imageUrl,
    List<String> imageUrls = const [],
    int? sourceBranchId,
  }) async {
    final resolvedImageUrls = <String>[];
    void addImageUrl(String? value) {
      final url = value?.trim() ?? '';
      if (url.isNotEmpty && !resolvedImageUrls.contains(url)) {
        resolvedImageUrls.add(url);
      }
    }

    addImageUrl(imageUrl);
    for (final url in imageUrls) {
      addImageUrl(url);
    }
    if (images.isNotEmpty) {
      final uploadedUrls = await _apiService.uploadMultipleImages(images);
      for (final url in uploadedUrls) {
        addImageUrl(url);
      }
    }
    final resolvedImageUrl =
        resolvedImageUrls.isEmpty ? '' : resolvedImageUrls.first;

    final body = <String, dynamic>{
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'phone': phone,
      'description': description,
      'OPENING_BUFFER_MINUTES': openingBufferMinutes,
      'LAST_BOOKING_BUFFER_MINUTES': lastBookingBufferMinutes,
      'LAST_SLOT_OVERFLOW_GRACE_MINUTES': lastSlotOverflowGraceMinutes,
      'imageUrl': resolvedImageUrl,
      'imageUrls': resolvedImageUrls,
      'schedule': schedule,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'selectedCategoryCodes': selectedCategoryCodes,
      if (sourceBranchId != null) 'sourceBranchId': sourceBranchId,
    };

    debugPrint('➡️ Creating Branch for Salon ID: $salonId');
    debugPrint('➡️ Payload: $body');

    return _apiService.addSalonBranch(salonId, body);
  }

  Future<Map<String, dynamic>> updateSalon({
    required int salonId,
    required String name,
    required String phone,
    required String startTime,
    required String endTime,
    required String description,
    int? openingBufferMinutes,
    int? lastBookingBufferMinutes,
    int? lastSlotOverflowGraceMinutes,
    Map<String, List<Map<String, String>>>? schedule,
    List<String>? selectedCategoryCodes,
    String? imageUrl,
    List<String>? imageUrls,
    Map<String, dynamic>? address,
    double? latitude,
    double? longitude,
  }) {
    final resolvedImageUrl = imageUrl ??
        (imageUrls != null && imageUrls.isNotEmpty ? imageUrls.first : null);
    return _apiService.updateSalon(salonId, {
      'name': name,
      'phone': phone,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      if (openingBufferMinutes != null)
        'OPENING_BUFFER_MINUTES': openingBufferMinutes,
      if (lastBookingBufferMinutes != null)
        'LAST_BOOKING_BUFFER_MINUTES': lastBookingBufferMinutes,
      if (lastSlotOverflowGraceMinutes != null)
        'LAST_SLOT_OVERFLOW_GRACE_MINUTES': lastSlotOverflowGraceMinutes,
      if (schedule != null) 'schedule': _openDaySchedulePayload(schedule),
      if (selectedCategoryCodes != null)
        'selectedCategoryCodes': selectedCategoryCodes,
      if (resolvedImageUrl != null) 'imageUrl': resolvedImageUrl,
      if (imageUrls != null) 'imageUrls': imageUrls,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  Future<Map<String, dynamic>> updateBranch({
    required int branchId,
    required String name,
    required String phone,
    required String startTime,
    required String endTime,
    required String description,
    int? openingBufferMinutes,
    int? lastBookingBufferMinutes,
    int? lastSlotOverflowGraceMinutes,
    Map<String, List<Map<String, String>>>? schedule,
    List<String>? selectedCategoryCodes,
    int? sourceBranchId,
    required Map<String, dynamic> address,
    required double latitude,
    required double longitude,
    String? imageUrl,
    List<String>? imageUrls,
  }) {
    final resolvedImageUrl = imageUrl ??
        (imageUrls != null && imageUrls.isNotEmpty ? imageUrls.first : null);
    return _apiService.updateBranch(branchId, {
      'name': name,
      'phone': phone,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      if (openingBufferMinutes != null)
        'OPENING_BUFFER_MINUTES': openingBufferMinutes,
      if (lastBookingBufferMinutes != null)
        'LAST_BOOKING_BUFFER_MINUTES': lastBookingBufferMinutes,
      if (lastSlotOverflowGraceMinutes != null)
        'LAST_SLOT_OVERFLOW_GRACE_MINUTES': lastSlotOverflowGraceMinutes,
      if (schedule != null) 'schedule': _openDaySchedulePayload(schedule),
      if (selectedCategoryCodes != null)
        'selectedCategoryCodes': selectedCategoryCodes,
      if (sourceBranchId != null) 'sourceBranchId': sourceBranchId,
      if (resolvedImageUrl != null) 'imageUrl': resolvedImageUrl,
      if (imageUrls != null) 'imageUrls': imageUrls,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<Map<String, dynamic>> activateSalon(int salonId) {
    return _apiService.activateSalon(salonId);
  }

  Future<Map<String, dynamic>> deactivateSalon(int salonId) {
    return _apiService.deactivateSalon(salonId);
  }

  Future<Map<String, dynamic>> deleteSalon(int salonId) {
    return _apiService.deleteSalon(salonId);
  }

  Future<Map<String, dynamic>> activateBranch(int branchId) {
    return _apiService.activateBranch(branchId);
  }

  Future<Map<String, dynamic>> deactivateBranch(int branchId) {
    return _apiService.deactivateBranch(branchId);
  }

  Future<Map<String, dynamic>> deleteBranch(int branchId) {
    return _apiService.deleteBranch(branchId);
  }

  Future<Map<String, dynamic>> fetchSalonCatalog(int branchId) {
    return _apiService.getService(branchId: branchId);
  }

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
    required int categoryId,
  }) {
    return _apiService.deleteCategoryApi(
      branchId: branchId,
      CategoryId: categoryId,
    );
  }

  // Future<Map<String, dynamic>> addSubCategory({
  //   required int branchId,
  //   required int categoryId,
  //   required String displayName,
  // }) {
  //   return _apiService.addSubCategoryApi(
  //     branchId: branchId,
  //     categoryId: categoryId,
  //     displayName: displayName,
  //   );
  // }
  Future<Map<String, dynamic>> addSubCategory({
    required int branchId,
    required int categoryId,
    required String displayName,
  }) {
    return _apiService.addSubCategoryApi(
      branchId: branchId,
      branchCategoryId: categoryId,
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
