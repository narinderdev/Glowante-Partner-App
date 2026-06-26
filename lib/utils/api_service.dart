import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // 👈 needed for File
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/aws_s3_uploader.dart'; // 👈 import uploader
import 'package:image_picker/image_picker.dart'; // 👈 add this
import '../services/auth_session_manager.dart';
import '../services/network_listener.dart';
import '../services/token_expiration_service.dart';
import '../Viewmodels/AddCategory.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import 'error_parser.dart';
import 'dart:async';

class _AuthHttpClient extends http.BaseClient {
  _AuthHttpClient();

  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request);
      NetworkManager.reportSuccessfulRequest();
      if (_shouldTriggerLogout(response.statusCode, request.headers)) {
        scheduleMicrotask(_handleUnauthorized);
      }
      return response;
    } catch (error) {
      NetworkManager.reportNetworkIssue(error, uri: request.url);
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  bool _shouldTriggerLogout(int statusCode, Map<String, String> headers) {
    if (statusCode != 401) return false;
    final authHeader = headers['Authorization'] ?? headers['authorization'];
    return authHeader != null && authHeader.trim().isNotEmpty;
  }

  void _handleUnauthorized() {
    unawaited(_clearSessionIfTokenPresent());
  }

  Future<void> _clearSessionIfTokenPresent() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    if (token == null || token.isEmpty) {
      return;
    }
    await AuthSessionManager.instance.forceLogout(reason: 'session_expired');
  }
}

final http.Client _authorizedHttpClient = _AuthHttpClient();

class ApiService {
  static http.Client get _sharedClient => _authorizedHttpClient;

  static void _debugPrintChunked(
    String tag,
    Object? message, {
    int chunkSize = 800,
  }) {
    final text = (message ?? '').toString();
    if (text.isEmpty) {
      debugPrint('[$tag] ');
      return;
    }

    for (int start = 0; start < text.length; start += chunkSize) {
      final end =
          (start + chunkSize < text.length) ? start + chunkSize : text.length;
      debugPrint('[$tag] ${text.substring(start, end)}');
    }
  }

  // static const String baseUrl = "http://64.227.148.231:3000/";
  // static const String baseUrl = "https://api.glowante.com/";
  static const String baseUrl = "https://dev-api.glowante.com/";
  // static const String baseUrl = "https://test-api.glowante.com/";
  // static const String baseUrl = "https://b86c-203-190-154-162.ngrok-free.app/";
  static const String userLogin = "auth/login";
  static const String verifyOtpEndpoint = "auth/verify-otp";
  static const String registerUserEndpoint = "auth/register";
  static const String resendOtpEndpoint = "auth/resend_otp";
  static const String updateUserProfile = "users/update";
  static const String createSalonEndpoint = "salons/create";
  static const String getSalonList = "salons/my";
  static const String logoutUser = "auth/logout";
  static const String deleteUser = "users/delete";
  static const String deleteAccount = "users/delete-account";
  static const String serviceCatalog = "service-catalog";
  static const String getBranchServices = "salon-service/catalog";
  static const String addSubCategory =
      "/branches/{branchId}/categories/{categoryId}/subcategories";
  static const String checkSendOtpEndpoint = "users/check-and-send-otp";
  static String addServiceAPI(int branchId) => "branches/$branchId/services";

  static String getSalonServicesAPI(int branchId) =>
      "branches/$branchId/services";

  static String addCategoryAPI(int salonId) {
    return "salons/$salonId/categories";
  }

  static String getCategoriesAPI(int salonId, {bool withSubcats = true}) =>
      "salons/$salonId/categories?withSubcats=$withSubcats";

  static String updateCategoryAPI(int branchId, int branchCategoryId) =>
      "branches/$branchId/categories/$branchCategoryId";

  // static String deleteCategoryAPI(int salonId, int categoryId) =>
  //     "salons/$salonId/categories/$categoryId";

  static String addSalonBranchAPI(int salonId) {
    return "salons/$salonId/branches/add";
  }

  static String updateBranchAPI(int branchId) {
    return "branches/$branchId";
  }

  static String activateBranchAPI(int branchId) {
    return "branches/$branchId/activate";
  }

  static String deactivateBranchAPI(int branchId) {
    return "branches/$branchId/deactivate";
  }

  static String deleteBranchAPI(int branchId) {
    return "branches/$branchId";
  }

  static String updateSalonAPI(int salonId) {
    return "salons/$salonId";
  }

  static String activateSalonAPI(int salonId) {
    return "salons/$salonId/activate";
  }

  static String deactivateSalonAPI(int salonId) {
    return "salons/$salonId/deactivate";
  }

  static String deleteSalonAPI(int salonId) {
    return "salons/$salonId";
  }

  static String addTeamMemberEndpoint(int id) {
    return "branches/$id/add-user";
  }

  static String addSalonTeamMemberEndpoint(int salonId) {
    return "salons/$salonId/users";
  }

  static String updateTeamMemberEndpoint(int branchId, int userId) {
    return "branches/$branchId/team/$userId";
  }

  static String activateTeamMemberEndpoint(int branchId, int userId) {
    return "branches/$branchId/team/$userId/activate";
  }

  static String deactivateTeamMemberEndpoint(int branchId, int userId) {
    return "branches/$branchId/team/$userId/deactivate";
  }

  static String teamAttendanceCheckInOutEndpoint(int branchId, int userId) {
    return "branches/$branchId/team/$userId/check-in-out";
  }

  static String teamAttendanceHistoryEndpoint(
    int branchId,
    int userId, {
    required int month,
    required int year,
  }) {
    return Uri(
      path: "branches/$branchId/team/$userId/check-in-out-history",
      queryParameters: <String, String>{
        'month': month.toString(),
        'year': year.toString(),
      },
    ).toString();
  }

  static String getBranchServicesAPI(int branchId) =>
      "branches/$branchId/services";
  static String linkBranchClientAPI(int branchId) =>
      "branches/$branchId/clients/link";
  static const String membershipPlansAPI = "admin/membership-plans";
  static String salonSubscriptionAPI(int salonId) =>
      "admin/salons/$salonId/subscription";
  static String salonSubscriptionsAPI(int salonId) =>
      "admin/salons/$salonId/subscriptions";
  static String getBranchServicesFlatAPI(int branchId) =>
      "branches/$branchId/services/flat";
  static String importPredefinedServicesAPI(int branchId) =>
      "branches/$branchId/services/import-predefined";
  static String getInventoryItemsAPI(
    int branchId, {
    int page = 1,
    int limit = 20,
  }) =>
      "branches/$branchId/inventory-items?page=$page&limit=$limit";
  static String getBranchVendorsAPI(int branchId) =>
      "branches/$branchId/vendors";
  static String getVendorDetailsAPI(int branchId, int vendorId) =>
      "branches/$branchId/vendors/$vendorId";
  static String getBranchStoreAPI(int branchId) => "branches/$branchId/store";
  static String branchRolesAPI(int branchId) => "branches/$branchId/roles";
  static String branchRoleDetailsAPI(int branchId, int roleId) =>
      "branches/$branchId/roles/$roleId";
  static String branchDashboardAPI(int branchId) =>
      "v2/branches/$branchId/dashboard";
  static String payrollSetupTeamMembersAPI(int branchId) =>
      "v2/branches/$branchId/payroll-setup/team-members";
  static String employeeSalaryHistoryAPI(int employeeId) =>
      "v2/employees/$employeeId/salary";
  static String employeeSalaryConfigAPI(int employeeId, int salaryId) =>
      "v2/employees/$employeeId/salary/$salaryId";
  static String generatePayrollAPI(
    int branchId, {
    required int month,
    required int year,
  }) =>
      "v2/branches/$branchId/payroll/generate?month=$month&year=$year";
  static String cancelPayrollAPI(int branchId, String payrollId) =>
      "v2/branches/$branchId/payroll/${Uri.encodeComponent(payrollId)}/cancel";
  static String branchAdvancesAPI(
    int branchId, {
    required int month,
    required int year,
  }) =>
      "v2/branches/$branchId/advances?month=$month&year=$year";
  static String employeeAdvancesAPI(int branchId, int employeeId) =>
      "v2/branches/$branchId/employees/$employeeId/advances";
  static String getStoreDetailsAPI(int branchId, int storeId) =>
      "branches/$branchId/store/$storeId";
  static String getInventoryItemDetailsAPI(int branchId, int inventoryId) =>
      "branches/$branchId/inventory-items/$inventoryId";
  static String getInventoryItemCategoriesOptionsAPI(int branchId) =>
      "branches/$branchId/inventory-items/categories/options";
  static String getPurchaseOrdersAPI(int branchId) =>
      "branches/$branchId/procurement/po";
  static String getPurchaseOrderDetailsAPI(int branchId, int poId) =>
      "branches/$branchId/procurement/po/$poId";
  static String updatePurchaseOrderStatusAPI(int branchId, int poId) =>
      "branches/$branchId/procurement/po/$poId/status";
  static String getGoodsReceiptNotesAPI(int branchId) =>
      "branches/$branchId/procurement/grn";
  static String getGoodsReceiptNoteDetailsAPI(int branchId, int grnId) =>
      "branches/$branchId/procurement/grn/$grnId";
  static String payrollReviewDetailsAPI(int branchId, String payrollId) =>
      "v2/branches/$branchId/review/payroll/$payrollId";
  static String payrollPaidLeavesReviewAPI(
    int branchId, {
    String? payrollId,
  }) =>
      payrollId == null || payrollId.trim().isEmpty
          ? "v2/branches/$branchId/review/paid-leaves"
          : "v2/branches/$branchId/review/paid-leaves?payrollId=$payrollId";
  static String payrollEmployeeAdjustmentsAPI(int payrollEmployeeId) =>
      "v2/payroll/$payrollEmployeeId/adjustments";

  static String payrollEmployeeAdjustmentDetailsAPI(
    int payrollEmployeeId,
    String adjustmentId,
  ) =>
      "v2/payroll/$payrollEmployeeId/adjustments/$adjustmentId";

  static const String payrollAdditionalChargesAPI =
      "payroll/additional-charges";

  static String payrollAdditionalChargeDetailsAPI(String chargeId) =>
      "payroll/additional-charges/$chargeId";

  static const String payrollDeductionsAPI = "payroll/deductions";

  static String payrollDeductionDetailsAPI(String deductionId) =>
      "payroll/deductions/$deductionId";
  static String payrollEmployeePaidLeaveAPI(int payrollEmployeeId) =>
      "v2/payroll/$payrollEmployeeId/paid-leave";
  static String branchPayrollPaidLeaveConfigAPI(int branchId) =>
      "v2/branches/$branchId/payroll/paid-leave-config";
  static String branchTeamAttendanceHistoryAPI(
    int branchId, {
    required int month,
    required int year,
  }) =>
      "branches/$branchId/team/check-in-out-history?month=$month&year=$year";
  static String salonHolidayCalendarAPI(
    int salonId, {
    int? month,
    int? year,
  }) {
    final hasMonth = month != null;
    final hasYear = year != null;
    if (!hasMonth && !hasYear) {
      return "salons/$salonId/holiday-calendar";
    }
    return "salons/$salonId/holiday-calendar?month=${month ?? ''}&year=${year ?? ''}";
  }

  static String salonHolidayCalendarDetailsAPI(int salonId, int holidayId) =>
      "salons/$salonId/holiday-calendar/$holidayId";
  static String getRolesSpecialization({int? branchId}) {
    if (branchId == null) return "users/constants";
    return "users/constants?branchId=$branchId";
  }

  static String getTeamMember(int id) {
    return "branches/$id/team";
  }

  static String addSalonOffer(int salonId) {
    return "salons/$salonId/offers";
  }

  static String getSalonPackagesDeals(int branchId) {
    return "branches/$branchId/offers";
  }

  static String deleteSalonOffer(int salonId, int offerId) {
    return "salons/$salonId/offers/$offerId";
  }

  static String setSalonOfferLive(int salonId, int offerId) {
    return "salons/$salonId/offers/$offerId/live";
  }

  static String setSalonOfferInactive(int salonId, int offerId) {
    return "salons/$salonId/offers/$offerId/inactive";
  }

  static String updateSalonBranchOffer(int branchId, int offerId) {
    return "branches/$branchId/offers/$offerId/override";
  }

  static String deleteSalonBranchOffer(int branchId, int offerId) {
    return "branches/$branchId/offers/$offerId";
  }

  static String setBranchOfferLive(int branchId, int offerId) {
    return "branches/$branchId/offers/$offerId/live";
  }

  static String setBranchOfferInactive(int branchId, int offerId) {
    return "branches/$branchId/offers/$offerId/inactive";
  }

  static String getSalonUser(int salonId, bool isActiveOnly) {
    return "salons/$salonId/users?activeOnly=true";
  }

  static String getBranchPackagesDealsUrl(int branchId) {
    return "${baseUrl}branches/$branchId/offers";
  }

  // get appointments
  static String getAppointmentByDate(int branchId, String date) {
    return "branches/$branchId/appointments/by-date?date=$date";
  }

  static String getMyAppointmentsAPI(int branchId) {
    return "branches/$branchId/appointments/mine";
  }

  static String getTeamAppointmentsByDateAPI(
    int branchId,
    int userId,
    String date,
  ) {
    return "branches/$branchId/appointments/team/$userId/by-date?date=$date";
  }

  static String confirmAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/confirm";
  }

  static String addSalonBranchOffer(int branchId) {
    return "branches/$branchId/offers";
  }

  static String startAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/start";
  }

  static String noShowAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/no-show";
  }

  static String completeAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/complete";
  }

  // get appointments
  static String getBranchRatings(int branchId) {
    return "branches/$branchId/appointments/ratings";
  }

  static String updateBranchCategory(int branchId, int branchCategoryId) {
    return "branches/$branchId/categories/$branchCategoryId";
  }

  static String updateBranchSubCategory(int branchId, int branchSubCategoryId) {
    return "branches/$branchId/subcategories/$branchSubCategoryId";
  }

  static String updateBranchService(int branchId, int branchServiceId) {
    return "branches/$branchId/services/$branchServiceId";
  }

  static String deleteBranchCategory(int branchId, int branchCategoryId) {
    return "branches/$branchId/services/category/$branchCategoryId";
  }

  static String deleteBranchSubCategory(int branchId, int branchSubCategoryId) {
    return "branches/$branchId/services/subCategory/$branchSubCategoryId";
  }

  static String deleteBranchService(int branchId, int branchServiceId) {
    return "branches/$branchId/services/$branchServiceId";
  }

  static String resolveWalkinNumberAPI(int branchId) {
    return "branches/$branchId/walkins/resolve-number";
  }

  static String getBranchClientsAPI(int branchId) {
    return "branches/$branchId/branch-client";
  }

  static String getBranchCustomersListAPI(int branchId) {
    return "branches/$branchId/customers-list";
  }

  static String getClientPurchasesAPI(int branchId, int clientId) {
    return "branches/$branchId/cart/purchases?clientId=$clientId";
  }

  static String getBranchCartAPI(int branchId, int userId) {
    return "branches/$branchId/cart?userId=$userId";
  }

  static String addCartItemsBulkAPI(int branchId) {
    return "branches/$branchId/cart/items/bulk";
  }

  static String updateCartItemAPI(int branchId, int itemId, {int? userId}) {
    final base = "branches/$branchId/cart/items/$itemId";
    return userId == null ? base : "$base?userId=$userId";
  }

  static String deleteCartItemAPI(int branchId, int itemId, {int? userId}) {
    final base = "branches/$branchId/cart/items/$itemId";
    return userId == null ? base : "$base?userId=$userId";
  }

  static String updateSalonOffer(int salonId, int offerId) {
    return "salons/$salonId/offers/$offerId";
  }

  //This below 4 api is pending to implement on frontend
  // Confirm Booking appointment (see static helper above)
  static String createAppointmentAPI(int branchId) {
    return "branches/$branchId/appointments/branch";
  }

  static String createManualBookingAPI(int branchId) {
    return "branches/$branchId/appointments/branch";
  }

  static String appointmentAvailabilityAPI(int branchId) {
    return "branches/$branchId/appointments/availability";
  }

  static String assignUserToBranchAPI(int branchId) {
    return "branches/$branchId/assign-user";
  }

  static String getSalonDetailAPI(int salonId) {
    return "salons/$salonId";
  }

  static String getSalon(int salonId, String status) {
    return "bookings/salon-bookings/$salonId?status=$status";
  }

  static String importClientsFileAPI(int branchId) {
    return "branches/$branchId/clients/import-file";
  }

  static String importClientsByPhoneAPI(int branchId) {
    return "branches/$branchId/clients/import-by-phone";
  }

  static const String reportsDashboardAPI = "reports/dashboard";
  static const String salonOwnerDashboardAPI = "reports/salon-owner-dashboard";
  static const String revenueSalesDashboardAPI =
      "reports/revenue-sales-dashboard";
  static const String staffPerformanceAPI = "reports/staff-performance";
  static const String operationsDashboardAPI = "reports/operations-dashboard";
  static const String aiInsightsDashboardSummaryAPI =
      "insights/dashboard-summary";

  // / ---------------------- IMAGE UPLOAD ----------------------

  // Future<String?> uploadImage(File file) async {
  //   // convert File -> XFile wrapper for AwsS3Uploader
  //   final url = await AwsS3Uploader.uploadImage(XFile(file.path));
  //   return url;
  // }

  Future<String?> uploadImage(File file) async {
    final uploader = AwsS3Uploader(); // create instance
    final url = await uploader.uploadImage(XFile(file.path));
    return url;
  }

  Future<List<String>> uploadMultipleImages(List<File> files) async {
    List<String> urls = [];
    for (File file in files) {
      final url = await uploadImage(file);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  Future<Map<String, dynamic>> getMembershipPlans() {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: membershipPlansAPI,
      debugTag: 'MembershipPlans',
    );
  }

  Future<Map<String, dynamic>> createMembershipPlan({
    required String name,
    required int monthlyPriceMinor,
    required int annualPriceMinor,
    required int branchLimit,
    required int staffLimit,
    required int storageLimit,
    required List<String> includedFeatures,
    required String status,
    required bool isRecommended,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: membershipPlansAPI,
      debugTag: 'CreateMembershipPlan',
      body: <String, dynamic>{
        'name': name,
        'monthlyPriceMinor': monthlyPriceMinor,
        'annualPriceMinor': annualPriceMinor,
        'branchLimit': branchLimit,
        'staffLimit': staffLimit,
        'storageLimit': storageLimit,
        'includedFeatures': includedFeatures,
        'status': status,
        'isRecommended': isRecommended,
      },
    );
  }

  Future<Map<String, dynamic>> getSalonSubscription(int salonId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: salonSubscriptionAPI(salonId),
      debugTag: 'SalonSubscription',
    );
  }

  Future<Map<String, dynamic>> createSalonSubscription({
    required int salonId,
    required int planId,
    required String billingCycle,
    required String paymentReference,
    required bool renew,
    DateTime? startDate,
    String? paymentStatus,
    String? razorpayOrderId,
    String? razorpaySignature,
    int? amountMinor,
    String currency = 'INR',
    bool replaceCurrentPlan = false,
  }) async {
    final normalizedBillingCycle =
        billingCycle.toUpperCase() == 'YEARLY' ? 'ANNUAL' : billingCycle;
    final payload = <String, dynamic>{
      'planId': planId,
      'billingCycle': normalizedBillingCycle,
      'renew': renew,
      'paymentReference': paymentReference,
      'razorpayPaymentId': paymentReference,
      if (startDate != null)
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
        'paymentStatus': paymentStatus.trim().toUpperCase(),
      if (razorpayOrderId != null && razorpayOrderId.isNotEmpty)
        'razorpayOrderId': razorpayOrderId,
      if (razorpaySignature != null && razorpaySignature.isNotEmpty)
        'razorpaySignature': razorpaySignature,
      if (amountMinor != null) 'amountMinor': amountMinor,
      'currency': currency,
      if (replaceCurrentPlan) 'replaceCurrentPlan': true,
    };

    final response = await _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionsAPI(salonId),
      debugTag: 'CreateSalonSubscription',
      body: payload,
    );
    if (response['success'] == true) return response;
    final statusCode = response['statusCode'];
    if (statusCode != 404 && statusCode != 405) return response;

    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionAPI(salonId),
      debugTag: 'CreateSalonSubscriptionSingular',
      body: payload,
    );
  }

  Future<Map<String, dynamic>> activateSalonSubscriptionNow({
    required int salonId,
    required int planId,
    required String billingCycle,
    int? upcomingMembershipId,
  }) async {
    final normalizedBillingCycle =
        billingCycle.toUpperCase() == 'YEARLY' ? 'ANNUAL' : billingCycle;
    final payload = <String, dynamic>{
      'planId': planId,
      'billingCycle': normalizedBillingCycle,
      'replaceCurrentPlan': true,
      if (upcomingMembershipId != null) ...{
        'upcomingMembershipId': upcomingMembershipId,
        'subscriptionId': upcomingMembershipId,
        'membershipId': upcomingMembershipId,
      },
    };

    final response = await _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionsAPI(salonId),
      debugTag: 'ActivateSalonSubscriptionNow',
      body: payload,
    );
    if (response['success'] == true) return response;
    final statusCode = response['statusCode'];
    final message = response['message']?.toString().toLowerCase() ?? '';
    final shouldTrySingular = statusCode == 404 ||
        statusCode == 405 ||
        (statusCode == 400 &&
            message.contains('upcoming membership already exists'));
    if (!shouldTrySingular) return response;

    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionAPI(salonId),
      debugTag: 'ActivateSalonSubscriptionNowSingular',
      body: payload,
    );
  }

  Future<Map<String, dynamic>> getBranchRoles(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchRolesAPI(branchId),
      debugTag: 'BranchRoles',
    );
  }

  Future<Map<String, dynamic>> createBranchRole({
    required int branchId,
    required String label,
    required List<int> permissionIds,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: branchRolesAPI(branchId),
      debugTag: 'CreateBranchRole',
      body: <String, dynamic>{
        'label': label,
        'permissionIds': permissionIds,
      },
    );
  }

  Future<Map<String, dynamic>> updateBranchRole({
    required int branchId,
    required int roleId,
    required String label,
    required List<int> permissionIds,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: branchRoleDetailsAPI(branchId, roleId),
      debugTag: 'UpdateBranchRole',
      body: <String, dynamic>{
        'label': label,
        'permissionIds': permissionIds,
      },
    );
  }

  Future<Map<String, dynamic>> addCartItemsBulk({
    required int branchId,
    required List<Map<String, dynamic>> items,
    int? userId,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: addCartItemsBulkAPI(branchId),
      debugTag: 'AddCartItemsBulk',
      body: <String, dynamic>{
        'items': items,
        if (userId != null) 'userId': userId,
      },
    );
  }

  Future<Map<String, dynamic>> getBranchCart({
    required int branchId,
    required int userId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getBranchCartAPI(branchId, userId),
      debugTag: 'GetBranchCart',
    );
  }

  Future<Map<String, dynamic>> updateCartItem({
    required int branchId,
    required int itemId,
    required int qty,
    required String notes,
    int? userId,
    int? selectedProId,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: updateCartItemAPI(branchId, itemId, userId: userId),
      debugTag: 'UpdateCartItem',
      body: <String, dynamic>{
        'qty': qty,
        'notes': notes,
        if (selectedProId != null) 'selectedProId': selectedProId,
      },
    );
  }

  Future<Map<String, dynamic>> deleteCartItem({
    required int branchId,
    required int itemId,
    int? userId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: deleteCartItemAPI(branchId, itemId, userId: userId),
      debugTag: 'DeleteCartItem',
    );
  }

  Future<Map<String, dynamic>> loadAppointmentAvailability({
    required int branchId,
    required String date,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: appointmentAvailabilityAPI(branchId),
      debugTag: 'AppointmentAvailability',
      body: <String, dynamic>{'date': date},
    );
  }

  // ---------------------- AUTH HELPERS ----------------------

  Future<String> getAuthToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('user_token');

    if (token == null || token.isEmpty) {
      return '';
    }

    if (TokenExpirationService.isTokenExpired(token)) {
      await AuthSessionManager.instance.forceLogout(reason: 'session_expired');
      return '';
    }

    return token;
  }

  Future<Map<String, dynamic>> _authorizedJsonRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    required String debugTag,
  }) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        return {
          'success': false,
          'message': 'No token found',
          'data': const <String, dynamic>{},
        };
      }

      final url = Uri.parse(baseUrl + endpoint);
      debugPrint('[$debugTag] $method $url');
      if (body != null) {
        _debugPrintChunked('$debugTag payload', body);
      }

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
      };
      if (body != null && method.toUpperCase() != 'GET') {
        headers['Content-Type'] = 'application/json';
      }

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _sharedClient.get(url, headers: headers);
          break;
        case 'POST':
          response = await _sharedClient.post(
            url,
            headers: headers,
            body: jsonEncode(body ?? const <String, dynamic>{}),
          );
          break;
        case 'PATCH':
          response = await _sharedClient.patch(
            url,
            headers: headers,
            body: jsonEncode(body ?? const <String, dynamic>{}),
          );
          break;
        case 'DELETE':
          response = await _sharedClient.delete(url, headers: headers);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }

      debugPrint('[$debugTag] status=${response.statusCode}');
      _debugPrintChunked(
        '$debugTag body',
        debugTag == 'MarkTeamAttendance'
            ? _attendanceBodyWithIst(response.body)
            : response.body,
      );

      dynamic decoded;
      if (response.body.isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = response.body;
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          'success': true,
          'data': decoded,
        };
      }

      if (decoded is Map<String, dynamic>) {
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Request failed',
          'data': decoded['data'] ?? decoded,
          'statusCode': response.statusCode,
        };
      }

      return {
        'success': false,
        'message': response.body.isEmpty ? 'Request failed' : response.body,
        'data': decoded ?? const <String, dynamic>{},
        'statusCode': response.statusCode,
      };
    } catch (error) {
      debugPrint('[$debugTag] error=$error');
      return {
        'success': false,
        'message': error.toString(),
        'data': const <String, dynamic>{},
      };
    }
  }

  String _attendanceBodyWithIst(String rawBody) {
    if (rawBody.isEmpty) return rawBody;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) return rawBody;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        for (final key in const ['checkedInAt', 'checkedOutAt']) {
          data[key] = _utcIsoToIstIso(data[key]);
        }
      }
      return jsonEncode(decoded);
    } catch (_) {
      return rawBody;
    }
  }

  String? _utcIsoToIstIso(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString().trim());
    if (parsed == null) return value?.toString();
    final utc = parsed.isUtc ? parsed : parsed.toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    final localIst = DateTime(
      ist.year,
      ist.month,
      ist.day,
      ist.hour,
      ist.minute,
      ist.second,
      ist.millisecond,
      ist.microsecond,
    );
    return localIst.toIso8601String();
  }

  // Login
  Future<Map<String, dynamic>> loginUser(String phoneNumber,
      {String? deviceToken}) async {
    final loginPayload = {
      "phoneNumber": phoneNumber,
      "source": "app",
    };

    String? resolvedToken = deviceToken;
    if (resolvedToken == null || resolvedToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      resolvedToken = prefs.getString('fcm_device_token');
    }
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      loginPayload['deviceToken'] = resolvedToken;
    }

    final response = await _sharedClient.post(
      Uri.parse(baseUrl + userLogin),
      headers: {"Content-Type": "application/json"},
      body: json.encode(loginPayload),
    );

    debugPrint("[LoginAPI] status=${response.statusCode}");
    _debugPrintChunked("LoginAPI body", response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      _debugPrintChunked("LoginAPI decoded", decoded);
      return decoded;
    } else {
      throw Exception("Failed login: ${response.body}");
    }
  }

  // Verify OTP
  // Future<Map<String, dynamic>> verifyOTP(String phoneNumber, String otp) async {
  //   final response = await _sharedClient.post(
  //     Uri.parse(baseUrl + verifyOtpEndpoint),
  //     headers: {"Content-Type": "application/json"},
  //     body: json.encode({"phoneNumber": phoneNumber, "otp": otp}),
  //   );

  //   debugPrint("[VerifyOTP] status=${response.statusCode}");
  //   _debugPrintChunked("VerifyOTP body", response.body);

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     final decoded = json.decode(response.body);
  //     _debugPrintChunked("VerifyOTP decoded", decoded);
  //     return decoded;
  //   } else {
  //     throw Exception("Failed OTP: ${response.body}");
  //   }
  // }
  Future<Map<String, dynamic>> verifyOTP(String phoneNumber, String otp) async {
    final response = await _sharedClient.post(
      Uri.parse(baseUrl + verifyOtpEndpoint),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "phoneNumber": phoneNumber,
        "otp": otp,
      }),
    );

    debugPrint("[VerifyOTP] status=${response.statusCode}");
    _debugPrintChunked("VerifyOTP body", response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      _debugPrintChunked("VerifyOTP decoded", decoded);
      return decoded;
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (decoded is Map<String, dynamic>) {
      return {
        'success': false,
        'message': decoded['message']?.toString() ?? 'Invalid OTP',
        'statusCode': response.statusCode,
      };
    }

    return {
      'success': false,
      'message': 'Invalid OTP',
      'statusCode': response.statusCode,
    };
  }
  // Future<Map<String, dynamic>> registerCustomer({
  //   required String phoneNumber,
  //   required String firstName,
  //   required String lastName,
  //   String source = 'salon_app',
  //   String? deviceToken,
  // }) async {
  //   String? resolvedToken = deviceToken;
  //   if (resolvedToken == null || resolvedToken.isEmpty) {
  //     final prefs = await SharedPreferences.getInstance();
  //     resolvedToken = prefs.getString('fcm_device_token');
  //   }

  //   final payload = <String, dynamic>{
  //     "phoneNumber": phoneNumber,
  //     "source": source,
  //     "firstName": firstName,
  //     "lastName": lastName,
  //     if (resolvedToken != null && resolvedToken.isNotEmpty)
  //       "deviceToken": resolvedToken,
  //   };

  //   final response = await _sharedClient.post(
  //     Uri.parse(baseUrl + registerUserEndpoint),
  //     headers: {"Content-Type": "application/json"},
  //     body: json.encode(payload),
  //   );

  //   debugPrint("[RegisterCustomer] status=${response.statusCode}");
  //   _debugPrintChunked("RegisterCustomer body", response.body);

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     return json.decode(response.body) as Map<String, dynamic>;
  //   }
  //   throw Exception("Failed register customer: ${response.body}");
  // }
  Future<Map<String, dynamic>> registerCustomer({
    required String phoneNumber,
    required String firstName,
    required String lastName,
    String source = 'salon_app',
    String? deviceToken,
  }) async {
    String resolvedToken = deviceToken?.trim() ?? '';

    if (resolvedToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      resolvedToken = prefs.getString('fcm_device_token')?.trim() ?? '';
    }

    if (resolvedToken.isEmpty) {
      resolvedToken = 'unknown';
    }

    final payload = <String, dynamic>{
      "phoneNumber": phoneNumber,
      "source": source,
      "firstName": firstName,
      "lastName": lastName,
      "deviceToken": resolvedToken,
    };

    debugPrint("[RegisterCustomer payload] $payload");

    final response = await _sharedClient.post(
      Uri.parse(baseUrl + registerUserEndpoint),
      headers: {"Content-Type": "application/json"},
      body: json.encode(payload),
    );

    debugPrint("[RegisterCustomer] status=${response.statusCode}");
    _debugPrintChunked("RegisterCustomer body", response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (decoded is Map<String, dynamic>) {
      return {
        'success': false,
        'message': decoded['message'] is List
            ? (decoded['message'] as List).join('\n')
            : decoded['message']?.toString() ?? 'Failed register customer',
        'statusCode': response.statusCode,
      };
    }

    return {
      'success': false,
      'message': 'Failed register customer',
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> linkBranchClient({
    required int branchId,
    required int userId,
  }) async {
    final token = await getAuthToken();
    final response = await _sharedClient.post(
      Uri.parse(baseUrl + linkBranchClientAPI(branchId)),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"userId": userId}),
    );

    debugPrint("[LinkBranchClient] status=${response.statusCode}");
    _debugPrintChunked("LinkBranchClient body", response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body.isEmpty
          ? <String, dynamic>{"success": true}
          : json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed link branch client: ${response.body}");
  }

  Future<Map<String, dynamic>> getBranchClients(
    int branchId, {
    String? selectedDateRange,
    String? tab,
    int? page,
  }) async {
    final token = await getAuthToken();
    final queryParameters = <String, String>{
      if (selectedDateRange != null) 'selectedDateRange': selectedDateRange,
      if (tab != null) 'tab': tab,
      if (page != null) 'page': page.toString(),
    };
    final baseUri = Uri.parse(baseUrl + getBranchClientsAPI(branchId));
    final uri = queryParameters.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParameters);
    final response = await _sharedClient.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[GetBranchClients] url=$uri");
    debugPrint("[GetBranchClients] status=${response.statusCode}");
    _debugPrintChunked("GetBranchClients body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = response.body.isEmpty ? '{}' : response.body;
      return json.decode(body) as Map<String, dynamic>;
    }
    throw Exception("Failed to fetch branch clients: ${response.body}");
  }

  Future<Map<String, dynamic>> getBranchCustomersList(int branchId) async {
    final token = await getAuthToken();
    final uri = Uri.parse(baseUrl + getBranchCustomersListAPI(branchId));
    final response = await _sharedClient.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[GetBranchCustomersList] url=$uri");
    debugPrint("[GetBranchCustomersList] status=${response.statusCode}");
    _debugPrintChunked("GetBranchCustomersList body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = response.body.isEmpty ? '{}' : response.body;
      return json.decode(body) as Map<String, dynamic>;
    }
    throw Exception("Failed to fetch branch customers: ${response.body}");
  }

  Future<Map<String, dynamic>> getClientPurchases({
    required int branchId,
    required int clientId,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + getClientPurchasesAPI(branchId, clientId));
    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[GetClientPurchases] url=$url");
    debugPrint("[GetClientPurchases] status=${response.statusCode}");
    _debugPrintChunked("GetClientPurchases body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = response.body.isEmpty ? '{}' : response.body;
      final decoded = json.decode(body);
      debugPrint(
        "[GetClientPurchases] decodedType=${decoded.runtimeType}",
      );
      if (decoded is Map<String, dynamic>) {
        debugPrint(
          "[GetClientPurchases] topLevelKeys=${decoded.keys.toList()}",
        );
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          debugPrint(
            "[GetClientPurchases] dataKeys=${data.keys.toList()}",
          );
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          final first = Map<String, dynamic>.from(data.first as Map);
          debugPrint(
            "[GetClientPurchases] firstItemKeys=${first.keys.toList()}",
          );
        }
      } else if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map) {
        final first = Map<String, dynamic>.from(decoded.first as Map);
        debugPrint(
          "[GetClientPurchases] firstItemKeys=${first.keys.toList()}",
        );
      }
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    }

    throw Exception("Failed to fetch client purchases: ${response.body}");
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    final resendPayload = {"phoneNumber": phoneNumber};
    final url = Uri.parse(baseUrl + resendOtpEndpoint);
    final headers = {"Content-Type": "application/json"};
    final body = json.encode(resendPayload);

    print("========== RESEND OTP START ==========");
    print("Request URL: $url");
    print("Request Headers: $headers");
    print("Request Body: $body");

    try {
      final stopwatch = Stopwatch()..start();

      final response = await _sharedClient.post(
        url,
        headers: headers,
        body: body,
      );

      stopwatch.stop();

      print("---------- RESPONSE ----------");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("Request Duration: ${stopwatch.elapsedMilliseconds} ms");
      print("------------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedResponse = json.decode(response.body);
        print("Decoded JSON Response: $decodedResponse");
        print("========== RESEND OTP SUCCESS ==========");
        return decodedResponse;
      } else {
        print("========== RESEND OTP FAILED ==========");
        print("Error Response Body: ${response.body}");
        throw Exception("Failed resend OTP: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("========== RESEND OTP ERROR ==========");
      print("Exception: $e");
      print("StackTrace: $stackTrace");
      rethrow;
    } finally {
      print("========== RESEND OTP END ==========\n");
    }
  }

  // Update profile
  Future<Map<String, dynamic>> updateUserProfileDetails(
    String firstName,
    String lastName,
    String email,
    String token,
  ) async {
    final updatePayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
    };

    // Log the payload being sent in the request
    print("Request Payload (Update Profile): $updatePayload");

    try {
      final response = await _sharedClient.post(
        Uri.parse(baseUrl + updateUserProfile),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(updatePayload),
      );

      // Log the response status and body
      print("Response Status Code (Update Profile): ${response.statusCode}");
      var responseMessage = response.body;
      Object responseLog = response.body;
      try {
        responseLog = const JsonEncoder.withIndent('  ').convert(
          json.decode(response.body),
        );
      } catch (_) {
        responseMessage = extractErrorMessage(
          response.body,
          fallback: 'Unexpected response from server',
        );
        responseLog = 'Non-JSON response (${response.statusCode}): '
            '$responseMessage';
      }
      print("Response Body (Update Profile): $responseLog");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Log the parsed JSON response
        final Map<String, dynamic> responseBody = json.decode(response.body);
        print("Response (Parsed): $responseBody");
        return responseBody;
      } else {
        // Log the error message if status code isn't 200/201
        print(
            "Failed update profile: ${response.statusCode}, $responseMessage");
        throw Exception("Failed update profile (${response.statusCode}): "
            "$responseMessage");
      }
    } catch (e) {
      // Log any errors that occur during the HTTP request
      final errorMessage = extractErrorMessage(
        e,
        fallback: 'Unable to update profile',
      );
      print("Error during profile update: $errorMessage");
      rethrow; // Re-throw the exception after logging
    }
  }

  // ---------------------- SALONS ----------------------

  // Future<Map<String, dynamic>> createSalon(
  //   String name,
  //   String phone,
  //   String startTime,
  //   String endTime,
  //   String description,
  //   String buildingName,
  //   String city,
  //   String pincode,
  //   String state,
  //   double latitude,
  //   double longitude, {
  //   String? imageUrl, // 👈 optional
  // }) async {
  //   final token = await getAuthToken();

  //   String formattedStartTime = _formatTime(startTime);
  //   String formattedEndTime = _formatTime(endTime);

  //   final createPayload = {
  //     "name": name,
  //     "phone": phone,
  //     "startTime": formattedStartTime,
  //     "endTime": formattedEndTime,
  //     "description": description,
  //     "address": {
  //       "line1": buildingName,
  //       "line2": "",
  //       "village": "",
  //       "district": "",
  //       "city": city,
  //       "state": state,
  //       "country": "India",
  //       "postalCode": pincode,
  //       "latitude": latitude,
  //       "longitude": longitude,
  //     },
  //   };

  //   if (imageUrl != null && imageUrl.isNotEmpty) {
  //     createPayload["imageUrl"] = imageUrl;
  //   }

  //   print("Payload to create salon: ${json.encode(createPayload)}");

  //   final response = await _sharedClient.post(
  //     Uri.parse(baseUrl + createSalonEndpoint),
  //     headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     },
  //     body: json.encode(createPayload),
  //   );

  //   print("Response (Create Salon): ${response.body}");

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     return json.decode(response.body);
  //   } else {
  //     throw Exception("Failed create salon: ${response.body}");
  //   }
  // }
  Future<Map<String, dynamic>> createSalon(
    String name,
    String phone,
    String startTime,
    String endTime,
    String description,
    String buildingName,
    String city,
    String pincode,
    String state,
    double latitude,
    double longitude, {
    String? imageUrl, // 👈 optional
    required List<String> selectedCategoryCodes, // ✅ new required field
  }) async {
    final token = await getAuthToken();

    // ✅ Format time to match backend expectations
    final formattedStartTime = _formatTime(startTime);
    final formattedEndTime = _formatTime(endTime);

    // ✅ Construct payload exactly as expected
    final createPayload = {
      "name": name,
      "phone": phone,
      "startTime": formattedStartTime,
      "endTime": formattedEndTime,
      "description": description,
      "OPENING_BUFFER_MINUTES": 30,
      "LAST_BOOKING_BUFFER_MINUTES": 30,
      "imageUrl": imageUrl, // 👈 matches backend field name
      "address": {
        "line1": buildingName,
        "line2": "",
        "village": "",
        "district": "",
        "city": city,
        "state": state,
        "country": "India",
        "postalCode": pincode,
        "latitude": latitude,
        "longitude": longitude,
      },
      "selectedCategoryCodes": selectedCategoryCodes, // ✅ added field
    };

    // Remove null values to keep payload clean
    createPayload.removeWhere((key, value) => value == null);

    print("📦 Payload to create salon: ${json.encode(createPayload)}");

    final response = await _sharedClient.post(
      Uri.parse(baseUrl + createSalonEndpoint),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode(createPayload),
    );

    print(
        "📥 Response (Create Salon): ${response.statusCode} ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("❌ Failed to create salon: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getSalonListApi() async {
    final token = await getAuthToken();

    final response = await _sharedClient.get(
      Uri.parse(baseUrl + getSalonList),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    _debugPrintChunked('Salon List URL', baseUrl + getSalonList);
    Object responseLog = response.body;
    var responseMessage = response.body;
    try {
      responseLog = const JsonEncoder.withIndent('  ').convert(
        json.decode(response.body),
      );
    } catch (_) {
      responseMessage = extractErrorMessage(
        response.body,
        fallback: 'Unexpected response from server',
      );
      responseLog = 'Non-JSON response (${response.statusCode}): '
          '$responseMessage';
    }
    _debugPrintChunked('Salon List Response', responseLog, chunkSize: 1000);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed get salons (${response.statusCode}): "
          "$responseMessage");
    }
  }

  // ---------------------- LOGOUT ----------------------

  Future<bool> logoutUserAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');

    if (token == null) return false;

    final url = Uri.parse(baseUrl + logoutUser);
    try {
      final response = await _sharedClient.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      print("Logout Response: ${response.body}");

      if (response.statusCode == 200) {
        await prefs.clear();
        return true;
      } else {
        await prefs.clear();
        return false;
      }
    } catch (e) {
      print("Error during logout: $e");
      await prefs.clear();
      return false;
    }
  }
  // ---------------------- DELETE USER ----------------------

  Future<bool> deleteUserAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');

    if (token == null) return false;

    final url = Uri.parse(
        baseUrl + deleteUser); // e.g. https://dev-api.glowante.com/users/delete
    try {
      final response = await _sharedClient.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "accept": "*/*",
        },
      );

      print("Delete User Response: ${response.statusCode} ${response.body}");

      // succeed on 200/204; adjust if your API returns something else
      if (response.statusCode == 200 || response.statusCode == 204) {
        await prefs.clear(); // user is deleted; clear local session
        return true;
      } else {
        // If API returns a JSON { success: false }, you can optionally check it here
        await prefs
            .clear(); // usually still clear since the user intended account removal
        return false;
      }
    } catch (e) {
      print("Error during delete user: $e");
      await prefs.clear();
      return false;
    }
  }

//----------------DELETE ACCOUNT PERMANENT---------------
  Future<bool> deleteAccountAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');

    print("🔑 Loaded token: $token");

    if (token == null) {
      print("❌ No token found in SharedPreferences");
      return false;
    }

    final url = Uri.parse("$baseUrl$deleteAccount");
    print("🌍 Request URL: $url");

    try {
      final response = await _sharedClient.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "accept": "application/json",
          // 👇 do NOT include Content-Type since there's no body
        },
      );

      print("📡 Delete Account Response Status: ${response.statusCode}");
      print("📩 Delete Account Response Body: ${response.body}");
      print("📑 Delete Account Response Headers: ${response.headers}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ Account deleted successfully, clearing local prefs...");
        await prefs.clear(); // only clear after confirmed delete
        return true;
      } else {
        print("⚠️ Failed to delete account, keeping prefs for retry...");
        return false;
      }
    } catch (e) {
      print("💥 Error during delete account: $e");
      return false;
    }
  }

  // ---------------------- HELPERS ----------------------

  String _formatTime(String time) {
    try {
      DateTime parsedTime = DateFormat.jm().parse(time);
      return DateFormat('HH:mm').format(parsedTime);
    } catch (e) {
      return time;
    }
  }

  Future<Map<String, dynamic>> markTeamAttendance({
    required int branchId,
    required int userId,
    required String action,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: teamAttendanceCheckInOutEndpoint(branchId, userId),
      body: <String, dynamic>{
        'action': action,
      },
      debugTag: 'MarkTeamAttendance',
    );
  }

  Future<Map<String, dynamic>> getTeamAttendanceHistory({
    required int branchId,
    required int userId,
    required int month,
    required int year,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: teamAttendanceHistoryEndpoint(
        branchId,
        userId,
        month: month,
        year: year,
      ),
      debugTag: 'TeamAttendanceHistory',
    );
  }

  Future<Map<String, dynamic>> addCategory({
    required int branchId,
    required AddCategoryRequest request,
  }) async {
    final token = await getAuthToken(); // 🔑 fetch saved token
    final url = Uri.parse(baseUrl + "branches/$branchId/categories");

    print("➡️ Calling Add Category API");
    print("➡️ URL: $url");
    print("➡️ Payload: ${jsonEncode(request.toJson())}");
    print("➡️ Token: $token");

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(request.toJson()),
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to add category: ${response.body}");
    }
  }

  // // ---------------------- DELETE CATEGORY ----------------------
  // Future<Map<String, dynamic>> deleteCategoryApi({
  //   required int branchId,
  //   required int CategoryId,
  // }) async {
  //   final token = await getAuthToken();
  //   final url =
  //       Uri.parse(baseUrl + "branches/$branchId/services/category/$CategoryId");

  //   print("➡️ Calling Delete Category API");
  //   print("➡️ URL: $url");

  //   final response = await _sharedClient.delete(
  //     url,
  //     headers: {'Authorization': 'Bearer $token'},
  //   );

  //   print("⬅️ Status Code: ${response.statusCode}");
  //   print("⬅️ Response Body: ${response.body}");

  //   if (response.statusCode == 200 || response.statusCode == 204) {
  //     return {"success": true, "message": "Category deleted successfully"};
  //   } else {
  //     throw Exception("Failed to delete category: ${response.body}");
  //   }
  // }
  Future<Map<String, dynamic>> deleteCategoryApi({
    required int branchId,
    required int CategoryId,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      "${baseUrl}branches/$branchId/services/category/$CategoryId",
    );

    print("➡️ Calling Delete Category API");
    print("➡️ URL: $url");

    final response = await _sharedClient.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 204) {
      return {
        "success": true,
        "message": body["message"] ?? "Category deleted successfully",
      };
    }

    return {
      "success": false,
      "message": body["message"] ?? "Failed to delete category",
      "statusCode": response.statusCode,
    };
  }

  // ---------------------- DELETE SUBCATEGORY ----------------------
  Future<Map<String, dynamic>> deleteSubCategoryApi({
    required int branchId,
    required int subCategoryId,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      return {"success": false, "message": "Auth token missing"};
    }

    final url = Uri.parse(
      "${baseUrl}branches/$branchId/services/subCategory/$subCategoryId",
    );

    print("➡️ Calling Delete SubCategory API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await _sharedClient.delete(
        url,
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      // ✅ decode body here
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {"success": true, "message": "Subcategory deleted successfully"};
      } else {
        // ✅ return the backend message
        return {
          "success": false,
          "message": body['message'] ?? "Failed to delete subcategory",
          "statusCode": response.statusCode,
        };
      }
    } catch (e) {
      print("❌ Error deleting subcategory: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------- DELETE SERVICE ----------------------
  Future<Map<String, dynamic>> deleteServiceApi({
    required int branchId,
    required int serviceId,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      return {"success": false, "message": "Auth token missing"};
    }

    final url = Uri.parse("${baseUrl}branches/$branchId/services/$serviceId");

    print("➡️ Calling Delete Service API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await _sharedClient.delete(
        url,
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {"success": true, "message": "Service deleted successfully"};
      } else {
        return {
          "success": false,
          "message": body['message'] ?? "Failed to delete service",
          "statusCode": response.statusCode,
        };
      }
    } catch (e) {
      print("❌ Error deleting service: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------- GET CATEGORIES ----------------------
  // inside ApiService class
  Future<Map<String, dynamic>> getCategories({
    required int salonId,
    bool withSubcats = true,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      baseUrl + getCategoriesAPI(salonId, withSubcats: withSubcats),
    );

    print("➡️ Calling Get Categories API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch categories: ${response.body}");
    }
  }

  // ---------------------- UPDATE CATEGORY ----------------------
  Future<Map<String, dynamic>> updateCategory({
    required int branchId,
    required int branchCategoryId,
    required AddCategoryRequest request,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      throw Exception('{"message":["Authentication required"]}');
    }

    final url =
        Uri.parse(baseUrl + "branches/$branchId/categories/$branchCategoryId");

    final payload = request.toJson();
    print("➡️ Calling Update Category API");
    print("➡️ URL: $url");
    print("➡️ Payload: $payload");

    final response = await _sharedClient.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to update category: ${response.body}');
  }

  // ---------------------- DELETE CATEGORY ----------------------
  // Future<Map<String, dynamic>> deleteCategory({
  //   required int branchId,
  //   required int CategoryId,
  // }) async {
  //   final token = await getAuthToken();
  //   final url = Uri.parse("${baseUrl}branches/$branchId/services/category/$CategoryId");

  //   print("➡️ Calling Delete Category API");
  //   print("➡️ URL: $url");
  //   print("➡️ Token: $token");

  //   final response = await _sharedClient.delete(
  //     url,
  //     headers: {
  //       "Authorization": "Bearer $token", // ✅ only auth header
  //     },
  //   );

  //   print("⬅️ Status Code: ${response.statusCode}");
  //   print("⬅️ Response Body: ${response.body}");

  //   if (response.statusCode == 200 || response.statusCode == 204) {
  //     return response.body.isNotEmpty ? jsonDecode(response.body) : {};
  //   } else {
  //     throw Exception("Failed to delete category: ${response.body}");
  //   }
  // }

  // ---------------------- SERVICE CATALOG ----------------------
  Future<Map<String, dynamic>> getServiceCatalog() async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + serviceCatalog);
    _debugPrintChunked('Service Catalog URL', url);
    _debugPrintChunked('Service Catalog Token', token);

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    _debugPrintChunked('Service Catalog Status', response.statusCode);
    final rawBody = response.body;
    _debugPrintChunked('Service Catalog Response Raw', rawBody);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(rawBody);
      const encoder = JsonEncoder.withIndent('  ');
      _debugPrintChunked(
        'Service Catalog Response Pretty',
        encoder.convert(decoded),
      );
      return decoded;
    } else {
      throw Exception("Failed to fetch service catalog: $rawBody");
    }
  }

  Future<Map<String, dynamic>> addService({
    required int branchId,
    required AddSalonServiceRequest request,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + addServiceAPI(branchId));
    final payload = request.toJson();

    print("➡️ Calling Add Service API");
    print("➡️ URL: $url");
    print("➡️ branchId: $branchId");
    print("➡️ Payload: ${const JsonEncoder.withIndent('  ').convert(payload)}");
    print("➡️ branchCategoryId: ${payload['branchCategoryId']}");
    print("➡️ branchSubCategoryId: ${payload['branchSubCategoryId']}");

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    print("⬅️ Service Status Code: ${response.statusCode}");
    print("⬅️ Service Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(response.body);
  }

  // ---------------------- GET SERVICES ----------------------
  Future<Map<String, dynamic>> getService({
    int? salonId,
    int? branchId,
  }) async {
    if (salonId == null && branchId == null) {
      throw ArgumentError('Either salonId or branchId must be provided.');
    }

    final token = await getAuthToken();
    final String path = branchId != null
        ? getBranchServicesAPI(branchId)
        : getSalonServicesAPI(salonId!);
    final url = Uri.parse(baseUrl + path);

    print("➡️ Calling Get Service API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch service(s): ${response.body}");
    }
  }

// -------------------- GET BRANCH SERVICES ------------
  Future<Map<String, dynamic>> getBranchService({required int branchId}) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      baseUrl + getBranchServicesAPI(branchId),
    ); // Direct string concatenation

    print("➡️ Calling Get Branch Service API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch branch service(s): ${response.body}");
    }
  }

  // ---------------------- ADD BRANCH ----------------------
  // Future<Map<String, dynamic>> addSalonBranch(
  //   int salonId,
  //   Map<String, dynamic> branchData,
  // ) async {
  //   final token = await getAuthToken();
  //   final url = Uri.parse(baseUrl + "salons/$salonId/branches/add");

  //   // Log the request payload before sending
  //   print("Sending payload to add branch: ");
  //   print("Token: $token");
  //   print("URL: $url");
  //   print("Payload: $branchData");

  //   final response = await _sharedClient.post(
  //     url,
  //     headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     },
  //     body: jsonEncode(branchData),
  //   );

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     // Log successful response
  //     print("Response: ${response.body}");
  //     return jsonDecode(response.body);
  //   } else {
  //     // Log failed response
  //     print("Failed to add branch: ${response.body}");
  //     throw Exception("Failed to add branch: ${response.body}");
  //   }
  // }
  Future<Map<String, dynamic>> addSalonBranch(
    int salonId,
    Map<String, dynamic> branchData,
  ) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + "salons/$salonId/branches/add");

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(branchData),
    );

    final decodedBody = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decodedBody;
    } else {
      final message = decodedBody["message"] ?? "Failed to add branch";

      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> updateSalon(
    int salonId,
    Map<String, dynamic> salonData,
  ) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + updateSalonAPI(salonId));
    _debugPrintChunked('Salon Update URL', url);
    _debugPrintChunked('Salon Update Payload', jsonEncode(salonData));

    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(salonData),
    );
    _debugPrintChunked('Salon Update Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to update salon: ${response.body}");
  }

  Future<Map<String, dynamic>> activateSalon(int salonId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + activateSalonAPI(salonId));
    _debugPrintChunked('Salon Activate URL', url);
    const body = '{}';
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Salon Activate Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to activate salon: ${response.body}");
  }

  Future<Map<String, dynamic>> deactivateSalon(int salonId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + deactivateSalonAPI(salonId));
    _debugPrintChunked('Salon Deactivate URL', url);
    const body = '{}';
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Salon Deactivate Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to deactivate salon: ${response.body}");
  }

  Future<Map<String, dynamic>> deleteSalon(int salonId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + deleteSalonAPI(salonId));
    _debugPrintChunked('Salon Delete URL', url);
    const body = '{}';
    final response = await _sharedClient.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Salon Delete Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to delete salon: ${response.body}");
  }

  Future<Map<String, dynamic>> updateBranch(
    int branchId,
    Map<String, dynamic> branchData,
  ) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + updateBranchAPI(branchId));
    _debugPrintChunked('Branch Update URL', url);
    _debugPrintChunked('Branch Update Payload', jsonEncode(branchData));

    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(branchData),
    );
    _debugPrintChunked('Branch Update Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to update branch: ${response.body}");
  }

  Future<Map<String, dynamic>> activateBranch(int branchId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + activateBranchAPI(branchId));
    _debugPrintChunked('Branch Activate URL', url);
    const body = '{}';
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Branch Activate Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to activate branch: ${response.body}");
  }

  Future<Map<String, dynamic>> deactivateBranch(int branchId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + deactivateBranchAPI(branchId));
    _debugPrintChunked('Branch Deactivate URL', url);
    const body = '{}';
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Branch Deactivate Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to deactivate branch: ${response.body}");
  }

  Future<Map<String, dynamic>> deleteBranch(int branchId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + deleteBranchAPI(branchId));
    _debugPrintChunked('Branch Delete URL', url);
    const body = '{}';
    final response = await _sharedClient.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    _debugPrintChunked('Branch Delete Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to delete branch: ${response.body}");
  }

  Future<Map<String, dynamic>> importPredefinedServices({
    required int branchId,
    required List<String> serviceCodes,
    List<String> unselectedCodes = const [],
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + importPredefinedServicesAPI(branchId));
    final payload = <String, dynamic>{
      "serviceCodes": serviceCodes,
      if (unselectedCodes.isNotEmpty) "unselectedCodes": unselectedCodes,
    };
    _debugPrintChunked('Import Predefined Services URL', url);
    _debugPrintChunked(
      'Import Predefined Services Payload',
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );
    _debugPrintChunked(
      'Import Predefined Services Status',
      response.statusCode,
    );
    _debugPrintChunked(
      'Import Predefined Services Response',
      response.body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to import predefined services: ${response.body}");
  }

  // ---------------------- GET BRANCH DETAILS ----------------------
  Future<Map<String, dynamic>> getBranchDetail(int branchId) async {
    final token = await getAuthToken(); // Get token from shared preferences
    final url = Uri.parse(
      '$baseUrl' + 'branches/$branchId',
    ); // Fix: avoid double slashes

    // Log the request details
    print("➡️ Calling Get Branch Detail API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await _sharedClient.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Authorization header
        },
      );

      // Log response status code and body
      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body); // Return the response as JSON
      } else {
        throw Exception("Failed to fetch branch details: ${response.body}");
      }
    } catch (e) {
      // Log any exceptions that occur
      print("Error fetching branch details: $e");
      rethrow;
    }
  }
// Future<Map<String, dynamic>> addSubCategoryApi({
//   required int branchId,
//   required int branchCategoryId,
//   required String displayName,
// }) async {
//   final url = Uri.parse(
//     '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/branches/$branchId/categories/$branchCategoryId/subcategories',
//   );

//   final token = await getAuthToken();

//   final requestBody = jsonEncode({
//     'branchCategoryId': branchCategoryId,
//     'displayName': displayName,
//     'sortOrder': 200,
//     'isActive': true,
//   });

//   final response = await _sharedClient.post(
//     url,
//     headers: {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     },
//     body: requestBody,
//   );

//   if (response.statusCode == 200 || response.statusCode == 201) {
//     return jsonDecode(response.body);
//   }

//   throw Exception(response.body);
// }
  Future<Map<String, dynamic>> addSubCategoryApi({
    required int branchId,
    required int branchCategoryId,
    required String displayName,
  }) async {
    final url = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/branches/$branchId/categories/$branchCategoryId/subcategories',
    );

    final token = await getAuthToken();

    final payload = {
      // 'branchCategoryId': branchCategoryId,
      'displayName': displayName,
      'sortOrder': 200,
      'isActive': true,
    };

    print("➡️ Calling Add SubCategory API");
    print("➡️ URL: $url");
    print("➡️ Payload: ${jsonEncode(payload)}");
    print("➡️ branchId: $branchId");
    print("➡️ branchCategoryId: $branchCategoryId");

    final response = await _sharedClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print("⬅️ SubCategory Status: ${response.statusCode}");
    print("⬅️ SubCategory Response: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception(response.body);
  }

  Future<Map<String, dynamic>> updateSubCategoryApi({
    required int branchId,
    required int subCategoryId,
    required String displayName,
    required int sortOrder,
    required bool isActive,
  }) async {
    final url = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/branches/$branchId/subcategories/$subCategoryId',
    );
    print("Request URL: $url");

    final token = await getAuthToken();
    if (token.isEmpty)
      throw Exception('{"message":["Authentication required"]}');

    final requestBody = json.encode({
      'displayName': displayName,
      'sortOrder': sortOrder,
      'isActive': isActive,
    });
    print("Request Body: $requestBody");

    final response = await _sharedClient.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: requestBody,
    );

    print("Response Status Code: ${response.statusCode}");
    print("Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    final body = response.body;
    throw Exception(body.isNotEmpty ? body : 'Failed to update subcategory');
  }

  // ---------------------- GET BRANCH SERVICE DETAILS ----------------------
  Future<Map<String, dynamic>> getBranchServiceDetail(int branchId) async {
    try {
      // Construct the full URL by concatenating strings using '+'
      final url = Uri.parse(baseUrl + 'branches/$branchId/services');

      print('Making GET request to: $url'); // Log the request URL

      // Make the GET request
      final response = await _sharedClient.get(url);

      // Log the response status and body
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Check if the response is successful
      if (response.statusCode == 200) {
        // Parse the response body as JSON
        final Map<String, dynamic> data = json.decode(response.body);

        // Log the parsed data
        print('Parsed Response Data: $data');

        // Check if the success flag is true
        if (data['success'] == true) {
          return data[
              'data']; // Return the service data (categories, subcategories, etc.)
        } else {
          throw Exception('Failed to fetch services: Success flag is false');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle any errors that occur during the request
      print('Error: $e');
      throw Exception('An error occurred while fetching the data');
    }
  }

  // ---------------------- GET ROLES AND SPECIALIZATIONS ----------------------
  Future<Map<String, dynamic>> getRolesAndSpecializations({
    int? branchId,
  }) async {
    try {
      // Fetch the token dynamically from SharedPreferences
      String token = await getAuthToken();
      final endpoint = getRolesSpecialization(branchId: branchId);

      // Log the request details (with the actual token)
      print('Sending request to: $baseUrl$endpoint');
      print('Headers: { "Authorization": "Bearer $token" }');

      // Check if token is empty
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      // Send the request with the actual token in the Authorization header
      final response = await _sharedClient.get(
        Uri.parse(baseUrl + endpoint),
        headers: {
          'Authorization': 'Bearer $token', // Use the actual token here
        },
      );

      // Log the response status code and body
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON
        final decoded = json.decode(response.body);
        final data = decoded['data'];
        if (data is! Map) {
          throw Exception('Invalid roles and specializations response');
        }
        print('Fetched roles and specializations data: $data');
        return Map<String, dynamic>.from(data); // Access the 'data' key
      } else {
        // If the server returns an error response, throw an exception
        throw Exception(
          'Failed to load roles and specializations. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Log the error
      print('Error fetching roles and specializations: $e');
      throw Exception('Error fetching roles and specializations: $e');
    }
  }

  // Endpoint to check user existence and send OTP
  static Future<Map<String, dynamic>> checkUserAndSendOtp(
      String phoneNumber) async {
    final url = Uri.parse('$baseUrl$checkSendOtpEndpoint');
    print('Sending request to: $url');

    final headers = {'Content-Type': 'application/json'};

    final apiService = ApiService();
    final token = await apiService.getAuthToken();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    print('Headers: { "Authorization": "Bearer $token" }');

    final body = json.encode({'phoneNumber': phoneNumber});

    try {
      final response =
          await _sharedClient.post(url, headers: headers, body: body);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Treat 200/201 as success and return parsed JSON.
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Ensure it’s a JSON object
        final parsed = json.decode(response.body);
        if (parsed is Map<String, dynamic>) return parsed;
        return {'success': true, 'data': parsed};
      }

      // ----- Non-2xx: extract server error cleanly -----
      String message = 'Verification failed. Please try again.';
      try {
        final parsed = json.decode(response.body);
        final msg = (parsed is Map<String, dynamic>) ? parsed['message'] : null;
        if (msg is List) {
          message = msg.join('\n');
        } else if (msg is String) {
          message = msg;
        }
      } catch (_) {
        // response body not JSON – keep default message
      }

      // Return a consistent shape the UI can read.
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': message,
      };
    } catch (e) {
      // Transport / parsing errors
      print('Error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // ---------------------- ADD TEAM MEMBER ----------------------
  Future<Map<String, dynamic>> addTeamMember(
    int branchId,
    Map<String, dynamic> teamMemberData,
  ) async {
    // Generate the full URL using static method
    final url = Uri.parse('$baseUrl${addTeamMemberEndpoint(branchId)}');

    // Get the auth token first
    String token = await getAuthToken();

    // Log the URL and the body being sent
    print('API URL: $url');
    print('Request Body: $teamMemberData');

    // Prepare headers, including the Authorization token
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Use the actual token here
    };

    final body = json.encode(teamMemberData); // Encode the data as JSON

    try {
      // Log the HTTP request being made
      print('Making POST request to: $url');

      final response =
          await _sharedClient.post(url, headers: headers, body: body);

      // Log the status code of the response
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          'success': false,
          'message':
              response.body.isNotEmpty ? response.body : 'Failed to add user',
        };
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print('Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceFirst(RegExp(r'^Exception:\\s*'), ''),
      };
    }
  }

// ---------------------- ADD SALON TEAM MEMBER ----------------------
  Future<Map<String, dynamic>> addSalonTeamMember(
    int salonId,
    Map<String, dynamic> teamMemberData,
  ) async {
    // Generate the full URL using static method
    final url = Uri.parse('$baseUrl${addSalonTeamMemberEndpoint(salonId)}');

    // Get the auth token first
    String token = await getAuthToken();

    // Log the URL and the body being sent
    print('API URL: $url');
    print('Request Body: $teamMemberData');

    // Prepare headers, including the Authorization token
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Use the actual token here
    };

    final body = json.encode(teamMemberData); // Encode the data as JSON

    try {
      // Log the HTTP request being made
      print('Making POST request to: $url');

      final response =
          await _sharedClient.post(url, headers: headers, body: body);

      // Log the status code of the response
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        // If request fails, throw an error
        throw Exception('Failed to add salon user');
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print('Error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ---------------------- GET TEAM MEMBERS ----------------------
  static Future<Map<String, dynamic>> getTeamMembers(int branchId) async {
    try {
      // Create an instance of ApiService to call the non-static getAuthToken method
      ApiService apiService = ApiService();

      // Fetch the token dynamically from SharedPreferences
      final String token =
          await apiService.getAuthToken(); // Call it on the instance

      if (token.isEmpty) {
        throw Exception('No token found');
      }

      // Construct the API URL using the static method
      final url = Uri.parse(
        '$baseUrl${getTeamMember(branchId)}',
      ); // Use getTeamMember method to get the endpoint

      // Log the URL and headers being sent
      print('API URL: $url');
      print('Request Headers: { "Authorization": "Bearer $token" }');

      // Prepare headers, including the Authorization token
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the token here
      };

      // Making the GET request
      final response = await _sharedClient.get(url, headers: headers);

      // Log the response status code and body
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load team members');
      }
    } catch (e) {
      // Log and handle errors
      print('Error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

//---------------Get Salon Offers------------------------
  Future<Map<String, dynamic>> getSalonPackagesDealsApi(int salonId) async {
    final url = Uri.parse(baseUrl + getSalonPackagesDeals(salonId));
    final sw = Stopwatch()..start();

    print('➡️ GET $url');

    try {
      final response = await _sharedClient.get(url);
      sw.stop();

      print('⬅️ ${response.statusCode} ${response.reasonPhrase} '
          '(${sw.elapsedMilliseconds} ms) for $url');

      // Try pretty JSON body (with length cap)
      try {
        final decoded = json.decode(response.body);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        final preview = pretty.length > 2000
            ? '${pretty.substring(0, 2000)}… (truncated)'
            : pretty;
        print('📦 Body preview:\n$preview');
      } catch (_) {
        // Non-JSON body preview
        final body = response.body;
        final preview = body.length > 2000
            ? '${body.substring(0, 2000)}… (truncated)'
            : body;
        print('📦 Body (text):\n$preview');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e, st) {
      print('❌ Error fetching salon packages: $e');
      print(st.toString());
      return {
        'success': false,
        'message': 'Error fetching salon packages',
        'data': [],
      };
    }
  }
  // ---------------------- CREATE SALON OFFER ----------------------

  Future<Map<String, dynamic>> createSalonOffer(
    int salonId,
    Map<String, dynamic> offerData,
  ) async {
    final url = Uri.parse(
      "$baseUrl${addSalonOffer(salonId)}",
    ); // Ensure this returns the correct endpoint

    // Log the full URL to check if it's correctly constructed
    print("Request URL: $url");

    // Log the request headers and the offer data being sent
    print("Request Headers: {'Content-Type': 'application/json'}");
    print("Request Body: ${json.encode(offerData)}");

    try {
      // Get the auth token if necessary
      final token =
          await getAuthToken(); // Assuming you need an authentication token

      final response = await _sharedClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // Use token if authentication is required
        },
        body: json.encode(offerData), // Sending the offer data as JSON
      );

      // Log the response status and body for debugging
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 201) {
        // Successfully created the offer
        return json.decode(
          response.body,
        ); // Returning the response in JSON format
      } else {
        // Handle unsuccessful response (e.g., 400, 500)
        return {
          'success': false,
          'message':
              'Failed to create offer. Status Code: ${response.statusCode}. Response: ${response.body}',
        };
      }
    } catch (e) {
      // Catch network errors or any other issues
      print("Error: $e");
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  // ---------------------- UPDATE SALON OFFER (PATCH) ----------------------

  Future<Map<String, dynamic>> updateSalonOfferPatch(
    int salonId,
    int offerId,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse("$baseUrl${updateSalonOffer(salonId, offerId)}");

    // Keep only non-null keys (PATCH semantics)
    final payload = Map<String, dynamic>.from(body)
      ..removeWhere((k, v) => v == null);

    print("🔹 [PATCH] Update Salon Offer → $url");
    print(
        "Headers: {Content-Type: application/json, Authorization: Bearer ***}");
    print("Body: ${jsonEncode(payload)}");

    try {
      final token = await getAuthToken();

      final resp = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("✅ Status: ${resp.statusCode}");
      print("Response: ${resp.body}");

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          return jsonDecode(resp.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            "success": true,
            "message": "Offer updated",
            "raw": resp.body
          };
        }
      }

      try {
        final m = jsonDecode(resp.body);
        if (m is Map<String, dynamic>) return m;
      } catch (_) {}

      return {
        "success": false,
        "message":
            "Failed to update offer. Status: ${resp.statusCode}. Body: ${resp.body}",
      };
    } catch (e, st) {
      print("❌ Error updateSalonOfferPatch: $e");
      print("StackTrace: $st");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------- DELETE SALON OFFER ----------------------
  Future<Map<String, dynamic>> deleteSalonOfferApi({
    required int salonId,
    required int offerId,
  }) async {
    final uri = Uri.parse(
      "$baseUrl${ApiService.deleteSalonOffer(salonId, offerId)}",
    );

    print("DELETE Request: $uri");

    try {
      final resp = await _sharedClient.delete(
        uri,
        headers: const {
          'Accept': 'application/json',
          // Don't send Content-Type since there is no body
        },
      ).timeout(const Duration(seconds: 25));

      print("Response [${resp.statusCode}]: ${resp.body}");

      final Map<String, dynamic> body = resp.body.isEmpty
          ? {}
          : (jsonDecode(resp.body) as Map<String, dynamic>);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Deleted',
          'data': body['data'],
        };
      } else {
        return {
          'success': body['success'] ?? false,
          'message': body['message'] ?? 'Failed to delete offer',
          'statusCode': resp.statusCode,
          'data': body['data'],
        };
      }
    } on TimeoutException {
      print("❌ DELETE timeout");
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      print("❌ DELETE error: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setSalonOfferStatus({
    required int salonId,
    required int offerId,
    required bool live,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      "$baseUrl${live ? setSalonOfferLive(salonId, offerId) : setSalonOfferInactive(salonId, offerId)}",
    );
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to update offer status: ${response.body}");
  }

  // ---------------------- CREATE SALON BRANCH OFFER ----------------------
  Future<Map<String, dynamic>> createSalonBranchOffer(
    int branchId,
    Map<String, dynamic> offerData,
  ) async {
    final url = Uri.parse(
      "$baseUrl${addSalonBranchOffer(branchId)}",
    ); // Ensure this returns the correct endpoint

    // Log the full URL to check if it's correctly constructed
    print("Request URL: $url");

    // Log the request headers and the offer data being sent
    print("Request Headers: {'Content-Type': 'application/json'}");
    print("Request Body: ${json.encode(offerData)}");

    try {
      // Get the auth token if necessary
      final token =
          await getAuthToken(); // Assuming you need an authentication token

      final response = await _sharedClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // Use token if authentication is required
        },
        body: json.encode(offerData), // Sending the offer data as JSON
      );

      // Log the response status and body for debugging
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 201) {
        // Successfully created the offer
        return json.decode(
          response.body,
        ); // Returning the response in JSON format
      } else {
        // Handle unsuccessful response (e.g., 400, 500)
        return {
          'success': false,
          'message':
              'Failed to create offer. Status Code: ${response.statusCode}. Response: ${response.body}',
        };
      }
    } catch (e) {
      // Catch network errors or any other issues
      print("Error: $e");
      return {'success': false, 'message': 'Error: $e'};
    }
  }

// ---------------------- GET BRANCH OFFERS ----------------------
  // API call method with logging
  static Future<Map<String, dynamic>> getBranchPackagesDeals(
    int branchId,
  ) async {
    final url = Uri.parse(
      getBranchPackagesDealsUrl(branchId),
    ); // Call the URL generator method
    print('Request URL: $url'); // Log the request URL

    try {
      final response = await _sharedClient.get(url);

      print(
        'Response Status Code: ${response.statusCode}',
      ); // Log the status code
      print('Response Body: ${response.body}'); // Log the response body

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Parsed Data: $data'); // Log the parsed data

        return {
          'success': data['success'],
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        print('Failed to load offers: ${response.body}'); // Log error response
        return {
          'success': false,
          'message': 'Failed to load offers',
          'data': [],
        };
      }
    } catch (e) {
      print('Error: $e'); // Log error
      return {'success': false, 'message': 'Error: $e', 'data': []};
    }
  }

  // ---------------------- UPDATE SALON BRANCH OFFER (PATCH) ----------------------
  Future<Map<String, dynamic>> updateSalonBranchOfferPatch(
    int branchId,
    int offerId,
    Map<String, dynamic> body,
  ) async {
    final url =
        Uri.parse("$baseUrl${updateSalonBranchOffer(branchId, offerId)}");

    // Remove null values (PATCH semantics)
    final payload = Map<String, dynamic>.from(body)
      ..removeWhere((k, v) => v == null);

    print("🔹 [PATCH] Update Salon Branch Offer → $url");
    print(
        "Headers: {Content-Type: application/json, Authorization: Bearer ***}");
    print("Body: ${jsonEncode(payload)}");

    try {
      final token = await getAuthToken();

      final resp = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("✅ Status: ${resp.statusCode}");
      print("Response: ${resp.body}");

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          return jsonDecode(resp.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            "success": true,
            "message": "Branch offer updated",
            "raw": resp.body
          };
        }
      }

      try {
        final m = jsonDecode(resp.body);
        if (m is Map<String, dynamic>) return m;
      } catch (_) {}

      return {
        "success": false,
        "message":
            "Failed to update branch offer. Status: ${resp.statusCode}. Body: ${resp.body}",
      };
    } catch (e, st) {
      print("❌ Error updateSalonBranchOfferPatch: $e");
      print("StackTrace: $st");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------- DELETE SALON BRANCH OFFER ----------------------
  Future<Map<String, dynamic>> deleteSalonBranchOfferApi({
    required int branchId,
    required int offerId,
  }) async {
    final uri = Uri.parse(
      "$baseUrl${deleteSalonBranchOffer(branchId, offerId)}",
    );

    print("🗑️ DELETE Branch Offer Request: $uri");

    try {
      final token = await getAuthToken();

      final resp = await _sharedClient.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 25));

      print("Response [${resp.statusCode}]: ${resp.body}");

      final Map<String, dynamic> body = resp.body.isEmpty
          ? {}
          : (jsonDecode(resp.body) as Map<String, dynamic>);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Branch offer deleted successfully',
          'data': body['data'],
        };
      } else {
        return {
          'success': body['success'] ?? false,
          'message': body['message'] ?? 'Failed to delete branch offer',
          'statusCode': resp.statusCode,
          'data': body['data'],
        };
      }
    } on TimeoutException {
      print("❌ DELETE Branch Offer timeout");
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      print("❌ DELETE Branch Offer error: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setBranchOfferStatus({
    required int branchId,
    required int offerId,
    required bool live,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      "$baseUrl${live ? setBranchOfferLive(branchId, offerId) : setBranchOfferInactive(branchId, offerId)}",
    );
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: '{}',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to update branch offer status: ${response.body}");
  }

  // ---------------------- GET SALON USERS ----------------------
  Future<Map<String, dynamic>> getSalonUsersApi(
    int salonId, {
    bool activeOnly = true,
  }) async {
    final uri = Uri.parse(baseUrl + getSalonUser(salonId, activeOnly));

    print("GET Request: $uri");

    try {
      final token = await getAuthToken(); // ✅ fetch token

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ✅ use token
      };

      final resp = await _sharedClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));

      print("Response [${resp.statusCode}]: ${resp.body}");

      final Map<String, dynamic> body = resp.body.isEmpty
          ? {}
          : (jsonDecode(resp.body) as Map<String, dynamic>);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Success',
          'data': body['data'] ?? [],
        };
      } else {
        return {
          'success': body['success'] ?? false,
          'message': body['message'] ?? 'Failed to fetch salon users',
          'statusCode': resp.statusCode,
          'data': body['data'] ?? [],
        };
      }
    } on TimeoutException {
      print("❌ GET timeout");
      return {'success': false, 'message': 'Request timed out', 'data': []};
    } catch (e) {
      print("❌ GET error: $e");
      return {'success': false, 'message': e.toString(), 'data': []};
    }
  }

  // ---------------------- FETCH APPOINTMENTS BY DATE ----------------------
  Future<Map<String, dynamic>> fetchAppointments(
    int branchId,
    String date,
  ) async {
    try {
      // Fetch the token from SharedPreferences
      final token =
          await getAuthToken(); // Use the same approach to get the token

      if (token.isEmpty) {
        throw Exception("No token found");
      }

      final url = baseUrl + getAppointmentByDate(branchId, date);

      // Log the request details for debugging
      print("Request URL: $url");
      print("Authorization: Bearer $token");

      final response = await _sharedClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json', // Add content-type header
          'Authorization': 'Bearer $token', // Add token in Authorization header
        },
      );

      // Log the response status code and body
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        // Decode the JSON response and return it
        final responseData = json.decode(response.body);
        print("Decoded Response Data: $responseData");
        return responseData;
      } else {
        throw Exception('Failed to load appointments');
      }
    } catch (e) {
      print("Error: $e");
      rethrow; // Rethrow to propagate the error
    }
  }

  Future<Map<String, dynamic>> fetchMyAppointments(int branchId) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception("No token found");
      }

      final url = baseUrl + getMyAppointmentsAPI(branchId);
      final response = await _sharedClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          return responseData;
        }
        return {
          'success': true,
          'data': responseData,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load stylist appointments',
        'data': const [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': const [],
      };
    }
  }

  Future<Map<String, dynamic>> fetchTeamAppointmentsByDate(
    int branchId,
    int userId,
    String date,
  ) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception("No token found");
      }

      final url =
          baseUrl + getTeamAppointmentsByDateAPI(branchId, userId, date);
      debugPrint(
        '[StylistBookingsAPI] GET $url | branchId=$branchId userId=$userId date=$date',
      );
      final response = await _sharedClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('[StylistBookingsAPI] status=${response.statusCode}');
      _debugPrintChunked('StylistBookingsAPI body', response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData =
            response.body.isEmpty ? const [] : json.decode(response.body);
        _debugPrintChunked('StylistBookingsAPI decoded', responseData);
        if (responseData is Map<String, dynamic>) {
          return responseData;
        }
        return {
          'success': true,
          'data': responseData,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load team appointments',
        'data': const [],
      };
    } catch (e) {
      debugPrint('[StylistBookingsAPI] error=$e');
      return {
        'success': false,
        'message': e.toString(),
        'data': const [],
      };
    }
  }

  Future<Map<String, dynamic>> fetchBranchServicesFlat(int branchId) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(baseUrl + getBranchServicesFlatAPI(branchId));
      debugPrint(
        '[StylistServicesAPI] GET $url | branchId=$branchId',
      );

      final response = await _sharedClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('[StylistServicesAPI] status=${response.statusCode}');
      _debugPrintChunked('StylistServicesAPI body', response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
        _debugPrintChunked('StylistServicesAPI decoded', decoded);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load services',
        'data': const [],
      };
    } catch (e) {
      debugPrint('[StylistServicesAPI] error=$e');
      return {
        'success': false,
        'message': e.toString(),
        'data': const [],
      };
    }
  }

  Future<Map<String, dynamic>> fetchInventoryItems(
    int branchId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
          baseUrl + getInventoryItemsAPI(branchId, page: page, limit: limit));
      debugPrint(
        '[StylistInventoryAPI] GET $url | branchId=$branchId page=$page limit=$limit',
      );

      final response = await _sharedClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[StylistInventoryAPI] status=${response.statusCode}');
      _debugPrintChunked('StylistInventoryAPI body', response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _debugPrintChunked('StylistInventoryAPI decoded', decoded);
          return decoded;
        }
        _debugPrintChunked('StylistInventoryAPI decoded', decoded);
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load inventory',
        'data': const <String, dynamic>{},
      };
    } catch (e) {
      debugPrint('[StylistInventoryAPI] error=$e');
      return {
        'success': false,
        'message': e.toString(),
        'data': const <String, dynamic>{},
      };
    }
  }

  Future<Map<String, dynamic>> getBranchVendors(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getBranchVendorsAPI(branchId),
      debugTag: 'BranchVendorsAPI',
    );
  }

  Future<Map<String, dynamic>> getVendorDetails({
    required int branchId,
    required int vendorId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getVendorDetailsAPI(branchId, vendorId),
      debugTag: 'VendorDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> createVendor({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: getBranchVendorsAPI(branchId),
      body: payload,
      debugTag: 'CreateVendorAPI',
    );
  }

  Future<Map<String, dynamic>> updateVendor({
    required int branchId,
    required int vendorId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: getVendorDetailsAPI(branchId, vendorId),
      body: payload,
      debugTag: 'UpdateVendorAPI',
    );
  }

  Future<Map<String, dynamic>> deleteVendor({
    required int branchId,
    required int vendorId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: getVendorDetailsAPI(branchId, vendorId),
      debugTag: 'DeleteVendorAPI',
    );
  }

  Future<Map<String, dynamic>> getStores(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getBranchStoreAPI(branchId),
      debugTag: 'StoreListAPI',
    );
  }

  Future<Map<String, dynamic>> getStoreDetails({
    required int branchId,
    required int storeId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getStoreDetailsAPI(branchId, storeId),
      debugTag: 'StoreDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> createStore({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: getBranchStoreAPI(branchId),
      body: payload,
      debugTag: 'CreateStoreAPI',
    );
  }

  Future<Map<String, dynamic>> updateStore({
    required int branchId,
    required int storeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: getStoreDetailsAPI(branchId, storeId),
      body: payload,
      debugTag: 'UpdateStoreAPI',
    );
  }

  Future<Map<String, dynamic>> deleteStore({
    required int branchId,
    required int storeId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: getStoreDetailsAPI(branchId, storeId),
      debugTag: 'DeleteStoreAPI',
    );
  }

  Future<Map<String, dynamic>> getInventoryItemDetails({
    required int branchId,
    required int inventoryId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getInventoryItemDetailsAPI(branchId, inventoryId),
      debugTag: 'InventoryItemDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> createInventoryItem({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: "branches/$branchId/inventory-items",
      body: payload,
      debugTag: 'CreateInventoryItemAPI',
    );
  }

  Future<Map<String, dynamic>> updateInventoryItem({
    required int branchId,
    required int inventoryId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: getInventoryItemDetailsAPI(branchId, inventoryId),
      body: payload,
      debugTag: 'UpdateInventoryItemAPI',
    );
  }

  Future<Map<String, dynamic>> deleteInventoryItem({
    required int branchId,
    required int inventoryId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: getInventoryItemDetailsAPI(branchId, inventoryId),
      debugTag: 'DeleteInventoryItemAPI',
    );
  }

  Future<Map<String, dynamic>> getInventoryItemCategories(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getInventoryItemCategoriesOptionsAPI(branchId),
      debugTag: 'InventoryItemCategoriesAPI',
    );
  }

  Future<Map<String, dynamic>> getPurchaseOrders(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getPurchaseOrdersAPI(branchId),
      debugTag: 'PurchaseOrderListAPI',
    );
  }

  Future<Map<String, dynamic>> getPurchaseOrderDetails({
    required int branchId,
    required int poId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getPurchaseOrderDetailsAPI(branchId, poId),
      debugTag: 'PurchaseOrderDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> createPurchaseOrder({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: getPurchaseOrdersAPI(branchId),
      body: payload,
      debugTag: 'CreatePurchaseOrderAPI',
    );
  }

  Future<Map<String, dynamic>> updatePurchaseOrderStatus({
    required int branchId,
    required int poId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: updatePurchaseOrderStatusAPI(branchId, poId),
      body: payload,
      debugTag: 'UpdatePurchaseOrderStatusAPI',
    );
  }

  Future<Map<String, dynamic>> getGoodsReceiptNotes(int branchId) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getGoodsReceiptNotesAPI(branchId),
      debugTag: 'GrnListAPI',
    );
  }

  Future<Map<String, dynamic>> getGoodsReceiptNoteDetails({
    required int branchId,
    required int grnId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: getGoodsReceiptNoteDetailsAPI(branchId, grnId),
      debugTag: 'GrnDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> createGoodsReceiptNote({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: getGoodsReceiptNotesAPI(branchId),
      body: payload,
      debugTag: 'CreateGrnAPI',
    );
  }

  Future<Map<String, dynamic>> createPayrollAdditionalCharge({
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: payrollAdditionalChargesAPI,
      body: payload,
      debugTag: 'CreatePayrollAdditionalChargeAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollAdditionalCharges() {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollAdditionalChargesAPI,
      debugTag: 'PayrollAdditionalChargesListAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollAdditionalChargeDetails({
    required String chargeId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollAdditionalChargeDetailsAPI(chargeId),
      debugTag: 'PayrollAdditionalChargeDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> updatePayrollAdditionalCharge({
    required String chargeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: payrollAdditionalChargeDetailsAPI(chargeId),
      body: payload,
      debugTag: 'UpdatePayrollAdditionalChargeAPI',
    );
  }

  Future<Map<String, dynamic>> deletePayrollAdditionalCharge({
    required String chargeId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: payrollAdditionalChargeDetailsAPI(chargeId),
      debugTag: 'DeletePayrollAdditionalChargeAPI',
    );
  }

  Future<Map<String, dynamic>> createPayrollDeduction({
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: payrollDeductionsAPI,
      body: payload,
      debugTag: 'CreatePayrollDeductionAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollDeductions() {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollDeductionsAPI,
      debugTag: 'PayrollDeductionsListAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollDeductionDetails({
    required String deductionId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollDeductionDetailsAPI(deductionId),
      debugTag: 'PayrollDeductionDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> updatePayrollDeduction({
    required String deductionId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: payrollDeductionDetailsAPI(deductionId),
      body: payload,
      debugTag: 'UpdatePayrollDeductionAPI',
    );
  }

  Future<Map<String, dynamic>> deletePayrollDeduction({
    required String deductionId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: payrollDeductionDetailsAPI(deductionId),
      debugTag: 'DeletePayrollDeductionAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollReviewDetails({
    required int branchId,
    required String payrollId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollReviewDetailsAPI(branchId, payrollId),
      debugTag: 'PayrollReviewDetailsAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollPaidLeavesReview({
    required int branchId,
    String? payrollId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollPaidLeavesReviewAPI(branchId, payrollId: payrollId),
      debugTag: 'PayrollPaidLeavesReviewAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollSetupTeamMembers({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollSetupTeamMembersAPI(branchId),
      debugTag: 'PayrollSetupTeamMembersAPI',
    );
  }

  Future<Map<String, dynamic>> createEmployeeSalaryConfig({
    required int employeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: employeeSalaryHistoryAPI(employeeId),
      body: payload,
      debugTag: 'CreateEmployeeSalaryConfigAPI',
    );
  }

  Future<Map<String, dynamic>> updateEmployeeSalaryConfig({
    required int employeeId,
    required int salaryId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: employeeSalaryConfigAPI(employeeId, salaryId),
      body: payload,
      debugTag: 'UpdateEmployeeSalaryConfigAPI',
    );
  }

  Future<Map<String, dynamic>> generatePayroll({
    required int branchId,
    required int month,
    required int year,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: generatePayrollAPI(branchId, month: month, year: year),
      debugTag: 'GeneratePayrollAPI',
    );
  }

  Future<Map<String, dynamic>> cancelPayroll({
    required int branchId,
    required String payrollId,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: cancelPayrollAPI(branchId, payrollId),
      debugTag: 'CancelPayrollAPI',
    );
  }

  Future<Map<String, dynamic>> getBranchAdvances({
    required int branchId,
    required int month,
    required int year,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchAdvancesAPI(branchId, month: month, year: year),
      debugTag: 'BranchAdvancesAPI',
    );
  }

  Future<Map<String, dynamic>> createEmployeeAdvance({
    required int branchId,
    required int employeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: employeeAdvancesAPI(branchId, employeeId),
      body: payload,
      debugTag: 'CreateEmployeeAdvanceAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollEmployeeAdjustments({
    required int payrollEmployeeId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollEmployeeAdjustmentsAPI(payrollEmployeeId),
      debugTag: 'PayrollEmployeeAdjustmentsListAPI',
    );
  }

  Future<Map<String, dynamic>> updatePayrollEmployeeAdjustment({
    required int payrollEmployeeId,
    required String adjustmentId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint:
          payrollEmployeeAdjustmentDetailsAPI(payrollEmployeeId, adjustmentId),
      body: payload,
      debugTag: 'UpdatePayrollEmployeeAdjustmentAPI',
    );
  }

  Future<Map<String, dynamic>> deletePayrollEmployeeAdjustment({
    required int payrollEmployeeId,
    required String adjustmentId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint:
          payrollEmployeeAdjustmentDetailsAPI(payrollEmployeeId, adjustmentId),
      debugTag: 'DeletePayrollEmployeeAdjustmentAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollEmployeePaidLeave({
    required int payrollEmployeeId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollEmployeePaidLeaveAPI(payrollEmployeeId),
      debugTag: 'PayrollEmployeePaidLeaveAPI',
    );
  }

  Future<Map<String, dynamic>> setPayrollEmployeePaidLeave({
    required int payrollEmployeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: payrollEmployeePaidLeaveAPI(payrollEmployeeId),
      body: payload,
      debugTag: 'SetPayrollEmployeePaidLeaveAPI',
    );
  }

  Future<Map<String, dynamic>> createPayrollEmployeePaidLeave({
    required int payrollEmployeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: payrollEmployeePaidLeaveAPI(payrollEmployeeId),
      body: payload,
      debugTag: 'CreatePayrollEmployeePaidLeaveAPI',
    );
  }

  Future<Map<String, dynamic>> deletePayrollEmployeePaidLeave({
    required int payrollEmployeeId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: payrollEmployeePaidLeaveAPI(payrollEmployeeId),
      debugTag: 'DeletePayrollEmployeePaidLeaveAPI',
    );
  }

  Future<Map<String, dynamic>> getBranchPayrollPaidLeaveConfig({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchPayrollPaidLeaveConfigAPI(branchId),
      debugTag: 'BranchPayrollPaidLeaveConfigAPI',
    );
  }

  Future<Map<String, dynamic>> createBranchPayrollPaidLeaveConfig({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: branchPayrollPaidLeaveConfigAPI(branchId),
      body: payload,
      debugTag: 'CreateBranchPayrollPaidLeaveConfigAPI',
    );
  }

  Future<Map<String, dynamic>> updateBranchPayrollPaidLeaveConfig({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: branchPayrollPaidLeaveConfigAPI(branchId),
      body: payload,
      debugTag: 'UpdateBranchPayrollPaidLeaveConfigAPI',
    );
  }

  Future<Map<String, dynamic>> deleteBranchPayrollPaidLeaveConfig({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: branchPayrollPaidLeaveConfigAPI(branchId),
      debugTag: 'DeleteBranchPayrollPaidLeaveConfigAPI',
    );
  }

  Future<Map<String, dynamic>> getBranchTeamAttendanceHistory({
    required int branchId,
    required int month,
    required int year,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchTeamAttendanceHistoryAPI(
        branchId,
        month: month,
        year: year,
      ),
      debugTag: 'BranchTeamAttendanceHistoryAPI',
    );
  }

  Future<Map<String, dynamic>> getSalonHolidayCalendar({
    required int salonId,
    required int month,
    required int year,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: salonHolidayCalendarAPI(salonId, month: month, year: year),
      debugTag: 'SalonHolidayCalendarAPI',
    );
  }

  Future<Map<String, dynamic>> createSalonHoliday({
    required int salonId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonHolidayCalendarAPI(salonId),
      body: payload,
      debugTag: 'CreateSalonHolidayAPI',
    );
  }

  Future<Map<String, dynamic>> updateSalonHoliday({
    required int salonId,
    required int holidayId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: salonHolidayCalendarDetailsAPI(salonId, holidayId),
      body: payload,
      debugTag: 'UpdateSalonHolidayAPI',
    );
  }

  Future<Map<String, dynamic>> deleteSalonHoliday({
    required int salonId,
    required int holidayId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: salonHolidayCalendarDetailsAPI(salonId, holidayId),
      debugTag: 'DeleteSalonHolidayAPI',
    );
  }

  // ---------------------- CONFIRM APPOINTMENT ----------------------
  Future<Map<String, dynamic>> confirmAppointment({
    required int branchId,
    required int appointmentId,
  }) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
        baseUrl + confirmAppointmentAPI(branchId, appointmentId),
      );
      print("Confirm Appointment URL: $url");

      final resp = await _sharedClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 25));

      print("[Confirm] Status: ${resp.statusCode}");
      print("[Confirm] Body: ${resp.body}");

      final body = resp.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(resp.body) as Map<String, dynamic>);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Appointment confirmed',
          'data': body['data'],
        };
      } else {
        return {
          'success': body['success'] ?? false,
          'message': body['message'] ?? 'Failed to confirm appointment',
          'statusCode': resp.statusCode,
          'data': body['data'],
        };
      }
    } catch (e) {
      print("Error confirming appointment: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  //It is a dummy api
  Future<Map<String, dynamic>> cancelAppointment({
    required int branchId,
    required int appointmentId,
  }) async {
    try {
      final response = await _sharedClient.post(
        Uri.parse('$baseUrl/appointments/$appointmentId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'branchId': branchId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Failed to cancel appointment'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateService({
    required int branchId,
    required int branchServiceId,
    required Map<String, dynamic> body,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      throw Exception('Authentication required');
    }

    final url = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/branches/$branchId/services/$branchServiceId',
    );

    final payload = {
      'displayName': body['displayName'] ?? body['name'],
      'description': body['description'] ?? '',
      'durationMin': body['durationMin'] ?? body['defaultDurationMin'],
      'priceType': body['priceType'] ?? 'fixed',
      'priceMinor': body['priceMinor'] ?? body['defaultPriceMinor'],
      'isActive': body['isActive'] ?? true,
      if (body.containsKey('passiveWaitEnabled'))
        'passiveWaitEnabled': body['passiveWaitEnabled'],
      if (body.containsKey('initialBusyMinutes'))
        'initialBusyMinutes': body['initialBusyMinutes'],
      if (body.containsKey('passiveWaitMinutes'))
        'passiveWaitMinutes': body['passiveWaitMinutes'],
      if (body.containsKey('finalBusyMinutes'))
        'finalBusyMinutes': body['finalBusyMinutes'],
      if (body.containsKey('commissionEnabled'))
        'commissionEnabled': body['commissionEnabled'],
      if (body.containsKey('commissionType'))
        'commissionType': body['commissionType'],
      if (body.containsKey('commissionPercentage'))
        'commissionPercentage': body['commissionPercentage'],
      if (body.containsKey('commissionFixedAmountMinor'))
        'commissionFixedAmountMinor': body['commissionFixedAmountMinor'],
      if (body.containsKey('commissionMaxAmountMinor'))
        'commissionMaxAmountMinor': body['commissionMaxAmountMinor'],
    }..removeWhere((key, value) => value == null);

    const encoder = JsonEncoder.withIndent('  ');
    print('🟢 [UPDATE SERVICE] PATCH -> $url');
    print('🔸 Request Body:\n${encoder.convert(payload)}');

    final response = await _sharedClient.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print('🔹 Response Status: ${response.statusCode}');
    print('🔹 Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = response.body.isEmpty ? '{}' : response.body;
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }

    String message = 'Failed to update service';

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'];

        if (msg is List) {
          message = msg.join('\n');
        } else if (msg != null) {
          message = msg.toString();
        }
      }
    } catch (_) {}

    throw Exception(message);
  }

// ---------------------- START APPOINTMENT ----------------------
  static Future<Map<String, dynamic>> startAppointment({
    required int branchId,
    required int appointmentId,
    required String otp,
  }) async {
    final token = await ApiService().getAuthToken();
    if (token.isEmpty) {
      throw Exception('Token is missing');
    }

    final url = Uri.parse(
      "$baseUrl${startAppointmentAPI(branchId, appointmentId)}",
    );

    bool _asBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' ||
            normalized == 'success' ||
            normalized == 'ok';
      }
      return false;
    }

    try {
      // 🔍 Log request
      print("====== [START_APPOINTMENT REQUEST] ======");
      print("➡️ URL: $url");
      print("➡️ Headers: {"
          "Content-Type: application/json, "
          "Authorization: Bearer ${token.substring(0, 8)}...}");
      print("➡️ Body: ${jsonEncode({
            'branchId': branchId,
            'appointmentId': appointmentId,
            'otp': otp,
          })}");
      print("=========================================");

      final response = await _sharedClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'branchId': branchId,
          'appointmentId': appointmentId,
          'otp': otp,
        }),
      );

      // 🔍 Log raw response
      print("====== [START_APPOINTMENT RESPONSE] =====");
      print("⬅️ Status: ${response.statusCode}");
      print("⬅️ Raw Body: ${response.body}");
      print("=========================================");

      final bool statusOk =
          response.statusCode >= 200 && response.statusCode < 300;

      Map<String, dynamic> body = const <String, dynamic>{};
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          }
        } catch (e) {
          print("⚠️ JSON Decode Error: $e");
          body = const <String, dynamic>{};
        }
      }

      // 🔍 Log decoded body
      print("====== [PARSED JSON BODY] ===============");
      print(body);
      print("=========================================");

      bool? successValue;
      if (body.containsKey('success')) {
        successValue = _asBool(body['success']);
      } else if (body.containsKey('status')) {
        successValue = _asBool(body['status']);
      }
      final bool success = successValue ?? statusOk;

      final result = <String, dynamic>{
        'success': success,
        'statusCode': response.statusCode,
        'body': body,
        'rawBody': response.body,
      };

      if (body.containsKey('message') && body['message'] != null) {
        result['message'] = body['message'];
      } else if (!success) {
        result['message'] = 'Failed to start appointment';
      }

      if (body.containsKey('data')) {
        result['data'] = body['data'];
      }

      // 🔍 Final result
      print("====== [FINAL RESULT MAP] ===============");
      print(result);
      print("=========================================");

      return result;
    } catch (e, stack) {
      print('[START_APPOINTMENT] Exception: $e');
      print('Stacktrace: $stack');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

// ---------------------- NO SHOW APPOINTMENT ----------------------
  Future<Map<String, dynamic>> noShowAppointment({
    required int branchId,
    required int appointmentId,
  }) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
        "$baseUrl${noShowAppointmentAPI(branchId, appointmentId)}",
      );

      final resp = await _sharedClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic> body = const <String, dynamic>{};
      if (resp.body.isNotEmpty) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      }

      final success = resp.statusCode >= 200 && resp.statusCode < 300;
      return {
        'success': body['success'] ?? success,
        'message': body['message'] ??
            (success ? 'Appointment marked no show' : 'Failed to mark no show'),
        'statusCode': resp.statusCode,
        'data': body['data'],
        'body': body,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

// ---------------------- COMPLETE APPOINTMENT ----------------------
  Future<Map<String, dynamic>> completeAppointment({
    required int branchId,
    required int appointmentId,
    required int rating,
    String? comment,
  }) async {
    try {
      final token = await ApiService().getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
        "$baseUrl${completeAppointmentAPI(branchId, appointmentId)}",
      );

      print("➡️ [COMPLETE_APPOINTMENT] Request:");
      print("  URL: $url");
      print("  Method: POST");
      print(
          "  Headers: { Content-Type: application/json, Authorization: Bearer $token }");
      print("  Body: ${jsonEncode({
            "rating": rating,
            if (comment != null) "comment": comment,
          })}");
      print("  Token: $token");
      final resp = await _sharedClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "rating": rating,
          if (comment != null) "comment": comment,
        }),
      );

      print("⬅️ [COMPLETE_APPOINTMENT] Response:");
      print("  Status Code: ${resp.statusCode}");
      print("  Body: ${resp.body}");

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isNotEmpty
            ? (jsonDecode(resp.body) as Map<String, dynamic>)
            : {};
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Appointment completed',
          'data': body['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to complete appointment',
          'statusCode': resp.statusCode,
          'body': resp.body,
        };
      }
    } catch (e, stack) {
      print("❌ [COMPLETE_APPOINTMENT] Exception: $e");
      print("Stacktrace: $stack");
      return {'success': false, 'message': e.toString()};
    }
  }

//Get Branch Ratings
  static Future<Map<String, dynamic>> fetchBranchRatings(int branchId) async {
    final token = await ApiService().getAuthToken();
    final url = Uri.parse(baseUrl + getBranchRatings(branchId));

    // Log request details
    print("➡️ [GET] $url");
    print("🔑 Token: $token");
    print("📩 Headers: {"
        '"Content-Type": "application/json", '
        '"Accept": "application/json", '
        '"Authorization": "Bearer $token"'
        "}");

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token", // 👈 token added here
      },
    );

    // Log response details
    print("⬅️ Response Status: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Failed to load branch ratings: ${response.statusCode} - ${response.body}",
      );
    }
  }

  // ------------------ UPDATE METHODS ------------------
// ------------------ UPDATE METHODS ------------------
// PATCH /branches/{branchId}/categories/{branchCategoryId}
  static Future<http.Response> updateBCategoryPatch(
    int branchId,
    int categoryId,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await ApiService().getAuthToken();
      final url =
          Uri.parse(baseUrl + updateBranchCategory(branchId, categoryId));

      final merged = {
        ...body,
        "isActive": true,
        "sortOrder": 200,
      }..removeWhere((k, v) => v == null);

      final safeToken =
          token.isNotEmpty ? '${token.substring(0, 8)}…redacted' : '';
      print("🔹 [PATCH] Update Category → $url");
      print(
          "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}");
      print("Body: ${jsonEncode(merged)}");

      final res = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(merged),
      );
      print("✅ Status: ${res.statusCode}");
      print("Response: ${res.body}");
      return res;
    } catch (e, st) {
      print("❌ Error in updateBCategoryPatch: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

// PATCH /branches/{branchId}/subcategories/{branchSubCategoryId}
  static Future<http.Response> updateBSubCategoryPatch(
    int branchId,
    int subCategoryId,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await ApiService().getAuthToken();
      final url =
          Uri.parse(baseUrl + updateBranchSubCategory(branchId, subCategoryId));

      final merged = {
        ...body,
        "isActive": true,
        "sortOrder": 200,
      }..removeWhere((k, v) => v == null);

      final safeToken =
          token.isNotEmpty ? '${token.substring(0, 8)}…redacted' : '';
      print("🔹 [PATCH] Update SubCategory → $url");
      print(
          "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}");
      print("Body: ${jsonEncode(merged)}");

      final res = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(merged),
      );
      print("✅ Status: ${res.statusCode}");
      print("Response: ${res.body}");
      return res;
    } catch (e, st) {
      print("❌ Error in updateBSubCategoryPatch: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

// PATCH /branches/{branchId}/services/{branchServiceId}
  static Future<http.Response> updateBServicePatch(
    int branchId,
    int serviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await ApiService().getAuthToken();
      final url = Uri.parse(baseUrl + updateBranchService(branchId, serviceId));

      // Enforce schema-required/allowed fields for service update
      final merged = {
        ...body,
        "isActive": true, // static per your requirement
        "priceType": "fixed", // swagger example shows "fixed"
      }..removeWhere((k, v) => v == null);

      final safeToken = token.isNotEmpty
          ? '${token.substring(0, token.length.clamp(0, 8))}…redacted'
          : '';

      print("🔹 [PATCH] Update Service → $url");
      print(
          "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}");
      print("Body: ${jsonEncode(merged)}");

      final response = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(merged),
      );

      print("✅ Status: ${response.statusCode}");
      print("Response: ${response.body}");
      return response;
    } catch (e, st) {
      print("❌ Error in updateBServicePatch: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

  // ------------------ DELETE METHODS ------------------
  static Future<http.Response> deleteBCategory(
      int branchId, int categoryId) async {
    try {
      final token = await ApiService().getAuthToken();
      final url =
          Uri.parse(baseUrl + deleteBranchCategory(branchId, categoryId));

      print("🗑 [DELETE] Category → $url");
      print("Headers: {Authorization: Bearer $token}");

      final response = await _sharedClient.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      print("✅ Status: ${response.statusCode}");
      print("Response: ${response.body}");

      return response;
    } catch (e, st) {
      print("❌ Error in deleteBCategory: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

  static Future<http.Response> deleteBSubCategory(
      int branchId, int subCategoryId) async {
    try {
      final token = await ApiService().getAuthToken();
      final url =
          Uri.parse(baseUrl + deleteBranchSubCategory(branchId, subCategoryId));

      print("🗑 [DELETE] SubCategory → $url");
      print("Headers: {Authorization: Bearer $token}");

      final response = await _sharedClient.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      print("✅ Status: ${response.statusCode}");
      print("Response: ${response.body}");

      return response;
    } catch (e, st) {
      print("❌ Error in deleteBSubCategory: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

  static Future<http.Response> deleteBService(
      int branchId, int serviceId) async {
    try {
      final token = await ApiService().getAuthToken();
      final url = Uri.parse(baseUrl + deleteBranchService(branchId, serviceId));

      print("🗑 [DELETE] Service → $url");
      print("Headers: {Authorization: Bearer $token}");

      final response = await _sharedClient.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      print("✅ Status: ${response.statusCode}");
      print("Response: ${response.body}");

      return response;
    } catch (e, st) {
      print("❌ Error in deleteBService: $e");
      print("StackTrace: $st");
      rethrow;
    }
  }

  /// ---------------------- RESOLVE WALKIN NUMBER ----------------------
  Future<Map<String, dynamic>> resolveWalkinNumber(
      int branchId, String countryCode, String phoneNumber) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${resolveWalkinNumberAPI(branchId)}');

    print("➡️ Calling Resolve Walkin Number API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");
    print("➡️ Body: { countryCode: $countryCode, phoneNumber: $phoneNumber }");

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "countryCode": countryCode,
        "phoneNumber": phoneNumber,
      }),
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to resolve walkin number: ${response.body}");
    }
  }

// ---------------------- CREATE APPOINTMENT ----------------------
  Future<Map<String, dynamic>> createAppointment(
      int branchId, Map<String, dynamic> payload) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${createAppointmentAPI(branchId)}');

    print("➡️ Calling Create Appointment API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");
    print("➡️ Payload: ${jsonEncode(payload)}");

    try {
      final response = await _sharedClient.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception("Failed to create appointment: ${response.body}");
      }
    } catch (e) {
      print("❌ Error creating appointment: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createManualBooking(
    int branchId,
    Map<String, dynamic> payload,
  ) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${createManualBookingAPI(branchId)}');

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to create manual booking: ${response.body}");
  }

  Future<Map<String, dynamic>> assignUserToBranch(
      int branchId,
      int userId,
      String joiningDate,
      List<Map<String, dynamic>> schedules,
      List<int> branchServiceIds,
      bool allowOnlineBooking) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${assignUserToBranchAPI(branchId)}');

    final payload = {
      "userId": userId,
      "joiningDate": joiningDate, // e.g. "2025-08-21"
      "schedules": schedules, // multiple schedules, multiple days allowed
      "branchServiceIds": branchServiceIds,
      "allowOnlineBooking": allowOnlineBooking,
    };

    print("➡️ Calling Assign User To Branch API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");
    print("➡️ Payload: ${jsonEncode(payload)}");

    try {
      final response = await _sharedClient.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        String message = 'Failed to assign user';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            message = response.body;
          }
        }
        throw Exception(message);
      }
    } catch (e) {
      print("❌ Error assigning user: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTeamMember({
    required int branchId,
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    final token = await getAuthToken();
    final url =
        Uri.parse('$baseUrl${updateTeamMemberEndpoint(branchId, userId)}');
    final response = await _sharedClient.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to update team member: ${response.body}");
  }

  // Future<Map<String, dynamic>> setTeamMemberActive({
  //   required int branchId,
  //   required int userId,
  //   required bool active,
  // }) async {
  //   final token = await getAuthToken();
  //   final endpoint = active
  //       ? activateTeamMemberEndpoint(branchId, userId)
  //       : deactivateTeamMemberEndpoint(branchId, userId);
  //   final url = Uri.parse('$baseUrl$endpoint');
  //   final response = await _sharedClient.patch(
  //     url,
  //     headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     },
  //     body: '{}',
  //   );

  //   if (response.statusCode >= 200 && response.statusCode < 300) {
  //     return json.decode(response.body) as Map<String, dynamic>;
  //   }
  //   throw Exception("Failed to update team member status: ${response.body}");
  // }
  Future<Map<String, dynamic>> setTeamMemberActive({
    required int branchId,
    required int userId,
    required bool active,
  }) async {
    final token = await getAuthToken();

    final endpoint = active
        ? activateTeamMemberEndpoint(branchId, userId)
        : deactivateTeamMemberEndpoint(branchId, userId);

    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await _sharedClient.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: '{}',
      );

      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': active
              ? 'Team member activated successfully'
              : 'Team member deactivated successfully',
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message': body['message']?.toString() ??
            (active
                ? 'Failed to activate team member'
                : 'Failed to deactivate team member'),
        'statusCode': response.statusCode,
        'data': body['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      };
    }
  }

  // Future<Map<String, dynamic>> deleteTeamMember({
  //   required int branchId,
  //   required int userId,
  // }) async {
  //   final token = await getAuthToken();
  //   final url =
  //       Uri.parse('$baseUrl${updateTeamMemberEndpoint(branchId, userId)}');
  //   final response = await _sharedClient.delete(
  //     url,
  //     headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     },
  //     body: '{}',
  //   );

  //   if (response.statusCode >= 200 && response.statusCode < 300) {
  //     return response.body.isEmpty
  //         ? <String, dynamic>{'success': true}
  //         : json.decode(response.body) as Map<String, dynamic>;
  //   }
  //   throw Exception("Failed to delete team member: ${response.body}");
  // }
  Future<Map<String, dynamic>> deleteTeamMember({
    required int branchId,
    required int userId,
  }) async {
    final token = await getAuthToken();
    final url =
        Uri.parse('$baseUrl${updateTeamMemberEndpoint(branchId, userId)}');

    try {
      final response = await _sharedClient.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: '{}',
      );

      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': 'Team member deleted successfully',
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message':
            body['message']?.toString() ?? 'Failed to delete team member',
        'statusCode': response.statusCode,
        'data': body['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      };
    }
  }

  Future<Map<String, dynamic>> importClientsByPhone({
    required int branchId,
    required List<Map<String, dynamic>> clients,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${importClientsByPhoneAPI(branchId)}');
    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({'clients': clients}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to import clients: ${response.body}");
  }

  Future<Map<String, dynamic>> importClientsFile({
    required int branchId,
    required File file,
  }) async {
    final token = await getAuthToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl${importClientsFileAPI(branchId)}'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await _sharedClient.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isEmpty
          ? <String, dynamic>{'success': true}
          : json.decode(body) as Map<String, dynamic>;
    }
    throw Exception("Failed to import clients file: $body");
  }

  Future<Map<String, dynamic>> getReportsDashboard({
    int? branchId,
    String? date,
  }) async {
    final token = await getAuthToken();
    final endpoint =
        branchId == null ? reportsDashboardAPI : salonOwnerDashboardAPI;
    final baseUri = Uri.parse('$baseUrl$endpoint');
    final queryParameters = <String, String>{
      if (branchId != null) 'branchId': branchId.toString(),
      if (date != null && date.trim().isNotEmpty) 'date': date,
    };
    final url = queryParameters.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParameters);
    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[ReportsDashboard] url=$url");
    debugPrint("[ReportsDashboard] status=${response.statusCode}");
    _debugPrintChunked("ReportsDashboard body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to load reports dashboard: ${response.body}");
  }

  Future<Map<String, dynamic>> getRevenueSalesDashboard({
    required int branchId,
    required String dateRange,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl$revenueSalesDashboardAPI').replace(
      queryParameters: {
        'branchId': branchId.toString(),
        'dateRange': dateRange,
      },
    );

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[RevenueSalesDashboard] url=$url");
    debugPrint("[RevenueSalesDashboard] status=${response.statusCode}");
    _debugPrintChunked("RevenueSalesDashboard body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to load revenue and sales: ${response.body}");
  }

  Future<Map<String, dynamic>> getStaffPerformanceReport({
    required int branchId,
    required String dateRange,
    int page = 1,
    int perPage = 10,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl$staffPerformanceAPI').replace(
      queryParameters: {
        'branchId': branchId.toString(),
        'dateRange': dateRange,
        'page': page.toString(),
        'perPage': perPage.toString(),
      },
    );

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[StaffPerformance] url=$url");
    debugPrint("[StaffPerformance] status=${response.statusCode}");
    _debugPrintChunked("StaffPerformance body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to load staff performance: ${response.body}");
  }

  Future<Map<String, dynamic>> getOperationsDashboard({
    required int branchId,
    required String dateRange,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl$operationsDashboardAPI').replace(
      queryParameters: {
        'branchId': branchId.toString(),
        'dateRange': dateRange,
      },
    );

    final response = await _sharedClient.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("[OperationsDashboard] url=$url");
    debugPrint("[OperationsDashboard] status=${response.statusCode}");
    _debugPrintChunked("OperationsDashboard body", response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception("Failed to load operations dashboard: ${response.body}");
  }

  Future<Map<String, dynamic>> getAiInsightsDashboardSummary({
    required int branchId,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final from = DateFormat('yyyy-MM-dd').format(fromDate);
    final to = DateFormat('yyyy-MM-dd').format(toDate);
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint:
          '$aiInsightsDashboardSummaryAPI?branch_id=$branchId&from_date=$from&to_date=$to',
      debugTag: 'AiInsightsDashboardSummary',
    );
  }

  Future<Map<String, dynamic>> getBranchDashboard({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchDashboardAPI(branchId),
      debugTag: 'BranchDashboardAPI',
    );
  }

  Future<Map<String, dynamic>> fetchMyAppointmentRatings(int branchId) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/branches/$branchId/appointments/ratings/me',
      );
      debugPrint(
        '[StylistReviewsAPI] GET $url | branchId=$branchId',
      );

      final response = await _sharedClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[StylistReviewsAPI] status=${response.statusCode}');
      _debugPrintChunked('StylistReviewsAPI body', response.body);

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      _debugPrintChunked('StylistReviewsAPI decoded', decoded);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map<String, dynamic>
            ? decoded['message']?.toString() ?? 'Failed to load reviews'
            : 'Failed to load reviews',
        'data': decoded,
      };
    } catch (e) {
      debugPrint('[StylistReviewsAPI] error=$e');
      return {
        'success': false,
        'message': e.toString(),
        'data': const <String, dynamic>{},
      };
    }
  }
}
