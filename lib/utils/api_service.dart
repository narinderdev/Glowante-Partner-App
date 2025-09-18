import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // 👈 needed for File
import 'package:path/path.dart'; // 👈 needed for basename(file.path)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/aws_s3_uploader.dart'; // 👈 import uploader
import 'package:image_picker/image_picker.dart'; // 👈 add this
import '../Viewmodels/AddCategory.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import '../Viewmodels/AddSalonBranchRequest.dart';
import '../Viewmodels/AddSalonServiceRequest.dart';
import 'dart:async';

class ApiService {
  static const String baseUrl = "https://dev-api.glowante.com/";
  static const String userLogin = "auth/login";
  static const String verifyOtpEndpoint = "auth/verify-otp";
  static const String resendOtpEndpoint = "auth/resend_otp";
  static const String updateUserProfile = "users/update";
  static const String createSalonEndpoint = "salons/create";
  static const String getSalonList = "salons/my";
  static const String logoutUser = "auth/logout";
  static const String serviceCatalog = "service-catalog";
  static const String getBranchServices = "salon-service/catalog";
  static const String addSubCategory =
      "/salons/{salonId}/categories/{categoryId}/subcategories";
  static const String checkSendOtpEndpoint = "users/check-and-send-otp";
  static String addServiceAPI(int salonId) => "salons/$salonId/services";

  static String getServicesAPI(int salonId) => "salons/$salonId/services";

  static String addCategoryAPI(int salonId) {
    return "salons/$salonId/categories";
  }

  static String getCategoriesAPI(int salonId, {bool withSubcats = true}) =>
      "salons/$salonId/categories?withSubcats=$withSubcats";

  static String updateCategoryAPI(int salonId, int categoryId) =>
      "salons/$salonId/categories/$categoryId";

  // static String deleteCategoryAPI(int salonId, int categoryId) =>
  //     "salons/$salonId/categories/$categoryId";

  static String addSalonBranchAPI(int salonId) {
    return "salons/$salonId/branches/add";
  }

  static String addTeamMemberEndpoint(int id) {
    return "branches/$id/add-user";
  }

  static const String getRolesSpecialization = "users/constants";

  static String getTeamMember(int id) {
    return "branches/$id/team";
  }

  static String addSalonOffer(int salonId) {
    return "salons/$salonId/offers";
  }

  static String getSalonPackagesDeals(int salonId) {
    return "salons/$salonId/offers";
  }

  static String deleteSalonOffer(int salonId, int offerId) {
    return "salons/$salonId/offers/$offerId";
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

  static String confirmAppointmentAPI(int branchId, int appointmentId) {
    return "branches/${branchId}/appointments/${appointmentId}/confirm";
  }

  static String addSalonBranchOffer(int branchId) {
    return "branches/$branchId/offers";
  }
  static String startAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/start";
  }
static String completeAppointmentAPI(int branchId, int appointmentId) {
    return "branches/$branchId/appointments/$appointmentId/complete";
  }
  //This below 2 api is pending to implement on frontend
  // Confirm Booking appointment (see static helper above)
  static String getSalonDetailAPI(int salonId) {
    return "salons/$salonId";
  }

  static String getSalon(int salonId, String status) {
    return "bookings/salon-bookings/$salonId?status=$status";
  }

  // / ---------------------- IMAGE UPLOAD ----------------------

  Future<String?> uploadImage(File file) async {
    // convert File -> XFile wrapper for AwsS3Uploader
    final url = await AwsS3Uploader.uploadImage(XFile(file.path));
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
  // ---------------------- AUTH HELPERS ----------------------

  Future<String> getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('user_token');
    return token ?? '';
  }
  // Login
  Future<Map<String, dynamic>> loginUser(String phoneNumber) async {
    final loginPayload = {
      "phoneNumber": phoneNumber,
      "source": "app",
      "deviceToken": "xyz-device-token",
    };

    final response = await http.post(
      Uri.parse(baseUrl + userLogin),
      headers: {"Content-Type": "application/json"},
      body: json.encode(loginPayload),
    );

    print("Response (Login): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed login: ${response.body}");
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOTP(String phoneNumber, String otp) async {
    final response = await http.post(
      Uri.parse(baseUrl + verifyOtpEndpoint),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"phoneNumber": phoneNumber, "otp": otp}),
    );

    print("Response (Verify OTP): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed OTP: ${response.body}");
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    final resendPayload = {"phoneNo": phoneNumber};

    final response = await http.post(
      Uri.parse(baseUrl + resendOtpEndpoint),
      headers: {"Content-Type": "application/json"},
      body: json.encode(resendPayload),
    );

    print("Response (Resend OTP): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed resend OTP: ${response.body}");
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

    final response = await http.post(
      Uri.parse(baseUrl + updateUserProfile),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode(updatePayload),
    );

    print("Response (Update Profile): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed update profile: ${response.body}");
    }
  }

  // ---------------------- SALONS ----------------------

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
  }) async {
    final token = await getAuthToken();

    String formattedStartTime = _formatTime(startTime);
    String formattedEndTime = _formatTime(endTime);

    final createPayload = {
      "name": name,
      "phone": phone,
      "startTime": formattedStartTime,
      "endTime": formattedEndTime,
      "description": description,
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
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      createPayload["imageUrl"] = imageUrl;
    }

    print("Payload to create salon: ${json.encode(createPayload)}");

    final response = await http.post(
      Uri.parse(baseUrl + createSalonEndpoint),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode(createPayload),
    );

    print("Response (Create Salon): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed create salon: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getSalonListApi() async {
    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse(baseUrl + getSalonList),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("Response (Salon List): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed get salons: ${response.body}");
    }
  }

  // ---------------------- LOGOUT ----------------------

  Future<bool> logoutUserAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');

    if (token == null) return false;

    final url = Uri.parse(baseUrl + logoutUser);
    try {
      final response = await http.get(
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

  // ---------------------- HELPERS ----------------------

  String _formatTime(String time) {
    try {
      DateTime parsedTime = DateFormat.jm().parse(time);
      return DateFormat('HH:mm').format(parsedTime);
    } catch (e) {
      return time;
    }
  }

  Future<Map<String, dynamic>> addCategory({
    required int salonId,
    required AddCategoryRequest request,
  }) async {
    final token = await getAuthToken(); // 🔑 fetch saved token
    final url = Uri.parse(baseUrl + "salons/$salonId/categories");

    // 🔹 Debug print before API call
    print("➡️ Calling Add Category API");
    print("➡️ URL: $url");
    print("➡️ Payload: ${jsonEncode(request.toJson())}");
    print("➡️ Token: $token");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // 👈 add token here
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

  // ---------------------- DELETE CATEGORY ----------------------
  Future<Map<String, dynamic>> deleteCategoryApi({
    required int salonId,
    required int categoryId,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      return {"success": false, "message": "Auth token missing"};
    }

    final url = Uri.parse(
      "${baseUrl}salons/$salonId/categories/$categoryId/delete",
    );

    print("➡️ Calling Delete Category API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await http.delete(
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
        return {"success": true, "message": "Category deleted successfully"};
      } else {
        return {
          "success": false,
          "message": body['message'] ?? "Failed to delete category",
          "statusCode": response.statusCode,
        };
      }
    } catch (e) {
      print("❌ Error deleting category: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // ---------------------- DELETE SUBCATEGORY ----------------------
  Future<Map<String, dynamic>> deleteSubCategoryApi({
    required int salonId,
    required int subCategoryId,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      return {"success": false, "message": "Auth token missing"};
    }

    final url = Uri.parse(
      "${baseUrl}salons/$salonId/subcategories/$subCategoryId/delete",
    );

    print("➡️ Calling Delete SubCategory API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await http.delete(
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
    required int salonId,
    required int serviceId,
  }) async {
    final token = await getAuthToken();

    if (token.isEmpty) {
      return {"success": false, "message": "Auth token missing"};
    }

    final url = Uri.parse("${baseUrl}salons/$salonId/services/$serviceId");

    print("➡️ Calling Delete Service API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    try {
      final response = await http.delete(
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

    final response = await http.get(
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
    required int salonId,
    required int categoryId,
    required AddCategoryRequest request,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + updateCategoryAPI(salonId, categoryId));

    final payload = request.toJson();

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to update category: ${response.body}');
  }

  // ---------------------- DELETE CATEGORY ----------------------
  Future<Map<String, dynamic>> deleteCategory({
    required int salonId,
    required int categoryId,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse("${baseUrl}salons/$salonId/categories/$categoryId");

    print("➡️ Calling Delete Category API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token", // ✅ only auth header
      },
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 204) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : {};
    } else {
      throw Exception("Failed to delete category: ${response.body}");
    }
  }

  // ---------------------- SERVICE CATALOG ----------------------
  Future<Map<String, dynamic>> getServiceCatalog() async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + serviceCatalog);

    print("➡️ Calling Service Catalog API");
    print("➡️ URL: $url");
    print("➡️ Token: $token");

    final response = await http.get(
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
      throw Exception("Failed to fetch service catalog: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> addService({
    required int salonId,
    required AddSalonServiceRequest request,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + addServiceAPI(salonId));

    print("➡️ Calling Add Service API");
    print("➡️ URL: $url");
    print("➡️ Payload: ${jsonEncode(request.toJson())}");

    final response = await http.post(
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
      throw Exception("Failed to add service: ${response.body}");
    }
  }

  // ---------------------- GET SERVICES ----------------------
  Future<Map<String, dynamic>> getService({required int salonId}) async {
    final token = await getAuthToken();
    final url = Uri.parse(
      baseUrl + getServicesAPI(salonId),
    ); // Direct string concatenation

    print("➡️ Calling Get Service API");
    print("➡️ URL: $url");

    final response = await http.get(
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

  // ---------------------- ADD BRANCH ----------------------
  Future<Map<String, dynamic>> addSalonBranch(
    int salonId,
    Map<String, dynamic> branchData,
  ) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + "salons/$salonId/branches/add");

    // Log the request payload before sending
    print("Sending payload to add branch: ");
    print("Token: $token");
    print("URL: $url");
    print("Payload: $branchData");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(branchData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Log successful response
      print("Response: ${response.body}");
      return jsonDecode(response.body);
    } else {
      // Log failed response
      print("Failed to add branch: ${response.body}");
      throw Exception("Failed to add branch: ${response.body}");
    }
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
      final response = await http.get(
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

  // ---------------------- ADD SUBCATEGORY ----------------------
  // Future<Map<String, dynamic>> addSubCategoryApi({
  //   required int salonId,
  //   required int categoryId,
  //   required String name,
  // }) async {
  //   // Fix the URL to avoid double slashes
  //   final url = Uri.parse(
  //     '$baseUrl${addSubCategory.replaceFirst(RegExp(r'^/'), '')}'
  //         .replaceAll("{salonId}", salonId.toString())
  //         .replaceAll("{categoryId}", categoryId.toString()),
  //   );

  //   try {
  //     final token = await getAuthToken(); // Fetch the token using your method

  //     if (token.isEmpty) {
  //       throw Exception("Token is missing");
  //     }

  //     // Print request details for debugging
  //     print("Sending request to URL: $url");
  //     print(
  //       "Request body: ${json.encode({
  //         'name': name,
  //         'sortOrder': 200, // Fixed sortOrder value
  //       })}",
  //     );

  //     final response = await http.post(
  //       url,
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Authorization":
  //             "Bearer $token", // Pass the token in the Authorization header
  //       },
  //       body: json.encode({
  //         "name": name,
  //         "sortOrder": 200, // Fixed sortOrder value
  //       }),
  //     );

  //     // Print response details for debugging
  //     print("Response status: ${response.statusCode}");
  //     print("Response body: ${response.body}");

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       // Return the response data if successful
  //       return json.decode(response.body);
  //     } else {
  //       // If the status code is not 200 or 201, throw an exception
  //       throw Exception("Failed to create subcategory");
  //     }
  //   } catch (e) {
  //     print("Error adding subcategory: $e"); // Print the error for debugging
  //     throw Exception("Error adding subcategory: $e");
  //   }
  // }
Future<Map<String, dynamic>> addSubCategoryApi({
  required int salonId,
  required int categoryId,
  required String name,
}) async {
  final url = Uri.parse(
    '$baseUrl${addSubCategory.replaceFirst(RegExp(r'^/'), '')}'
      .replaceAll("{salonId}", salonId.toString())
      .replaceAll("{categoryId}", categoryId.toString()),
  );

  final token = await getAuthToken();
  if (token.isEmpty) {
    // Throw JSON so your Cubit’s _extractErrorMessage can show a nice SnackBar
    throw Exception('{"message":["Authentication required"]}');
  }

  print("Sending request to URL: $url");
  final bodyJson = json.encode({"name": name, "sortOrder": 200});
  print("Request body: $bodyJson");

  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: bodyJson,
  );

  print("Response status: ${response.statusCode}");
  print("Response body: ${response.body}");

  if (response.statusCode == 200 || response.statusCode == 201) {
    return json.decode(response.body) as Map<String, dynamic>;
  }

  // Surface backend validation verbatim (e.g. {"message":["Name must start with an uppercase letter"], ...})
  throw Exception(response.body.isNotEmpty ? response.body : 'Failed to create subcategory');
}

  // ---------------------- UPDATE SUBCATEGORY ----------------------

  // Future<Map<String, dynamic>> updateSubCategoryApi({
  //   required int salonId,
  //   required int subCategoryId,
  //   required String name,
  // }) async {
  //   final url = Uri.parse(
  //     baseUrl + 'salons/$salonId/subcategories/$subCategoryId',
  //   );
  //   // Log the URL being hit
  //   print("Request URL: $url");

  //   try {
  //     // Request body containing the new name
  //     final requestBody = json.encode({
  //       'name': name, // Update the name of the subcategory
  //     });

  //     // Log the request body
  //     print("Request Body: $requestBody");

  //     // Send the PATCH request
  //     final response = await http.patch(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: requestBody,
  //     );

  //     // Log the status code
  //     print("Response Status Code: ${response.statusCode}");

  //     // Log the response body
  //     print("Response Body: ${response.body}");

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       // Return the response body if successful
  //       return json.decode(response.body);
  //     } else {
  //       // Log the error response
  //       print("Failed to update subcategory. Error: ${response.body}");
  //       throw Exception('Failed to update subcategory');
  //     }
  //   } 
  //   catch (e) {
  //     // Log any errors
  //     print("Error updating subcategory: $e");
  //     throw Exception('Error updating subcategory: $e');
  //   }
  // }

Future<Map<String, dynamic>> updateSubCategoryApi({
  required int salonId,
  required int subCategoryId,
  required String name,
}) async {
  final url = Uri.parse(
    '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/salons/$salonId/subcategories/$subCategoryId',
  );
  print("Request URL: $url");

  final token = await getAuthToken();
  // optional: short-circuit if missing
  if (token.isEmpty) throw Exception('{"message":["Authentication required"]}');

  final requestBody = json.encode({'name': name});
  print("Request Body: $requestBody");

  final response = await http.patch(
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

  // ❗ Surface server validation to Cubit (e.g., {"message":["Name must start with an uppercase letter"], ...})
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
      final response = await http.get(url);

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
          return data['data']; // Return the service data (categories, subcategories, etc.)
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
  Future<Map<String, dynamic>> getRolesAndSpecializations() async {
    try {
      // Fetch the token dynamically from SharedPreferences
      String token = await getAuthToken();

      // Log the request details (with the actual token)
      print('Sending request to: $baseUrl$getRolesSpecialization');
      print('Headers: { "Authorization": "Bearer $token" }');

      // Check if token is empty
      if (token.isEmpty) {
        throw Exception('No token found');
      }

      // Send the request with the actual token in the Authorization header
      final response = await http.get(
        Uri.parse(baseUrl + getRolesSpecialization),
        headers: {
          'Authorization': 'Bearer $token', // Use the actual token here
        },
      );

      // Log the response status code and body
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON
        final data = json.decode(response.body)['data'];
        print('Fetched roles and specializations data: $data');
        return data; // Access the 'data' key in the response
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
    String phoneNumber,
  ) async {
    final url = Uri.parse('$baseUrl$checkSendOtpEndpoint');
    print('Sending request to: $url');

    final headers = {'Content-Type': 'application/json'};

    // Fetch the token and include it in the header
    ApiService apiService =
        ApiService(); // Create an instance of ApiService to access the method
    String token = await apiService
        .getAuthToken(); // Call getAuthToken() using the instance
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token'; // Add token to the headers
    }

    // Print the headers
    print('Headers: { "Authorization": "Bearer $token" }');

    final body = json.encode({'phoneNumber': phoneNumber});

    try {
      final response = await http.post(url, headers: headers, body: body);

      // Log the response status code and body
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Update to handle both 200 and 201 as success codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        // If request fails, throw an error
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print('Error: $e');
      return {'success': false, 'message': 'Error: $e'};
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

      final response = await http.post(url, headers: headers, body: body);

      // Log the status code of the response
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // If successful, parse the response JSON
        return json.decode(response.body);
      } else {
        // If request fails, throw an error
        throw Exception('Failed to add user');
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
      final String token = await apiService
          .getAuthToken(); // Call it on the instance

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
      final response = await http.get(url, headers: headers);

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

  Future<Map<String, dynamic>> getSalonPackagesDealsApi(int salonId) async {
    final url = Uri.parse(baseUrl + getSalonPackagesDeals(salonId));
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data; // contains success, message, and data (list of offers)
      } else {
        throw Exception(
          "Failed to fetch salon packages: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("❌ Error fetching salon packages: $e");
      return {
        "success": false,
        "message": "Error fetching salon packages",
        "data": [],
      };
    }
  }

  Future<Map<String, dynamic>> deleteSalonOfferApi({
    required int salonId,
    required int offerId,
  }) async {
    final uri = Uri.parse(
      "$baseUrl${ApiService.deleteSalonOffer(salonId, offerId)}",
    );

    print("DELETE Request: $uri");

    try {
      final resp = await http
          .delete(
            uri,
            headers: const {
              'Accept': 'application/json',
              // Don't send Content-Type since there is no body
            },
          )
          .timeout(const Duration(seconds: 25));

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

      final resp = await http
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

      final response = await http.post(
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

  // API call method with logging
  static Future<Map<String, dynamic>> getBranchPackagesDeals(
    int branchId,
  ) async {
    final url = Uri.parse(
      getBranchPackagesDealsUrl(branchId),
    ); // Call the URL generator method
    print('Request URL: $url'); // Log the request URL

    try {
      final response = await http.get(url);

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

      final response = await http.get(
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

      final resp = await http
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
      final response = await http.post(
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

  Future<Map<String, dynamic>> createSalonBranchOffer(
    int salonId,
    Map<String, dynamic> offerData,
  ) async {
    final url = Uri.parse(
      "$baseUrl${addSalonBranchOffer(salonId)}",
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

      final response = await http.post(
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

  Future<Map<String, dynamic>> updateService({
    required int salonId,
    required int serviceId,
    required Map<String, dynamic> body,
  }) async {
    final token = await getAuthToken();
    if (token.isEmpty) {
      throw Exception('Token is missing');
    }

    final url = Uri.parse(baseUrl + 'salons/$salonId/services/$serviceId');
    final payload = Map<String, dynamic>.from(body)
      ..removeWhere((key, value) => value == null);

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = response.body.isEmpty ? '{}' : response.body;
      return json.decode(responseBody) as Map<String, dynamic>;
    }

    throw Exception('Failed to update service: ${response.body}');
  }

// ---------------------- START APPOINTMENT ----------------------
static Future<Map<String, dynamic>> startAppointment({
  required int branchId,
  required int appointmentId,
  required String otp,
}) async {
  // get token
  final token = await ApiService().getAuthToken();
  if (token.isEmpty) {
    throw Exception('Token is missing');
  }

  final url = Uri.parse("$baseUrl${startAppointmentAPI(branchId, appointmentId)}");

  print("➡️ [START_APPOINTMENT] Request:");
  print("  URL: $url");
  print("  Method: POST");
  print("  Headers: { Content-Type: application/json, Authorization: Bearer $token }");
  print("  Body: ${jsonEncode({
    "branchId": branchId,
    "appointmentId": appointmentId,
    "otp": otp,
  })}");

  try {
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "branchId": branchId,
        "appointmentId": appointmentId,
        "otp": otp,
      }),
    );

    print("⬅️ [START_APPOINTMENT] Response:");
    print("  Status Code: ${response.statusCode}");
    print("  Body: ${response.body}");

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        print("✅ Parsed JSON: $decoded");
        return decoded;
      } catch (err) {
        print("❌ JSON Decode Error: $err");
        return {
          "success": false,
          "error": "Invalid JSON",
          "rawBody": response.body,
        };
      }
    } else {
      return {
        "success": false,
        "statusCode": response.statusCode,
        "body": response.body,
      };
    }
  } catch (e, stack) {
    print("❌ [START_APPOINTMENT] Exception: $e");
    print("Stacktrace: $stack");
    return {
      "success": false,
      "error": e.toString(),
    };
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
    print("  Headers: { Content-Type: application/json, Authorization: Bearer $token }");
    print("  Body: ${jsonEncode({
      "rating": rating,
      if (comment != null) "comment": comment,
    })}");

    final resp = await http.post(
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


}
