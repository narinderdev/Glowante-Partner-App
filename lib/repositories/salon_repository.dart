import 'dart:io';

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
    List<File> images = const [],
  }) async {
    String? imageUrl;
    if (images.isNotEmpty) {
      final urls = await _apiService.uploadMultipleImages(images);
      if (urls.isNotEmpty) {
        imageUrl = urls.first;
      }
    }

    return _apiService.createSalon(
      name,
      phone,
      startTime,
      endTime,
      description,
      buildingName,
      city,
      pincode,
      state,
      latitude,
      longitude,
      imageUrl: imageUrl,
    );
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
    required int salonId,
    required int categoryId,
    required AddCategoryRequest request,
  }) {
    return _apiService.updateCategory(
      salonId: salonId,
      categoryId: categoryId,
      name: request.name,
    );
  }

  Future<Map<String, dynamic>> deleteCategory({
    required int salonId,
    required int categoryId,
  }) {
    return _apiService.deleteCategoryApi(
      salonId: salonId,
      categoryId: categoryId,
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
    required int salonId,
    required int subCategoryId,
    required String name,
  }) {
    return _apiService.updateSubCategoryApi(
      salonId: salonId,
      subCategoryId: subCategoryId,
      name: name,
    );
  }

  Future<Map<String, dynamic>> deleteSubCategory({
    required int salonId,
    required int subCategoryId,
  }) {
    return _apiService.deleteSubCategoryApi(
      salonId: salonId,
      subCategoryId: subCategoryId,
    );
  }

  Future<Map<String, dynamic>> deleteService({
    required int salonId,
    required int serviceId,
  }) {
    return _apiService.deleteServiceApi(salonId: salonId, serviceId: serviceId);
  }

  Future<Map<String, dynamic>> addService({
    required int salonId,
    required AddSalonServiceRequest request,
  }) {
    return _apiService.addService(salonId: salonId, request: request);
  }

  Future<Map<String, dynamic>> updateService(
    int salonId,
    int serviceId,
    Map<String, dynamic> body,
  ) {
    return _apiService.updateService(
      salonId: salonId,
      serviceId: serviceId,
      body: body,
    );
  }

  Future<Map<String, dynamic>> createSalonOffer({
    required int salonId,
    required Map<String, dynamic> offerData,
  }) {
    return _apiService.createSalonOffer(salonId, offerData);
  }

  Future<Map<String, dynamic>> fetchSalonOffers(int salonId) {
    return _apiService.getSalonPackagesDealsApi(salonId);
  }

  Future<Map<String, dynamic>> deleteSalonOffer({
    required int salonId,
    required int offerId,
  }) {
    return _apiService.deleteSalonOfferApi(salonId: salonId, offerId: offerId);
  }
}
