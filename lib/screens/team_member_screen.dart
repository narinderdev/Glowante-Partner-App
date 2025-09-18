import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AddTeam.dart';
import 'AddStylist.dart';
import '../utils/api_service.dart';

class TeamMemberScreen extends StatefulWidget {
  final Map<String, dynamic> branchDetails;

  const TeamMemberScreen({Key? key, required this.branchDetails}) : super(key: key);

  @override
  State<TeamMemberScreen> createState() => _TeamMemberScreenState();
}

class _TeamMemberScreenState extends State<TeamMemberScreen> {
  @override
  void initState() {
    super.initState();
    _saveBranchId();
  }

  int? _parseBranchId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _saveBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final int? branchId = _parseBranchId(
      widget.branchDetails['id'] ?? widget.branchDetails['branchId'],
    );

    if (branchId != null) {
      await prefs.setInt('branchId', branchId);
      debugPrint("✅ Branch ID saved: $branchId");
    } else {
      debugPrint("⚠️ Branch ID is null, not saved.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? branchId = _parseBranchId(
      widget.branchDetails['id'] ?? widget.branchDetails['branchId'],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Become a stylist?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  ElevatedButton(
                    onPressed: () {
                if (branchId != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddStylistScreen(branchId: branchId!),
    ),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Branch ID missing. Cannot add stylist.')),
  );
}


                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Become Stylist',
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // const SizedBox(height: 40),

              // Text("Branch Id: ${branchId ?? '—'}"),
              const SizedBox(height: 16),

              // If branchId is missing, show a friendly message instead of calling the API with null
              if (branchId == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Branch ID missing. Please go back and select a branch again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                // ✅ Expanded wraps the FutureBuilder (so GridView can scroll)
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ApiService.getTeamMembers(branchId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!['success'] != true) {
                        return const Center(child: Text('Failed to load team members'));
                      }

                      final List<dynamic> teamMembers = snapshot.data!['data'] ?? [];
                      if (teamMembers.isEmpty) {
                        return const Center(child: Text('No team members yet'));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: teamMembers.length,
                        itemBuilder: (context, index) {
                          final member = teamMembers[index] as Map<String, dynamic>;
                          final String firstName = (member['firstName'] ?? '').toString().trim();
                          final String lastName = (member['lastName'] ?? '').toString().trim();
                          final String fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      'assets/images/image.png',
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                        height: 110,
                                        child: Center(child: Icon(Icons.person, size: 48, color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    fullName.isNotEmpty ? fullName : 'No Name',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Hair Dresser', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('1 year+ Experience', style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.star, color: Colors.orange, size: 16),
                                      SizedBox(width: 4),
                                      Text('4.4 (43)',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {
          final int? idForNav = branchId;
          if (idForNav != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddTeamScreen(branchId: idForNav)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a branch first.')),
            );
          }
        },
        child: const Icon(Icons.add,color: Colors.white,),
      ),
    );
  }
}
