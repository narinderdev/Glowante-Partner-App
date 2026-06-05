import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'AssignUserSlots.dart'; // 👈 NEW: Step 3 screen
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';

class SelectServicesAssignUser extends StatefulWidget {
  final int salonId;
  final int userId;
  final int branchId;
  final String joinedAt;
  final Map<String, dynamic> member; // ✅ add
  final List<Map<String, dynamic>> salons;
  final Map<int, bool>? initialSelected;

  const SelectServicesAssignUser({
    Key? key,
    required this.salonId,
    required this.userId,
    required this.branchId,
    required this.joinedAt,
    required this.member, // ✅ add
    required this.salons,
    this.initialSelected,
  }) : super(key: key);

  @override
  State<SelectServicesAssignUser> createState() =>
      _SelectServicesAssignUserState();
}

class _SelectServicesAssignUserState extends State<SelectServicesAssignUser> {
  List categories = [];
  final Map<int, bool> selected = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      selected.addAll(widget.initialSelected!);
    }
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final resp = await ApiService()
          .getBranchService(branchId: widget.branchId); // ✅ branch not salon
      if (resp['success'] == true) {
        setState(() {
          categories = resp['data']?['categories'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<int> get selectedServiceIds =>
      selected.entries.where((e) => e.value).map((e) => e.key).toList();

  bool get allSelected {
    final allIds = _allServiceIds();
    return allIds.isNotEmpty && allIds.every((id) => selected[id] == true);
  }

  void toggleAll(bool? value) {
    for (final id in _allServiceIds()) {
      selected[id] = value == true;
    }
    setState(() {});
  }

  List<int> _allServiceIds() {
    final ids = <int>[];
    for (final cat in _visibleCategories()) {
      for (final s in (cat['services'] ?? [])) {
        ids.add((s as Map)['id'] as int); // ✅ branch service id
      }
      for (final sub in _visibleSubCategories(cat)) {
        for (final s in ((sub['services'] ?? []) as List)) {
          ids.add((s as Map)['id'] as int); // ✅ branch service id
        }
      }
    }
    return ids;
  }

  List<Map<String, dynamic>> _visibleCategories() {
    return categories
        .whereType<Map>()
        .map((cat) => Map<String, dynamic>.from(cat))
        .where(_categoryHasServices)
        .toList();
  }

  bool _categoryHasServices(Map<String, dynamic> cat) {
    final services = cat['services'] as List? ?? const [];
    if (services.isNotEmpty) return true;
    return _visibleSubCategories(cat).isNotEmpty;
  }

  List<Map<String, dynamic>> _visibleSubCategories(Map<String, dynamic> cat) {
    final subs = cat['subCategories'] as List? ?? const [];
    return subs
        .whereType<Map>()
        .map((sub) => Map<String, dynamic>.from(sub))
        .where((sub) => ((sub['services'] as List?) ?? const []).isNotEmpty)
        .toList();
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int price = (s['priceMinor'] ?? 0) as int;
    final int duration = (s['durationMin'] ?? 0) as int;
    final bool checked = selected[id] ?? false;

    return CheckboxListTile(
      value: checked,
      onChanged: (val) => setState(() => selected[id] = val ?? false),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      subtitle: Text("₹$price • $duration mins"),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final List services = cat['services'] as List? ?? [];
    final List<Map<String, dynamic>> subs = _visibleSubCategories(cat);

    final allIds = [
      ...services.map((s) => (s as Map)['id'] as int),
      ...subs.expand((sub) => ((sub['services'] ?? []) as List)
          .map((s) => (s as Map)['id'] as int)),
    ];
    final int selCount = allIds.where((id) => selected[id] == true).length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(cat['displayName']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text("$selCount/${allIds.length}",
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        children: [
          ...services
              .map<Widget>(
                  (s) => _buildServiceItem((s as Map).cast<String, dynamic>()))
              .toList(),
          ...subs.map<Widget>((subMap) {
            final List subServices = subMap['services'] as List? ?? [];
            return ExpansionTile(
              title: Text(subMap['displayName']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              children: subServices
                  .map<Widget>((s) =>
                      _buildServiceItem((s as Map).cast<String, dynamic>()))
                  .toList(),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildProfileSubpageAppBar(
        title: translateText("Assign User"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: MultiStepFlowHeader(
                    currentStep: 2,
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

                // Select All
                if (_allServiceIds().isNotEmpty)
                  Card(
                    margin: const EdgeInsets.all(8),
                    child: CheckboxListTile(
                      value: allSelected,
                      onChanged: toggleAll,
                      title: Text(translateText("Select All Services")),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // children: [
                  //   Text(
                  //     "User ID: ${widget.userId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 4),
                  //   Text(
                  //     "Joined At: ${widget.joinedAt}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //    SizedBox(height: 4),
                  //   Text(
                  //     "Salon ID: ${widget.salonId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 4),
                  //   Text(
                  //     "Branch ID: ${widget.branchId}",
                  //     style: const TextStyle(
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.w600,
                  //       color: Colors.black54,
                  //     ),
                  //   ),
                  //   SizedBox(height: 12),
                  // ],
                ),

                // Categories
                Expanded(
                  child: _visibleCategories().isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              translateText(
                                'No services are available for this branch to assign.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _visibleCategories().length,
                          itemBuilder: (ctx, i) =>
                              _buildCategory(_visibleCategories()[i]),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.orange),
                  ),
                  child: Text(
                    translateText("Back"),
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final ids = selectedServiceIds;

                    // ✅ Add salonId & branchId
                    final payload = {
                      "userId": widget.userId,
                      "joinedAt": widget.joinedAt,
                      "salonId": widget.salonId,
                      "branchId": widget.branchId,
                      "branchServiceIds": ids,
                    };

                    print("➡️ Final Payload: $payload");

                    // 👉 Navigate to Step 3
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignUserSlot(
                          salonId: widget.salonId,
                          branchId: widget.branchId,
                          userId: widget.userId,
                          selectedServiceIds: ids,
                          member: widget.member, // ✅ pass to Step 2
                          salons: widget.salons,
                          joinedAt: widget.joinedAt, // 👈 don’t forget this
                        ),
                      ),
                    ).then((assigned) {
                      if (assigned == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(translateText("Next")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
