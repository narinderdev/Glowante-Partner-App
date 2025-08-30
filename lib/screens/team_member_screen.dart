import 'package:flutter/material.dart';
import 'AddTeam.dart';  // Import AddTeam screen
import 'AddStylist.dart';  // Import AddStylist screen
import '../utils/api_service.dart'; // Import ApiService for the API call

class TeamMemberScreen extends StatelessWidget {
  final Map<String, dynamic> branchDetails;  // Accepting branchDetails

  const TeamMemberScreen({Key? key, required this.branchDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null, // Remove app bar completely
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
            SizedBox(height: 40),  // Add space between the row and team member list
//  Text("Branch Id: ${branchDetails['id']}"),
            // Fetch and display team members
            FutureBuilder<Map<String, dynamic>>(
//             future: ApiService.getTeamMembers(branchDetails['id']),
// builder: (context, snapshot) {
//   if (snapshot.connectionState == ConnectionState.waiting) {
//     return Center(child: CircularProgressIndicator());
//   } else if (snapshot.hasError) {
//     return Center(child: Text('Error: ${snapshot.error}'));
//   } else if (!snapshot.hasData || !snapshot.data!['success']) {
//     return Center(child: Text('Failed to load team members'));
//   } else {
//     List teamMembers = snapshot.data!['data'];
//     return Expanded(
//       child: GridView.builder(
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2, // 2 columns
//           crossAxisSpacing: 16.0, // Space between columns
//           mainAxisSpacing: 16.0, // Space between rows
//         ),
//         itemCount: teamMembers.length,
//         itemBuilder: (context, index) {
//           var member = teamMembers[index];
//           return Card(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//             elevation: 4,
//             child: Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   CircleAvatar(
//                     radius: 40,
//                     backgroundImage: AssetImage('assets/images/default_avatar.png'), // Placeholder image
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     member['firstName'] != null && member['lastName'] != null
//                         ? '${member['firstName']} ${member['lastName']}'
//                         : 'No Name',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 4),
//                   Text('Hair Dresser', style: TextStyle(color: Colors.grey)),
//                   SizedBox(height: 4),
//                   Text('1 year+ Experience', style: TextStyle(color: Colors.grey)),
//                   SizedBox(height: 8),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.star, color: Colors.orange, size: 16),
//                       SizedBox(width: 4),
//                       Text(
//                         '4.4 (43)',
//                         style: TextStyle(fontSize: 14, color: Colors.black),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// },
future: ApiService.getTeamMembers(branchDetails['id']),
builder: (context, snapshot) {
  if (snapshot.connectionState == ConnectionState.waiting) {
    return Center(child: CircularProgressIndicator());
  } else if (snapshot.hasError) {
    return Center(child: Text('Error: ${snapshot.error}'));
  } else if (!snapshot.hasData || !snapshot.data!['success']) {
    return Center(child: Text('Failed to load team members'));
  } else {
    List teamMembers = snapshot.data!['data'];
    return Expanded(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 columns
          crossAxisSpacing: 16.0, // Space between columns
          mainAxisSpacing: 16.0, // Space between rows
        ),
        itemCount: teamMembers.length,
        itemBuilder: (context, index) {
          var member = teamMembers[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Container(
              height: 230, // Fixed height for the card
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rectangular image instead of CircleAvatar
                  Image.asset(
                    'assets/images/photo.png', // Placeholder image
                    height: 120, // Set height for rectangular image
                    width: 120, // Set width for rectangular image
                    fit: BoxFit.cover, // Ensure the image fits well
                  ),
                  SizedBox(height: 8),
                  Text(
                    member['firstName'] != null && member['lastName'] != null
                        ? '${member['firstName']} ${member['lastName']}'
                        : 'No Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('Hair Dresser', style: TextStyle(fontWeight:FontWeight.bold, color: Colors.black)),
                  SizedBox(height: 4),
                  Text('1 year+ Experience', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '4.4 (43)',
                        style: TextStyle(fontSize: 14, fontWeight:FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
},

            ),
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
