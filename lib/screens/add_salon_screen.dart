// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // To format time
// import 'package:image_picker/image_picker.dart'; // For image selection
// import 'add_location_screen.dart';  // Import AddLocationScreen
// import '../utils/api_service.dart';  // Import ApiService
// import 'dart:io';  // To work with files like images
// import '../screens/bottom_nav.dart'; // Import BottomNav for navigation
// import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences

// class AddSalonScreen extends StatefulWidget {
//   final String? id;
//   final String? phoneNumber;
//   final String? fullPhoneNumber;
//   final String? firstName;
//   final String? lastName;
//   final String? email;
//   final String? isProceedFrom;
//   final String? buildingName;
//   final String? city;
//   final String? pincode;
//   final String? state;
//   final double? latitude;
//   final double? longitude;

//   const AddSalonScreen({
//     Key? key,
//     this.id,
//     this.phoneNumber,
//     this.fullPhoneNumber,
//     this.firstName,
//     this.lastName,
//     this.email,
//     this.isProceedFrom,
//     this.buildingName,
//     this.city,
//     this.pincode,
//     this.state,
//     this.latitude,
//     this.longitude,
//   }) : super(key: key);

//   @override
//   _AddSalonScreenState createState() => _AddSalonScreenState();
// }

// class _AddSalonScreenState extends State<AddSalonScreen> {
//   String buildingName = '';
//   String city = '';
//   String pincode = '';
//   String state = '';
//  double? latitude;
//   double? longitude;
//   final ApiService apiService = ApiService();

//   // Controllers for user input fields
//   final TextEditingController salonNameController = TextEditingController();
//   final TextEditingController startTimeController = TextEditingController();
//   final TextEditingController endTimeController = TextEditingController();
//   final TextEditingController descriptionController = TextEditingController();
//   final TextEditingController phoneNumberController = TextEditingController();

//  @override
// void initState() {
//   super.initState();
//   buildingName = widget.buildingName ?? '';
//   city = widget.city ?? '';
//   pincode = widget.pincode ?? '';
//   state = widget.state ?? '';
//    _loadPhoneNumber(); // 👈 load from prefs
// }

// Future<void> _loadPhoneNumber() async {
//   final prefs = await SharedPreferences.getInstance();
//   final savedPhone = prefs.getString('phone_number') ?? '';
//   setState(() {
//     phoneNumberController.text = widget.phoneNumber ?? savedPhone;
//   });
// }
//   // Variables for Time Picker
//   TimeOfDay? startTime;
//   TimeOfDay? endTime;

//   // For picking images
//   final ImagePicker _picker = ImagePicker();
//   List<XFile>? _images = [];
  
// Future<void> _navigateToAddLocation() async {
//   final result = await Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (_) => AddLocationScreen(
//         buildingName: buildingName,
//         city: city,
//         pincode: pincode,
//         state: state,
//       ),
//     ),
//   );

//   // If data is returned, update the address components and store latitude/longitude
//   if (result != null) {
//     setState(() {
//       buildingName = result['buildingName'];
//       city = result['city'];
//       pincode = result['pincode'];
//       state = result['state'];
//       latitude = result['latitude'];  // Store latitude
//       longitude = result['longitude']; // Store longitude
//     });
//   }
// }


//   // Time picker function
//   Future<void> _selectTime(BuildContext context, bool isStartTime) async {
//     final TimeOfDay? picked = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.now(),
//       builder: (BuildContext context, Widget? child) {
//         return MediaQuery(
//           data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null) {
//       setState(() {
//         if (isStartTime) {
//           startTime = picked;
//           startTimeController.text = DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
//         } else {
//           endTime = picked;
//           endTimeController.text = DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
//         }
//       });
//     }
//   }

//   // Function to pick images from the gallery
//   Future<void> _pickImage() async {
//     final List<XFile>? selectedImages = await _picker.pickMultiImage();
//     setState(() {
//       _images = selectedImages;
//     });
//   }
// // Submit salon details
// Future<void> _submitSalonDetails() async {
//   if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty) {
//     try {
//       String? imageUrl;
//       List<String> imageUrls = [];

//       // ✅ Upload images if any selected
//       if (_images != null && _images!.isNotEmpty) {
//         final files = _images!.map((xfile) => File(xfile.path)).toList();
//         imageUrls = await apiService.uploadMultipleImages(files);

//         // If backend supports only one imageUrl
//         imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
//       }

//       final result = await apiService.createSalon(
//         salonNameController.text,
//         phoneNumberController.text,
//         startTimeController.text,
//         endTimeController.text,
//         descriptionController.text,
//         buildingName,
//         city,
//         pincode,
//         state,
//         latitude ?? 0.0,
//         longitude ?? 0.0,
//         imageUrl: imageUrl, // 👈 single optional image
//         // if backend supports multiple, pass imageUrls instead
//       );

//       print("Salon created successfully: $result");

//      Navigator.pushAndRemoveUntil(
//   context,
//   MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 0)),
//   (Route<dynamic> route) => false,
// );

//     } catch (e) {
//       print("Error creating salon: $e");
//     }
//   } else {
//     print('Address components and location are required');
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Add Salon'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Salon Name
//             _buildTextField(salonNameController, 'Salon Name *', 'Enter your salon name'),

//             // Phone Number (pre-filled)
//         _buildTextField(phoneNumberController, 'Phone Number *',  phoneNumberController.text,  enabled: false),


//             // Start Time and End Time
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildTimePickerField(
//                     controller: startTimeController,
//                     label: 'Start Time *',
//                     onTap: () => _selectTime(context, true),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 Expanded(
//                   child: _buildTimePickerField(
//                     controller: endTimeController,
//                     label: 'End Time *',
//                     onTap: () => _selectTime(context, false),
//                   ),
//                 ),
//               ],
//             ),

//             // Location (Button to open AddLocationScreen)
//             SizedBox(height: 20),
//             if (buildingName.isNotEmpty && city.isNotEmpty && pincode.isNotEmpty && state.isNotEmpty) ...[
//               // Show full address and edit button if address exists
//               Row(
//                 children: [
//                   Expanded(child: Text('$buildingName, $city, $pincode, $state')),
//                   IconButton(
//                     icon: Icon(Icons.edit, color: Colors.blue),
//                     onPressed: _navigateToAddLocation,
//                   ),
//                 ],
//               ),
//             ] else ...[
//               // Show the "Add Location" button if no address exists
//               ElevatedButton(
//                 onPressed: _navigateToAddLocation,
//                 child: Text('Add Location'),
//                 style: ElevatedButton.styleFrom(
//                   minimumSize: Size(double.infinity, 50), // Full width, fixed height
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10), // Rounded corners with radius 10
//                   ),
//                   backgroundColor: Colors.orange, // Background color (optional)
//                   foregroundColor: Colors.white, // Text color (optional)
//                 ),
//               ),
//             ],

//             SizedBox(height: 20),

//             // Description
//             _buildTextField(descriptionController, 'Description *', 'Enter a description about your salon'),

//             // Salon Images
//             SizedBox(height: 20),
//             Text('Salon Images', style: TextStyle(fontSize: 16, color: Colors.black)),
//             IconButton(
//               icon: Icon(Icons.add, size: 40, color: Colors.orange),
//               onPressed: _pickImage,
//             ),
//             if (_images != null && _images!.isNotEmpty)
//               Wrap(
//                 children: _images!.map((image) {
//                   return Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Image.file(
//                       File(image.path),
//                       width: 80,
//                       height: 80,
//                       fit: BoxFit.cover,
//                     ),
//                   );
//                 }).toList(),
//               ),

//             // Add Salon Button
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _submitSalonDetails,
//               child: Text('+Add Salon'),
//               style: ElevatedButton.styleFrom(
//                 minimumSize: Size(double.infinity, 50), // Full width, fixed height
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10), // Rounded corners with radius 10
//                 ),
//                 backgroundColor: Colors.orange, // Background color (optional)
//                 foregroundColor: Colors.white, // Text color (optional)
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Custom method to build text fields with consistent styling
//   Widget _buildTextField(TextEditingController? controller, String label, String hint, {bool enabled = true}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       child: TextField(
//         controller: controller,
//         enabled: enabled,
//         decoration: InputDecoration(
//           labelText: label,
//           hintText: hint,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//             borderSide: BorderSide(color: Colors.orange),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//             borderSide: BorderSide(color: Colors.orange),
//           ),
//         ),
//       ),
//     );
//   }

//   // Custom method to build time picker fields
//   Widget _buildTimePickerField({
//     required TextEditingController controller,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: _buildTextField(controller, label, 'Select time', enabled: true),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'add_location_screen.dart';
import '../utils/api_service.dart';
import 'dart:io';
import 'dart:convert';
import '../screens/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final _formKey = GlobalKey<FormState>();
bool _isLoading = false;

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
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('phone_number') ?? '';
    setState(() {
      phoneNumberController.text = widget.phoneNumber ?? savedPhone;
    });
  }

  TimeOfDay? startTime;
  TimeOfDay? endTime;

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
          startTimeController.text =
              DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
        } else {
          endTime = picked;
          endTimeController.text =
              DateFormat.jm().format(DateTime(0, 0, 0, picked.hour, picked.minute));
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();
    setState(() {
      _images = selectedImages;
    });
  }

Future<void> _submitSalonDetails() async {
  if (_isLoading) return; // prevent multiple clicks
  if (_formKey.currentState?.validate() ?? false) {
    if (buildingName.isEmpty || city.isEmpty || pincode.isEmpty || state.isEmpty) {
      _showAlert("Missing Location", "Please select your location", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      List<String> imageUrls = [];

      if (_images != null && _images!.isNotEmpty) {
        final files = _images!.map((xfile) => File(xfile.path)).toList();
        imageUrls = await apiService.uploadMultipleImages(files);
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
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      // ✅ Success
      _showAlert("Success", "Salon created successfully!");
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
          (Route<dynamic> route) => false,
        );
      });

    } catch (e) {
      // ✅ Error parsing
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


  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('Add Salon'),
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Form(
  //         key: _formKey,
  //         child: SingleChildScrollView(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               _buildTextField(salonNameController, 'Salon Name *', 'Enter your salon name'),

  //               _buildTextField(phoneNumberController, 'Phone Number *',
  //                   phoneNumberController.text,
  //                   enabled: false),

  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: _buildTimePickerField(
  //                       controller: startTimeController,
  //                       label: 'Start Time *',
  //                       onTap: () => _selectTime(context, true),
  //                     ),
  //                   ),
  //                   SizedBox(width: 10),
  //                   Expanded(
  //                     child: _buildTimePickerField(
  //                       controller: endTimeController,
  //                       label: 'End Time *',
  //                       onTap: () => _selectTime(context, false),
  //                     ),
  //                   ),
  //                 ],
  //               ),

  //               SizedBox(height: 20),
  //               if (buildingName.isNotEmpty &&
  //                   city.isNotEmpty &&
  //                   pincode.isNotEmpty &&
  //                   state.isNotEmpty) ...[
  //                 Container(
  //                   padding: EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     border: Border.all(color: Colors.orange, width: 1.5),
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                   child: Row(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Expanded(
  //                         child: Text(
  //                           '$buildingName, $city, $pincode, $state',
  //                           style: TextStyle(fontSize: 14, color: Colors.black87),
  //                         ),
  //                       ),
  //                       IconButton(
  //                         icon: Icon(Icons.edit, color: Colors.blue),
  //                         onPressed: _navigateToAddLocation,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ] else ...[
  //                 ElevatedButton(
  //                   onPressed: _navigateToAddLocation,
  //                   child: Text('Add Location'),
  //                   style: ElevatedButton.styleFrom(
  //                     minimumSize: Size(double.infinity, 50),
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     backgroundColor: Colors.orange,
  //                     foregroundColor: Colors.white,
  //                   ),
  //                 ),
  //               ],

  //               SizedBox(height: 20),
  //               _buildTextField(
  //                   descriptionController, 'Description *', 'Enter a description about your salon'),

  //               SizedBox(height: 20),
  //               Text('Salon Images', style: TextStyle(fontSize: 16, color: Colors.black)),
  //               IconButton(
  //                 icon: Icon(Icons.add, size: 40, color: Colors.orange),
  //                 onPressed: _pickImage,
  //               ),
  //               if (_images != null && _images!.isNotEmpty)
  //                 Wrap(
  //                   children: _images!.map((image) {
  //                     return Padding(
  //                       padding: const EdgeInsets.all(8.0),
  //                       child: Image.file(
  //                         File(image.path),
  //                         width: 80,
  //                         height: 80,
  //                         fit: BoxFit.cover,
  //                       ),
  //                     );
  //                   }).toList(),
  //                 ),

  //               SizedBox(height: 20),
  //               ElevatedButton(
  //                 onPressed: _submitSalonDetails,
  //                 child: Text('+Add Salon'),
  //                 style: ElevatedButton.styleFrom(
  //                   minimumSize: Size(double.infinity, 50),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                   backgroundColor: Colors.orange,
  //                   foregroundColor: Colors.white,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  void _showAlert(String title, String message, {bool isError = false}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('Add Salon')),
    body: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(salonNameController, 'Salon Name *', 'Enter your salon name'),

                  _buildTextField(
                    phoneNumberController,
                    'Phone Number *',
                    phoneNumberController.text,
                    enabled: false,
                  ),

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
                  if (buildingName.isNotEmpty &&
                      city.isNotEmpty &&
                      pincode.isNotEmpty &&
                      state.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '$buildingName, $city, $pincode, $state',
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: _navigateToAddLocation,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _navigateToAddLocation,
                      child: Text('Add Location'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],

                  SizedBox(height: 20),
                  _buildTextField(
                    descriptionController,
                    'Description *',
                    'Enter a description about your salon',
                  ),

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

                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitSalonDetails,
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text("Processing..."),
                            ],
                          )
                        : Text('+Add Salon'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
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
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildTextField(TextEditingController? controller, String label, String hint,
      {bool enabled = true, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
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
