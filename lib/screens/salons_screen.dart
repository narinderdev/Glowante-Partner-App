import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'package:intl/intl.dart';
import '../screens/branch_screen.dart';
import '../screens/add_branch_screen.dart';
import '../screens/add_salon_screen.dart';
import '../Viewmodels/BranchViewModel.dart';
import '../screens/Package.dart';
class SalonsScreen extends StatefulWidget {
  @override
  _SalonsScreenState createState() => _SalonsScreenState();
}

class _SalonsScreenState extends State<SalonsScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;
  int? expandedIndex; // 👈 Track expanded salon index
  bool fabExpanded = false; // 👈 Track FAB state

  @override
  void initState() {
    super.initState();
    salonsList = getSalonListApi();
  }

  Future<List<Map<String, dynamic>>> getSalonListApi() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        List salons = response['data'];
        return salons.map((salon) {
          return {
            'id': salon['id'],
            'name': salon['name'],
            'branches': salon['branches'],
            'imageUrl': salon['branches'] != null &&
                        salon['branches'].isNotEmpty &&
                        salon['branches'][0]['imageUrl'] != null
                ? salon['branches'][0]['imageUrl']
                : null,
          };
        }).toList();
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("Error fetching salon list: $e");
      return [];
    }
  }

  void _goToAddSalon() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSalonScreen()),
    ).then((_) {
      setState(() {
        salonsList = getSalonListApi();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Salons'),
        actions: [
          // + icon at the top-right of the AppBar to add salon
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _goToAddSalon, // Navigate to AddSalonScreen
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>( 
        future: salonsList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: ElevatedButton.icon(
                onPressed: _goToAddSalon,
                icon: Icon(Icons.add),
                label: Text("Add Salon"),
              ),
            );
          } else {
            final salons = snapshot.data!;
            return ListView.builder(
              itemCount: salons.length,
              itemBuilder: (context, index) {
                final salon = salons[index];
                final isExpanded = expandedIndex == index;

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              expandedIndex = isExpanded ? null : index; // toggle
                            });
                          },
                          child: Row(
                            children: [
                              // Salon image
                              if (salon['imageUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    salon['imageUrl'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Icon(Icons.store, size: 40, color: Colors.grey),
                              SizedBox(width: 12),

                              // Salon name
                              Expanded(
                                child: Text(
                                  salon['name'],
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),

                              // Expand/Collapse icon
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        if (isExpanded) ...[
                          // Display branches under each salon above the "Add Branch" section
                          ...salon['branches'].map<Widget>((branch) {
                            return Column(
                              children: [
                                // Branch details
                                ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                                  title: Text(branch['name']),
                                ),

                                // Row for Address and View Branch button
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      // Address in two lines
                                      Expanded(
                                        flex: 1, // Address takes half of the space
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Line 1 of the address
                                            Text(
                                              '${branch['address']['line1']}',
                                              style: TextStyle(fontSize: 12), // Smaller font size
                                              maxLines: 1, // Allow this text to be on one line
                                            ),
                                            // Line 2 of the address (city, state, postal code)
                                            Text(
                                              '${branch['address']['state']} ${branch['address']['postalCode']}',
                                              style: TextStyle(fontSize: 12), // Smaller font size
                                              maxLines: 1, // Allow this text to be on one line
                                            ),
                                          ],
                                        ),
                                      ),

                                      // View Branch button takes the other half
                                      SizedBox(width: 10), // Space between address and button
                                  ElevatedButton(
  onPressed: () async {
    try {
      // Create an instance of ApiService and fetch branch details
      final branchDetails = await ApiService().getBranchDetail(branch['id']);

      print("Navigating to BranchScreen with branch details: $branchDetails, salonId: ${salon['id']}");

      // Navigate to BranchScreen and pass the branch details
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => BranchScreen(
      salonId: salon['id'], // Pass salon ID
     branchDetails: branchDetails['data'], // Pass the branch details
    ),
  ),
);

    } catch (e) {
      print("Error fetching branch details: $e");
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange, // Orange background color
    foregroundColor: Colors.white, // White text color
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Smaller button
    textStyle: TextStyle(fontSize: 10), // Smaller text
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8), // Slightly curved corners
    ),
  ),
  child: Text("View Branch"),
),
                                    ],
                                  ),
                                ),
                                Divider(), // Divider between branches
                              ],
                            );
                          }).toList(),

                          // Add Branch section
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddBranchScreen(salonId: salon['id']),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "+ Add Branch",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),

      // Floating Action Button with menu
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fabExpanded)
            // Wrap all FAB items in a white container with reduced width
            Container(
              width: 70, // Decrease the width here (make it smaller)
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _fabMenuItem(Icons.group, "Team"),
                  SizedBox(height: 8),
                  _fabMenuItem(Icons.local_offer, "Deals"),
                  SizedBox(height: 8),
                  _fabMenuItem(Icons.card_giftcard, "Packages"),
                  SizedBox(height: 16),
                ],
              ),
            ),
          SizedBox(height: 16),  // Extra space before the + icon
          FloatingActionButton(
            backgroundColor: Colors.orange,
            child: Icon(fabExpanded ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                fabExpanded = !fabExpanded;
              });
            },
          ),
        ],
      ),
    );
  }
Widget _fabMenuItem(IconData icon, String label) {
  return Container(
    margin: EdgeInsets.only(bottom: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          mini: true,
          backgroundColor: Colors.orange,
          child: Icon(icon, color: Colors.white),
          onPressed: () {
            print("$label clicked");

            // Add navigation logic based on the label
            if (label == "Packages") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PackageScreen()), // Navigate to PackageScreen
              );
            } else {
              // Handle other cases for "Team" and "Deals" if needed
            }
          },
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
            fontSize: 10, // Decreased font size here
          ),
        ),
      ],
    ),
  );
}

}
