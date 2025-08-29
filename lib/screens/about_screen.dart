import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  final Map<String, dynamic> branchDetails;

  AboutScreen({required this.branchDetails});

  @override
  Widget build(BuildContext context) {
    final description = branchDetails['description'] ?? 'No description available';
    
    return Scaffold(
      // Remove the app bar completely
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('Branch Name: ${branchDetails['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // SizedBox(height: 10),
            // Text('Branch ID: ${branchDetails['id']}', style: TextStyle(fontSize: 16)),
            // SizedBox(height: 10),
            Text('$description', style: TextStyle(fontSize: 16)),
            // SizedBox(height: 10),
            // Text('Phone: ${branchDetails['phone']}', style: TextStyle(fontSize: 16)),
            // SizedBox(height: 10),
            // Text('Address: ${branchDetails['address']['line1'] ?? 'No address'}', style: TextStyle(fontSize: 16)),
            // SizedBox(height: 10),
            // Text('City: ${branchDetails['address']['city'] ?? 'No city'}', style: TextStyle(fontSize: 16)),
            // SizedBox(height: 10),
            // Text('State: ${branchDetails['address']['state'] ?? 'No state'}', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
