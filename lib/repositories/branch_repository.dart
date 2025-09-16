import '../utils/api_service.dart';

class BranchRepository {
  BranchRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<Map<String, dynamic>> fetchBranchDetail(int branchId) {
    return _apiService.getBranchDetail(branchId);
  }

  Future<Map<String, dynamic>> fetchBranchOffers(int branchId) {
    return ApiService.getBranchPackagesDeals(branchId);
  }

  Future<Map<String, dynamic>> createBranchOffer({
    required int branchId,
    required Map<String, dynamic> offerData,
  }) {
    return _apiService.createSalonBranchOffer(branchId, offerData);
  }
}
