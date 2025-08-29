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
class ApiService {
  static const String baseUrl = "https://dev4-api.glowante.com/";

  static const String userLogin = "auth/login";
  static const String verifyOtpEndpoint = "auth/verify-otp";
  static const String resendOtpEndpoint = "auth/resend_otp"; 
  static const String updateUserProfile = "users/update";
  static const String createSalonEndpoint = "salons/create";
  static const String getSalonList = "salons/my";
  static const String logoutUser = "auth/logout";
  static const String serviceCatalog = "service-catalog";
  static const String getBranchServices = "salon-service/catalog";
   static const String addSubCategory = "/salons/{salonId}/categories/{categoryId}/subcategories";
 static String addServiceAPI(int salonId) =>
      "salons/$salonId/services";

static String getServicesAPI(int salonId) =>
      "salons/$salonId/services";

  static String addCategoryAPI(int salonId) {
    return "salons/$salonId/categories";
  }
    static String getCategoriesAPI(int salonId, {bool withSubcats = true}) =>
      "salons/$salonId/categories?withSubcats=$withSubcats";

  static String updateCategoryAPI(int salonId, int categoryId) =>
      "salons/$salonId/categories/$categoryId";

  static String deleteCategoryAPI(int salonId, int categoryId) =>
      "salons/$salonId/categories/$categoryId";

  static String addSalonBranchAPI(int salonId) {
    return "salons/$salonId/branches/add";
  }


  static String addTeamMember(int id) {
    return "branches/$id/add-user";
  }
static const String getRolesSpecialization = "users/constants";

  static String getTeamMember(int id) {
    return "branches/$id/team";
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
      String firstName, String lastName, String email, String token) async {
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
      final response = await http.get(url, headers: {
        "Authorization": "Bearer $token",
      });

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

// inside ApiService class
 Future<Map<String, dynamic>> getCategories({
    required int salonId,
    bool withSubcats = true,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + getCategoriesAPI(salonId, withSubcats: withSubcats));

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
    required String name,
  }) async {
    final token = await getAuthToken();
    final url = Uri.parse(baseUrl + updateCategoryAPI(salonId, categoryId));

    final payload = {"name": name};

    print("➡️ Calling Update Category API");
    print("➡️ URL: $url");
    print("➡️ Payload: $payload");
    print("➡️ Token: $token");

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    print("⬅️ Status Code: ${response.statusCode}");
    print("⬅️ Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to update category: ${response.body}");
    }
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
      "Authorization": "Bearer $token",   // ✅ only auth header
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

  // ---------------------- ADD SERVICE ----------------------
  // Future<Map<String, dynamic>> addService({
  //   required int salonId,
  //   required AddSalonServiceRequest request,
  // }) async {
  //   final token = await getAuthToken();
  //   final url = Uri.parse(baseUrl + addServiceAPI(salonId));

  //   print("➡️ Calling Add Service API");
  //   print("➡️ URL: $url");
  //   print("➡️ Payload: ${jsonEncode(request.toJson())}");

  //   final response = await http.post(
  //     url,
  //     headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     },
  //     body: jsonEncode(request.toJson()),
  //   );

  //   print("⬅️ Status Code: ${response.statusCode}");
  //   print("⬅️ Response Body: ${response.body}");

  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     return jsonDecode(response.body);
  //   } else {
  //     throw Exception("Failed to add service: ${response.body}");
  //   }
  // }
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
  final url = Uri.parse(baseUrl + getServicesAPI(salonId)); // Direct string concatenation

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
  Future<Map<String, dynamic>> addSalonBranch(int salonId, Map<String, dynamic> branchData) async {
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
  final url = Uri.parse('$baseUrl' + 'branches/$branchId'); // Fix: avoid double slashes

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
Future<Map<String, dynamic>> addSubCategoryApi({
  required int salonId,
  required int categoryId,
  required String name,
}) async {
  // Fix the URL to avoid double slashes
  final url = Uri.parse('$baseUrl${addSubCategory.replaceFirst(RegExp(r'^/'), '')}'
      .replaceAll("{salonId}", salonId.toString())
      .replaceAll("{categoryId}", categoryId.toString()));

  try {
    final token = await getAuthToken(); // Fetch the token using your method

    if (token.isEmpty) {
      throw Exception("Token is missing");
    }

    // Print request details for debugging
    print("Sending request to URL: $url");
    print("Request body: ${json.encode({
      'name': name,
      'sortOrder': 200, // Fixed sortOrder value
    })}");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // Pass the token in the Authorization header
      },
      body: json.encode({
        "name": name,
        "sortOrder": 200, // Fixed sortOrder value
      }),
    );

    // Print response details for debugging
    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Return the response data if successful
      return json.decode(response.body); 
    } else {
      // If the status code is not 200 or 201, throw an exception
      throw Exception("Failed to create subcategory");
    }
  } catch (e) {
    print("Error adding subcategory: $e"); // Print the error for debugging
    throw Exception("Error adding subcategory: $e");
  }
} 

// ---------------------- UPDATE SUBCATEGORY ----------------------

Future<Map<String, dynamic>> updateSubCategoryApi({
  required int salonId,
  required int subCategoryId,
  required String name,
}) async {
final url = Uri.parse(baseUrl + 'salons/$salonId/subcategories/$subCategoryId');
  // Log the URL being hit
  print("Request URL: $url");

  try {
    // Request body containing the new name
    final requestBody = json.encode({
      'name': name,  // Update the name of the subcategory
    });

    // Log the request body
    print("Request Body: $requestBody");

    // Send the PATCH request
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    // Log the status code
    print("Response Status Code: ${response.statusCode}");

    // Log the response body
    print("Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Return the response body if successful
      return json.decode(response.body);
    } else {
      // Log the error response
      print("Failed to update subcategory. Error: ${response.body}");
      throw Exception('Failed to update subcategory');
    }
  } catch (e) {
    // Log any errors
    print("Error updating subcategory: $e");
    throw Exception('Error updating subcategory: $e');
  }
}

  // ---------------------- GET BRANCH SERVICE DETAILS ----------------------
   Future<Map<String, dynamic>> getBranchServiceDetail(int branchId) async {
    try {
      // Construct the full URL by concatenating strings using '+'
      final url = Uri.parse(baseUrl + 'branches/$branchId/services');
      
      print('Making GET request to: $url');  // Log the request URL

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
      throw Exception('Failed to load roles and specializations. Status code: ${response.statusCode}');
    }
  } catch (e) {
    // Log the error
    print('Error fetching roles and specializations: $e');
    throw Exception('Error fetching roles and specializations: $e');
  }
}

}


