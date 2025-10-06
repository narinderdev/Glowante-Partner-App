import 'package:flutter/material.dart';
import '../utils/api_service.dart'; // make sure this has getSalonUsersApi(salonId)
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
  late Future<List<Map<String, dynamic>>> salonsList;
  int? selectedSalonId;
  Map<String, dynamic>? selectedSalon;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(translateText('Team Members'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          future: salonsList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
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
                      labelText: translateText("Salon"),
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: translateText("No salons available"),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: Center(child: Text(translateText("No salons available"))),
                  ),
                ],
              );
            } else {
              final salons = snapshot.data!;

              // Auto-pick the first salon once
              if (!_autoPicked && selectedSalonId == null && salons.isNotEmpty) {
                _autoPicked = true;
                selectedSalonId = salons.first['id'] as int;
                selectedSalon = {
                  'salonId': salons.first['id'],
                  'salonName': salons.first['name'],
                };
                teamMembersFuture = getTeamMembers(selectedSalonId!);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Salon-only dropdown
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedSalonId,
                    items: salons
                        .map<DropdownMenuItem<int>>(
                          (s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(
                              s['name'],
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSalonId = value;
                        if (value != null) {
                          final picked =
                              salons.firstWhere((s) => s['id'] == value);
                          selectedSalon = {
                            'salonId': picked['id'],
                            'salonName': picked['name'],
                          };
                          teamMembersFuture = getTeamMembers(value);

                          print(
                            "Selected SalonId: ${picked['id']} | SalonName: ${picked['name']}",
                          );
                        }
                      });
                    },
                    decoration: InputDecoration(
                      labelText: translateText("Salon"),
                      labelStyle: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: translateText("Select salon"),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    icon: Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Colors.white,
                  ),

                  SizedBox(height: 16),

                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: teamMembersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text("Error: ${snapshot.error}"),
                          );
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(translateText("No team members found")),
                          );
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/image.png',
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => SizedBox(
                                          height: 110,
                                          child: Center(
                                            child: Icon(
                                              Icons.person,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "${m['firstName']} ${m['lastName'] ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        (m['roles'] != null &&
                                                m['roles'].isNotEmpty)
                                            ? m['roles'][0]['label']
                                            : "Staff",
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.work, size: 16, color: AppColors.starColor),
                                          SizedBox(width: 4),
                                          Text(translateText("2 year+ Experience"), style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.star, size: 16, color: AppColors.starColor),
                                          SizedBox(width: 4),
                                          Text(translateText("4.5 (43)"), style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const Spacer(),
                                      // View Member
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TeamMemberDetails(
                                                member: m,
                                                salons: salons,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.starColor,
                                          foregroundColor: AppColors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
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
      // Add Member
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (selectedSalon != null) {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTeamScreen(
                  salonId: selectedSalon!['salonId'],
                  salonName: selectedSalon!['salonName'], // ✅ REQUIRED by your AddTeamScreen
                ),
              ),
            );

            if (refresh == true) {
              setState(() {
                teamMembersFuture = getTeamMembers(selectedSalon!['salonId']);
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(translateText("Please select a salon first."))),
            );
          }
        },
        label: Text(translateText("Add Member")),
        icon: Icon(Icons.add),
        backgroundColor: AppColors.starColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
