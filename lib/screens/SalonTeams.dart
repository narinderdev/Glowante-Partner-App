import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'Addteam.dart';
import 'TeamMemberDetails.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class TeamScreen extends StatefulWidget {
  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<Map<String, dynamic>>> branchOptionsFuture;

  int? selectedBranchId;
  Map<String, dynamic>? selectedBranch; // {branchId, branchName, salonId, salonName}
  Future<List<dynamic>>? teamMembersFuture;

  bool _autoPicked = false;

  @override
  void initState() {
    super.initState();
    branchOptionsFuture = _getBranchOptions(); // single list for the dropdown
  }

  /// Flattens salons->branches to branch options:
  /// [{branchId, branchName, salonId, salonName}]
  Future<List<Map<String, dynamic>>> _getBranchOptions() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final List salons = response['data'] ?? [];
        final List<Map<String, dynamic>> out = [];
        for (final s in salons) {
          final sid = s['id'];
          final sname = s['name'];
          final List branches = (s['branches'] as List? ?? []);
          for (final b in branches) {
            if (b == null) continue;
            out.add({
              'branchId': b['id'],
              'branchName': b['name'],
              'salonId': sid,
              'salonName': sname,
            });
          }
        }
        return out;
      } else {
        throw Exception("Failed to fetch salon list");
      }
    } catch (e) {
      print("❌ Error fetching salons/branches: $e");
      return [];
    }
  }

  Future<List<dynamic>> _getTeamMembersByBranch(int branchId) async {
    try {
      final response = await ApiService.getTeamMembers(branchId);
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

  void _pickBranch(Map<String, dynamic> branchOpt) {
    selectedBranch = branchOpt;
    selectedBranchId = branchOpt['branchId'] as int?;
    if (selectedBranchId != null) {
      teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!); // ✅ always by branchId
    } else {
      teamMembersFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          translateText('Team Members'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: branchOptionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: null,
                    items: const <DropdownMenuItem<int>>[],
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: translateText("Branch"),
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: translateText("No branches available"),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  Expanded(child: Center(child: Text(translateText("No branches available")))),
                ],
              );
            } else {
              final branches = snapshot.data!;

              // ✅ Auto-pick first branch exactly once
              if (!_autoPicked && branches.isNotEmpty) {
                _autoPicked = true;
                _pickBranch(branches.first);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ ONE dropdown: "Salon — Branch"
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedBranchId,
                    items: branches
                        .map((b) => DropdownMenuItem<int>(
                              value: b['branchId'] as int,
                              child: Text(
                                "${b['branchName']}",
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final picked = branches.firstWhere((b) => b['branchId'] == value);
                      setState(() {
                        _pickBranch(picked);
                        print("Picked Branch -> branchId=${picked['branchId']} "
                            "branchName=${picked['branchName']} | salonId=${picked['salonId']} salonName=${picked['salonName']}");
                      });
                    },
                    decoration: InputDecoration(
                      labelText: translateText("Salon"),
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: translateText("Select branch"),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.starColor));
                        } else if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(child: Text(translateText("No team members found")));
                        } else {
                          final members = snapshot.data!;
                          return GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.7,
                            ),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final m = members[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/image.png',
                                        height: 40,
                                        width: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => SizedBox(
                                          height: 110,
                                          child: Center(child: Icon(Icons.person, size: 48, color: Colors.grey)),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${m['firstName']} ${m['lastName'] ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (m['roles'] != null && m['roles'].isNotEmpty)
                                            ? m['roles'][0]['label']
                                            : "Staff",
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.work, size: 16, color: AppColors.starColor),
                                          const SizedBox(width: 4),
                                          Text(translateText("2 year+ Experience"), style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.star, size: 16, color: AppColors.starColor),
                                          const SizedBox(width: 4),
                                          Text(translateText("4.5 (43)"), style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TeamMemberDetails(
                                                member: m,
                                                salons: null, // optional; not needed if you only use branchId
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.starColor,
                                          foregroundColor: AppColors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(translateText("View Member")),
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
        onPressed: () async {
          if (selectedBranch != null) {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTeamScreen(
                  // ✅ your flows can rely purely on branchId
                  branchId: selectedBranch!['branchId'],
                  // pass salon info only if your AddTeamScreen UI wants to show it:
                  salonId: selectedBranch!['salonId'],
                  salonName: selectedBranch!['salonName'],
                ),
              ),
            );
            if (refresh == true) {
              setState(() {
                teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!); // ✅ refresh by branch
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(translateText("Team member added successfully"))),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(translateText("Please select a branch first."))),
            );
          }
        },
        label: Text(translateText("Add Member")),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.starColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
