import 'package:flutter/material.dart';
import 'services_screen.dart';
import 'team_member_screen.dart';
import 'reviews_screen.dart';
import 'about_screen.dart'; 
import 'Package.dart';

class BranchScreen extends StatelessWidget {
  final int salonId;
  final Map<String, dynamic> branchDetails;

  const BranchScreen({Key? key, required this.salonId, required this.branchDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final branchDetails = this.branchDetails;
    final imageUrl = branchDetails['imageUrl'];
    final description = branchDetails['description'] ?? 'No description available';

    return DefaultTabController(
      length: 5, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text('Branch Details'),
        ),
        body: Column(
          children: [
            // Image with location
            Stack(
              children: [
                // Image (50% height)
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  width: MediaQuery.of(context).size.width,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height * 0.5, fit: BoxFit.cover)
                      : Icon(Icons.store, size: 70, color: Colors.grey),
                ),
                // Location at the bottom left of the image
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branchDetails['name'] ?? 'Branch Name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.white, size: 18), // Black location icon
                          SizedBox(width: 2), // Space between icon and address
                          Text('${branchDetails['address']['line1'] ?? 'No address'}', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Scrollable TabBar below the image
            Container(
              color: Colors.white, // Optional: Set a background color for the TabBar
              child: TabBar(
                isScrollable: true, // Enable horizontal scrolling for tabs
                tabs: [
                  Tab(text: 'Services'),
                  Tab(text: 'Deals'),
                  Tab(text: 'Team Member'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'About'),
                ],
              ),
            ),
            // TabBarView below the TabBar
            Expanded(
              child: TabBarView(
                children: [
                  ServicesScreen(branchId: branchDetails['id']), 
                  PackageScreen(isFromBranchScreen: true),  // Pass flag to PackageScreen
                  TeamMemberScreen(branchDetails: branchDetails), // Team Member Tab
                  ReviewsScreen(),  // Reviews Tab
                  AboutScreen(branchDetails: branchDetails), // About Tab
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
