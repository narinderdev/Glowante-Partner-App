import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // To format time
import 'package:image_picker/image_picker.dart'; // For image selection
import 'add_location_screen.dart';  // Import AddLocationScreen
import '../utils/api_service.dart';  // Import ApiService
import 'dart:io';  // To work with files like images
import '../screens/bottom_nav.dart'; // Import BottomNav for navigation
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences

class AddSalonScreen extends StatefulWidget {
  final String? id;
  final String? phoneNumber;
  final String? fullPhoneNumber;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? isProceedFrom;
  final String? buildingName;
  final String? city;
  final String? pincode;
  final String? state;
  final double? latitude;
  final double? longitude;

  const AddSalonScreen({
    Key? key,
    this.id,
    this.phoneNumber,
    this.fullPhoneNumber,
    this.firstName,
    this.lastName,
    this.email,
    this.isProceedFrom,
    this.buildingName,
    this.city,
    this.pincode,
    this.state,
    this.latitude,
    this.longitude,
  }) : super(key: key);

  @override
  _AddSalonScreenState createState() => _AddSalonScreenState();
}

class _AddSalonScreenState extends State<AddSalonScreen> {
  String buildingName = '';
  String city = '';
  String pincode = '';
  String state = '';
 double? latitude;
  double? longitude;
  final ApiService apiService = ApiService();

  // Controllers for user input fields
  final TextEditingController salonNameController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

 @override
void initState() {
  super.initState();
  buildingName = widget.buildingName ?? '';
  city = widget.city ?? '';
  pincode = widget.pincode ?? '';
  state = widget.state ?? '';
   _loadPhoneNumber(); // 👈 load from prefs
}

Future<void> _loadPhoneNumber() async {
  final prefs = await SharedPreferences.getInstance();
  final savedPhone = prefs.getString('phone_number') ?? '';
  setState(() {
    phoneNumberController.text = widget.phoneNumber ?? savedPhone;
  });
}
  // Variables for Time Picker
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // For picking images
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images = [];
  
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


  // Time picker function
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
        if (isStartTime) {
          startTime = picked;
          startTimeController.text = DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
        } else {
          endTime = picked;
          endTimeController.text = DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
        }
      });
    }
  }

  // Function to pick images from the gallery
  Future<void> _pickImage() async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();
    setState(() {
      _images = selectedImages;
    });
  }
// Submit salon details
Future<void> _submitSalonDetails() async {
  if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty) {
    try {
      String? imageUrl;
      List<String> imageUrls = [];

      // ✅ Upload images if any selected
      if (_images != null && _images!.isNotEmpty) {
        final files = _images!.map((xfile) => File(xfile.path)).toList();
        imageUrls = await apiService.uploadMultipleImages(files);

        // If backend supports only one imageUrl
        imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
      }

      final result = await apiService.createSalon(
        salonNameController.text,
        phoneNumberController.text,
        startTimeController.text,
        endTimeController.text,
        descriptionController.text,
        buildingName,
        city,
        pincode,
        state,
        latitude ?? 0.0,
        longitude ?? 0.0,
        imageUrl: imageUrl, // 👈 single optional image
        // if backend supports multiple, pass imageUrls instead
      );

      print("Salon created successfully: $result");

     Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 0)),
  (Route<dynamic> route) => false,
);

    } catch (e) {
      print("Error creating salon: $e");
    }
  } else {
    print('Address components and location are required');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Salon'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salon Name
            _buildTextField(salonNameController, 'Salon Name *', 'Enter your salon name'),

            // Phone Number (pre-filled)
        _buildTextField(phoneNumberController, 'Phone Number *',  phoneNumberController.text,  enabled: false),


            // Start Time and End Time
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

            // Location (Button to open AddLocationScreen)
            SizedBox(height: 20),
            if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty) ...[
              // Show full address and edit button if address exists
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
              // Show the "Add Location" button if no address exists
              ElevatedButton(
                onPressed: _navigateToAddLocation,
                child: Text('Add Location'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50), // Full width, fixed height
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners with radius 10
                  ),
                  backgroundColor: Colors.orange, // Background color (optional)
                  foregroundColor: Colors.white, // Text color (optional)
                ),
              ),
            ],

            SizedBox(height: 20),

            // Description
            _buildTextField(descriptionController, 'Description *', 'Enter a description about your salon'),

            // Salon Images
            SizedBox(height: 20),
            Text('Salon Images', style: TextStyle(fontSize: 16, color: Colors.black)),
            IconButton(
              icon: Icon(Icons.add, size: 40, color: Colors.orange),
              onPressed: _pickImage,
            ),
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

            // Add Salon Button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitSalonDetails,
              child: Text('+Add Salon'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Full width, fixed height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners with radius 10
                ),
                backgroundColor: Colors.orange, // Background color (optional)
                foregroundColor: Colors.white, // Text color (optional)
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom method to build text fields with consistent styling
  Widget _buildTextField(TextEditingController? controller, String label, String hint, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      ),
    );
  }

  // Custom method to build time picker fields
  Widget _buildTimePickerField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(controller, label, 'Select time', enabled: true),
      ),
    );
  }
}
