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

  bool _autoPicked = false; // ensure we only auto-pick once

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
      final response = await ApiService().getSalonUsersApi(salonId); // 👈 calls your API
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
      // Header: bold + white
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Team Members",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No salons found"));
            } else {
              final salons = snapshot.data!;

              // Auto-pick first available branch once
              if (!_autoPicked && selectedBranchId == null) {
                int? firstSalonId;
                Map<String, dynamic>? firstBranch;
                for (final s in salons) {
                  final branches = (s['branches'] as List?) ?? const [];
                  if (branches.isNotEmpty) {
                    firstSalonId = s['id'] as int;
                    firstBranch = branches.first as Map<String, dynamic>;
                    break;
                  }
                }
                if (firstBranch != null && firstSalonId != null) {
                  _autoPicked = true;
                  selectedBranchId = firstBranch['id'] as int;
                  selectedBranch = {
                    'salonId': firstSalonId,
                    'branchId': firstBranch['id'],
                    'branchName': firstBranch['name'],
                  };
                  teamMembersFuture = getTeamMembers(firstSalonId);
                } else {
                  // No branches in any salon; keep dropdown disabled with hint
                  _autoPicked = true;
                }
              }

              // Flatten all branches to build dropdown items
              final List<Map<String, dynamic>> allBranches = salons
                  .expand<Map<String, dynamic>>((s) => ((s['branches'] as List?) ?? const [])
                      .map((b) => {
                            'branchId': b['id'],
                            'branchName': b['name'],
                            'salonId': s['id'],
                            'salonName': s['name'],
                          }))
                  .toList();

              final bool hasAnyBranch = allBranches.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Styled dropdown
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: hasAnyBranch ? selectedBranchId : null,
                    items: hasAnyBranch
                        ? allBranches
                            .map<DropdownMenuItem<int>>(
                              (b) => DropdownMenuItem<int>(
                                value: b['branchId'] as int,
                                child: Text(
                                  "${b['salonName']} • ${b['branchName']}",
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                            .toList()
                        : const <DropdownMenuItem<int>>[],
                    onChanged: hasAnyBranch
                        ? (value) {
                            setState(() {
                              selectedBranchId = value;
                              if (value != null) {
                                final picked = allBranches.firstWhere(
                                    (b) => b['branchId'] == value);
                                selectedBranch = {
                                  'salonId': picked['salonId'],
                                  'branchId': picked['branchId'],
                                  'branchName': picked['branchName'],
                                };
                                teamMembersFuture =
                                    getTeamMembers(picked['salonId'] as int);

                                print(
                                    "Selected SalonId: ${selectedBranch!['salonId']} "
                                    "| BranchId: ${selectedBranch!['branchId']} "
                                    "| BranchName: ${selectedBranch!['branchName']}");
                              }
                            });
                          }
                        : null,
                    decoration: InputDecoration(
                      labelText: "Salon & Branch",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: hasAnyBranch
                          ? "Select salon branch"
                          : "No salon branches available",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Colors.white,
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: teamMembersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text("Error: ${snapshot.error}"));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text("No team members found"));
                        } else {
                          final members = snapshot.data!;
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
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
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                          height: 110,
                                          child: Center(
                                              child: Icon(Icons.person,
                                                  size: 48,
                                                  color: Colors.grey)),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${m['firstName']} ${m['lastName'] ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
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
                                        children: const [
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
                                        children: const [
                                          Icon(Icons.star,
                                              size: 16, color: Colors.black),
                                          SizedBox(width: 4),
                                          Text("4.5 (43)",
                                              style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const Spacer(),
                                      // View Member: black bg, white text
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  TeamMemberDetails(
                                                member: m,
                                                salons: salons,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
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
      // Add Member: black bg, white text
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (selectedBranch != null) {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTeamScreen(
                  branchId: selectedBranch!['branchId'],
                  salonId: selectedBranch!['salonId'],
                  branchName: selectedBranch!['branchName'],
                ),
              ),
            );

            if (refresh == true) {
              setState(() {
                teamMembersFuture =
                    getTeamMembers(selectedBranch!['salonId']);
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select a branch first.")),
            );
          }
        },
        label: const Text("Add Member"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    );
  }
}
