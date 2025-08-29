import 'package:flutter/material.dart';
import 'AddTeam.dart';  // Import AddTeam screen
import 'AddStylist.dart';  // Import AddStylist screen

class TeamMemberScreen extends StatelessWidget {
  final Map<String, dynamic> branchDetails;  // Add this to accept branchDetails

  const TeamMemberScreen({Key? key, required this.branchDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null, // Remove the app bar completely
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Add space above the row
            SizedBox(height: 40), // Space between the top and the row

            // Row to align "Become a stylist?" text and "Become Stylist" button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space the text and button
              children: [
                Text(
                  'Become a stylist?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to AddStylist screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddStylistScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, // Set the background color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Curved corners
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Button padding
                  ),
                  child: Text(
                    'Become Stylist',
                    style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold), // White text
                  ),
                ),
              ],
            ),
            SizedBox(height: 80), // Add some space between the row and bottom button
            Text('Branch ID: ${branchDetails['id']}', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      // "+" floating action button at the bottom right
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple, // Set the floating button color
        onPressed: () {
          // Pass branch ID (not the whole branchDetails)
Navigator.push(
  context,
  MaterialPageRoute(
builder: (_) => AddTeamScreen(branchId: branchDetails['id']), 
  ),
);



        },
        child: Icon(Icons.add),
      ),
    );
  }
}
