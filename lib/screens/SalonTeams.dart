import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'Addteam.dart';
import 'TeamMemberDetails.dart';
import 'AssignUser.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

const Color _teamGold = Color(0xFF8B6500);
const Color _teamInk = Color(0xFF2D2926);
const Color _teamMuted = Color(0xFF756A61);
const Color _teamBorder = Color(0xFFE8DED6);

String _teamBranchLabel(Map<String, dynamic>? branch) {
  if (branch == null) return translateText('Select Branch');
  final branchName = branch['branchName']?.toString().trim() ?? '';
  if (branchName.isNotEmpty) return branchName;
  final salonName = branch['salonName']?.toString().trim() ?? '';
  if (salonName.isNotEmpty) return salonName;
  return translateText('Select Branch');
}

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
  final GlobalKey _branchSelectorKey = GlobalKey();
bool _hasTeamMembers = false;
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
              'addressSummary': _branchAddressSummary(b['address']),
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

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _branchAddressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    void push(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty ||
          text.toLowerCase() == 'null' ||
          parts.contains(text)) {
        return;
      }
      parts.add(text);
    }

    push(address['line1']);
    push(address['line2']);
    push(address['village']);
    push(address['district']);
    push(address['city']);
    push(address['state']);
    push(address['postalCode']);
    push(address['country']);
    return parts.join(', ');
  }

  // Future<List<dynamic>> _getTeamMembersByBranch(int branchId) async {
  //   try {
  //     final response = await ApiService.getTeamMembers(branchId);
  //     if (response['success'] == true) {
  //       return response['data'] ?? [];
  //     } else {
  //       return [];
  //     }
  //   } catch (e) {
  //     print("❌ Error fetching team members: $e");
  //     return [];
  //   }
  // }
Future<List<dynamic>> _getTeamMembersByBranch(int branchId) async {
  try {
    final response = await ApiService.getTeamMembers(branchId);

    final members = response['success'] == true && response['data'] is List
        ? List<dynamic>.from(response['data'] as List)
        : <dynamic>[];

    if (mounted && selectedBranchId == branchId) {
      final hasMembers = members.isNotEmpty;
      if (_hasTeamMembers != hasMembers) {
        setState(() {
          _hasTeamMembers = hasMembers;
        });
      }
    }

    return members;
  } catch (e) {
    print("❌ Error fetching team members: $e");

    if (mounted && selectedBranchId == branchId && _hasTeamMembers) {
      setState(() {
        _hasTeamMembers = false;
      });
    }

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

  // Future<void> _deleteMember(int userId) async {
  //   final branchId = selectedBranchId;
  //   if (branchId == null) return;
  //   final shouldDelete = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(translateText('Delete Team Member')),
  //       content: Text(
  //         translateText('Are you sure you want to delete this team member?'),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: Text(translateText('Cancel')),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: Text(
  //             translateText('Delete'),
  //             style: const TextStyle(color: Colors.red),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (shouldDelete != true) return;

  //   setState(() => _deletingMemberIds.add(userId));
  //   try {
  //     await ApiService().deleteTeamMember(
  //       branchId: branchId,
  //       userId: userId,
  //     );
  //     await _refreshTeamMembers();
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _deletingMemberIds.remove(userId));
  //     }
  //   }
  // }
  Future<void> _deleteMember(int userId) async {
  final branchId = selectedBranchId;

  if (branchId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateText('Please select a branch first'))),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(translateText('Delete Team Member')),
      content: Text(
        translateText(
          'Are you sure you want to delete this team member? This action cannot be undone.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(translateText('Cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            translateText('Delete'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() => _deletingMemberIds.add(userId));

  try {
    await ApiService().deleteTeamMember(
      branchId: branchId,
      userId: userId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translateText('Team member deleted successfully')),
      ),
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

  // void _pickBranch(Map<String, dynamic> branchOpt) {
  //   selectedBranch = branchOpt;
  //   selectedBranchId = _asInt(branchOpt['branchId']);
  //   if (selectedBranchId != null) {
  //     teamMembersFuture =
  //         _getTeamMembersByBranch(selectedBranchId!); // ✅ always by branchId
  //   } else {
  //     teamMembersFuture = null;
  //   }
  // }

void _pickBranch(Map<String, dynamic> branchOpt) {
  selectedBranch = branchOpt;
  selectedBranchId = _asInt(branchOpt['branchId']);
  _hasTeamMembers = false;

  if (selectedBranchId != null) {
    teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!);
  } else {
    teamMembersFuture = null;
  }
}
  Future<void> _openBranchPicker(
    List<Map<String, dynamic>> branches,
  ) async {
    if (branches.isEmpty) return;

    final selectorContext = _branchSelectorKey.currentContext;
    if (selectorContext == null) return;

    final selectorBox = selectorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (selectorBox == null || overlayBox == null) return;

    final selectorOffset = selectorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final top = selectorOffset.dy + selectorBox.size.height + 6;
    final maxHeight = (overlayBox.size.height - top - 18).clamp(160.0, 360.0);

    final selected = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              left: selectorOffset.dx,
              top: top,
              width: selectorBox.size.width,
              child: Material(
                color: Colors.white,
                elevation: 10,
                shadowColor: const Color(0x26000000),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _teamBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    itemCount: branches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = branches[index];
                      final isSelected = _asInt(item['branchId']) ==
                          _asInt(selectedBranch?['branchId']);
                      return InkWell(
                        onTap: () => Navigator.pop(dialogContext, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFF3E8D1),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: _teamGold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _teamBranchLabel(item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _teamInk,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    if ((item['addressSummary'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        (item['addressSummary'] ?? '')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _teamMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: _teamGold,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _pickBranch(selected));
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

  Future<void> _openAddMember() async {
    if (selectedBranch != null) {
      final refresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTeamScreen(
            branchId: selectedBranch!['branchId'],
            salonId: selectedBranch!['salonId'],
            salonName: selectedBranch!['salonName'],
          ),
        ),
      );
      if (!mounted) return;
      if (refresh == true) {
        setState(() {
          teamMembersFuture = _getTeamMembersByBranch(selectedBranchId!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translateText("Team member added successfully")),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translateText("Please select a branch first.")),
        ),
      );
    }
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
                  _TeamBranchSelector(
                    selectedBranch: null,
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _NoTeamMembersState(
                      onAddTeamMember: null,
                      message: translateText('No branches available'),
                    ),
                  ),
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
                  _TeamBranchSelector(
                    key: _branchSelectorKey,
                    selectedBranch: selectedBranch,
                    onTap: () => _openBranchPicker(branches),
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
                          return _NoTeamMembersState(
                            onAddTeamMember:
                                selectedBranch == null ? null : _openAddMember,
                          );
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
                                            style:
                                                const TextStyle(fontSize: 9.5),
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
    floatingActionButton: _hasTeamMembers
    ? FloatingActionButton.extended(
        onPressed: _openAddMember,
        label: Text(translateText("Add Member")),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFD0A244),
        foregroundColor: Colors.white,
      )
    : null,
    );
  }
}

class _TeamBranchSelector extends StatelessWidget {
  const _TeamBranchSelector({
    super.key,
    required this.selectedBranch,
    required this.onTap,
  });

  final Map<String, dynamic>? selectedBranch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final branchLabel = _teamBranchLabel(selectedBranch);
    final addressSummary =
        (selectedBranch?['addressSummary'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _teamBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      branchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teamInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (addressSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        addressSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _teamMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: onTap == null ? Colors.grey.shade400 : _teamGold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoTeamMembersState extends StatelessWidget {
  const _NoTeamMembersState({
    this.onAddTeamMember,
    this.message,
  });

  final VoidCallback? onAddTeamMember;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final messageText = message ?? translateText('No team members yet');

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final compact = availableHeight < 620;
        final imageHeight =
            (availableHeight * (compact ? 0.22 : 0.26)).clamp(118.0, 185.0);
        final quoteFontSize = compact ? 15.0 : 18.0;
        final quoteLineHeight = compact ? 1.35 : 1.45;
        final iconSize = compact ? 48.0 : 56.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 10 : 18, 0, 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/add team logo.png',
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: imageHeight,
                    width: double.infinity,
                    color: const Color(0xFFF5EFE8),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _teamGold,
                      size: 42,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 14 : 22),
              Text(
                '”',
                style: TextStyle(
                  color: const Color(0xFFD0A244),
                  fontSize: compact ? 28 : 34,
                  height: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 2 : 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '"Great things in business are\nnever done by one person.\nThey’re done by a team of\npeople."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6E6863),
                    fontSize: quoteFontSize,
                    height: quoteLineHeight,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Container(
                width: 58,
                height: 1,
                color: const Color(0xFFD0A244),
              ),
              SizedBox(height: compact ? 14 : 24),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _teamBorder),
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: _teamMuted,
                  size: compact ? 24 : 28,
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              Text(
                messageText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _teamInk,
                  fontSize: compact ? 19 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  translateText(
                    'Start building your world-class salon team. Add stylists, therapists, and coordinators to manage their schedules and performance.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _teamMuted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAddTeamMember != null) ...[
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onAddTeamMember,
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: Text(
                      translateText('Add Team Member'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0A244),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
