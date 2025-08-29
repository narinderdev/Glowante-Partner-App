import 'package:flutter/material.dart';
import 'Adddeals.dart';

class PackageScreen extends StatelessWidget {
  final bool isFromBranchScreen; // Add a flag to determine the source

  // Constructor to receive the flag
  const PackageScreen({Key? key, this.isFromBranchScreen = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Conditionally remove the AppBar or keep it
      appBar: isFromBranchScreen
          ? null // No app bar when coming from BranchScreen
          : AppBar(
              title: Text("Package Deals"),
              automaticallyImplyLeading: !isFromBranchScreen, // Disable back button when coming from BranchScreen
            ),
      body: Center(
        child: Text('Packages Screen Content'),
      ),
      // Always show the floating action button
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: Icon(Icons.add),
        onPressed: () {
          // Navigate to AddDeals screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddDealsScreen()),
          );
        },
      ),
    );
  }
}
