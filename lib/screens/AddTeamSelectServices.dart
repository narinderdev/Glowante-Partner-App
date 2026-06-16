import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';
import 'team_online_availability_screen.dart';

class AddTeamSelectServices extends StatefulWidget {
  final Map<String, dynamic> teamMemberData;

  const AddTeamSelectServices({super.key, required this.teamMemberData});

  @override
  State<AddTeamSelectServices> createState() => _AddTeamSelectServicesState();
}

class _AddTeamSelectServicesState extends State<AddTeamSelectServices> {
  bool _loading = true;
  bool _submitting = false;

  // API response (categories with nested subCategories & services)
  List _categories = [];

  // Track selections by branch service id
  final Map<int, bool> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final serviceId in _initialSelectedServiceIds()) {
      _selected[serviceId] = true;
    }
    _fetchServices();
  }

  List<int> _initialSelectedServiceIds() {
    final ids = <int>{};

    void addId(dynamic value) {
      if (value is int) {
        ids.add(value);
      } else if (value is num) {
        ids.add(value.toInt());
      } else if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) ids.add(parsed);
      }
    }

    final directIds = widget.teamMemberData['branchServiceIds'];
    if (directIds is List) {
      for (final id in directIds) {
        addId(id);
      }
    }

    final userBranchServices = widget.teamMemberData['userBranchServices'];
    if (userBranchServices is List) {
      for (final item in userBranchServices) {
        if (item is! Map) continue;
        addId(item['branchServiceId']);
        final branchService = item['branchService'];
        if (branchService is Map) {
          addId(branchService['id']);
        }
      }
    }

    return ids.toList();
  }

  Future<void> _fetchServices() async {
    setState(() => _loading = true);
    try {
      final int branchId = (widget.teamMemberData['branchId'] as int?) ?? 0;
      final resp = await ApiService().getBranchService(branchId: branchId);
      if (resp['success'] == true) {
        setState(() {
          _categories = resp['data']?['categories'] ?? [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showError(resp['message']?.toString() ?? 'Failed to load services.');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Unable to load services. Please try again.');
    }
  }
// ---------- Helpers: put inside _AddTeamSelectServicesState ----------

  /// Convert "08:00 AM" / "8:00 pm" → "08:00". If already "HH:mm", returns as-is.
  String _to24h(String input) {
    final s = input.trim();

    // already HH:mm (00–23)
    final reg24 = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    if (reg24.hasMatch(s)) return s;

    // match 8:05 am / 08:05 PM / 12:00 am etc.
    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
    final m = reg12.firstMatch(s);
    if (m != null) {
      int h = int.parse(m.group(1)!);
      final int min = int.parse(m.group(2)!);
      final String mer = m.group(3)!.toUpperCase();
      if (h == 12) h = 0;
      if (mer == 'PM') h += 12;
      final hh = h.toString().padLeft(2, '0');
      final mm = min.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    // if we can’t parse, just return as-is (or throw)
    return s;
  }

  /// Map UI display names to API enum codes. Adjust to your backend’s values.
  String _roleToCode(String name) {
    final n = name.toString().trim().toLowerCase();
    const map = {
      'salon worker': 'salon_worker',
      'worker': 'salon_worker',
      'stylist': 'salon_worker',
      'receptionist': 'salon_receptionist',
      'salon receptionist': 'salon_receptionist',
    };
    return map[n] ?? n.replaceAll(' ', '_'); // fallback to snake_case
  }

  String _specToCode(String name) {
    final n = name.toString().trim().toLowerCase();
    const map = {
      'hair cut': 'hair_cut',
      'haircut': 'hair_cut',
      'facial': 'facial',
      'pedicure': 'pedicure',
    };
    return map[n] ?? n.replaceAll(' ', '_');
  }

  /// Remove nulls and keys the API doesn’t need in body (since branch is in URL).
  Map<String, dynamic> _cleanBody(Map<String, dynamic> m) {
    final copy = Map<String, dynamic>.from(m)
      ..remove('useSalonHours')
      ..remove('otp')
      ..remove('profileImage')
      ..remove('branchId'); // branch comes from URL
    copy.removeWhere((k, v) => v == null);
    return copy;
  }

  /// Build exactly what the API expects.
  Map<String, dynamic> _buildPayloadForApi(
    Map<String, dynamic> base,
    List<int> branchServiceIds,
  ) {
    // roles & specs normalization
    final roles = (base['roles'] as List? ?? const [])
        .map((e) => _roleToCode(e.toString()))
        .toList();

    final specs = (base['specialities'] as List? ??
            base['specializations'] as List? ??
            const [])
        .map((e) => _specToCode(e.toString()))
        .toList();

    // schedules normalization to HH:mm
    final schedules =
        (base['schedules'] as List? ?? const []).map<Map<String, dynamic>>((s) {
      final sm = (s as Map).cast<String, dynamic>();
      return {
        'day': (sm['day'] ?? '').toString().toLowerCase(),
        'startTime': _to24h((sm['startTime'] ?? sm['start'] ?? '').toString()),
        'endTime': _to24h((sm['endTime'] ?? sm['end'] ?? '').toString()),
      };
    }).toList();

    // countryCode default
    final countryCode = (base['countryCode'] ?? '+91').toString();

    // joiningDate passthrough (string "YYYY-MM-DD" preferred)
    final joiningDate = base['joiningDate'];

    final result = <String, dynamic>{
      'countryCode': countryCode,
      'phoneNumber': base['phoneNumber'],
      'firstName': base['firstName'],
      'lastName': base['lastName'],
      'email': base['email'],
      'gender': (base['gender'] ?? '').toString().toLowerCase(),
      'joiningDate': joiningDate, // ensure it's "yyyy-MM-dd"
      'info': base['info'] ?? base['brief'],
      'roles': roles,
      'specialities': specs,
      'schedules': schedules,
      'branchServiceIds': branchServiceIds,
      'profilePictureUrl': base['profilePictureUrl'],
      'allowOnlineBooking': base['allowOnlineBooking'] ?? false,
    };

    return _cleanBody(result);
  }

  List<int> _allServiceIds() {
    final ids = <int>[];
    for (final cat in _visibleCategories()) {
      for (final s in (cat['services'] ?? [])) {
        ids.add((s as Map)['id'] as int); // branch service id
      }
      for (final sub in _visibleSubCategories(cat)) {
        for (final s in ((sub['services'] ?? []) as List)) {
          ids.add((s as Map)['id'] as int); // branch service id
        }
      }
    }
    return ids;
  }

  List<Map<String, dynamic>> _visibleCategories() {
    return _categories
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

  List<int> get _selectedServiceIds =>
      _selected.entries.where((e) => e.value).map((e) => e.key).toList();

  bool get _allSelected {
    final all = _allServiceIds();
    return all.isNotEmpty && all.every((id) => _selected[id] == true);
  }

  bool get _hasAssignableServices => _allServiceIds().isNotEmpty;

  bool? _selectionValue(List<int> ids) {
    if (ids.isEmpty) return false;
    final selectedCount = ids.where((id) => _selected[id] == true).length;
    if (selectedCount == 0) return false;
    if (selectedCount == ids.length) return true;
    return null;
  }

  void _setServiceIds(List<int> ids, bool selected) {
    for (final id in ids) {
      _selected[id] = selected;
    }
    setState(() {});
  }

  void _toggleAll(bool? value) {
    for (final id in _allServiceIds()) {
      _selected[id] = value == true;
    }
    setState(() {});
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final int id = s['id'] as int;
    final String name = (s['displayName'] ?? '').toString();
    final int priceMinor = (s['priceMinor'] ?? 0) as int;
    final int durationMin = (s['durationMin'] ?? 0) as int;
    final bool checked = _selected[id] ?? false;

    return CheckboxListTile(
      value: checked,
      activeColor: AppColors.starColor,
      checkboxShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onChanged: (val) => setState(() => _selected[id] = val ?? false),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F1B18),
        ),
      ),
      subtitle: Text(
        "₹$priceMinor • $durationMin mins",
        style: const TextStyle(color: Color(0xFF6F665E)),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final List services = cat['services'] as List? ?? [];
    final visibleSubs = _visibleSubCategories(cat);

    if (services.isEmpty && visibleSubs.isEmpty) {
      return const SizedBox.shrink();
    }

    final allIds = <int>[
      ...services.map((s) => (s as Map)['id'] as int),
      ...visibleSubs.expand((sub) => ((sub['services'] ?? []) as List)
          .map<int>((s) => (s as Map)['id'] as int)),
    ];

    final int selCount = allIds.where((id) => _selected[id] == true).length;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8DED6)),
      ),
      child: ExpansionTile(
        iconColor: AppColors.starColor,
        collapsedIconColor: const Color(0xFF756A61),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          children: [
            Checkbox(
              value: _selectionValue(allIds),
              tristate: true,
              activeColor: AppColors.starColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (value) => _setServiceIds(allIds, value == true),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                (cat['displayName'] ?? '').toString(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1B18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text("$selCount/${allIds.length}",
                style: const TextStyle(
                  color: AppColors.starColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
        children: [
          // top-level services
          ...services.map<Widget>(
            (s) => _buildServiceItem((s as Map).cast<String, dynamic>()),
          ),

          // subcategories
          ...visibleSubs.map<Widget>((subMap) {
            final List subServices = subMap['services'] as List? ?? [];
            final subIds = subServices
                .map((s) => (s as Map)['id'])
                .whereType<int>()
                .toList();
            return ExpansionTile(
              iconColor: AppColors.starColor,
              collapsedIconColor: const Color(0xFF756A61),
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.only(left: 24, right: 12),
              title: Row(
                children: [
                  Checkbox(
                    value: _selectionValue(subIds),
                    tristate: true,
                    activeColor: AppColors.starColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (value) => _setServiceIds(subIds, value == true),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      (subMap['displayName'] ?? '').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2926),
                      ),
                    ),
                  ),
                ],
              ),
              children: subServices
                  .map<Widget>((s) =>
                      _buildServiceItem((s as Map).cast<String, dynamic>()))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  // Future<void> _submit() async {
  //   if (_selectedServiceIds.isEmpty) {
  //     _showError('Please select at least one service.');
  //     return;
  //   }

  //   setState(() => _submitting = true);
  //   try {
  //     // Merge selected services into payload (as branchServiceIds)
  //     final payload = Map<String, dynamic>.from(widget.teamMemberData);
  //     payload['branchServiceIds'] = _selectedServiceIds;

  //     final int branchId = (payload['branchId'] as int?) ?? 0;

  //     final response = await ApiService().addTeamMember(branchId, payload);

  //     if (!mounted) return;

  //     if (response['success'] == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Team member added successfully')),
  //       );
  //       Navigator.pushAndRemoveUntil(
  //         context,
  //         MaterialPageRoute(builder: (_) => TeamScreen()),
  //         (route) => false,
  //       );
  //     } else {
  //       _showError(response['message']?.toString() ?? 'Failed to add team member');
  //     }
  //   } catch (e) {
  //     _showError('An unexpected error occurred.');
  //   } finally {
  //     if (mounted) setState(() => _submitting = false);
  //   }
  // }

  Future<void> _goToOnlineAvailability() async {
    setState(() => _submitting = true);
    try {
      // Build normalized body
      final payload = _buildPayloadForApi(
        widget.teamMemberData,
        _selectedServiceIds, // List<int>
      );

      final int branchId = (widget.teamMemberData['branchId'] as int?) ?? 0;
      final response = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.teamMemberData['isEdit'] == true
              ? TeamOnlineAvailabilityScreen.editMember(
                  branchId: branchId,
                  userId: (widget.teamMemberData['userId'] as int?) ?? 0,
                  payload: payload,
                )
              : TeamOnlineAvailabilityScreen.addMember(
                  branchId: branchId,
                  payload: payload,
                ),
        ),
      );
      if (!mounted) return;
      if (response == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Response'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${widget.teamMemberData["firstName"] ?? ""} ${widget.teamMemberData["lastName"] ?? ""}'
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Select Services'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: MultiStepFlowHeader(
                    currentStep: 3,
                    steps: const [
                      FlowStepItem(stepNumber: 1, label: 'Personal Details'),
                      FlowStepItem(stepNumber: 2, label: 'Schedule'),
                      FlowStepItem(stepNumber: 3, label: 'Services'),
                      FlowStepItem(stepNumber: 4, label: 'Online Availability'),
                    ],
                  ),
                ),
                // Summary
                if (fullName.isNotEmpty && _hasAssignableServices)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        // translateText('Assign services to') + ' $fullName', // Only translate the static part
                        translateText(
                            'Assign services'), // Only translate the static part
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F1B18),
                        ),
                      ),
                    ),
                  ),

                // Select All
                if (_hasAssignableServices)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE8DED6)),
                    ),
                    child: CheckboxListTile(
                      value: _allSelected,
                      onChanged: _toggleAll,
                      title: Text(translateText('Select All Services')),
                      activeColor: AppColors.starColor,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),

                // Categories
                Expanded(
                  child: _hasAssignableServices
                      ? ListView.builder(
                          itemCount: _visibleCategories().length,
                          itemBuilder: (ctx, i) =>
                              _buildCategory(_visibleCategories()[i]),
                        )
                      : const _NoAssignableServicesState(),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D2926),
                    side: const BorderSide(color: Color(0xFFE2D3BF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(translateText('Previous')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _goToOnlineAvailability,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          translateText('Next'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
}

class _NoAssignableServicesState extends StatelessWidget {
  const _NoAssignableServicesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFF6EFE3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.design_services_outlined,
                color: AppColors.starColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              translateText(
                'No services are available for this branch to assign.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translateText(
                'Please select a different branch or add branch services.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
