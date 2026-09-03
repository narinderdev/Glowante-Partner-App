// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings, non_constant_identifier_names, unnecessary_string_interpolations, prefer_adjacent_string_concatenation, curly_braces_in_flow_control_structures, no_leading_underscores_for_local_identifiers

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // 👈 needed for File
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/aws_s3_uploader.dart'; // 👈 import uploader
import 'package:image_picker/image_picker.dart'; // 👈 add this
import '../config/app_environment.dart';
import '../services/auth_session_manager.dart';
import '../services/network_listener.dart';
import '../services/token_expiration_service.dart';
import '../Viewmodels/AddCategory.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import 'error_parser.dart';
import 'dart:async';

String _apiErrorMessage(dynamic body, {required String fallback}) {
  return extractErrorMessage(body, fallback: fallback);
}

/// Parses a response using the standard `{success, message, data}` envelope
/// (the `/auth/otp/*` and `/*team-invitations*` endpoints both follow it).
///
/// On 200/201 the decoded envelope is returned as-is. On any other status,
/// this builds a consistent failure map exposing the structured `error.code`
/// from the response body (e.g. `INVALID_OTP`, `INVITATION_EXPIRED`)
/// alongside the human-readable message, plus a `retryAfterSeconds` value
/// read from the `Retry-After` header on 429s.
Map<String, dynamic> _parseEnvelopeResponse(
  http.Response response, {
  required String fallback,
}) {
  dynamic decoded;
  try {
    decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
  } catch (_) {
    decoded = {};
  }

  if (response.statusCode == 200 || response.statusCode == 201) {
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': true, 'data': decoded};
  }

  final Map<String, dynamic> map =
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  final dynamic error = map['error'];
  final String? code =
      error is Map ? error['code']?.toString() : map['code']?.toString();
  final String message = _apiErrorMessage(response.body, fallback: fallback);

  final String? retryAfterHeader =
      response.headers['retry-after'] ?? response.headers['Retry-After'];
  final int? retryAfterSeconds =
      retryAfterHeader == null ? null : int.tryParse(retryAfterHeader.trim());

  return {
    'success': false,
    'message': message,
    if (code != null && code.isNotEmpty) 'code': code,
    'statusCode': response.statusCode,
    if (retryAfterSeconds != null) 'retryAfterSeconds': retryAfterSeconds,
  };
}

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

  static String get baseUrl => AppEnvironment.baseUrl;

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

  static void _logRequest({
    required String tag,
    required Uri url,
    required Map<String, String> headers,
    required Object body,
  }) {
    print('[$tag] URL: $url');
    print('[$tag] Headers: $headers');
    print('[$tag] Body: $body');
  }

  static List<Map<String, dynamic>> _extractMapList(dynamic source) {
    dynamic candidate = source;
    final visited = <String>{};

    while (candidate is Map) {
      final map = Map<String, dynamic>.from(candidate);
      final listKeys = ['data', 'appointments', 'items', 'bookings'];
      var foundNested = false;

      for (final key in listKeys) {
        final nested = map[key];
        if (nested is List) {
          candidate = nested;
          foundNested = true;
          break;
        }
        if (nested is Map && visited.add('$key:${nested.hashCode}')) {
          candidate = nested;
          foundNested = true;
          break;
        }
      }

      if (!foundNested) {
        return const <Map<String, dynamic>>[];
      }
    }

    if (candidate is List) {
      return candidate
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  static const String otpRequestEndpoint = "auth/otp/request";
  static const String otpResendEndpoint = "auth/otp/resend";
  static const String otpVerifyChallengeEndpoint = "auth/otp/verify";
  // Salon team invitation endpoints (see invitation_plan.md).
  static const String teamInvitationResolveEndpoint =
      "public/team-invitations/resolve";
  static const String teamInvitationAcceptEndpoint =
      "public/team-invitations/accept";
  static const String myTeamInvitationsEndpoint = "me/team-invitations";
  static String myTeamInvitationDeclineEndpoint(int invitationId) =>
      "me/team-invitations/$invitationId/decline";
  static String salonTeamInvitationsEndpoint(int salonId) =>
      "salons/$salonId/team-invitations";
  static String salonTeamInvitationCancelEndpoint(
    int salonId,
    int invitationId,
  ) =>
      "salons/$salonId/team-invitations/$invitationId/cancel";
  // salon_team_part_1_updated_3.md / salon_team_part_2.md — the new
  // dedicated Team read (summary/members/invitations/detail) and
  // profile-completion (PATCH) endpoints. These sit alongside, and will
  // eventually replace, the legacy endpoints above for Team-screen reads;
  // the legacy routes stay live for backward compatibility per that spec.
  static String salonTeamSummaryEndpoint(int salonId) =>
      "salons/$salonId/team/summary";
  static String salonTeamMembersEndpoint(int salonId) =>
      "salons/$salonId/team/members";
  static String salonTeamInvitationsV2Endpoint(int salonId) =>
      "salons/$salonId/team/invitations";
  static String salonTeamMemberDetailEndpoint(int salonId, int userId) =>
      "salons/$salonId/team/$userId";
  static String salonTeamMemberProfileEndpoint(int salonId, int userId) =>
      "salons/$salonId/team/$userId/profile";
  static String salonTeamMemberAvatarEndpoint(int salonId, int userId) =>
      "salons/$salonId/team/$userId/avatar";
  // salon_user_compensation.md — employment type + salary history, on the
  // same salons/:salonId/team controller prefix as the routes above.
  static String salonTeamMemberCompensationEndpoint(int salonId, int userId) =>
      "salons/$salonId/team/$userId/compensation";
  static String salonTeamMemberEmploymentTypeEndpoint(
    int salonId,
    int userId,
  ) =>
      "salons/$salonId/team/$userId/employment-type";
  static String salonTeamMemberCompensationItemEndpoint(
    int salonId,
    int userId,
    int compensationId,
  ) =>
      "salons/$salonId/team/$userId/compensation/$compensationId";
  // Legacy endpoint, still used by the walk-in client verification flow in
  // AddBookings.dart. Not covered by the AUTH-04 OTP challenge cutover spec
  // (see authentication_implmentation.md) — needs its own follow-up.
  static const String verifyOtpEndpoint = "auth/verify-otp";
  static const String registerUserEndpoint = "auth/register";
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

  static String salonPayoutAccountsAPI(int salonId) =>
      "salons/$salonId/payout-accounts";

  static String salonPayoutAccountOnboardBankAPI(int salonId) =>
      "salons/$salonId/payout-accounts/onboard-bank";

  static String salonPayoutAccountAPI(int salonId, int payoutAccountId) =>
      "salons/$salonId/payout-accounts/$payoutAccountId";

  static String salonPayoutAccountDefaultAPI(
    int salonId,
    int payoutAccountId,
  ) =>
      "salons/$salonId/payout-accounts/$payoutAccountId/default";

  static String salonPayoutAccountSecondaryAPI(
    int salonId,
    int payoutAccountId,
  ) =>
      "salons/$salonId/payout-accounts/$payoutAccountId/secondary";

  static String salonPayoutAccountUpdateBankAPI(
    int salonId,
    int payoutAccountId,
  ) =>
      "salons/$salonId/payout-accounts/$payoutAccountId/update-bank";

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

  static String validateTeamMemberContactEndpoint(int branchId) {
    return "branches/$branchId/team/validate-contact";
  }

  static String teamMemberDetailsEndpoint(int branchId, int userId) {
    return "branches/$branchId/team/$userId";
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
  static String salonUpcomingSubscriptionActivateNowAPI(int salonId) =>
      "salons/$salonId/subscriptions/upcoming/activate-now";
  static String salonSubscriptionPaymentOrderAPI(int salonId) =>
      "salons/$salonId/subscriptions/payment-order";
  static String salonSubscriptionPaymentVerifyAPI(int salonId) =>
      "salons/$salonId/subscriptions/payment-verify";
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
  static String branchCommissionServicesAPI(int branchId) =>
      "v2/branches/$branchId/commission/services";
  static String branchCommissionStaffAPI(int branchId) =>
      "v2/branches/$branchId/commission/staff";
  static String branchCommissionStaffOverridesAPI(int branchId) =>
      "v2/branches/$branchId/commission/staff-overrides";
  static String branchCommissionStaffOverrideAPI(
    int branchId,
    String overrideId,
  ) =>
      "v2/branches/$branchId/commission/staff-overrides/$overrideId";
  static String branchEmployeeSalaryHistoryAPI(int branchId, int employeeId) =>
      "v2/branches/$branchId/employees/$employeeId/salary";
  static String branchEmployeeSalaryConfigAPI(
    int branchId,
    int employeeId,
    int salaryId,
  ) =>
      "v2/branches/$branchId/employees/$employeeId/salary/$salaryId";
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
  static String branchAdvanceDetailAPI(int branchId, int advanceId) =>
      "v2/branches/$branchId/advances/$advanceId";
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
  static String payrollEmployeeReviewAPI(
    int branchId, {
    required int employeeId,
    required String payrollId,
  }) =>
      "v2/branches/$branchId/review/employees/$employeeId?payrollId=${Uri.encodeComponent(payrollId)}";
  static String payrollEmployeePayAPI(int payrollEmployeeId) =>
      "v2/payroll/employees/$payrollEmployeeId/pay";
  static String payrollPaidLeavesReviewAPI(int branchId, {String? payrollId}) =>
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

  static String payrollAdditionalChargesAPI({
    int? payrollEmployeeId,
    String? payrollId,
  }) {
    final query = <String>[];
    if (payrollEmployeeId != null && payrollEmployeeId > 0) {
      query.add('payrollEmployeeId=$payrollEmployeeId');
    }
    if (payrollId != null && payrollId.trim().isNotEmpty) {
      query.add('payrollId=${Uri.encodeComponent(payrollId)}');
    }
    return query.isEmpty
        ? "payroll/additional-charges"
        : "payroll/additional-charges?${query.join('&')}";
  }

  static String payrollAdditionalChargeDetailsAPI(String chargeId) =>
      "payroll/additional-charges/$chargeId";

  static String payrollDeductionsAPI({
    int? payrollEmployeeId,
    String? payrollId,
  }) {
    final query = <String>[];
    if (payrollEmployeeId != null && payrollEmployeeId > 0) {
      query.add('payrollEmployeeId=$payrollEmployeeId');
    }
    if (payrollId != null && payrollId.trim().isNotEmpty) {
      query.add('payrollId=${Uri.encodeComponent(payrollId)}');
    }
    return query.isEmpty
        ? "payroll/deductions"
        : "payroll/deductions?${query.join('&')}";
  }

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
  static String salonHolidayCalendarAPI(int salonId, {int? month, int? year}) {
    final queryParts = <String>[
      if (month != null) 'month=$month',
      if (year != null) 'year=$year',
    ];
    if (queryParts.isEmpty) {
      return "salons/$salonId/holiday-calendar";
    }
    return "salons/$salonId/holiday-calendar?${queryParts.join('&')}";
  }

  static String salonHolidayCalendarDetailsAPI(int salonId, int holidayId) =>
      "salons/$salonId/holiday-calendar/$holidayId";
  static String getRolesSpecialization({int? branchId}) {
    if (branchId == null) return "users/constants";
    return "users/constants?branchId=$branchId";
  }

  static String getTeamMember(
    int id, {
    String status = 'all',
    bool? allowOnlineBooking,
    List<int> serviceIds = const <int>[],
    DateTime? date,
    bool includeAssignedForDate = false,
    String search = '',
  }) {
    final query = <String, String>{};
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.isNotEmpty && normalizedStatus != 'all') {
      query['status'] = normalizedStatus;
    }
    if (allowOnlineBooking != null) {
      query['allowOnlineBooking'] = allowOnlineBooking.toString();
    }
    if (serviceIds.isNotEmpty) {
      query['serviceIds'] = serviceIds.join(',');
    }
    if (date != null) {
      query['date'] = DateFormat('yyyy-MM-dd').format(date);
    }
    if (includeAssignedForDate) {
      query['includeAssignedForDate'] = 'true';
    }
    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    }

    if (query.isEmpty) return "branches/$id/team";
    return Uri(path: "branches/$id/team", queryParameters: query).toString();
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

  static String appointmentAvailabilityAPI(int branchId, {int? userId}) {
    return Uri(
      path: "branches/$branchId/appointments/availability",
      queryParameters:
          userId == null ? null : <String, String>{'userId': userId.toString()},
    ).toString();
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

  Future<Map<String, dynamic>> createSalonSubscriptionPaymentOrder({
    required int salonId,
    required int planId,
    required String billingCycle,
    required int amountMinor,
    DateTime? startDate,
    bool replaceCurrentPlan = false,
  }) {
    final normalizedBillingCycle =
        billingCycle.toUpperCase() == 'YEARLY' ? 'ANNUAL' : billingCycle;
    final payload = <String, dynamic>{
      'planId': planId,
      'billingCycle': normalizedBillingCycle,
      'amountMinor': amountMinor,
      if (startDate != null)
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      if (replaceCurrentPlan) 'replaceCurrentPlan': true,
    };

    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionPaymentOrderAPI(salonId),
      debugTag: 'CreateSalonSubscriptionPaymentOrder',
      body: payload,
    );
  }

  Future<Map<String, dynamic>> verifySalonSubscriptionPayment({
    required int salonId,
    required Object paymentTransactionId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonSubscriptionPaymentVerifyAPI(salonId),
      debugTag: 'VerifySalonSubscriptionPayment',
      body: <String, dynamic>{
        'paymentTransactionId': paymentTransactionId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
      },
    );
  }

  Future<Map<String, dynamic>> activateSalonSubscriptionNow({
    required int salonId,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: salonUpcomingSubscriptionActivateNowAPI(salonId),
      debugTag: 'ActivateSalonSubscriptionNow',
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
      body: <String, dynamic>{'label': label, 'permissionIds': permissionIds},
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
      body: <String, dynamic>{'label': label, 'permissionIds': permissionIds},
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
    required int userId,
    required String date,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: appointmentAvailabilityAPI(branchId, userId: userId),
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

      final headers = <String, String>{'Authorization': 'Bearer $token'};
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
        return {'success': true, 'data': decoded};
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
        'message': extractErrorMessage(error),
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

  // Request an OTP challenge (auth/otp/request) — replaces the old
  // auth/login endpoint. `purpose` is either 'LOGIN_OR_REGISTER' (default,
  // staff/owner login) or 'SALON_INVITATION_ACCEPTANCE' (with a
  // `contextToken` from the invitation email link).
  Future<Map<String, dynamic>> requestOtp({
    required String nationalNumber,
    String countryIsoCode = 'IN',
    String countryCode = '+91',
    String purpose = 'LOGIN_OR_REGISTER',
    String? contextToken,
    String? deviceToken,
  }) async {
    final requestPayload = <String, dynamic>{
      "purpose": purpose,
      "countryIsoCode": countryIsoCode,
      "countryCode": countryCode,
      "nationalNumber": nationalNumber,
      "source": "salon_app",
      "platform": AppEnvironment.platform,
    };

    String? resolvedToken = deviceToken;
    if (resolvedToken == null || resolvedToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      resolvedToken = prefs.getString('fcm_device_token');
    }
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      requestPayload['deviceToken'] = resolvedToken;
    }
    if (contextToken != null && contextToken.isNotEmpty) {
      requestPayload['contextToken'] = contextToken;
    }

    final url = Uri.parse(baseUrl + otpRequestEndpoint);
    final headers = {"Content-Type": "application/json"};
    final body = json.encode(requestPayload);

    _logRequest(
        tag: 'OtpRequest Request', url: url, headers: headers, body: body);

    final response =
        await _sharedClient.post(url, headers: headers, body: body);

    debugPrint("[OtpRequest] status=${response.statusCode}");
    _debugPrintChunked("OtpRequest body", response.body);

    return _parseEnvelopeResponse(response, fallback: 'Failed to send OTP');
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
      body: json.encode({"phoneNumber": phoneNumber, "otp": otp}),
    );

    debugPrint("[VerifyOTP] status=${response.statusCode}");
    _debugPrintChunked("VerifyOTP body", response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.body);
        _debugPrintChunked("VerifyOTP decoded", decoded);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'success': true, 'data': decoded};
      } catch (error) {
        return {
          'success': false,
          'message': extractErrorMessage(
            error,
            fallback: 'OTP verification failed',
          ),
          'statusCode': response.statusCode,
        };
      }
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    } else {
      decoded = {};
    }

    if (decoded is Map<String, dynamic>) {
      return {
        'success': false,
        'message': decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString()
            : 'Invalid OTP',
        'statusCode': response.statusCode,
      };
    }

    if (decoded is String) {
      final cleaned = extractErrorMessage(decoded, fallback: 'Invalid OTP');
      if (cleaned.isNotEmpty && cleaned != decoded.trim()) {
        return {
          'success': false,
          'message': cleaned,
          'statusCode': response.statusCode,
        };
      }
    }

    return {
      'success': false,
      'message': 'Invalid OTP',
      'statusCode': response.statusCode,
    };
  }

  // Verify an OTP challenge (auth/otp/verify) — replaces the old
  // auth/verify-otp endpoint for staff/owner login. Keyed on the
  // `challengeId` returned by requestOtp/resendOtp, not the phone number.
  Future<Map<String, dynamic>> verifyOtpChallenge(
    String challengeId,
    String otp,
  ) async {
    final url = Uri.parse(baseUrl + otpVerifyChallengeEndpoint);
    final headers = {"Content-Type": "application/json"};
    final body = json.encode({"challengeId": challengeId, "otp": otp});

    _logRequest(
        tag: 'OtpVerify Request', url: url, headers: headers, body: body);

    final response =
        await _sharedClient.post(url, headers: headers, body: body);

    debugPrint("[OtpVerify] status=${response.statusCode}");
    _debugPrintChunked("OtpVerify body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'OTP verification failed',
    );
  }

  // Resend an OTP challenge (auth/otp/resend) — replaces the old
  // auth/resend_otp endpoint. Only the challengeId is sent; phone, purpose,
  // and device cannot change on resend.
  Future<Map<String, dynamic>> resendOtpChallenge(String challengeId) async {
    final url = Uri.parse(baseUrl + otpResendEndpoint);
    final headers = {"Content-Type": "application/json"};
    final body = json.encode({"challengeId": challengeId});

    _logRequest(
        tag: 'OtpResend Request', url: url, headers: headers, body: body);

    final response =
        await _sharedClient.post(url, headers: headers, body: body);

    debugPrint("[OtpResend] status=${response.statusCode}");
    _debugPrintChunked("OtpResend body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Failed to resend OTP',
    );
  }

  // ---------------------- SALON TEAM INVITATIONS ----------------------
  // See invitation_plan.md. Phase 1: invitation = salon membership only;
  // branch/services are assigned separately after accept.

  // Unauthenticated — landing-page metadata for an invitation link.
  Future<Map<String, dynamic>> resolveTeamInvitation(
    String invitationToken,
  ) async {
    final url = Uri.parse(baseUrl + teamInvitationResolveEndpoint)
        .replace(queryParameters: {'invitationToken': invitationToken});

    _logRequest(
      tag: 'ResolveTeamInvitation Request',
      url: url,
      headers: const {},
      body: '',
    );

    final response = await _sharedClient.get(url);

    debugPrint("[ResolveTeamInvitation] status=${response.statusCode}");
    _debugPrintChunked("ResolveTeamInvitation body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load this invitation',
    );
  }

  // Requires the invitee's Bearer JWT (obtained via the OTP challenge with
  // purpose=SALON_INVITATION_ACCEPTANCE + this same invitationToken as
  // contextToken). The JWT's phone must match the invitation's invitedPhone.
  Future<Map<String, dynamic>> acceptTeamInvitation(
    String invitationToken,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final url = Uri.parse(baseUrl + teamInvitationAcceptEndpoint);
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode({'invitationToken': invitationToken});

    _logRequest(
      tag: 'AcceptTeamInvitation Request',
      url: url,
      headers: headers,
      body: body,
    );

    final response =
        await _sharedClient.post(url, headers: headers, body: body);

    debugPrint("[AcceptTeamInvitation] status=${response.statusCode}");
    _debugPrintChunked("AcceptTeamInvitation body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to accept this invitation',
    );
  }

  // Invitations sent to the logged-in user's own phone number.
  Future<Map<String, dynamic>> getMyTeamInvitations({
    String status = 'PENDING',
    int limit = 20,
    String? cursor,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final baseUri = Uri.parse(baseUrl + myTeamInvitationsEndpoint);
    final queryParameters = <String, String>{
      if (status.isNotEmpty) 'status': status,
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final url = baseUri.replace(queryParameters: queryParameters);
    final headers = {
      "Authorization": "Bearer $token",
    };

    _logRequest(
      tag: 'MyTeamInvitations Request',
      url: url,
      headers: headers,
      body: '',
    );

    final response = await _sharedClient.get(url, headers: headers);

    debugPrint("[MyTeamInvitations] status=${response.statusCode}");
    _debugPrintChunked("MyTeamInvitations body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load invitations',
    );
  }

  Future<Map<String, dynamic>> declineTeamInvitation(
    int invitationId,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final url =
        Uri.parse(baseUrl + myTeamInvitationDeclineEndpoint(invitationId));
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    _logRequest(
      tag: 'DeclineTeamInvitation Request',
      url: url,
      headers: headers,
      body: '',
    );

    final response =
        await _sharedClient.post(url, headers: headers, body: jsonEncode({}));

    debugPrint("[DeclineTeamInvitation] status=${response.statusCode}");
    _debugPrintChunked("DeclineTeamInvitation body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to decline this invitation',
    );
  }

  // Owner or super-admin only. Sends a salon invitation instead of adding a
  // team member directly (the legacy branches/:id/add-user path).
  Future<Map<String, dynamic>> sendTeamInvitation({
    required int salonId,
    required String firstName,
    required String lastName,
    required String nationalNumber,
    required String email,
    String countryIsoCode = 'IN',
    String countryCode = '+91',
    String? message,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final url = Uri.parse(baseUrl + salonTeamInvitationsEndpoint(salonId));
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode({
      'firstName': firstName,
      'lastName': lastName,
      'countryIsoCode': countryIsoCode,
      'countryCode': countryCode,
      'nationalNumber': nationalNumber,
      'email': email,
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
    });

    _logRequest(
      tag: 'SendTeamInvitation Request',
      url: url,
      headers: headers,
      body: body,
    );

    final response =
        await _sharedClient.post(url, headers: headers, body: body);

    debugPrint("[SendTeamInvitation] status=${response.statusCode}");
    _debugPrintChunked("SendTeamInvitation body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to send this invitation',
    );
  }

  // Owner or super-admin only. Pending/history invitations for a salon
  // (shown alongside active team members — see invitation_plan.md §8).
  Future<Map<String, dynamic>> getSalonTeamInvitations(
    int salonId, {
    String status = 'PENDING',
    int limit = 20,
    String? cursor,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final baseUri = Uri.parse(baseUrl + salonTeamInvitationsEndpoint(salonId));
    final queryParameters = <String, String>{
      if (status.isNotEmpty) 'status': status,
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final url = baseUri.replace(queryParameters: queryParameters);
    final headers = {
      "Authorization": "Bearer $token",
    };

    _logRequest(
      tag: 'SalonTeamInvitations Request',
      url: url,
      headers: headers,
      body: '',
    );

    final response = await _sharedClient.get(url, headers: headers);

    debugPrint("[SalonTeamInvitations] status=${response.statusCode}");
    _debugPrintChunked("SalonTeamInvitations body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load invitations',
    );
  }

  // ---- salon_team_part_1_updated_3.md — new Team read endpoints ----

  Future<Map<String, dynamic>> getTeamSummaryV2(
    int salonId, {
    int? branchId,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final baseUri = Uri.parse(baseUrl + salonTeamSummaryEndpoint(salonId));
    final url = baseUri.replace(
      queryParameters: {
        if (branchId != null) 'branchId': '$branchId',
      },
    );
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'TeamSummary Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.get(url, headers: headers);
    debugPrint("[TeamSummary] status=${response.statusCode}");
    _debugPrintChunked("TeamSummary body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load team summary',
    );
  }

  // status is required by the backend contract — 'active' or
  // 'setup_required'. There is no combined "all members" value.
  Future<Map<String, dynamic>> getTeamMembersV2(
    int salonId, {
    required String status,
    int? branchId,
    String? search,
    String sort = 'name_asc',
    int page = 1,
    int pageSize = 20,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final baseUri = Uri.parse(baseUrl + salonTeamMembersEndpoint(salonId));
    final url = baseUri.replace(
      queryParameters: {
        'status': status,
        if (branchId != null) 'branchId': '$branchId',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort': sort,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'TeamMembersV2 Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.get(url, headers: headers);
    debugPrint("[TeamMembersV2] status=${response.statusCode}");
    _debugPrintChunked("TeamMembersV2 body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load team members',
    );
  }

  Future<Map<String, dynamic>> getTeamInvitationsV2(
    int salonId, {
    String status = 'all',
    String? search,
    String sort = 'name_asc',
    int page = 1,
    int pageSize = 20,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final baseUri =
        Uri.parse(baseUrl + salonTeamInvitationsV2Endpoint(salonId));
    final url = baseUri.replace(
      queryParameters: {
        'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort': sort,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'TeamInvitationsV2 Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.get(url, headers: headers);
    debugPrint("[TeamInvitationsV2] status=${response.statusCode}");
    _debugPrintChunked("TeamInvitationsV2 body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load invitations',
    );
  }

  Future<Map<String, dynamic>> getTeamMemberDetailV2(
    int salonId,
    int userId,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url =
        Uri.parse(baseUrl + salonTeamMemberDetailEndpoint(salonId, userId));
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'TeamMemberDetailV2 Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.get(url, headers: headers);
    debugPrint("[TeamMemberDetailV2] status=${response.statusCode}");
    _debugPrintChunked("TeamMemberDetailV2 body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load team member',
    );
  }

  // ---- salon_team_part_2.md — fill-missing profile-completion writes ----
  //
  // Omit a key entirely for "no change". A populated field supplied with a
  // different value is rejected server-side (409) — this method does not
  // pre-filter; the caller (the Complete Profile screen) only ever sends
  // fields it rendered as editable (i.e. currently missing).
  Future<Map<String, dynamic>> patchTeamMemberProfile(
    int salonId,
    int userId,
    Map<String, dynamic> fields,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url =
        Uri.parse(baseUrl + salonTeamMemberProfileEndpoint(salonId, userId));
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode(fields);
    _logRequest(
      tag: 'TeamMemberProfilePatch Request',
      url: url,
      headers: headers,
      body: body,
    );
    final response =
        await _sharedClient.patch(url, headers: headers, body: body);
    debugPrint("[TeamMemberProfilePatch] status=${response.statusCode}");
    _debugPrintChunked("TeamMemberProfilePatch body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to update profile',
    );
  }

  Future<Map<String, dynamic>> patchTeamMemberAvatar(
    int salonId,
    int userId,
    String profilePictureUrl,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url =
        Uri.parse(baseUrl + salonTeamMemberAvatarEndpoint(salonId, userId));
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode({'profilePictureUrl': profilePictureUrl});
    _logRequest(
      tag: 'TeamMemberAvatarPatch Request',
      url: url,
      headers: headers,
      body: body,
    );
    final response =
        await _sharedClient.patch(url, headers: headers, body: body);
    debugPrint("[TeamMemberAvatarPatch] status=${response.statusCode}");
    _debugPrintChunked("TeamMemberAvatarPatch body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to update avatar',
    );
  }

  // ---- salon_user_compensation.md — employment type + salary history ----
  //
  // Compensation belongs to the salon membership (user_salon), not the
  // global profile — deliberately separate from getTeamMemberDetailV2 /
  // patchTeamMemberProfile above (the spec explicitly forbids adding
  // compensation to Team list/detail responses).
  Future<Map<String, dynamic>> getTeamMemberCompensation(
    int salonId,
    int userId,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url = Uri.parse(
      baseUrl + salonTeamMemberCompensationEndpoint(salonId, userId),
    );
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'TeamMemberCompensation Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.get(url, headers: headers);
    debugPrint("[TeamMemberCompensation] status=${response.statusCode}");
    _debugPrintChunked("TeamMemberCompensation body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load compensation',
    );
  }

  Future<Map<String, dynamic>> patchTeamMemberEmploymentType(
    int salonId,
    int userId,
    String employmentType,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url = Uri.parse(
      baseUrl + salonTeamMemberEmploymentTypeEndpoint(salonId, userId),
    );
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode({'employmentType': employmentType});
    _logRequest(
      tag: 'EmploymentTypePatch Request',
      url: url,
      headers: headers,
      body: body,
    );
    final response =
        await _sharedClient.patch(url, headers: headers, body: body);
    debugPrint("[EmploymentTypePatch] status=${response.statusCode}");
    _debugPrintChunked("EmploymentTypePatch body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to update employment type',
    );
  }

  Future<Map<String, dynamic>> createTeamMemberCompensation(
    int salonId,
    int userId,
    Map<String, dynamic> fields,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url = Uri.parse(
      baseUrl + salonTeamMemberCompensationEndpoint(salonId, userId),
    );
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode(fields);
    _logRequest(
      tag: 'CompensationCreate Request',
      url: url,
      headers: headers,
      body: body,
    );
    final response =
        await _sharedClient.post(url, headers: headers, body: body);
    debugPrint("[CompensationCreate] status=${response.statusCode}");
    _debugPrintChunked("CompensationCreate body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to save compensation',
    );
  }

  Future<Map<String, dynamic>> patchTeamMemberCompensation(
    int salonId,
    int userId,
    int compensationId,
    Map<String, dynamic> fields,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url = Uri.parse(
      baseUrl +
          salonTeamMemberCompensationItemEndpoint(
            salonId,
            userId,
            compensationId,
          ),
    );
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode(fields);
    _logRequest(
      tag: 'CompensationPatch Request',
      url: url,
      headers: headers,
      body: body,
    );
    final response =
        await _sharedClient.patch(url, headers: headers, body: body);
    debugPrint("[CompensationPatch] status=${response.statusCode}");
    _debugPrintChunked("CompensationPatch body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to update compensation',
    );
  }

  Future<Map<String, dynamic>> deleteTeamMemberCompensation(
    int salonId,
    int userId,
    int compensationId,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }
    final url = Uri.parse(
      baseUrl +
          salonTeamMemberCompensationItemEndpoint(
            salonId,
            userId,
            compensationId,
          ),
    );
    final headers = {"Authorization": "Bearer $token"};
    _logRequest(
      tag: 'CompensationDelete Request',
      url: url,
      headers: headers,
      body: '',
    );
    final response = await _sharedClient.delete(url, headers: headers);
    debugPrint("[CompensationDelete] status=${response.statusCode}");
    _debugPrintChunked("CompensationDelete body", response.body);
    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to cancel compensation',
    );
  }

  // Owner or super-admin only. Locks the invitation row and transitions
  // PENDING -> CANCELLED (idempotent if already CANCELLED).
  Future<Map<String, dynamic>> cancelSalonTeamInvitation(
    int salonId,
    int invitationId,
  ) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final url = Uri.parse(
      baseUrl + salonTeamInvitationCancelEndpoint(salonId, invitationId),
    );
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    _logRequest(
      tag: 'CancelTeamInvitation Request',
      url: url,
      headers: headers,
      body: '',
    );

    final response =
        await _sharedClient.post(url, headers: headers, body: jsonEncode({}));

    debugPrint("[CancelTeamInvitation] status=${response.statusCode}");
    _debugPrintChunked("CancelTeamInvitation body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to cancel this invitation',
    );
  }

  // Owner only. Salon-wide team list (active members regardless of branch
  // assignment) — used to surface accepted invitees who have no branch yet.
  Future<Map<String, dynamic>> getSalonUsers(int salonId) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'No token found',
        'data': const <String, dynamic>{},
      };
    }

    final url = Uri.parse(baseUrl + addSalonTeamMemberEndpoint(salonId));
    final headers = {
      "Authorization": "Bearer $token",
    };

    _logRequest(
      tag: 'SalonUsers Request',
      url: url,
      headers: headers,
      body: '',
    );

    final response = await _sharedClient.get(url, headers: headers);

    debugPrint("[SalonUsers] status=${response.statusCode}");
    _debugPrintChunked("SalonUsers body", response.body);

    return _parseEnvelopeResponse(
      response,
      fallback: 'Unable to load salon team',
    );
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
      "platform": AppEnvironment.platform,
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

    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = null;
    }

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
      'message': extractErrorMessage(
        response.body,
        fallback: 'Failed register customer',
      ),
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed link branch client'),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to fetch branch clients',
      ),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to fetch branch customers',
      ),
    );
  }

  // Resend OTP
  // Update profile
  Future<Map<String, dynamic>> updateUserProfileDetails(
    String firstName,
    String lastName,
    String email,
    String token, {
    String? profilePictureUrl,
  }) async {
    final updatePayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      if (profilePictureUrl != null && profilePictureUrl.trim().isNotEmpty)
        "profilePictureUrl": profilePictureUrl.trim(),
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
        responseLog = const JsonEncoder.withIndent(
          '  ',
        ).convert(json.decode(response.body));
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
          "Failed update profile: ${response.statusCode}, $responseMessage",
        );
        throw Exception(responseMessage);
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
    required bool becomeStylist,
    required int openingBufferMinutes,
    required int lastBookingBufferMinutes,

    // ✅ optional
    int? lastSlotOverflowGraceMinutes,
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
      "openingBufferMinutes": openingBufferMinutes,
      "lastBookingBufferMinutes": lastBookingBufferMinutes,

      if (lastSlotOverflowGraceMinutes != null)
        "lastSlotOverflowGraceMinutes": lastSlotOverflowGraceMinutes,
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
      "becomeStylist": becomeStylist,
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
      "📥 Response (Create Salon): ${response.statusCode} ${response.body}",
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(
        _apiErrorMessage(response.body, fallback: '❌ Failed to create salon'),
      );
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
      responseLog = const JsonEncoder.withIndent(
        '  ',
      ).convert(json.decode(response.body));
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
      throw Exception(
        "Failed get salons (${response.statusCode}): "
        "$responseMessage",
      );
    }
  }

  // ---------------------- LOGOUT ----------------------

  Future<bool> logoutUserAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');

    if (token == null || token.isEmpty) return false;

    final url = Uri.parse(baseUrl + logoutUser);

    try {
      final response = await _sharedClient.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({}),
      );

      print("Logout Response: ${response.statusCode} ${response.body}");

      await prefs.clear();

      return response.statusCode >= 200 && response.statusCode < 300;
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
      baseUrl + deleteUser,
    ); // e.g. https://dev-api.glowante.com/users/delete
    try {
      final response = await _sharedClient.delete(
        url,
        headers: {"Authorization": "Bearer $token", "accept": "*/*"},
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
    final value = time.trim();
    if (value.isEmpty) return time;

    final twelveHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (twelveHourMatch != null) {
      var hour = int.tryParse(twelveHourMatch.group(1) ?? '');
      final minute = int.tryParse(twelveHourMatch.group(2) ?? '');
      final meridiem = twelveHourMatch.group(3)?.toUpperCase();

      if (hour == null || minute == null || meridiem == null) {
        return time;
      }

      if (meridiem == 'PM' && hour < 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return time;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
    }

    final twentyFourHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(value);
    if (twentyFourHourMatch != null) {
      final hour = int.tryParse(twentyFourHourMatch.group(1) ?? '');
      final minute = int.tryParse(twentyFourHourMatch.group(2) ?? '');
      final second = int.tryParse(twentyFourHourMatch.group(3) ?? '') ?? 0;

      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        return time;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
    }

    try {
      final parsedTime = DateFormat.jm().parse(value);
      return DateFormat('HH:mm:ss').format(parsedTime);
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
      body: <String, dynamic>{'action': action},
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
      throw Exception(
        _apiErrorMessage(response.body, fallback: 'Failed to add category'),
      );
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
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
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
      throw Exception(
        _apiErrorMessage(response.body, fallback: 'Failed to fetch categories'),
      );
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

    final url = Uri.parse(
      baseUrl + "branches/$branchId/categories/$branchCategoryId",
    );

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

    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to update category'),
    );
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
      throw Exception(
        _apiErrorMessage(rawBody, fallback: 'Failed to fetch service catalog'),
      );
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

    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to add service'),
    );
  }

  // ---------------------- GET SERVICES ----------------------
  Future<Map<String, dynamic>> getService({int? salonId, int? branchId}) async {
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
      throw Exception(
        _apiErrorMessage(response.body, fallback: 'Failed to fetch service(s)'),
      );
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
      throw Exception(
        _apiErrorMessage(
          response.body,
          fallback: 'Failed to fetch branch service(s)',
        ),
      );
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decodedBody = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      return decodedBody;
    } else {
      throw Exception(
        _apiErrorMessage(response.body, fallback: 'Failed to add branch'),
      );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to update salon'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to activate salon'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to deactivate salon'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to delete salon'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to update branch'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to activate branch'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to deactivate branch'),
    );
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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to delete branch'),
    );
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
      "unselectedCodes": unselectedCodes,
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
    _debugPrintChunked('Import Predefined Services Response', response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to import predefined services',
      ),
    );
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
        throw Exception(
          _apiErrorMessage(
            response.body,
            fallback: 'Failed to fetch branch details',
          ),
        );
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

    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to add subcategory'),
    );
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

      final response = await _sharedClient.post(
        url,
        headers: headers,
        body: body,
      );

      // Log the status code of the response
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        final message = extractErrorMessage(
          response.body,
          fallback: 'Failed to add user',
        );
        return {'success': false, 'message': message};
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print('Error: $e');
      return {
        'success': false,
        'message': extractErrorMessage(e, fallback: 'Failed to add user'),
      };
    }
  }

  Future<Map<String, dynamic>> validateTeamMemberContact(
    int branchId, {
    String? email,
    String? phoneNumber,
  }) async {
    final url = Uri.parse(
      '$baseUrl${validateTeamMemberContactEndpoint(branchId)}',
    );

    final token = await getAuthToken();
    final payload = <String, dynamic>{};
    final cleanedEmail = email?.trim();
    final cleanedPhone = phoneNumber?.trim();

    if (cleanedEmail != null && cleanedEmail.isNotEmpty) {
      payload['email'] = cleanedEmail;
    }
    if (cleanedPhone != null && cleanedPhone.isNotEmpty) {
      payload['phoneNumber'] = cleanedPhone;
    }

    print('[Validate Team Contact] URL: $url');
    print('[Validate Team Contact] Payload: $payload');

    try {
      final response = await _sharedClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      print('[Validate Team Contact] Status Code: ${response.statusCode}');
      print('[Validate Team Contact] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final message = extractErrorMessage(
        response.body,
        fallback: 'Unable to validate team member contact',
      );
      return {'success': false, 'message': message};
    } catch (e) {
      print('Error: $e');
      return {
        'success': false,
        'message': extractErrorMessage(
          e,
          fallback: 'Unable to validate team member contact',
        ),
      };
    }
  }

  // ---------------------- GET TEAM MEMBERS ----------------------
  static Future<Map<String, dynamic>> getTeamMembers(
    int branchId, {
    String status = 'all',
    bool? allowOnlineBooking,
    List<int> serviceIds = const <int>[],
    DateTime? date,
    bool includeAssignedForDate = false,
    String search = '',
  }) async {
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
        '$baseUrl${getTeamMember(branchId, status: status, allowOnlineBooking: allowOnlineBooking, serviceIds: serviceIds, date: date, includeAssignedForDate: includeAssignedForDate, search: search)}',
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

  static Future<Map<String, dynamic>> getTeamMemberDetails(
    int branchId,
    int userId,
  ) async {
    try {
      final apiService = ApiService();
      final token = await apiService.getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(
        '$baseUrl${teamMemberDetailsEndpoint(branchId, userId)}',
      );

      print('API URL: $url');
      print('Request Headers: { "Authorization": "Bearer $token" }');

      final response = await _sharedClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Failed to load team member details');
    } catch (e) {
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

      print(
        '⬅️ ${response.statusCode} ${response.reasonPhrase} '
        '(${sw.elapsedMilliseconds} ms) for $url',
      );

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
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
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
      "Headers: {Content-Type: application/json, Authorization: Bearer ***}",
    );
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
            "raw": resp.body,
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to update offer status',
      ),
    );
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
    final url = Uri.parse(
      "$baseUrl${updateSalonBranchOffer(branchId, offerId)}",
    );

    // Remove null values (PATCH semantics)
    final payload = Map<String, dynamic>.from(body)
      ..removeWhere((k, v) => v == null);

    print("🔹 [PATCH] Update Salon Branch Offer → $url");
    print(
      "Headers: {Content-Type: application/json, Authorization: Bearer ***}",
    );
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
            "raw": resp.body,
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to update branch offer status',
      ),
    );
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

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : json.decode(response.body);
      print("Decoded Response Data: $decoded");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'success': true, 'data': decoded};
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Success',
          'data': _extractMapList(body),
        };
      }

      if (decoded is Map<String, dynamic>) {
        return {
          'success': decoded['success'] ?? false,
          'message':
              decoded['message']?.toString() ?? 'Failed to load appointments',
          'statusCode': response.statusCode,
          'data': _extractMapList(decoded),
        };
      }

      throw Exception('Failed to load appointments');
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
        return {'success': true, 'data': responseData};
      }

      return {
        'success': false,
        'message': 'Failed to load stylist appointments',
        'data': const [],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'data': const []};
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

      final responseData = response.body.isEmpty
          ? <String, dynamic>{}
          : json.decode(response.body);
      _debugPrintChunked('StylistBookingsAPI decoded', responseData);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = responseData is Map<String, dynamic>
            ? responseData
            : <String, dynamic>{'success': true, 'data': responseData};
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'Success',
          'data': _extractMapList(body),
        };
      }

      if (responseData is Map<String, dynamic>) {
        return {
          'success': responseData['success'] ?? false,
          'message': responseData['message']?.toString() ??
              'Failed to load team appointments',
          'statusCode': response.statusCode,
          'data': _extractMapList(responseData),
        };
      }

      return {
        'success': false,
        'message': 'Failed to load team appointments',
        'statusCode': response.statusCode,
        'data': const [],
      };
    } catch (e) {
      debugPrint('[StylistBookingsAPI] error=$e');
      return {'success': false, 'message': e.toString(), 'data': const []};
    }
  }

  Future<Map<String, dynamic>> fetchBranchServicesFlat(int branchId) async {
    try {
      final token = await getAuthToken();
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      final url = Uri.parse(baseUrl + getBranchServicesFlatAPI(branchId));
      debugPrint('[StylistServicesAPI] GET $url | branchId=$branchId');

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
        return {'success': true, 'data': decoded};
      }

      return {
        'success': false,
        'message': 'Failed to load services',
        'data': const [],
      };
    } catch (e) {
      debugPrint('[StylistServicesAPI] error=$e');
      return {'success': false, 'message': e.toString(), 'data': const []};
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
        baseUrl + getInventoryItemsAPI(branchId, page: page, limit: limit),
      );
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
        return {'success': true, 'data': decoded};
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
      endpoint: payrollAdditionalChargesAPI(),
      body: payload,
      debugTag: 'CreatePayrollAdditionalChargeAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollAdditionalCharges({
    int? payrollEmployeeId,
    String? payrollId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollAdditionalChargesAPI(
        payrollEmployeeId: payrollEmployeeId,
        payrollId: payrollId,
      ),
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
      endpoint: payrollDeductionsAPI(),
      body: payload,
      debugTag: 'CreatePayrollDeductionAPI',
    );
  }

  Future<Map<String, dynamic>> getPayrollDeductions({
    int? payrollEmployeeId,
    String? payrollId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollDeductionsAPI(
        payrollEmployeeId: payrollEmployeeId,
        payrollId: payrollId,
      ),
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

  Future<Map<String, dynamic>> getPayrollEmployeeReview({
    required int branchId,
    required String payrollId,
    required int employeeId,
  }) async {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: payrollEmployeeReviewAPI(
        branchId,
        employeeId: employeeId,
        payrollId: payrollId,
      ),
      debugTag: 'PayrollEmployeeReviewAPI',
    );
  }

  Future<Map<String, dynamic>> markPayrollEmployeePaid({
    required int payrollEmployeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: payrollEmployeePayAPI(payrollEmployeeId),
      body: payload,
      debugTag: 'PayrollEmployeePayAPI',
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

  Future<Map<String, dynamic>> getBranchCommissionStaff({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchCommissionStaffAPI(branchId),
      debugTag: 'BranchCommissionStaffAPI',
    );
  }

  Future<Map<String, dynamic>> getBranchCommissionServices({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchCommissionServicesAPI(branchId),
      debugTag: 'BranchCommissionServicesAPI',
    );
  }

  Future<Map<String, dynamic>> getBranchCommissionStaffOverrides({
    required int branchId,
  }) {
    return _authorizedJsonRequest(
      method: 'GET',
      endpoint: branchCommissionStaffOverridesAPI(branchId),
      debugTag: 'BranchCommissionStaffOverridesAPI',
    );
  }

  Future<Map<String, dynamic>> saveBranchCommissionStaffOverrides({
    required int branchId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: branchCommissionStaffOverridesAPI(branchId),
      body: payload,
      debugTag: 'SaveBranchCommissionStaffOverridesAPI',
    );
  }

  Future<Map<String, dynamic>> deleteBranchCommissionStaffOverride({
    required int branchId,
    required String overrideId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: branchCommissionStaffOverrideAPI(branchId, overrideId),
      debugTag: 'DeleteBranchCommissionStaffOverrideAPI',
    );
  }

  Future<Map<String, dynamic>> createEmployeeSalaryConfig({
    required int branchId,
    required int employeeId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'POST',
      endpoint: branchEmployeeSalaryHistoryAPI(branchId, employeeId),
      body: payload,
      debugTag: 'CreateEmployeeSalaryConfigAPI',
    );
  }

  Future<Map<String, dynamic>> updateEmployeeSalaryConfig({
    required int branchId,
    required int employeeId,
    required int salaryId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: branchEmployeeSalaryConfigAPI(branchId, employeeId, salaryId),
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

  Future<Map<String, dynamic>> updateBranchAdvance({
    required int branchId,
    required int advanceId,
    required Map<String, dynamic> payload,
  }) {
    return _authorizedJsonRequest(
      method: 'PATCH',
      endpoint: branchAdvanceDetailAPI(branchId, advanceId),
      body: payload,
      debugTag: 'UpdateBranchAdvanceAPI',
    );
  }

  Future<Map<String, dynamic>> deleteBranchAdvance({
    required int branchId,
    required int advanceId,
  }) {
    return _authorizedJsonRequest(
      method: 'DELETE',
      endpoint: branchAdvanceDetailAPI(branchId, advanceId),
      debugTag: 'DeleteBranchAdvanceAPI',
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
      endpoint: payrollEmployeeAdjustmentDetailsAPI(
        payrollEmployeeId,
        adjustmentId,
      ),
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
      endpoint: payrollEmployeeAdjustmentDetailsAPI(
        payrollEmployeeId,
        adjustmentId,
      ),
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
    required int year,
    int? month,
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
      if (body.containsKey('serviceType') || body.containsKey('code'))
        'serviceType': body['serviceType'] ?? body['code'],
      if (body.containsKey('serviceTypeName'))
        'serviceTypeName': body['serviceTypeName'],
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
      print(
        "➡️ Headers: {"
        "Content-Type: application/json, "
        "Authorization: Bearer ${token.substring(0, 8)}...}",
      );
      print(
        "➡️ Body: ${jsonEncode({
              'branchId': branchId,
              'appointmentId': appointmentId,
              'otp': otp
            })}",
      );
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
      return {'success': false, 'message': e.toString()};
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
    List<int> serviceIds = const <int>[],
    List<Map<String, dynamic>> inventoryItems = const <Map<String, dynamic>>[],
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
        "  Headers: { Content-Type: application/json, Authorization: Bearer $token }",
      );
      print(
        "  Body: ${jsonEncode({
              "rating": rating,
              if (comment != null) "comment": comment,
              if (serviceIds.isNotEmpty) "serviceIds": serviceIds,
              if (inventoryItems.isNotEmpty) "inventoryItems": inventoryItems
            })}",
      );
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
          if (serviceIds.isNotEmpty) "serviceIds": serviceIds,
          if (inventoryItems.isNotEmpty) "inventoryItems": inventoryItems,
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
    print(
      "📩 Headers: {"
      '"Content-Type": "application/json", '
      '"Accept": "application/json", '
      '"Authorization": "Bearer $token"'
      "}",
    );

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
      final url = Uri.parse(
        baseUrl + updateBranchCategory(branchId, categoryId),
      );

      final merged = {...body, "isActive": true, "sortOrder": 200}
        ..removeWhere((k, v) => v == null);

      final safeToken =
          token.isNotEmpty ? '${token.substring(0, 8)}…redacted' : '';
      print("🔹 [PATCH] Update Category → $url");
      print(
        "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}",
      );
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
      final url = Uri.parse(
        baseUrl + updateBranchSubCategory(branchId, subCategoryId),
      );

      final merged = {...body, "isActive": true, "sortOrder": 200}
        ..removeWhere((k, v) => v == null);

      final safeToken =
          token.isNotEmpty ? '${token.substring(0, 8)}…redacted' : '';
      print("🔹 [PATCH] Update SubCategory → $url");
      print(
        "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}",
      );
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
        "Headers: {Authorization: Bearer $safeToken, Content-Type: application/json}",
      );
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
    int branchId,
    int categoryId,
  ) async {
    try {
      final token = await ApiService().getAuthToken();
      final url = Uri.parse(
        baseUrl + deleteBranchCategory(branchId, categoryId),
      );

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
    int branchId,
    int subCategoryId,
  ) async {
    try {
      final token = await ApiService().getAuthToken();
      final url = Uri.parse(
        baseUrl + deleteBranchSubCategory(branchId, subCategoryId),
      );

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
    int branchId,
    int serviceId,
  ) async {
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

  Future<Map<String, dynamic>> getSalonPayoutAccounts(int salonId) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + salonPayoutAccountsAPI(salonId));

    print("➡️ Calling Get Payout Accounts API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await _sharedClient.get(
        url,
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body is Map<String, dynamic>) return body;
        return {"success": true, "data": body};
      }

      if (body is Map<String, dynamic>) {
        return {
          "success": false,
          "message": body['message']?.toString() ??
              'Failed to load salon payout accounts',
          "statusCode": response.statusCode,
        };
      }

      return {
        "success": false,
        "message": 'Failed to load salon payout accounts',
        "statusCode": response.statusCode,
      };
    } catch (e) {
      print("❌ Error in getSalonPayoutAccounts: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> createSalonPayoutAccount({
    required int salonId,
    required Map<String, dynamic> payload,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + salonPayoutAccountOnboardBankAPI(salonId));

    print("➡️ Calling Onboard Salon Payout Bank Account API");
    print("➡️ URL: $url");
    print("➡️ Payload: $payload");

    try {
      final response = await _sharedClient.post(
        url,
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (body is Map<String, dynamic>) return body;
        return {"success": true, "data": body};
      }

      if (body is Map<String, dynamic>) {
        return {
          "success": false,
          "message": body['message']?.toString() ??
              'Failed to create salon payout account',
          "statusCode": response.statusCode,
        };
      }

      return {
        "success": false,
        "message": 'Failed to create salon payout account',
        "statusCode": response.statusCode,
      };
    } catch (e) {
      print("❌ Error in createSalonPayoutAccount: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSalonPayoutAccount({
    required int salonId,
    required int payoutAccountId,
    required Map<String, dynamic> payload,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      baseUrl + salonPayoutAccountUpdateBankAPI(salonId, payoutAccountId),
    );

    print("➡️ Calling Update Salon Payout Account API");
    print("➡️ URL: $url");
    print("➡️ Payload: $payload");

    try {
      final response = await _sharedClient.patch(
        url,
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (body is Map<String, dynamic>) return body;
        return {"success": true, "data": body};
      }

      if (body is Map<String, dynamic>) {
        return {
          "success": false,
          "message": body['message']?.toString() ??
              'Failed to update salon payout account',
          "statusCode": response.statusCode,
        };
      }

      return {
        "success": false,
        "message": 'Failed to update salon payout account',
        "statusCode": response.statusCode,
      };
    } catch (e) {
      print("❌ Error in updateSalonPayoutAccount: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSalonPayoutAccount({
    required int salonId,
    required int payoutAccountId,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      baseUrl + salonPayoutAccountAPI(salonId, payoutAccountId),
    );

    print("➡️ Calling Delete Salon Payout Account API");
    print("➡️ URL: $url");

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

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (body is Map<String, dynamic>) return body;
        return {"success": true, "data": body};
      }

      if (body is Map<String, dynamic>) {
        return {
          "success": false,
          "message": body['message']?.toString() ??
              'Failed to delete salon payout account',
          "statusCode": response.statusCode,
        };
      }

      return {
        "success": false,
        "message": 'Failed to delete salon payout account',
        "statusCode": response.statusCode,
      };
    } catch (e) {
      print("❌ Error in deleteSalonPayoutAccount: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> setSalonPayoutAccountDefault({
    required int salonId,
    required int payoutAccountId,
  }) {
    return _patchSalonPayoutAccountRole(
      salonId: salonId,
      payoutAccountId: payoutAccountId,
      path: salonPayoutAccountDefaultAPI(salonId, payoutAccountId),
      label: 'Default',
    );
  }

  Future<Map<String, dynamic>> setSalonPayoutAccountSecondary({
    required int salonId,
    required int payoutAccountId,
  }) {
    return _patchSalonPayoutAccountRole(
      salonId: salonId,
      payoutAccountId: payoutAccountId,
      path: salonPayoutAccountSecondaryAPI(salonId, payoutAccountId),
      label: 'Secondary',
    );
  }

  Future<Map<String, dynamic>> _patchSalonPayoutAccountRole({
    required int salonId,
    required int payoutAccountId,
    required String path,
    required String label,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + path);

    print("➡️ Calling Make Salon Payout Account $label API");
    print("➡️ URL: $url");

    try {
      final response = await _sharedClient.patch(
        url,
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("⬅️ Status Code: ${response.statusCode}");
      print("⬅️ Response Body: ${response.body}");

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (body is Map<String, dynamic>) return body;
        return {"success": true, "data": body};
      }

      if (body is Map<String, dynamic>) {
        return {
          "success": false,
          "message": body['message']?.toString() ??
              'Failed to update salon payout account',
          "statusCode": response.statusCode,
        };
      }

      return {
        "success": false,
        "message": 'Failed to update salon payout account',
        "statusCode": response.statusCode,
      };
    } catch (e) {
      print("❌ Error in make salon payout account $label: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  /// ---------------------- RESOLVE WALKIN NUMBER ----------------------
  Future<Map<String, dynamic>> resolveWalkinNumber(
    int branchId,
    String countryCode,
    String phoneNumber,
  ) async {
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
        "platform": AppEnvironment.platform,
      }),
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        _apiErrorMessage(
          response.body,
          fallback: 'Failed to resolve walkin number',
        ),
      );
    }
  }

  // ---------------------- CREATE APPOINTMENT ----------------------
  Future<Map<String, dynamic>> createAppointment(
    int branchId,
    Map<String, dynamic> payload,
  ) async {
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
        throw Exception(
          _apiErrorMessage(
            response.body,
            fallback: 'Failed to create appointment',
          ),
        );
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

    debugPrint('➡️ [CREATE_BOOKING] URL: $url');
    debugPrint('➡️ [CREATE_BOOKING] Payload: ${jsonEncode(payload)}');

    final response = await _sharedClient.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    debugPrint('⬅️ [CREATE_BOOKING] Status: ${response.statusCode}');
    debugPrint('⬅️ [CREATE_BOOKING] Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to create manual booking',
      ),
    );
  }

  Future<Map<String, dynamic>> assignUserToBranch(
    int branchId,
    int userId,
    String joiningDate,
    List<Map<String, dynamic>> schedules,
    List<int> branchServiceIds,
    bool allowOnlineBooking, {
    List<int> branchRoleIds = const [],
    List<String> roles = const [],
    // Narinder, 2026-09-03: 'BRANCH_HOURS' (no `schedules`, branch timings
    // are copied server-side) or 'CUSTOM' (`schedules` required).
    String scheduleMode = 'CUSTOM',
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse('$baseUrl${assignUserToBranchAPI(branchId)}');

    final payload = {
      "userId": userId,
      "joiningDate": joiningDate, // e.g. "2025-08-21"
      "scheduleMode": scheduleMode,
      if (scheduleMode == 'CUSTOM') "schedules": schedules,
      "branchServiceIds": branchServiceIds,
      "branchRoleIds": branchRoleIds,
      "roles": roles,
      "allowOnlineBooking": allowOnlineBooking,
      // Not sent: backend rejects it with "property experience should not
      // exist" (strict whitelist validation) — not part of this endpoint's
      // contract, unlike the other fields above.
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
    final url = Uri.parse(
      '$baseUrl${updateTeamMemberEndpoint(branchId, userId)}',
    );
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
    throw Exception(
      extractErrorMessage(
        response.body,
        fallback: 'Failed to update team member',
      ),
    );
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
    final url = Uri.parse(
      '$baseUrl${updateTeamMemberEndpoint(branchId, userId)}',
    );

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
    throw Exception(
      _apiErrorMessage(response.body, fallback: 'Failed to import clients'),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to load reports dashboard',
      ),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to load revenue and sales',
      ),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to load staff performance',
      ),
    );
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
    throw Exception(
      _apiErrorMessage(
        response.body,
        fallback: 'Failed to load operations dashboard',
      ),
    );
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

  Future<Map<String, dynamic>> getBranchDashboard({required int branchId}) {
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
      debugPrint('[StylistReviewsAPI] GET $url | branchId=$branchId');

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
        return {'success': true, 'data': decoded};
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
