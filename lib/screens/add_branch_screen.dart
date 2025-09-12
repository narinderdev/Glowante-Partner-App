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
      appBar: AppBar(title: const Text('Add Branch'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card container for primary details
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTextField(branchNameController, 'Branch Name *', 'Enter branch name'),
                      _buildTextField(
                        phoneController,
                        'Phone Number *',
                        'Enter phone number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerField(
                              controller: startTimeController,
                              label: 'Start Time *',
                              onTap: () => _selectTime(context, true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimePickerField(
                              controller: endTimeController,
                              label: 'End Time *',
                              onTap: () => _selectTime(context, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('$buildingName, $city, $pincode, $state')),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: _navigateToAddLocation,
                            ),
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: _navigateToAddLocation,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Add Location'),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildTextField(
                    descriptionController,
                    'Description *',
                    'Enter a description',
                    maxLines: 4,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Images
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Branch Images', style: TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo, color: Colors.orange)),
                        ],
                      ),
                      if (_images != null && _images!.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _images!.map((image) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(image.path),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            );
                          }).toList(),
                        )
                      else
                        const Text('No images selected'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              ElevatedButton(
                onPressed: _submitBranchDetails,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Submit Branch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to build text fields
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.orange),
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
