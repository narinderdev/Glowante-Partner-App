// import 'package:flutter/material.dart';
// import '../utils/api_service.dart';
// import '../utils/colors.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';

// import 'package:flutter/services.dart';

// class AddTeamSelectServices extends StatefulWidget {
//   final int salonId;
//   final Map<String, dynamic> teamPayload;

//   const AddTeamSelectServices({
//     super.key,
//     required this.salonId,
//     required this.teamPayload,
//   });

//   @override
//   State<AddTeamSelectServices> createState() => _AddTeamSelectServicesState();
// }

// class _AddTeamSelectServicesState extends State<AddTeamSelectServices> {
//   List<dynamic> _categories = [];
//   bool _loading = true;
//   bool _isSubmitting = false;
//   final Set<int> _selectedServiceIds = {}; // store selected service IDs

//   @override
//   void initState() {
//     super.initState();
//     _fetchServices();
//   }

//   Future<void> _fetchServices() async {
//     try {
//       final response = await ApiService().getService(salonId: widget.salonId);
//       setState(() {
//         _categories = response['data']['categories'] ?? [];
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() => _loading = false);
//       debugPrint("❌ Error fetching services: $e");
//     }
//   }

//   Future<void> _submit() async {
//     if (_selectedServiceIds.isEmpty) {
//       // Show message if no service is selected
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(translateText("Please select at least one service"))),
//       );
//       return;
//     }

//     // Prepare the final payload with the selected services
//     final finalPayload = {
//       ...widget.teamPayload,
//       //  "salonId": widget.salonId,
//       "selectedServiceIds": _selectedServiceIds.toList(),
//     };

//     // Log the final payload
//     debugPrint("✅ FINAL PAYLOAD: $finalPayload");

//     setState(() {
//       _isSubmitting = true;
//     });

//     // Simulating API call (replace with actual API)
//     await Future.delayed(const Duration(seconds: 2));

//     setState(() {
//       _isSubmitting = false;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(translateText("Team member added successfully"))),
//     );
//   }

//   int? _parseServiceId(dynamic rawId) {
//     if (rawId is int) return rawId;
//     if (rawId is String) return int.tryParse(rawId);
//     return null;
//   }

//   List<int> _collectServiceIds(List<dynamic> services) {
//     final result = <int>[];
//     for (final service in services) {
//       if (service is Map) {
//         final int? id = _parseServiceId(service['id']);
//         if (id != null) result.add(id);
//       }
//     }
//     return result;
//   }

//   void _toggleSelectAll(List<int> ids, bool select) {
//     if (ids.isEmpty) return;
//     setState(() {
//       if (select) {
//         _selectedServiceIds.addAll(ids);
//       } else {
//         _selectedServiceIds.removeAll(ids);
//       }
//     });
//   }

//   Widget _buildSelectAllButton({
//     required List<int> ids,
//     required bool allSelected,
//     required bool partiallySelected,
//   }) {
//     final IconData icon;
//     if (allSelected) {
//       icon = Icons.check_box;
//     } else if (partiallySelected) {
//       icon = Icons.indeterminate_check_box;
//     } else {
//       icon = Icons.check_box_outline_blank;
//     }

//     return IconButton(
//       splashRadius: 20,
//       padding: EdgeInsets.zero,
//       icon: Icon(icon, color: AppColors.starColor),
//       tooltip: allSelected
//           ? translateText("Clear selection")
//           : translateText("Select all"),
//       onPressed: ids.isEmpty ? null : () => _toggleSelectAll(ids, !allSelected),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         // Let the gradient show through:
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         // Ensure status bar + icons look good on the gradient:
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(
//           color: Colors.white, // back button color
//         ),
//         title: Text(
//           translateText('Select Services'),
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         // Paint the gradient here:
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.starColor, // your start color
//                 AppColors.getStartedButton, // your end color
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: _loading
//           ? Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _categories.length,
//               itemBuilder: (_, i) {
//                 final categoryMap =
//                     Map<String, dynamic>.from(_categories[i] as Map);
//                 final List<dynamic> services =
//                     categoryMap['services'] as List? ?? const [];
//                 final List<dynamic> subCats =
//                     categoryMap['subCategories'] as List? ?? const [];

//                 final List<int> categoryServiceIds =
//                     _collectServiceIds(services);
//                 final bool categoryAllSelected =
//                     categoryServiceIds.isNotEmpty &&
//                         categoryServiceIds.every(_selectedServiceIds.contains);
//                 final bool categoryPartialSelected = !categoryAllSelected &&
//                     categoryServiceIds.any(_selectedServiceIds.contains);

//                 return ExpansionTile(
//                   title: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           categoryMap['displayName'] ??
//                               categoryMap['name'] ??
//                               'Unnamed',
//                           style: const TextStyle(color: Colors.black),
//                         ),
//                       ),
//                       if (categoryServiceIds.isNotEmpty)
//                         _buildSelectAllButton(
//                           ids: categoryServiceIds,
//                           allSelected: categoryAllSelected,
//                           partiallySelected: categoryPartialSelected,
//                         ),
//                     ],
//                   ),
//                   children: [
//                     ...services.map<Widget>((srv) {
//                       final serviceMap = Map<String, dynamic>.from(srv as Map);
//                       final int? id = _parseServiceId(serviceMap['id']);
//                       if (id == null) return const SizedBox.shrink();
//                       final name =
//                           serviceMap['displayName'] ?? serviceMap['name'] ?? '';
//                       final price = serviceMap['priceMinor'] ?? 0;
//                       final duration = serviceMap['durationMin'] ?? 0;
//                       final desc = serviceMap['description'] ?? '';
//                       final checked = _selectedServiceIds.contains(id);

//                       return CheckboxListTile(
//                         value: checked,
//                         onChanged: (v) {
//                           setState(() {
//                             if (v == true) {
//                               _selectedServiceIds.add(id);
//                             } else {
//                               _selectedServiceIds.remove(id);
//                             }
//                           });
//                         },
//                         title: Text(
//                           name,
//                           style: const TextStyle(color: Colors.black),
//                         ),
//                         subtitle: Text(
//                           '₹$price • $duration min\n$desc',
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(color: Colors.black),
//                         ),
//                         checkColor: Colors.black,
//                         activeColor: Colors.black,
//                         selectedTileColor: Colors.black,
//                       );
//                     }),
//                     ...subCats.map<Widget>((sub) {
//                       final subMap = Map<String, dynamic>.from(sub as Map);
//                       final List<dynamic> subServices =
//                           subMap['services'] as List? ?? const [];
//                       final List<int> subServiceIds =
//                           _collectServiceIds(subServices);

//                       final bool subAllSelected = subServiceIds.isNotEmpty &&
//                           subServiceIds.every(_selectedServiceIds.contains);
//                       final bool subPartialSelected = !subAllSelected &&
//                           subServiceIds.any(_selectedServiceIds.contains);

//                       return ExpansionTile(
//                         title: Row(
//                           children: [
//                             Expanded(
//                               child: Text(
//                                 subMap['displayName'] ??
//                                     subMap['name'] ??
//                                     'Unnamed',
//                                 style: const TextStyle(color: Colors.black),
//                               ),
//                             ),
//                             if (subServiceIds.isNotEmpty)
//                               _buildSelectAllButton(
//                                 ids: subServiceIds,
//                                 allSelected: subAllSelected,
//                                 partiallySelected: subPartialSelected,
//                               ),
//                           ],
//                         ),
//                         children: subServices.map<Widget>((srv) {
//                           final srvMap = Map<String, dynamic>.from(srv as Map);
//                           final int? id = _parseServiceId(srvMap['id']);
//                           if (id == null) return const SizedBox.shrink();
//                           final checked = _selectedServiceIds.contains(id);
//                           final name =
//                               srvMap['displayName'] ?? srvMap['name'] ?? '';
//                           final price = srvMap['priceMinor'] ?? 0;
//                           final duration = srvMap['durationMin'] ?? 0;
//                           final desc = srvMap['description'] ?? '';

//                           return CheckboxListTile(
//                             value: checked,
//                             onChanged: (v) {
//                               setState(() {
//                                 if (v == true) {
//                                   _selectedServiceIds.add(id);
//                                 } else {
//                                   _selectedServiceIds.remove(id);
//                                 }
//                               });
//                             },
//                             title: Text(
//                               name,
//                               style: const TextStyle(color: Colors.black),
//                             ),
//                             subtitle: Text(
//                               '₹$price • $duration min\n$desc',
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(color: Colors.black),
//                             ),
//                             checkColor: Colors.white,
//                             activeColor: AppColors.starColor,
//                             selectedTileColor: Colors.white,
//                           );
//                         }).toList(),
//                       );
//                     }).toList(),
//                   ],
//                 );
//               },
//             ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ElevatedButton(
//           child: _isSubmitting
//               ? const CircularProgressIndicator(color: AppColors.starColor)
//               : Text(translateText("Submit")),
//           onPressed: _isSubmitting ? null : _submit,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: AppColors.starColor,
//             foregroundColor: Colors.white,
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'dart:convert';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/multi_step_flow_header.dart';
import 'team_online_availability_screen.dart';

class AddTeamSelectServices extends StatefulWidget {
  final Map<String, dynamic> teamMemberData;

  const AddTeamSelectServices({Key? key, required this.teamMemberData})
      : super(key: key);

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
    final initialSelected =
        (widget.teamMemberData['branchServiceIds'] as List? ?? const [])
            .map((e) {
      if (e is num) return e.toInt();
      return int.tryParse(e.toString());
    }).whereType<int>();
    for (final serviceId in initialSelected) {
      _selected[serviceId] = true;
    }
    _fetchServices();
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
    final n = (name ?? '').toString().trim().toLowerCase();
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
    final n = (name ?? '').toString().trim().toLowerCase();
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
    for (final c in _categories) {
      final cat = c as Map<String, dynamic>;
      for (final s in (cat['services'] ?? [])) {
        ids.add((s as Map)['id'] as int); // branch service id
      }
      for (final sub in (cat['subCategories'] ?? [])) {
        for (final s in ((sub as Map)['services'] ?? [])) {
          ids.add((s as Map)['id'] as int); // branch service id
        }
      }
    }
    return ids;
  }

  List<int> get _selectedServiceIds =>
      _selected.entries.where((e) => e.value).map((e) => e.key).toList();

  bool get _allSelected {
    final all = _allServiceIds();
    return all.isNotEmpty && all.every((id) => _selected[id] == true);
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
      onChanged: (val) => setState(() => _selected[id] = val ?? false),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      subtitle: Text("₹$priceMinor • $durationMin mins"),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final List services = cat['services'] as List? ?? [];
    final List subs = cat['subCategories'] as List? ?? [];

    final allIds = <int>[
      ...services.map((s) => (s as Map)['id'] as int),
      ...subs.expand((sub) => ((sub as Map)['services'] ?? [])
          .map<int>((s) => (s as Map)['id'] as int)),
    ];

    final int selCount = allIds.where((id) => _selected[id] == true).length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                (cat['displayName'] ?? '').toString(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Text("$selCount/${allIds.length}",
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        children: [
          // top-level services
          ...services
              .map<Widget>(
                  (s) => _buildServiceItem((s as Map).cast<String, dynamic>()))
              .toList(),

          // subcategories
          ...subs.map<Widget>((sub) {
            final subMap = (sub as Map).cast<String, dynamic>();
            final List subServices = subMap['services'] as List? ?? [];
            return ExpansionTile(
              tilePadding: const EdgeInsets.only(left: 24, right: 12),
              title: Text(
                (subMap['displayName'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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
    if (_selectedServiceIds.isEmpty) {
      _showError('Please select at least one service.');
      return;
    }

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
      backgroundColor: Colors.white,
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
                if (fullName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        // translateText('Assign services to') + ' $fullName', // Only translate the static part
                        translateText(
                            'Assign services'), // Only translate the static part
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                // Select All
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: CheckboxListTile(
                    value: _allSelected,
                    onChanged: _toggleAll,
                    title: Text(translateText('Select All Services')),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ),

                // Categories
                Expanded(
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (ctx, i) => _buildCategory(
                        (_categories[i] as Map).cast<String, dynamic>()),
                  ),
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
                    backgroundColor: const Color(0xFFE5E7EB),
                    foregroundColor: const Color(0xFF374151),
                    side: BorderSide.none,
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
                      borderRadius: BorderRadius.circular(6),
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
