import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

import '../utils/api_service.dart';

import '../Viewmodels/AddCategory.dart';

import '../Viewmodels/AddSalonBranchRequest.dart';

import '../Viewmodels/AddSalonServiceRequest.dart';

class SalonRepository {
  SalonRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

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
    required String buildingName,
    required String city,
    required String pincode,
    required String state,
    required double latitude,
    required double longitude,
    required List<String> serviceCodes,
    List<File> images = const [],
  }) async {
    String? imageUrl;
    if (images.isNotEmpty) {
      final urls = await _apiService.uploadMultipleImages(images);
      if (urls.isNotEmpty) {
        imageUrl = urls.first;
      }
    }

    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'image_url': imageUrl,
      'address': {
        'line1': '$buildingName, $city'.trim(),
        'line2': pincode.isNotEmpty ? '$pincode, ' : '',
        'village': '',
        'district': '',
        'city': city,
        'state': state,
        'country': 'India',
        'postalCode': pincode,
        'latitude': latitude,
        'longitude': longitude,
      },
      'selectedCategoryCodes': serviceCodes,
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final payloadLog = encoder.convert(body);
    debugPrint('[SalonRepository] createSalon payload ->\n$payloadLog');
    FirebaseCrashlytics.instance
        .log('[SalonRepository] createSalon payload -> $payloadLog');

    final endpoint =
        Uri.parse(ApiService.baseUrl + ApiService.createSalonEndpoint);
    final token = await _apiService.getAuthToken();
    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

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

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

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
  }) async {
    String imageUrl = '';

    if (images.isNotEmpty) {
      final urls = await _apiService.uploadMultipleImages(images);

      if (urls.isNotEmpty) {
        imageUrl = urls.first;
      }
    }

    final request = AddSalonBranchRequest(
      name: name,
      phone: phone,
      startTime: startTime,
      endTime: endTime,
      description: description,
      image_url: imageUrl,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );

    return _apiService.addSalonBranch(salonId, request.toJson());
  }

  Future<Map<String, dynamic>> fetchSalonCatalog(int salonId) {
    return _apiService.getService(salonId: salonId);
  }

  Future<Map<String, dynamic>> addCategory({
    required int salonId,
    required AddCategoryRequest request,
  }) {
    return _apiService.addCategory(salonId: salonId, request: request);
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

  Future<Map<String, dynamic>> addSubCategory({
    required int salonId,
    required int categoryId,
    required String name,
  }) {
    return _apiService.addSubCategoryApi(
      salonId: salonId,
      categoryId: categoryId,
      name: name,
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

  Future<Map<String, dynamic>> deleteService({
    required int branchId,
    required int serviceId,
  }) {
    return _apiService.deleteServiceApi(branchId: branchId, serviceId: serviceId);
  }

  Future<Map<String, dynamic>> addService({
    required int salonId,
    required AddSalonServiceRequest request,
  }) {
    return _apiService.addService(salonId: salonId, request: request);
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
