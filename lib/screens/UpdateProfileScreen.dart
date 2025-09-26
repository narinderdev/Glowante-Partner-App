import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/api_service.dart';
import '../screens/add_salon_screen.dart'; // Import AddSalonScreen
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart'; // Import AddSalonCubit
import 'package:bloc_onboarding/repositories/salon_repository.dart'; // Import SalonRepository

class UpdateUserProfileScreen extends StatefulWidget {
  final String token; // Token passed from OTP verification screen

  // Constructor to accept the token
  UpdateUserProfileScreen({required this.token});

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
  Future<void> _updateProfile() async {
    String firstName = firstNameController.text;
    String lastName = lastNameController.text;
    String email = emailController.text;

    // Reset errors
    setState(() {
      firstNameError = '';
      lastNameError = '';
      emailError = '';
    });

    // Validate input
    bool isValid = true;
    if (firstName.isEmpty) {
      setState(() {
        firstNameError = 'First Name is required';
      });
      isValid = false;
    }
    if (lastName.isEmpty) {
      setState(() {
        lastNameError = 'Last Name is required';
      });
      isValid = false;
    }
    if (email.isEmpty) {
      setState(() {
        emailError = 'Email is required';
      });
      isValid = false;
    }

    if (!isValid) return; // Don't proceed if validation fails

    setState(() {
      isLoading = true;
    });

    try {
      final response = await apiService.updateUserProfileDetails(
        firstName,
        lastName,
        email,
        widget.token,
      );

      // Check for success
      if (response['success'] == true) {
        var userData = response['data'];
        int salonId = userData['salonId'] ?? 0;

        // Retrieve latitude and longitude from user data or set defaults if they don't exist
        double? latitude = userData['latitude'] ?? 0.0;
        double? longitude = userData['longitude'] ?? 0.0;

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
      } else {
        // Handle API response error and show an alert dialog with validation messages
        List<String> errorMessages = List<String>.from(response['message'] ?? []);
        _showErrorDialog(errorMessages);
      }
    } catch (e) {
      setState(() {
        emailError = 'Error updating profile: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to show the error messages in an alert dialog
  void _showErrorDialog(List<String> errorMessages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Profile Update Failed"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: errorMessages
                .map((error) => Text(error, style: TextStyle(color: Colors.red)))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
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
        title: const Text(
          'Update Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(  // Wrapping the body in a SingleChildScrollView
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
            _buildTextField(emailController, 'Email', 'Enter your email', 'email', emailError),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading ? null : _updateProfile, // Disable button while loading
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.black, // Use backgroundColor instead of primary
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
                      'Update Profile',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom method to build text fields with consistent styling
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    String fieldType, // to determine the field type for error handling
    String fieldError, // to handle specific field error message
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              // Clear error when user starts typing
              setState(() {
                if (fieldType == 'firstName') firstNameError = '';
                if (fieldType == 'lastName') lastNameError = '';
                if (fieldType == 'email') emailError = '';
              });
            },
            inputFormatters: [
              // Restrict input to alphabet and whitespace only for first/last names
              if (fieldType != 'email') 
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]')),
            ],
            textCapitalization: fieldType == 'email'
                ? TextCapitalization.none
                : TextCapitalization.words, // Automatically capitalize for name fields
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
          ),
          if (fieldError.isNotEmpty) ...[
            SizedBox(height: 5),
            Text(
              fieldError,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
