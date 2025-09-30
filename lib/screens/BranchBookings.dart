import 'package:flutter/material.dart';
import '../utils/api_service.dart';  // Correct import path for apiservices.dart

class BookingsScreen extends StatefulWidget {
  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> salonList = [];
  String? selectedSalon;

  @override
  void initState() {
    super.initState();
    fetchSalonList();
  }
Future<List<Map<String, dynamic>>> getSalonListApi() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final List salons = response['data'];
        return salons.map<Map<String, dynamic>>((salon) {
          return {
            'id': salon['id'],
            'name': salon['name'],
            'branches': salon['branches'],
          };
        }).toList();
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      debugPrint("Error fetching salon list: $e");
      return [];
    }
  }
  
  Future<void> fetchSalonList() async {
    try {
      final salons = await getSalonListApi(); // Get the list of salons
      setState(() {
        salonList = salons;
        selectedSalon = salons.isNotEmpty ? salons[0]['name'] : null; // Set the first salon as the selected one by default
      });
    } catch (e) {
      print('Error fetching salon list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide the back button
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: salonList.isEmpty
                ? CircularProgressIndicator()  // Show a loading indicator while fetching
                : DropdownButton<String>(
                    value: selectedSalon,
                    hint: Text('Select Salon'),
                    onChanged: (newValue) {
                      setState(() {
                        selectedSalon = newValue;
                      });
                    },
                    items: salonList.map((salon) {
                      return DropdownMenuItem<String>(
                        value: salon['name'],  // Show salon name in the dropdown
                        child: Text(salon['name']),
                      );
                    }).toList(),
                  ),
          ),
          Expanded(
            child: Center(
              child: Text('Your Bookings will appear here.'),
            ),
          ),
        ],
      ),
    );
  }
}
