import 'package:flutter/material.dart';
import 'select_services_AssignUser.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../widgets/multi_step_flow_header.dart';

class Branch {
  final int id;
  final int salonId;
  final String name;
  final String address;

  Branch({
    required this.id,
    required this.salonId,
    required this.name,
    required this.address,
  });
}

class AssignUserScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> salons;
  final int salonId; // filter branches by this salonId

  late final List<Branch> branches;

  AssignUserScreen({
    Key? key,
    required this.member,
    required this.salons,
    required this.salonId,
  }) : super(key: key) {
    // Build Branch list from salons and filter by salonId
    branches = salons
        .expand((salon) {
          final id = salon['id'] ?? 0;
          final salonBranches = salon['branches'] as List? ?? [];
          return salonBranches.map((branch) {
            return Branch(
              id: branch['id'] ?? 0,
              salonId: id,
              name: branch['name'] ?? '',
              address:
                  "${branch['address']?['line1'] ?? ''}, ${branch['address']?['city'] ?? ''}",
            );
          });
        })
        .where((branch) => branch.salonId == salonId)
        .toList();
  }

  @override
  State<AssignUserScreen> createState() => _AssignUserScreenState();
}

class _AssignUserScreenState extends State<AssignUserScreen> {
  int? _selectedBranchId;

  Set<int> _assignedBranchIds() {
    final assignedBranchIds = <int>{};
    final rawAssignments = widget.member['userBranches'];
    if (rawAssignments is! List) {
      return assignedBranchIds;
    }

    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;
      final branch = assignment['branch'];
      final dynamic rawId =
          branch is Map ? branch['id'] : assignment['branchId'];
      final int? branchId = rawId is int
          ? rawId
          : rawId is num
              ? rawId.toInt()
              : int.tryParse('${rawId ?? ''}');
      if (branchId != null) {
        assignedBranchIds.add(branchId);
      }
    }

    return assignedBranchIds;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  bool _memberBelongsToSalon(int salonId) {
    final rawUserSalons = widget.member['userSalons'];
    if (rawUserSalons is List) {
      for (final item in rawUserSalons) {
        if (item is! Map) continue;
        final salon = item['salon'];
        final rawSalonId = salon is Map ? salon['id'] : item['salonId'];
        if (_toInt(rawSalonId) == salonId) {
          return true;
        }
      }
    }

    final assignedBranchIds = _assignedBranchIds();
    return widget.branches.any(
      (branch) =>
          branch.salonId == salonId && assignedBranchIds.contains(branch.id),
    );
  }

  List<Branch> get _availableBranches {
    final assignedBranchIds = _assignedBranchIds();
    return widget.branches
        .where((branch) => !assignedBranchIds.contains(branch.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    print("🟢 Salon ID (filter): ${widget.salonId}");
    print("🟢 Total salons received: ${widget.salons.length}");

    for (final s in widget.salons) {
      print("Salon: ${s['name']} (${s['id']})");
      final branches = s['branches'] ?? [];
      print("  Branches count: ${branches.length}");
      for (final b in branches) {
        print(
            "    ↳ Branch: ${b['name']} | ID: ${b['id']} | Salon ID: ${s['id']}");
      }
    }

    print("🟡 Filtered branches for salonId ${widget.salonId}:");
    for (final b in widget.branches) {
      print("   ✅ ${b.name} (ID: ${b.id}) - SalonId: ${b.salonId}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> userSalons =
        (widget.member['userSalons'] ?? []) as List<dynamic>;
    final String joinedAt = userSalons.isNotEmpty
        ? (userSalons[0]['joinedAt'] ?? '').toString()
        : 'N/A';
    final availableBranches = _availableBranches;
    final noBranchesLeft = availableBranches.isEmpty;
    final selectedBranchId = availableBranches.any(
      (branch) => branch.id == _selectedBranchId,
    )
        ? _selectedBranchId
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Assign User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Step header (Step 1 active)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: MultiStepFlowHeader(
                currentStep: 1,
                useIcons: true,
                steps: const [
                  FlowStepItem(
                    stepNumber: 1,
                    label: 'Select Branches',
                    icon: Icons.place_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 2,
                    label: 'Choose Services',
                    icon: Icons.handyman_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 3,
                    label: 'Schedule',
                    icon: Icons.calendar_today_outlined,
                  ),
                  FlowStepItem(
                    stepNumber: 4,
                    label: 'Complete',
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),

            Text(
              translateText(
                "Choose branch where you'd like to assign that team member",
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: widget.branches.isEmpty
                  ? Center(
                      child: Text(
                        translateText("No branches found for this salon"),
                      ),
                    )
                  : noBranchesLeft
                      ? Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              translateText(
                                "This team member is already assigned to every branch in this salon.",
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: availableBranches.length,
                          itemBuilder: (_, i) {
                            final branch = availableBranches[i];
                            final isSelected = selectedBranchId == branch.id;
                            return _buildBranchCard(branch, isSelected);
                          },
                        ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: noBranchesLeft || selectedBranchId == null
                    ? null
                    : () async {
                        final branch = availableBranches
                            .firstWhere((b) => b.id == selectedBranchId);

                        if (!_memberBelongsToSalon(branch.salonId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                translateText(
                                  'This team member is not part of this salon. Add them to this salon before assigning a branch.',
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        // Go to Step 2
                        final assigned = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SelectServicesAssignUser(
                              salonId: branch.salonId,
                              branchId: branch.id,
                              userId: widget.member['id'],
                              joinedAt: joinedAt,
                              member: widget.member, // ✅ add this
                              salons: widget.salons,
                            ),
                          ),
                        );

                        // Maintain selection after returning
                        if (assigned == true && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  translateText("Next"),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard(Branch branch, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedBranchId = branch.id),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.starColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title: Text(
            branch.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(
            branch.address,
            style: const TextStyle(color: Colors.black54),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: AppColors.starColor)
              : Icon(Icons.radio_button_unchecked, color: Colors.grey),
        ),
      ),
    );
  }
}
