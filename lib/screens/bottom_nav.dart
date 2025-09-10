import 'package:flutter/material.dart';
import 'home_screen.dart';  // Ensure HomeScreen is imported
import 'salons_screen.dart'; // Adjust the path as needed for Salons screen
import 'category_screen.dart'; // Adjust the path as needed for Category screen
import 'profile_screen.dart'; // Adjust the path as needed for Profile screen
import 'Bookings.dart'; // Adjust the path as needed for Bookings screen

class BottomNav extends StatefulWidget {
  final int tabIndex;

  BottomNav({required this.tabIndex});

  @override
  _BottomNavState createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  late int currentIndex;
  Color tabBarBackgroundColor = Colors.grey; // Default background color for tab bar

  @override
  void initState() {
    super.initState();
    currentIndex = widget.tabIndex;  // Set initial tab index from constructor
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the appBar here
      body: _getBodyForTab(currentIndex),  // Show content based on current tab index
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;  // Update the selected tab
            // Change background color of the tab bar depending on selected index
            tabBarBackgroundColor = index == 0 ? Colors.orange : Colors.grey; // Update color logic as needed
          });
        },
        backgroundColor: tabBarBackgroundColor,  // Set background color of the tab bar
        selectedItemColor: Colors.orange, // Custom Peach color
        unselectedItemColor: Colors.black, // Inactive tab color
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Salons'),  // Salons tab
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Category'),  // Category tab
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Bookings'),  // Category tab
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),  // Profile tab
        ],
      ),
    );
  }

  // Function to return body content based on selected tab index
  Widget _getBodyForTab(int index) {
    switch (index) {
      case 0:
        return HomeScreen();  // Show HomeScreen for tabIndex 0
      case 1:
        return SalonsScreen();  // Show SalonsScreen for tabIndex 1
      case 2:
        return CategoryScreen();  // Show CategoryScreen for tabIndex 2
      case 3:
        return BookingsScreen();  // Show ProfileScreen for tabIndex 3
      case 4:
        return ProfileScreen();  // Show ProfileScreen for tabIndex 3
      default:
        return HomeScreen();  // Default to HomeScreen if no valid index
    }
  }
}
