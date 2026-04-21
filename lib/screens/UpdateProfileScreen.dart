import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/api_service.dart';
import '../screens/add_salon_screen.dart'; // Import AddSalonScreen
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart'; // Import AddSalonCubit
import 'package:bloc_onboarding/repositories/salon_repository.dart'; // Import SalonRepository
import '../utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'stylist_bottom_nav.dart';

class UpdateUserProfileScreen extends StatefulWidget {
  final String token; // Token passed from OTP verification screen
  final bool isStylist;

  // Constructor to accept the token
  UpdateUserProfileScreen({
    super.key,
    required this.token,
    this.isStylist = false,
  });

  @override
  _UpdateUserProfileScreenState createState() =>
      _UpdateUserProfileScreenState();
}

class _UpdateUserProfileScreenState extends State<UpdateUserProfileScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String firstNameError = '';
  String lastNameError = '';
  String emailError = '';

  bool isLoading = false; // Flag to show loader while updating profile

  // API service instance
  final ApiService apiService = ApiService();

  // Function to update user profile
//   Future<void> _updateProfile() async {
// String firstName = _capitalizeFirstLetter(firstNameController.text.trim());
//   String lastName = _capitalizeFirstLetter(lastNameController.text.trim());
// String email = emailController.text.trim();

//     // Reset errors
//     setState(() {
//       firstNameError = '';
//       lastNameError = '';
//       emailError = '';
//     });

//     // Validate input
//     bool isValid = true;
//     if (firstName.isEmpty) {
//       setState(() {
//         firstNameError = translateText('First Name is required');
//       });
//       isValid = false;
//     }
//     if (lastName.isEmpty) {
//       setState(() {
//         lastNameError = translateText('Last Name is required');
//       });
//       isValid = false;
//     }
//    if (email.isEmpty) {
//   setState(() => emailError = 'Email is required');
//   isValid = false;
// } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
//   setState(() => emailError = 'Enter a valid email');
//   isValid = false;
// }

//     if (!isValid) return; // Don't proceed if validation fails

//     setState(() {
//       isLoading = true;
//     });

//  try {
//       final response = await apiService.updateUserProfileDetails(
//         firstName,
//         lastName,
//         email,
//         widget.token,
//       );
//  SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString('firstName', firstName);
//     await prefs.setString('lastName', lastName);
//     await prefs.setString('email', email);
//     await prefs.setString('first_name', firstName);
//     await prefs.setString('last_name', lastName);
//     await prefs.setBool('profile_complete', true);
//     await prefs.setBool('profile_pending', false);
//     print('Saved firstName: $firstName');
//   print('Saved lastName: $lastName');
//   print('Saved email: $email');
//       // Check for success
//       if (response['success'] == true) {
//         var userData = response['data'];
//         int salonId = userData['salonId'] ?? 0;

//         // Retrieve latitude and longitude from user data or set defaults if they don't exist
//         double? latitude = userData['latitude'] ?? 0.0;
//         double? longitude = userData['longitude'] ?? 0.0;

//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => BlocProvider(
//               create: (context) =>
//                   AddSalonCubit(context.read<SalonRepository>()),
//               child: AddSalonScreen(
//                 id: userData['id'].toString(),
//                 phoneNumber: userData['phoneNumber'],
//                 fullPhoneNumber: userData['fullPhoneNumber'],
//                 firstName: userData['firstName'] ?? '',
//                 lastName: userData['lastName'] ?? '',
//                 email: userData['email'] ?? '',
//                 isProceedFrom: "onboarding",
//                 buildingName: userData['buildingName'] ?? '',
//                 city: userData['city'] ?? '',
//                 pincode: userData['pincode'] ?? '',
//                 state: userData['state'] ?? '',
//                 latitude: latitude,
//                 longitude: longitude,
//               ),
//             ),
//           ),
//         );
//       } else {
//         // Handle API response error and show an alert dialog with validation messages
//         List<String> errorMessages = List<String>.from(response['message'] ?? []);
//         _showErrorDialog(errorMessages);
//       }
//     } catch (e) {
//       setState(() {
//         emailError = 'Error updating profile: $e';
//       });
//     } finally {
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }
  Future<void> _updateProfile() async {
    String firstName = _capitalizeFirstLetter(firstNameController.text.trim());
    String lastName = _capitalizeFirstLetter(lastNameController.text.trim());
    String email = emailController.text.trim();

    // Reset errors
    setState(() {
      firstNameError = '';
      lastNameError = '';
      emailError = '';
    });

    // Validate input
    bool isValid = true;

    // ✅ First name validation
    if (firstName.isEmpty) {
      setState(() => firstNameError = translateText('First Name is required'));
      isValid = false;
    } else if (firstName.length < 2) {
      setState(() => firstNameError =
          translateText('First Name must be at least 2 characters'));
      isValid = false;
    }

    // ✅ Last name validation
    if (lastName.isEmpty) {
      setState(() => lastNameError = translateText('Last Name is required'));
      isValid = false;
    } else if (lastName.length < 2) {
      setState(() => lastNameError =
          translateText('Last Name must be at least 2 characters'));
      isValid = false;
    }

    // ✅ Email validation
    if (email.isEmpty) {
      setState(() => emailError = translateText('Email is required'));
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => emailError = translateText('Enter a valid email'));
      isValid = false;
    }

    if (!isValid) return;

    setState(() => isLoading = true);

    try {
      final response = await apiService.updateUserProfileDetails(
        firstName,
        lastName,
        email,
        widget.token,
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('firstName', firstName);
      await prefs.setString('lastName', lastName);
      await prefs.setString('email', email);
      await prefs.setString('first_name', firstName);
      await prefs.setString('last_name', lastName);
      await prefs.setBool('profile_complete', true);
      await prefs.setBool('profile_pending', false);

      if (response['success'] == true) {
        var userData = response['data'];
        double? latitude = userData['latitude'] ?? 0.0;
        double? longitude = userData['longitude'] ?? 0.0;

        if (widget.isStylist) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const StylistBottomNav(tabIndex: 0),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (context) =>
                    AddSalonCubit(context.read<SalonRepository>()),
                child: AddSalonScreen(
                  id: userData['id'].toString(),
                  phoneNumber: userData['phoneNumber'],
                  fullPhoneNumber: userData['fullPhoneNumber'],
                  firstName: userData['firstName'] ?? '',
                  lastName: userData['lastName'] ?? '',
                  email: userData['email'] ?? '',
                  isProceedFrom: "onboarding",
                  buildingName: userData['buildingName'] ?? '',
                  city: userData['city'] ?? '',
                  pincode: userData['pincode'] ?? '',
                  state: userData['state'] ?? '',
                  latitude: latitude,
                  longitude: longitude,
                ),
              ),
            ),
          );
        }
      } else {
        List<String> errorMessages =
            List<String>.from(response['message'] ?? []);
        _showErrorDialog(errorMessages);
      }
    } catch (e) {
      setState(() => emailError = 'Error updating profile: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _capitalizeFirstLetter(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  // Function to show the error messages in an alert dialog
  void _showErrorDialog(List<String> errorMessages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translateText("Profile Update Failed")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: errorMessages
                .map(
                    (error) => Text(error, style: TextStyle(color: Colors.red)))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(translateText("OK")),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          translateText('Create Profile'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        // Wrapping the body in a SingleChildScrollView
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              firstNameController,
              'First Name',
              'Enter your first name',
              'firstName',
              firstNameError,
            ),
            _buildTextField(
              lastNameController,
              'Last Name',
              'Enter your last name',
              'lastName',
              lastNameError,
            ),
            _buildTextField(emailController, 'Email', 'Enter your email',
                'email', emailError),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : _updateProfile, // Disable button while loading
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors
                    .starColor, // Use backgroundColor instead of primary
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator(
                      color: Colors.white,
                    ) // Show loader when loading
                  : Text(
                      translateText('Create Profile'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

// Custom method to build text fields with consistent stylingWidget
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    String fieldType,
    String fieldError,
  ) {
    final bool isNameField =
        fieldType == 'firstName' || fieldType == 'lastName';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final text = value.text;
              return TextField(
                controller: controller,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  setState(() {
                    if (fieldType == 'firstName') firstNameError = '';
                    if (fieldType == 'lastName') lastNameError = '';
                    if (fieldType == 'email') emailError = '';
                  });
                },
                keyboardType: fieldType == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                inputFormatters: [
                  if (fieldType == 'email')
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  if (isNameField)
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]')),
                  if (isNameField) LengthLimitingTextInputFormatter(50),
                ],
                textCapitalization: isNameField
                    ? TextCapitalization.words
                    : TextCapitalization.none,
                // decoration: InputDecoration(
                //   labelText: label,
                //   hintText: hint,
                //   counterText: '',
                //   suffixIcon: isNameField && text.isNotEmpty
                //       ? Padding(
                //           padding: const EdgeInsets.only(right: 10, top: 14),
                //           child: Text(
                //             '${text.length}/30',
                //             style: TextStyle(
                //               fontSize: 12,
                //               color: text.length >= 30
                //                   ? Colors.red
                //                   : Colors.grey,
                //             ),
                //           ),
                //         )
                //       : null,
                //   border: OutlineInputBorder(
                //     borderRadius: BorderRadius.circular(8),
                //     borderSide: const BorderSide(color: Colors.black),
                //   ),
                //   focusedBorder: OutlineInputBorder(
                //     borderRadius: BorderRadius.circular(8),
                //     borderSide:
                //         const BorderSide(color: Colors.black, width: 2),
                //   ),
                // ),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  counterText: '',

                  // ✅ Always show counter, even when empty
                  suffixIcon: isNameField
                      ? Padding(
                          padding: const EdgeInsets.only(right: 10, top: 14),
                          child: Text(
                            '${text.length}/50',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  text.length >= 50 ? Colors.red : Colors.grey,
                            ),
                          ),
                        )
                      : null,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.getStartedButton),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.getStartedButton, width: 2),
                  ),
                ),
              );
            },
          ),
          if (fieldError.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              fieldError,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
