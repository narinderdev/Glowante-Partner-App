import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import '../Viewmodels/AddSalonBranchRequest.dart';

class BranchViewModel extends ChangeNotifier {
  final ApiService apiService = ApiService();
  
  // To store the branch details after getting them from the API
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> get branches => _branches;

  // Error handling for adding and getting branches
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Get all branches of a salon
  Future<void> getBranchDetail(int salonId) async {
    try {
      final response = await apiService.getBranchDetail(salonId); // Correct method to get branches
      if (response['success'] == true) {
        _branches = response['data'] ?? [];
        notifyListeners();
      } else {
        throw Exception("Failed to fetch branches.");
      }
    } catch (e) {
      _errorMessage = "Failed to load branches: $e";
      notifyListeners();
    }
  }

  // Add a new branch for the salon
  Future<void> addSalonBranch(int salonId, AddSalonBranchRequest branchRequest) async {
    try {
      final response = await apiService.addSalonBranch(salonId, branchRequest.toJson());
      if (response['success'] == true) {
        _branches.add(response['data']);
        notifyListeners();
      } else {
        throw Exception("Failed to add branch.");
      }
    } catch (e) {
      _errorMessage = "Failed to add branch: $e";
      notifyListeners();
    }
  }
}
