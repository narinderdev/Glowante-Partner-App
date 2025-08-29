import 'dart:convert';

import 'package:http/http.dart' as http;

class AddSalonBranchRequest {
  final String name;
  final String phone;
  final String startTime;
  final String endTime;
  final String description;
  final String image_url;  // Changed field name
  final Map<String, dynamic> address;
  final double latitude;
  final double longitude;

  AddSalonBranchRequest({
    required this.name,
    required this.phone,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.image_url,  // Ensure this is the right key
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'image_url': image_url.isEmpty ? "" : image_url,  // Changed field name
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}


