import 'package:flutter/material.dart';
import '../screens/Adddeals.dart';  // Import the AddDealsScreen

class BranchDealsScreen extends StatelessWidget {
  final Map<String, dynamic> branchDetails;

  const BranchDealsScreen({Key? key, required this.branchDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final branchName = branchDetails['name'] ?? 'Branch Name';
    final String line1 = branchDetails['address']?['line1'] ?? 'No address';
    final branchId = branchDetails['id'] ?? 'No ID';  // Fetch branch ID

    return Scaffold(
      appBar: null,  // Remove the app bar
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Branch ID: $branchId',  // Display branch ID
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to AddDealsScreen with source: 'DEAL'
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDealsScreen(
                salonId: branchDetails['id'],
                salonName: branchDetails['name'],
                onPackageCreated: (id) {}, // You can define the callback here
                source: 'DEAL',  // Pass 'DEAL' as the source
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Deal'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
