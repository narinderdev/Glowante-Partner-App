import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class TeamMemberScreen extends StatefulWidget {
  final Map<String, dynamic> branchDetails;

  const TeamMemberScreen({super.key, required this.branchDetails});

  @override
  State<TeamMemberScreen> createState() => _TeamMemberScreenState();
}

class _TeamMemberScreenState extends State<TeamMemberScreen> {
  Future<Map<String, dynamic>>? _teamMembersFuture;

  @override
  void initState() {
    super.initState();
    _saveBranchId();
    final branchId = _currentBranchId;
    if (branchId != null) {
      _teamMembersFuture = ApiService.getTeamMembers(branchId);
    }
  }

  int? get _currentBranchId => _parseBranchId(
        widget.branchDetails['id'] ?? widget.branchDetails['branchId'],
      );

  int? _parseBranchId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _saveBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final int? branchId = _currentBranchId;

    if (branchId != null) {
      await prefs.setInt('branchId', branchId);
      debugPrint("✅ Branch ID saved: $branchId");
    } else {
      debugPrint("⚠️ Branch ID is null, not saved.");
    }
  }

  Future<void> _refreshTeamMembers() async {
    final branchId = _currentBranchId;
    if (branchId == null || !mounted) return;

    final future = ApiService.getTeamMembers(branchId);
    setState(() {
      _teamMembersFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final int? branchId = _currentBranchId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            children: [
              // SizedBox(height: 40),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Become a stylist?',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                 if (branchId != null) {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (_) => AddStylistScreen(branchId: branchId!),
//     ),
//   );
// } else {
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text('Branch ID missing. Cannot add stylist.')),
//   );
// }

//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                     ),
//                     child: Text('Become Stylist',
//                         style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
//                   ),
//                 ],
//               ),
              // SizedBox(height: 40),

              // Text("Branch Id: ${branchId ?? '—'}"),
              SizedBox(height: 16),

              // If branchId is missing, show a friendly message instead of calling the API with null
              if (branchId == null)
                Expanded(
                  child: Center(
                    child: Text(
                      translateText(
                          'Branch ID missing. Please go back and select a branch again.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                // ✅ Expanded wraps the FutureBuilder (so GridView can scroll)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshTeamMembers,
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _teamMembersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const _RefreshableBranchTeamState(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _RefreshableBranchTeamState(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData ||
                            snapshot.data!['success'] != true) {
                          return _RefreshableBranchTeamState(
                            child: Text(
                              translateText('Failed to load team members'),
                            ),
                          );
                        }

                        final List<dynamic> teamMembers =
                            snapshot.data!['data'] ?? [];
                        if (teamMembers.isEmpty) {
                          return _RefreshableBranchTeamState(
                            child: Text(translateText('No team members yet')),
                          );
                        }

                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: teamMembers.length,
                          itemBuilder: (context, index) {
                            final member =
                                teamMembers[index] as Map<String, dynamic>;
                            final String firstName =
                                (member['firstName'] ?? '').toString().trim();
                            final String lastName =
                                (member['lastName'] ?? '').toString().trim();
                            final String fullName = [firstName, lastName]
                                .where((s) => s.isNotEmpty)
                                .join(' ');

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
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
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      fullName.isNotEmpty
                                          ? fullName
                                          : 'No Name',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      translateText('Hair Dresser'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      translateText('1 year+ Experience'),
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          translateText('4.4 (43)'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: Colors.orange,
      //   onPressed: () {
      //     final int? idForNav = branchId;
      //     if (idForNav != null) {
      //       Navigator.push(context, MaterialPageRoute(builder: (_) => AddTeamScreen(branchId: idForNav)));
      //     } else {
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         SnackBar(content: Text('Please select a branch first.')),
      //       );
      //     }
      //   },
      //   child: Icon(Icons.add,color: Colors.white,),
      // ),
    );
  }
}

class _RefreshableBranchTeamState extends StatelessWidget {
  const _RefreshableBranchTeamState({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: child),
        ),
      ],
    );
  }
}
