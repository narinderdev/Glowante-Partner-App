import 'package:flutter/material.dart';
import 'select_services_AssignUser.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../widgets/multi_step_flow_header.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _assignUserBackground = Color(0xFFFBFAF8);
const Color _assignUserBorder = Color(0xFFE8DED6);
const Color _assignUserText = Color(0xFF2B241D);
const Color _assignUserMuted = Color(0xFF8C7A66);
const Color _assignUserSurface = Colors.white;
const Color _assignUserSoftGold = Color(0xFFFFF3D5);

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
    super.key,
    required this.member,
    required this.salons,
    required this.salonId,
  }) {
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
              address: _branchAddressSummary(branch['address']),
            );
          });
        })
        .where((branch) => branch.salonId == salonId)
        .toList();
  }

  static String _branchAddressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
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

    push(rawAddress['line1']);
    push(rawAddress['line2']);
    push(rawAddress['village']);
    push(rawAddress['district']);
    push(rawAddress['city']);
    push(rawAddress['state']);
    push(rawAddress['postalCode']);
    push(rawAddress['country']);
    return parts.join(', ');
  }

  @override
  State<AssignUserScreen> createState() => _AssignUserScreenState();
}

class _AssignUserScreenState extends State<AssignUserScreen> {
  int? _selectedBranchId;
  final Map<int, Set<int>> _rememberedSelectedServiceIdsByBranchId = {};

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
    debugPrint("Assign user salon filter: ${widget.salonId}");
    debugPrint("Assign user salons received: ${widget.salons.length}");

    for (final s in widget.salons) {
      debugPrint("Salon: ${s['name']} (${s['id']})");
      final branches = s['branches'] ?? [];
      debugPrint("  Branches count: ${branches.length}");
      for (final b in branches) {
        debugPrint(
          "    Branch: ${b['name']} | ID: ${b['id']} | Salon ID: ${s['id']}",
        );
      }
    }

    debugPrint("Filtered branches for salonId ${widget.salonId}:");
    for (final b in widget.branches) {
      debugPrint("   ${b.name} (ID: ${b.id}) - SalonId: ${b.salonId}");
    }
  }

  String get _memberName {
    final firstName = (widget.member['firstName'] ?? '').toString().trim();
    final lastName = (widget.member['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? translateText('Team Member') : fullName;
  }

  String get _memberInitials {
    final parts = _memberName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TM';
    final first = parts.first.substring(0, 1).toUpperCase();
    final second = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$second';
  }

  Future<void> _goNext({
    required int selectedBranchId,
    required String joinedAt,
    required List<Branch> availableBranches,
  }) async {
    final branch =
        availableBranches.firstWhere((b) => b.id == selectedBranchId);

    if (!_memberBelongsToSalon(branch.salonId)) {
      Fluttertoast.showToast(
          msg: translateText(
        'This team member is not part of this salon. Add them to this salon before assigning a branch.',
      ));
      return;
    }

    final navigator = Navigator.of(context);
    final rememberedSelectedServiceIds =
        _rememberedSelectedServiceIdsByBranchId[selectedBranchId] ?? <int>{};
    final result = await navigator.push<dynamic>(
      MaterialPageRoute(
        builder: (_) => SelectServicesAssignUser(
          salonId: branch.salonId,
          branchId: branch.id,
          userId: widget.member['id'],
          joinedAt: joinedAt,
          member: widget.member,
          salons: widget.salons,
          initialSelected: {
            for (final serviceId in rememberedSelectedServiceIds)
              serviceId: true,
          },
        ),
      ),
    );

    if (!mounted) return;
    if (result is Map) {
      final rawSelected = result['selectedServiceIds'];
      if (rawSelected is List) {
        _rememberedSelectedServiceIdsByBranchId[selectedBranchId] =
            rawSelected.whereType<int>().toSet();
      }

      if (result['completed'] == true) {
        navigator.pop(true);
      }
      return;
    }

    if (result is List) {
      _rememberedSelectedServiceIdsByBranchId[selectedBranchId] =
          result.whereType<int>().toSet();
      return;
    }

    if (result == true) {
      navigator.pop(true);
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
      backgroundColor: _assignUserBackground,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Assign User'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MultiStepFlowHeader(
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
            const SizedBox(height: 20),
            Text(
              translateText('Select Branch'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.starColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              translateText(
                "Choose branch where you'd like to assign that team member",
              ),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: _assignUserMuted,
              ),
            ),
            const SizedBox(height: 16),
            _MemberAssignSummary(
              initials: _memberInitials,
              name: _memberName,
              availableCount: availableBranches.length,
              totalCount: widget.branches.length,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: widget.branches.isEmpty
                  ? const _AssignUserEmptyState(
                      title: 'No branches found',
                      message: 'No branches found for this salon',
                    )
                  : noBranchesLeft
                      ? const _AssignUserEmptyState(
                          title: 'All branches assigned',
                          message:
                              'This team member is already assigned to every branch in this salon.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: availableBranches.length,
                          itemBuilder: (_, i) {
                            final branch = availableBranches[i];
                            final isSelected = selectedBranchId == branch.id;
                            return _buildBranchCard(branch, isSelected);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: _assignUserBackground,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _assignUserText,
                    side: const BorderSide(color: _assignUserBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    translateText('Back'),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: noBranchesLeft || selectedBranchId == null
                      ? null
                      : () => _goNext(
                            selectedBranchId: selectedBranchId,
                            joinedAt: joinedAt,
                            availableBranches: availableBranches,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFD8CEC5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    translateText("Next"),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchCard(Branch branch, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedBranchId = branch.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: _assignUserCardDecoration(highlighted: isSelected),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _assignUserSoftGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 18,
                color: isSelected ? AppColors.starColor : _assignUserMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name.isEmpty ? translateText('Branch') : branch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _assignUserText,
                    ),
                  ),
                  if (branch.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      branch.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _assignUserMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _BranchSelectionMark(selected: isSelected),
          ],
        ),
      ),
    );
  }
}

class _MemberAssignSummary extends StatelessWidget {
  const _MemberAssignSummary({
    required this.initials,
    required this.name,
    required this.availableCount,
    required this.totalCount,
  });

  final String initials;
  final String name;
  final int availableCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _assignUserCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _assignUserSoftGold,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: AppColors.starColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _assignUserText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${translateText('Available branches')}: $availableCount/$totalCount',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _assignUserMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchSelectionMark extends StatelessWidget {
  const _BranchSelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.starColor : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppColors.starColor : _assignUserBorder,
          width: 1.3,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}

class _AssignUserEmptyState extends StatelessWidget {
  const _AssignUserEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _assignUserCardDecoration(),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _assignUserSoftGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_off_outlined,
                  color: AppColors.starColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translateText(title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _assignUserText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                translateText(message),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _assignUserMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

BoxDecoration _assignUserCardDecoration({bool highlighted = false}) {
  return BoxDecoration(
    color: _assignUserSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: highlighted ? AppColors.starColor : _assignUserBorder,
      width: highlighted ? 1.2 : 1,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
}
