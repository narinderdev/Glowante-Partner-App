// import 'dart:io';  // Ensure this import for File class
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';  // To format time
// import 'package:image_picker/image_picker.dart';  // For image selection
// import 'add_location_screen.dart';  // Import AddLocationScreen
// import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
// import '../utils/api_service.dart';  // Import ApiService
// import '../Viewmodels/AddSalonBranchRequest.dart'; // Import AddSalonBranchRequest
// import '../utils/aws_s3_uploader.dart';

// class AddBranchScreen extends StatefulWidget {
//   final int salonId;

//   const AddBranchScreen({Key? key, required this.salonId}) : super(key: key);

//   @override
//   _AddBranchScreenState createState() => _AddBranchScreenState();
// }

// class _AddBranchScreenState extends State<AddBranchScreen> {
//   String buildingName = '';
//   String city = '';
//   String pincode = '';
//   String state = '';
//   double? latitude;
//   double? longitude;

//   // Controllers for user input fields
//   final TextEditingController branchNameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController startTimeController = TextEditingController();
//   final TextEditingController endTimeController = TextEditingController();
//   final TextEditingController descriptionController = TextEditingController();
//   final ImagePicker _picker = ImagePicker();
//   List<XFile>? _images = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadPhoneNumber();
//   }

//   Future<void> _loadPhoneNumber() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedPhone = prefs.getString('phone_number') ?? '';
//     setState(() {
//       phoneController.text = savedPhone;
//     });
//   }

//   Future<void> _pickImage() async {
//     final List<XFile>? selectedImages = await _picker.pickMultiImage();
//     setState(() {
//       _images = selectedImages;
//     });
//   }

//   // Function to navigate to AddLocationScreen and get the location data back
//   Future<void> _navigateToAddLocation() async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddLocationScreen(
//           buildingName: buildingName,
//           city: city,
//           pincode: pincode,
//           state: state,
//         ),
//       ),
//     );

//     // If data is returned, update the address components and store latitude/longitude
//     if (result != null) {
//       setState(() {
//         buildingName = result['buildingName'];
//         city = result['city'];
//         pincode = result['pincode'];
//         state = result['state'];
//         latitude = result['latitude'];  // Store latitude
//         longitude = result['longitude']; // Store longitude
//       });
//     }
//   }
//   Future<void> _selectTime(BuildContext context, bool isStartTime) async {
//   final TimeOfDay? picked = await showTimePicker(
//     context: context,
//     initialTime: TimeOfDay.now(),
//     builder: (BuildContext context, Widget? child) {
//       return MediaQuery(
//         data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
//         child: child!,
//       );
//     },
//   );
//   if (picked != null) {
//     setState(() {
//       // Convert TimeOfDay to 24-hour format time string
//       final timeString = DateFormat.Hm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
      
//       if (isStartTime) {
//         startTimeController.text = timeString; // Set the start time
//       } else {
//         endTimeController.text = timeString; // Set the end time
//       }
//     });
//   }
// }

//   // Submit branch details
// Future<void> _submitBranchDetails() async {
//   if (branchNameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
//     try {
//       String? imageUrl;
//       List<String> imageUrls = [];

//       // Upload images if any selected
//       if (_images != null && _images!.isNotEmpty) {
//         final files = _images!.map((xfile) => File(xfile.path)).toList();
//         imageUrls = await ApiService().uploadMultipleImages(files);

//         // If backend supports only one image_url
//         imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
//       }

//       // Create branch request with formatted address and handle nullable imageUrl properly
//       final branchRequest = AddSalonBranchRequest(
//         name: branchNameController.text,
//         phone: phoneController.text,
//         startTime: startTimeController.text, // Already formatted in 24-hour format
//         endTime: endTimeController.text,     // Already formatted in 24-hour format
//         description: descriptionController.text,
//         image_url: imageUrl ?? "", // Changed to image_url
//         address: {
//           "line1": "$buildingName, $city, $pincode, $state",
//           "line2": "",
//           "city": city,
//           "state": state,
//           "country": "India", // Add country
//           "postalCode": pincode,
//           "village": "", // Add village (if available)
//           "district": "", // Add district (if available)
//           "latitude": latitude ?? 0.0,
//           "longitude": longitude ?? 0.0
//         },
//         latitude: latitude ?? 0.0,
//         longitude: longitude ?? 0.0,
//       );

//       final branchRequestMap = branchRequest.toJson();  // Convert to Map<String, dynamic>

//       // Log the payload
//       print("Branch Request Map (Payload): $branchRequestMap");

//       // Send the request to add the branch
//       final response = await ApiService().addSalonBranch(widget.salonId, branchRequestMap);

//       // Check for successful response
//       if (response != null && response['success'] == true) {
//         Navigator.pop(context); // Go back after adding branch
//       } else {
//         print("Failed to add branch: ${response['message']}");
//       }
//     } catch (e) {
//       print("Error adding branch: $e");
//     }
//   }
// }




//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Add Branch'), centerTitle: true),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Card container for primary details
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 elevation: 2,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     children: [
//                       _buildTextField(branchNameController, 'Branch Name *', 'Enter branch name'),
//                       _buildTextField(
//                         phoneController,
//                         'Phone Number *',
//                         'Enter phone number',
//                         keyboardType: TextInputType.phone,
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildTimePickerField(
//                               controller: startTimeController,
//                               label: 'Start Time *',
//                               onTap: () => _selectTime(context, true),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: _buildTimePickerField(
//                               controller: endTimeController,
//                               label: 'End Time *',
//                               onTap: () => _selectTime(context, false),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // Location section
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 elevation: 2,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
//                       const SizedBox(height: 8),
//                       if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty)
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(child: Text('$buildingName, $city, $pincode, $state')),
//                             IconButton(
//                               icon: const Icon(Icons.edit, color: Colors.blue),
//                               onPressed: _navigateToAddLocation,
//                             ),
//                           ],
//                         )
//                       else
//                         ElevatedButton(
//                           onPressed: _navigateToAddLocation,
//                           style: ElevatedButton.styleFrom(
//                             minimumSize: const Size(double.infinity, 48),
//                             backgroundColor: Colors.orange,
//                             foregroundColor: Colors.white,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                           ),
//                           child: const Text('Add Location'),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // Description
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 elevation: 2,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: _buildTextField(
//                     descriptionController,
//                     'Description *',
//                     'Enter a description',
//                     maxLines: 4,
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // Images
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 elevation: 2,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text('Branch Images', style: TextStyle(fontWeight: FontWeight.w600)),
//                           IconButton(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo, color: Colors.orange)),
//                         ],
//                       ),
//                       if (_images != null && _images!.isNotEmpty)
//                         Wrap(
//                           spacing: 8,
//                           runSpacing: 8,
//                           children: _images!.map((image) {
//                             return ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.file(
//                                 File(image.path),
//                                 width: 90,
//                                 height: 90,
//                                 fit: BoxFit.cover,
//                               ),
//                             );
//                           }).toList(),
//                         )
//                       else
//                         const Text('No images selected'),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 20),

//               // Submit button
//               ElevatedButton(
//                 onPressed: _submitBranchDetails,
//                 style: ElevatedButton.styleFrom(
//                   minimumSize: const Size(double.infinity, 50),
//                   backgroundColor: Colors.orange,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//                 child: const Text('Submit Branch'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Method to build text fields
//   Widget _buildTextField(
//     TextEditingController controller,
//     String label,
//     String hint, {
//     int maxLines = 1,
//     TextInputType? keyboardType,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       child: TextField(
//         controller: controller,
//         maxLines: maxLines,
//         keyboardType: keyboardType,
//         decoration: InputDecoration(
//           labelText: label,
//           hintText: hint,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//             borderSide: BorderSide(color: Colors.orange),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//             borderSide: const BorderSide(color: Colors.orange),
//           ),
//         ),
//       ),
//     );
//   }

//   // Time picker field builder
//   Widget _buildTimePickerField({
//     required TextEditingController controller,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: _buildTextField(controller, label, 'Select time'),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'add_location_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';
import '../Viewmodels/AddSalonBranchRequest.dart';
import '../utils/aws_s3_uploader.dart';
import 'bottom_nav.dart';
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

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
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

    if (result != null) {
      setState(() {
        buildingName = result['buildingName'];
        city = result['city'];
        pincode = result['pincode'];
        state = result['state'];
        latitude = result['latitude'];
        longitude = result['longitude'];
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final timeString = DateFormat.Hm()
          .format(DateTime(0, 0, 0, picked.hour, picked.minute));
      setState(() {
        if (isStartTime) {
          startTimeController.text = timeString;
        } else {
          endTimeController.text = timeString;
        }
      });
    }
  }

  void _showAlert(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: isError ? Colors.red : Colors.green),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
Future<void> _submitBranchDetails() async {
  if (_isLoading) return;

  if (_formKey.currentState?.validate() ?? false) {
    if (buildingName.isEmpty ||
        city.isEmpty ||
        pincode.isEmpty ||
        state.isEmpty) {
      _showAlert("Missing Location", "Please select branch location",
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      List<String> imageUrls = [];

      if (_images != null && _images!.isNotEmpty) {
        final files = _images!.map((xfile) => File(xfile.path)).toList();
        imageUrls = await ApiService().uploadMultipleImages(files);
        imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
      }

      final branchRequest = AddSalonBranchRequest(
        name: branchNameController.text,
        phone: phoneController.text,
        startTime: startTimeController.text,
        endTime: endTimeController.text,
        description: descriptionController.text,
        image_url: imageUrl ?? "",
        address: {
          "line1": "$buildingName, $city, $pincode, $state",
          "line2": "",
          "city": city,
          "state": state,
          "country": "India",
          "postalCode": pincode,
          "village": "",
          "district": "",
          "latitude": latitude ?? 0.0,
          "longitude": longitude ?? 0.0,
        },
        latitude: latitude ?? 0.0,
        longitude: longitude ?? 0.0,
      );

      final response = await ApiService()
          .addSalonBranch(widget.salonId, branchRequest.toJson());

      if (response != null && response['success'] == true) {
  if (mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
      (Route<dynamic> route) => false,
    );
  }
}
 else {
        String errorMsg = "Something went wrong";

        if (response != null && response['message'] != null) {
          if (response['message'] is List) {
            errorMsg = response['message'].join(", ");
          } else {
            errorMsg = response['message'].toString();
          }
        }

        _showAlert("Error", errorMsg, isError: true);
      }
    } catch (e) {
      String errorMsg = "Something went wrong";

      try {
        final regex = RegExp(r'\{.*\}');
        final match = regex.firstMatch(e.toString());
        if (match != null) {
          final Map<String, dynamic> errorJson = json.decode(match.group(0)!);

          if (errorJson.containsKey('message')) {
            if (errorJson['message'] is List) {
              errorMsg = errorJson['message'].join(", ");
            } else {
              errorMsg = errorJson['message'].toString();
            }
          } else if (errorJson.containsKey('error')) {
            errorMsg = errorJson['error'].toString();
          }
        }
      } catch (_) {
        errorMsg = e.toString();
      }

      if (mounted) {
        _showAlert("Alert", errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Branch'), centerTitle: true),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Details Card
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTextField(branchNameController,
                                'Branch Name *', 'Enter branch name'),
                            _buildTextField(phoneController, 'Phone Number *',
                                'Enter phone number',
                                keyboardType: TextInputType.phone),
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

                    // Location Card
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Location',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (buildingName.isNotEmpty &&
                                city.isNotEmpty &&
                                pincode.isNotEmpty &&
                                state.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        '$buildingName, $city, $pincode, $state'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: _navigateToAddLocation,
                                  ),
                                ],
                              )
                            else
                             SizedBox(
  width: double.infinity, // 👈 full width
  child: ElevatedButton(
    onPressed: _navigateToAddLocation,
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: const Text('Add Location'),
  ),
),

                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description Card
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildTextField(descriptionController,
                            'Description *', 'Enter description',
                            maxLines: 4),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Images
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Branch Images (optional)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                                IconButton(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.add_a_photo,
                                        color: Colors.orange)),
                              ],
                            ),
                            if (_images != null && _images!.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: _images!
                                    .map((img) => Image.file(File(img.path),
                                        width: 80, height: 80))
                                    .toList(),
                              )
                            else
                              const Text("No images selected"),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitBranchDetails,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('Submit Branch'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

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
