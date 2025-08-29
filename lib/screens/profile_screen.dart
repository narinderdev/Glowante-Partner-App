import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final ApiService apiService = ApiService();

  void _showLogoutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildLogoutActions(context)],
          ),
        );
      },
    );
  }

  Widget _buildLogoutActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Logout',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Are you sure you want to Log Out?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Divider(color: Colors.grey, thickness: 1, indent: 30, endIndent: 30),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ❌ Cancel button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), // just close modal
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 10),
              // ✅ Confirm Logout
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await apiService.logoutUserAPI();
                    Navigator.pop(context); // close modal
                    if (success) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                        (route) => false,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed. Please try again.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Yes, Log out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, // 👈 Orange background
            foregroundColor: Colors.white,  // 👈 White text
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () => _showLogoutModal(context),
          child: Text(
            'Logout',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
