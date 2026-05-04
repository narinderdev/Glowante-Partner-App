import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'Addteam.dart';
import 'TeamMemberDetails.dart';
import 'AssignUser.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class TeamScreen extends StatefulWidget {
  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<Map<String, dynamic>>> branchOptionsFuture;

  int? selectedBranchId;
  Map<String, dynamic>?
      selectedBranch; // {branchId, branchName, salonId, salonName}
  Future<List<dynamic>>? teamMembersFuture;
  List<Map<String, dynamic>> _salons = const [];

  bool _autoPicked = false;
  final Set<int> _statusUpdatingIds = {};
  final Set<int> _deletingMemberIds = {};

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
        _salons = salons
            .whereType<Map>()
            .map((salon) => Map<String, dynamic>.from(salon))
            .toList();
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

  Future<void> _refreshTeamMembers() async {
    if (selectedBranchId == null || !mounted) return;
    setState(() {
      teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!);
    });
  }

  Future<void> _toggleMemberActive(int userId, bool makeActive) async {
    final branchId = selectedBranchId;
    if (branchId == null) return;
    setState(() => _statusUpdatingIds.add(userId));
    try {
      await ApiService().setTeamMemberActive(
        branchId: branchId,
        userId: userId,
        active: makeActive,
      );
      await _refreshTeamMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _statusUpdatingIds.remove(userId));
      }
    }
  }

  Future<void> _deleteMember(int userId) async {
    final branchId = selectedBranchId;
    if (branchId == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translateText('Delete Team Member')),
        content: Text(
          translateText('Are you sure you want to delete this team member?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(translateText('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              translateText('Delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    setState(() => _deletingMemberIds.add(userId));
    try {
      await ApiService().deleteTeamMember(
        branchId: branchId,
        userId: userId,
      );
      await _refreshTeamMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingMemberIds.remove(userId));
      }
    }
  }

  void _pickBranch(Map<String, dynamic> branchOpt) {
    selectedBranch = branchOpt;
    selectedBranchId = branchOpt['branchId'] as int?;
    if (selectedBranchId != null) {
      teamMembersFuture =
          _getTeamMembersByBranch(selectedBranchId!); // ✅ always by branchId
    } else {
      teamMembersFuture = null;
    }
  }

  bool _memberHasAssignments(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    return rawAssignments is List && rawAssignments.isNotEmpty;
  }

  String? _salonNameForBranchId(int branchId) {
    for (final salon in _salons) {
      final salonName = (salon['name'] ?? '').toString().trim();
      final branches = salon['branches'] as List? ?? const [];
      for (final branch in branches) {
        if (branch is! Map) continue;
        final rawId = branch['id'];
        final id = rawId is int
            ? rawId
            : rawId is num
                ? rawId.toInt()
                : int.tryParse('${rawId ?? ''}');
        if (id == branchId) {
          return salonName;
        }
      }
    }
    return null;
  }

  String _memberAssignedSalonLabel(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];
    if (rawAssignments is! List || rawAssignments.isEmpty) {
      return '';
    }

    final salonNames = <String>{};
    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final rawBranchId = branch is Map ? branch['id'] : assignment['branchId'];
      final branchId = rawBranchId is int
          ? rawBranchId
          : rawBranchId is num
              ? rawBranchId.toInt()
              : int.tryParse('${rawBranchId ?? ''}');
      if (branchId == null) continue;
      final salonName = _salonNameForBranchId(branchId);
      if (salonName != null && salonName.isNotEmpty) {
        salonNames.add(salonName);
      }
    }

    if (salonNames.isNotEmpty) {
      return salonNames.join(', ');
    }

    return (selectedBranch?['salonName'] ?? '').toString().trim();
  }

  Widget _buildAssignButtonChild(Map<String, dynamic> member) {
    if (!_memberHasAssignments(member)) {
      return Text(translateText("Assign"));
    }

    final assignedSalonLabel = _memberAssignedSalonLabel(member);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          translateText("Assigned to"),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (assignedSalonLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            assignedSalonLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, height: 1.15),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Team Members'),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                      child: Center(
                          child: Text(translateText("No branches available")))),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final picked =
                          branches.firstWhere((b) => b['branchId'] == value);
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.starColor));
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text("Error: ${snapshot.error}"));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                              child:
                                  Text(translateText("No team members found")));
                        } else {
                          final members = snapshot.data!;
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isCompactPhone = screenWidth < 390;
                          final crossAxisCount = screenWidth >= 1024 ? 3 : 2;
                          final cardHeight = isCompactPhone ? 390.0 : 370.0;
                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: cardHeight,
                            ),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final m = members[index];
                              final userId = (m['id'] as num?)?.toInt() ?? 0;
                              final isActive = m['active'] != false;
                              final isStatusUpdating =
                                  _statusUpdatingIds.contains(userId);
                              final isDeleting =
                                  _deletingMemberIds.contains(userId);
                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        child: (m['profilePictureUrl'] !=
                                                    null &&
                                                m['profilePictureUrl']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? Image.network(
                                                m['profilePictureUrl'],
                                                height: 44,
                                                width: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Image.asset(
                                                  'assets/images/image.png',
                                                  height: 44,
                                                  width: 44,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Image.asset(
                                                'assets/images/image.png',
                                                height: 44,
                                                width: 44,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${m['firstName']} ${m['lastName'] ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (m['roles'] != null &&
                                                m['roles'].isNotEmpty)
                                            ? m['roles'][0]['label']
                                            : "Staff",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.work,
                                            size: 13,
                                            color: AppColors.starColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              translateText(
                                                  "2 year+ Experience"),
                                              style: const TextStyle(
                                                  fontSize: 9.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 13,
                                            color: AppColors.starColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            translateText("4.5 (43)"),
                                            style: const TextStyle(fontSize: 9.5),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: (isDeleting ||
                                                      isStatusUpdating)
                                                  ? null
                                                  : () async {
                                                      final refresh =
                                                          await Navigator.push<
                                                              bool>(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              AddTeamScreen(
                                                            branchId:
                                                                selectedBranch![
                                                                    'branchId'],
                                                            salonId:
                                                                selectedBranch![
                                                                    'salonId'],
                                                            salonName:
                                                                selectedBranch![
                                                                    'salonName'],
                                                            isEdit: true,
                                                            initialMember: Map<
                                                                String,
                                                                dynamic>.from(
                                                              m,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      if (refresh == true) {
                                                        await _refreshTeamMembers();
                                                      }
                                                    },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: AppColors.starColor,
                                                ),
                                                foregroundColor:
                                                    AppColors.starColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                minimumSize:
                                                    const Size.fromHeight(34),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                textStyle: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              child: Text(
                                                translateText("Edit"),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: (isDeleting ||
                                                      isStatusUpdating)
                                                  ? null
                                                  : () => _deleteMember(
                                                        userId,
                                                      ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Colors.red,
                                                ),
                                                foregroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                minimumSize:
                                                    const Size.fromHeight(34),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                textStyle: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              child: isDeleting
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.red,
                                                      ),
                                                    )
                                                  : Text(
                                                      translateText("Delete"),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed:
                                              (isDeleting || isStatusUpdating)
                                                  ? null
                                                  : () => _toggleMemberActive(
                                                        userId,
                                                        !isActive,
                                                      ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: AppColors.starColor,
                                            ),
                                            foregroundColor:
                                                AppColors.starColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            minimumSize:
                                                const Size.fromHeight(34),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            textStyle: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: isStatusUpdating
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  translateText(
                                                    isActive
                                                        ? "Deactivate"
                                                        : "Activate",
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              (isDeleting || isStatusUpdating)
                                                  ? null
                                                  : () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              TeamMemberDetails(
                                                            member: m,
                                                            salons: null,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.starColor,
                                            foregroundColor: AppColors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            minimumSize:
                                                const Size.fromHeight(34),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            textStyle: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: Text(
                                            translateText("View Member"),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: (isDeleting ||
                                                  isStatusUpdating ||
                                                  selectedBranch == null ||
                                                  _salons.isEmpty)
                                              ? null
                                              : () async {
                                                  final assigned =
                                                      await Navigator.push<
                                                          bool>(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AssignUserScreen(
                                                        member: Map<String,
                                                            dynamic>.from(
                                                          m,
                                                        ),
                                                        salons: _salons,
                                                        salonId:
                                                            selectedBranch![
                                                                'salonId'],
                                                      ),
                                                    ),
                                                  );
                                                  if (assigned == true) {
                                                    await _refreshTeamMembers();
                                                  }
                                                },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: AppColors.starColor,
                                            ),
                                            foregroundColor:
                                                AppColors.starColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            minimumSize:
                                                const Size.fromHeight(36),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            textStyle: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: _buildAssignButtonChild(
                                            Map<String, dynamic>.from(m),
                                          ),
                                        ),
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
            if (!context.mounted) return;
            if (refresh == true) {
              setState(() {
                teamMembersFuture = _getTeamMembersByBranch(
                    selectedBranchId!); // ✅ refresh by branch
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(translateText("Team member added successfully"))),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(translateText("Please select a branch first."))),
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
