import 'dart:io';  // Ensure this import for File class
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // To format time
import 'package:image_picker/image_picker.dart';  // For image selection
import 'add_location_screen.dart';  // Import AddLocationScreen
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
import '../utils/api_service.dart';  // Import ApiService
import '../Viewmodels/AddSalonBranchRequest.dart'; // Import AddSalonBranchRequest
import '../utils/aws_s3_uploader.dart';

class AddBranchScreen extends StatefulWidget {
  final int salonId;

  const AddBranchScreen({Key? key, required this.salonId}) : super(key: key);

  @override
  _AddBranchScreenState createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  String buildingName = '';
  String city = '';
  String pincode = '';
  String state = '';
  double? latitude;
  double? longitude;

  // Controllers for user input fields
  final TextEditingController branchNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images = [];

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('phone_number') ?? '';
    setState(() {
      phoneController.text = savedPhone;
    });
  }

  Future<void> _pickImage() async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();
    setState(() {
      _images = selectedImages;
    });
  }

  // Function to navigate to AddLocationScreen and get the location data back
  Future<void> _navigateToAddLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          buildingName: buildingName,
          city: city,
          pincode: pincode,
          state: state,
        ),
      ),
    );

    // If data is returned, update the address components and store latitude/longitude
    if (result != null) {
      setState(() {
        buildingName = result['buildingName'];
        city = result['city'];
        pincode = result['pincode'];
        state = result['state'];
        latitude = result['latitude'];  // Store latitude
        longitude = result['longitude']; // Store longitude
      });
    }
  }
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      );
    },
  );
  if (picked != null) {
    setState(() {
      // Convert TimeOfDay to 24-hour format time string
      final timeString = DateFormat.Hm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
      
      if (isStartTime) {
        startTimeController.text = timeString; // Set the start time
      } else {
        endTimeController.text = timeString; // Set the end time
      }
    });
  }
}

  // Submit branch details
Future<void> _submitBranchDetails() async {
  if (branchNameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
    try {
      String? imageUrl;
      List<String> imageUrls = [];

      // Upload images if any selected
      if (_images != null && _images!.isNotEmpty) {
        final files = _images!.map((xfile) => File(xfile.path)).toList();
        imageUrls = await ApiService().uploadMultipleImages(files);

        // If backend supports only one image_url
        imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
      }

      // Create branch request with formatted address and handle nullable imageUrl properly
      final branchRequest = AddSalonBranchRequest(
        name: branchNameController.text,
        phone: phoneController.text,
        startTime: startTimeController.text, // Already formatted in 24-hour format
        endTime: endTimeController.text,     // Already formatted in 24-hour format
        description: descriptionController.text,
        image_url: imageUrl ?? "", // Changed to image_url
        address: {
          "line1": "$buildingName, $city, $pincode, $state",
          "line2": "",
          "city": city,
          "state": state,
          "country": "India", // Add country
          "postalCode": pincode,
          "village": "", // Add village (if available)
          "district": "", // Add district (if available)
          "latitude": latitude ?? 0.0,
          "longitude": longitude ?? 0.0
        },
        latitude: latitude ?? 0.0,
        longitude: longitude ?? 0.0,
      );

      final branchRequestMap = branchRequest.toJson();  // Convert to Map<String, dynamic>

      // Log the payload
      print("Branch Request Map (Payload): $branchRequestMap");

      // Send the request to add the branch
      final response = await ApiService().addSalonBranch(widget.salonId, branchRequestMap);

      // Check for successful response
      if (response != null && response['success'] == true) {
        Navigator.pop(context); // Go back after adding branch
      } else {
        print("Failed to add branch: ${response['message']}");
      }
    } catch (e) {
      print("Error adding branch: $e");
    }
  }
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Branch')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(branchNameController, 'Branch Name *', 'Enter branch name'),
            _buildTextField(phoneController, 'Phone Number *', 'Enter phone number'),

            // Time picker fields
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerField(
                    controller: startTimeController,
                    label: 'Start Time *',
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildTimePickerField(
                    controller: endTimeController,
                    label: 'End Time *',
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20), 

            // If location is provided, display it
            if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: Text('$buildingName, $city, $pincode, $state')),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: _navigateToAddLocation,
                  ),
                ],
              ),
            ] else ...[
              // If no address, show Add Location button
              ElevatedButton(
                onPressed: _navigateToAddLocation,
                child: Text('Add Location'),
              ),
            ],

            // Description field
            SizedBox(height: 20),
            _buildTextField(descriptionController, 'Description *', 'Enter a description'),

            // Pick Image button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Images'),
            ),

            // Display selected images
            if (_images != null && _images!.isNotEmpty)
              Wrap(
                children: _images!.map((image) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(
                      File(image.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),

            // Submit button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitBranchDetails,
              child: Text('Submit Branch'),
            ),
          ],
        ),
      ),
    );
  }

  // Method to build text fields
  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      ),
    );
  }

  // Time picker field builder
  Widget _buildTimePickerField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(controller, label, 'Select time'),
      ),
    );
  }
}
