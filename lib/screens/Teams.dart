import 'package:flutter/material.dart';
import '../utils/api_service.dart'; // 👈 make sure this has getSalonUsersApi defined
import 'Addteam.dart';
import 'TeamMemberDetails.dart';

class TeamScreen extends StatefulWidget {
  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<Map<String, dynamic>>> salonsList;
  int? selectedBranchId;
  Map<String, dynamic>? selectedBranch;
  Future<List<dynamic>>? teamMembersFuture;

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

  Future<List<dynamic>> getTeamMembers(int salonId) async {
    try {
     final response = await ApiService().getSalonUsersApi(salonId);
// 👈 calls your API
      if (response['success'] == true) {
        return response['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print("❌ Error fetching team members: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Team Members")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text("No salons found"));
            } else {
              final salons = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<int>(
                    isExpanded: true,
                    value: selectedBranchId,
                    hint: Text("Select Salon Branch"),
                    items: salons.expand((salon) {
                      final branches = salon['branches'] as List;
                      return branches.map<DropdownMenuItem<int>>((branch) {
                        return DropdownMenuItem(
                          value: branch['id'],
                          child: Text(
                            branch['name'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList();
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBranchId = value;
                        if (value != null) {
                          final salon = salons.firstWhere((s) =>
                              (s['branches'] as List)
                                  .any((b) => b['id'] == value));
                          final branch = (salon['branches'] as List)
                              .firstWhere((b) => b['id'] == value);
                          selectedBranch = {
                            'salonId': salon['id'],
                            'branchId': branch['id'],
                            'branchName': branch['name'],
                          };

                          // fetch team members when salon branch changes
                          teamMembersFuture = getTeamMembers(salon['id']);

                          print("Selected SalonId: ${selectedBranch!['salonId']} "
                              "| BranchId: ${selectedBranch!['branchId']} "
                              "| BranchName: ${selectedBranch!['branchName']}");
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: teamMembersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(child: Text("No team members found"));
                        } else {
                          final members = snapshot.data!;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.7,
                            ),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final m = members[index];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                     Image.asset(
                                      'assets/images/image.png',
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                        height: 110,
                                        child: Center(child: Icon(Icons.person, size: 48, color: Colors.grey)),
                                      ),
                                    ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${m['firstName']} ${m['lastName'] ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (m['roles'] != null &&
                                                m['roles'].isNotEmpty)
                                            ? m['roles'][0]['label']
                                            : "Staff",
                                        style: TextStyle(
                                            color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.work,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text("2 year+ Experience",
                                              style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.star,
                                              size: 16, color: Colors.orange),
                                          SizedBox(width: 4),
                                          Text("4.5 (43)",
                                              style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const Spacer(),
                                    ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamMemberDetails(member: m),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange[400],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  child: const Text("View Member"),
),

                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    final int? branchId = selectedBranch?['branchId']; // ✅ extract branchId
    if (branchId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTeamScreen(branchId: branchId), // ✅ pass branchId
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a branch first."),
        ),
      );
    }
  },
  label: const Text("Add Member"),
  icon: const Icon(Icons.add),
  backgroundColor: Colors.orange[300],
),

    );
  }
}
