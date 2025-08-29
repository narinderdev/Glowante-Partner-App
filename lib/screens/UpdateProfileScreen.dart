import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../screens/bottom_nav.dart'; // Import BottomNav for navigation
import '../screens/add_salon_screen.dart'; // Ensure the correct path

class UpdateUserProfileScreen extends StatefulWidget {
  final String token; // Token passed from OTP verification screen

  // Constructor to accept the token
  UpdateUserProfileScreen({required this.token});

  @override
  _UpdateUserProfileScreenState createState() => _UpdateUserProfileScreenState();
}

class _UpdateUserProfileScreenState extends State<UpdateUserProfileScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false; // Flag to show loader while updating profile

  // API service instance
  final ApiService apiService = ApiService();

  // Function to update user profile
Future<void> _updateProfile() async {
  String firstName = firstNameController.text;
  String lastName = lastNameController.text;
  String email = emailController.text;

  if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
    setState(() {
      errorMessage = 'All fields are required';
    });
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    final response = await apiService.updateUserProfileDetails(firstName, lastName, email, widget.token);

    if (response['success'] == true) {
      var userData = response['data'];
      int salonId = userData['salonId'] ?? 0;

      // Retrieve latitude and longitude from user data or set defaults if they don't exist
      double? latitude = userData['latitude'] ?? 0.0;
      double? longitude = userData['longitude'] ?? 0.0;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddSalonScreen(
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
            latitude: latitude,  // Pass latitude
            longitude: longitude,  // Pass longitude
          ),
        ),
      );
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'Failed to update profile';
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Error updating profile: $e';
    });
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  // Helper function to capitalize the first letter of a string
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Profile'),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(firstNameController, 'First Name', 'Enter your first name'),
            _buildTextField(lastNameController, 'Last Name', 'Enter your last name'),
            _buildTextField(emailController, 'Email', 'Enter your email'),
            if (errorMessage.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading ? null : _updateProfile, // Disable button while loading
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Use backgroundColor instead of primary
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white) // Show loader when loading
                  : Text('Update Profile', style: TextStyle(color: Colors.white)),
            ),
            //  SizedBox(height: 20),
            // // Display the token on the screen
            // Text('Token: ${widget.token}', style: TextStyle(fontSize: 16, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  // Custom method to build text fields with consistent styling
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      ),
    );
  }
}
