// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'SelectServices.dart';
// import '../utils/api_service.dart';

// class AddBookingScreen extends StatefulWidget {
//   final int? salonId; // needed for SelectServicesModal
//   final int? branchId; // future use when posting appointment

//   const AddBookingScreen({Key? key, this.salonId, this.branchId})
//       : super(key: key);

//   @override
//   State<AddBookingScreen> createState() => _AddBookingScreenState();
// }

// class _AddBookingScreenState extends State<AddBookingScreen> {
//   final _formKey = GlobalKey<FormState>();

//   // Form fields
//   final TextEditingController _clientNameCtrl = TextEditingController();
//   final TextEditingController _mobileCtrl = TextEditingController();

//   // Keep existing names so your payload stays the same.
//   String? _staffRole; // we'll sync this to the selected service name
//   String? _professional; // selected professional name (or "Any")
// DateTime? _selectedDate;
//   TimeOfDay? _startTime;
//   TimeOfDay? _endTime;

//   // Selected services from modal: each {id, name, price, qty, durationMin}
//   List<Map<String, dynamic>> _selectedServices = [];

//   // Services tree for the modal and flat list for lookup.
//   List<Map<String, dynamic>> _svcTree = []; // nodes: {name, services[], subs[]}
//   List<Map<String, dynamic>> _branchServices = []; // flat items: {id, name, priceMinor, durationMin, path}
//   bool _loadingServices = true;

//   // Focused/active service (drives Professional filtering)
//   int? _selectedServiceId;
//   String? _selectedServiceName;

//   // Team members
//   List<Map<String, dynamic>> _teamMembers = [];
//   bool _loadingMembers = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadServices();
//     _loadTeamMembers();
//   }

//   @override
//   void dispose() {
//     _clientNameCtrl.dispose();
//     _mobileCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _loadServices() async {
//     if (widget.branchId == null) return;
//     try {
//       final data = await ApiService().getBranchServiceDetail(widget.branchId!);

//       final List<Map<String, dynamic>> flat = [];
//       final List<Map<String, dynamic>> tree = [];
//       final categories = data['categories'] as List? ?? [];

//       for (final cat in categories) {
//         final catName = (cat['displayName'] ?? '').toString().trim();
//         final List catServices = cat['services'] as List? ?? [];
//         final List subCats = cat['subCategories'] as List? ?? [];

//         final catNode = {
//           'name': catName,
//           'services': <Map<String, dynamic>>[],
//           'subs': <Map<String, dynamic>>[],
//         };

//         // services directly under category
//         for (final svc in catServices) {
//           final svcMap = {
//             'id': svc['id'],
//             'name': (svc['displayName'] ?? '').toString(),
//             'priceMinor': svc['priceMinor'],
//             'durationMin': svc['durationMin'],
//             'path': [catName, (svc['displayName'] ?? '').toString()]
//                 .where((e) => (e as String).isNotEmpty)
//                 .join(' • '),
//           };
//           flat.add(svcMap);
//           (catNode['services'] as List).add(svcMap);
//         }

//         // subcategories
//         for (final sub in subCats) {
//           final subName = (sub['displayName'] ?? '').toString().trim();
//           final List subServices = sub['services'] as List? ?? [];
//           final subNode = {
//             'name': subName,
//             'services': <Map<String, dynamic>>[],
//           };
//           for (final svc in subServices) {
//             final svcMap = {
//               'id': svc['id'],
//               'name': (svc['displayName'] ?? '').toString(),
//               'priceMinor': svc['priceMinor'],
//               'durationMin': svc['durationMin'],
//               'path':
//                   [catName, subName, (svc['displayName'] ?? '').toString()]
//                       .where((e) => (e as String).isNotEmpty)
//                       .join(' • '),
//             };
//             flat.add(svcMap);
//             (subNode['services'] as List).add(svcMap);
//           }
//           (catNode['subs'] as List).add(subNode);
//         }

//         tree.add(catNode);
//       }

//       setState(() {
//         _branchServices = flat; // quick lookup/totals
//         _svcTree = tree; // for the modal UI
//         _loadingServices = false;
//       });
//     } catch (e) {
//       print("Error fetching services: $e");
//       setState(() {
//         _branchServices = [];
//         _svcTree = [];
//         _loadingServices = false;
//       });
//     }
//   }

//   void _showServicePicker() async {
//     final picked = await showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) {
//         final bool locked = false; // multi-select allowed at all times

//         return DraggableScrollableSheet(
//           expand: false,
//           initialChildSize: 0.8,
//           minChildSize: 0.5,
//           maxChildSize: 0.95,
//           builder: (_, controller) {
//             return Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       const Icon(Icons.design_services),
//                       const SizedBox(width: 8),
//                       const Text('Select Service',
//                           style: TextStyle(
//                               fontWeight: FontWeight.w700, fontSize: 16)),
//                       const Spacer(),
//                       IconButton(
//                         icon: const Icon(Icons.close),
//                         onPressed: () => Navigator.pop(ctx),
//                       ),
//                     ],
//                   ),
//                   Expanded(
//                     child: ListView.builder(
//                       controller: controller,
//                       itemCount: _svcTree.length,
//                       itemBuilder: (_, i) {
//                         final cat = _svcTree[i];
//                         final catName = (cat['name'] ?? '').toString();
//                         final List catSvcs =
//                             (cat['services'] as List?) ?? const [];
//                         final List subs = (cat['subs'] as List?) ?? const [];

//                         return Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(vertical: 6),
//                               child: Text(
//                                 catName,
//                                 style: const TextStyle(
//                                     fontWeight: FontWeight.bold, fontSize: 15),
//                               ),
//                             ),
//                             for (final s in catSvcs)
//                               _serviceTile(ctx, s, leftPad: 12, locked: locked),
//                             for (final sub in subs) ...[
//                               Padding(
//                                 padding:
//                                     const EdgeInsets.fromLTRB(8, 8, 0, 4),
//                                 child: Text(
//                                   (sub['name'] ?? '').toString(),
//                                   style: TextStyle(
//                                     color: Colors.grey.shade700,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                               for (final s in (sub['services'] as List))
//                                 _serviceTile(ctx, s,
//                                     leftPad: 24, locked: locked),
//                             ],
//                             const Divider(height: 20),
//                           ],
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );

//     if (picked != null) {
//       final v = picked['id'] as int;
//       final name = (picked['name'] ?? '').toString();

//       setState(() {
//         final already = _selectedServices.any((s) => s['id'] == v);

//         if (already) {
//           // Deselect (remove chip)
//           _selectedServices.removeWhere((s) => s['id'] == v);

//           // If it was the active service, move focus to another selected one (or none)
//           if (_selectedServiceId == v) {
//             _selectedServiceId = _selectedServices.isNotEmpty
//                 ? _selectedServices.last['id'] as int
//                 : null;
//             _selectedServiceName = _selectedServices.isNotEmpty
//                 ? _selectedServices.last['name'] as String
//                 : null;
//             _staffRole = _selectedServiceName;
//             // Keep current _professional as is; chips will render only
//             // after pro selection anyway.
//           }
//         } else {
//           // Add (select) this service
//           _selectedServices.add({
//             'id': v,
//             'name': name,
//             'price': picked['priceMinor'],
//             'qty': 1,
//             'durationMin': picked['durationMin'],
//           });

//           // Make the newly tapped service the ACTIVE one for pro filtering
//           _selectedServiceId = v;
//           _selectedServiceName = name;
//           _staffRole = name;

//           // Reset professional so the user must confirm/choose (incl. Any)
//           _professional = null;
//         }
//       });
//     }
//   }

//   // Service row in the bottom sheet.
//   Widget _serviceTile(
//     BuildContext ctx,
//     Map<String, dynamic> svc, {
//     double leftPad = 0,
//     bool locked = false,
//   }) {
//     final int svcId = svc['id'] as int;
//     final String name = (svc['name'] ?? '').toString();
//     final int? duration = svc['durationMin'] as int?;
//     final num? priceMinor = svc['priceMinor'] as num?;
//     final String priceText =
//         priceMinor == null ? '' : '₹${priceMinor.toString()}';
//     final String meta = [
//       if (duration != null && duration > 0) '${duration} min',
//       if (priceText.isNotEmpty) priceText,
//     ].join(' • ');

//     final bool isActive = _selectedServiceId == svcId;
//     final bool isSelected =
//         _selectedServices.any((e) => (e['id'] as int) == svcId);

//     // Icon logic: active > selected > none
//     final Widget trailing = isActive
//         ? const Icon(Icons.radio_button_checked, color: Colors.orange)
//         : (isSelected
//             ? const Icon(Icons.check_box, color: Colors.grey)
//             : const Icon(Icons.check_box_outline_blank, color: Colors.grey));

//     return Padding(
//       padding: EdgeInsets.only(left: leftPad),
//       child: ListTile(
//         dense: true,
//         contentPadding: const EdgeInsets.only(left: 8, right: 8),
//         leading: const Icon(Icons.cut),
//         title:
//             Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
//         subtitle: meta.isNotEmpty ? Text(meta) : null,
//         trailing: trailing,
//         onTap: () => Navigator.pop<Map<String, dynamic>>(ctx, svc),
//       ),
//     );
//     // ^ Tapping toggles selection and makes this the active service.
//   }

//   Future<void> _loadTeamMembers() async {
//     if (widget.branchId == null) return;
//     setState(() => _loadingMembers = true);

//     try {
//       final response = await ApiService.getTeamMembers(widget.branchId!);
//       if (response['success'] == true) {
//         final List members = response['data'] ?? [];
//         setState(() {
//           _teamMembers = members.cast<Map<String, dynamic>>();
//         });
//       }
//     } catch (e) {
//       print("Error loading team members: $e");
//     } finally {
//       setState(() => _loadingMembers = false);
//     }
//   }

//   List<Map<String, dynamic>> _filterMembersByServices() {
//     final int? currentBranchId = widget.branchId;
//     final int? selectedId = _selectedServiceId; // strict match by ID

//     if (selectedId == null) return [];

//     final matches = _teamMembers.where((member) {
//       final branches = member['userBranches'] as List? ?? [];
//       for (final ub in branches) {
//         final b = ub['branch'] as Map<String, dynamic>?;
//         final int? bId = b?['id'] as int?;
//         if (currentBranchId != null && bId != currentBranchId) continue;

//         final services = ub['userBranchServices'] as List? ?? [];
//         for (final s in services) {
//           final bs = s['branchService'] as Map<String, dynamic>?;
//           final int? serviceId = bs?['id'] as int?;
//           if (serviceId == selectedId) return true;
//         }
//       }
//       return false;
//     }).toList();

//     final names = matches
//         .map((m) => "${m['firstName']} ${m['lastName'] ?? ''}".trim())
//         .toList();
//     print('Selected service id: $selectedId @ branch $currentBranchId -> $names');

//     return matches;
//   }

//   Map<int, int> _selectedQtyMap() {
//     final map = <int, int>{};
//     for (final s in _selectedServices) {
//       final id = s['id'] as int;
//       final int qty = (s['qty'] ?? 0) as int;
//       if (qty > 0) map[id] = qty;
//     }
//     return map;
//   }

//   double get _servicesTotal {
//     double sum = 0;
//     for (final s in _selectedServices) {
//       final num price = (s['price'] ?? 0) as num; // in rupees already
//       final int qty = (s['qty'] ?? 0) as int;
//       sum += (price * qty).toDouble();
//     }
//     return sum;
//   }

//   String _formatTimeOfDay(TimeOfDay? t) {
//     if (t == null) return '';
//     final now = DateTime.now();
//     final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
//     return DateFormat('h:mm a').format(dt);
//   }
//  String _formatDate(DateTime? d) {
//     if (d == null) return '';
//     return DateFormat('EEE, MMM d, yyyy').format(d);
//   }
//   Future<void> _pickDate() async {
//     final now = DateTime.now();
//     final initial = _selectedDate ?? now;
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: DateTime(now.year, now.month, now.day), // today onwards
//       lastDate: DateTime(now.year + 3),
//     );
//     if (picked != null) {
//       setState(() => _selectedDate = picked);
//     }
//   }
//   Future<void> _pickTime({required bool isStart}) async {
//     final initialTime =
//         (isStart ? _startTime : _endTime) ??
//             const TimeOfDay(hour: 9, minute: 0);
//     final picked =
//         await showTimePicker(context: context, initialTime: initialTime);
//     if (picked != null) {
//       setState(() {
//         if (isStart) {
//           _startTime = picked;
//           // Ensure end >= start
//           if (_endTime != null) {
//             final s = _toMinutes(_startTime!);
//             final e = _toMinutes(_endTime!);
//             if (e <= s) {
//               _endTime = TimeOfDay(
//                   hour: picked.hour, minute: (picked.minute + 30) % 60);
//             }
//           }
//         } else {
//           _endTime = picked;
//         }
//       });
//     }
//   }

//   int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

//   void _save() {
//     if (!_formKey.currentState!.validate()) return;

//     if (_selectedServiceId == null) {
//       _showError('Please select Service');
//       return;
//     }
//     if (_professional == null) {
//       _showError('Please select Professional (or Any)');
//       return;
//     }
//       // NEW: validate date
//     if (_selectedDate == null) {
//       _showError('Please select a date');
//       return;
//     }
//     if (_startTime == null || _endTime == null) {
//       _showError('Please select start and end time');
//       return;
//     }

//     final payload = {
//       'clientName': _clientNameCtrl.text.trim(),
//       'phone': _mobileCtrl.text.trim(),
//       'staffRole': _staffRole, // for backward compatibility
//       'professional': _professional,
//        'date': _formatDate(_selectedDate),
//       'dateISO': _selectedDate!.toIso8601String(), // helpful for backend
//       'startTime': _formatTimeOfDay(_startTime),
//       'endTime': _formatTimeOfDay(_endTime),
//       'services': _selectedServices,
//       'salonId': widget.salonId,
//       'branchId': widget.branchId,
//     };

//     Navigator.pop(context, payload);
//   }

//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final matched = _filterMembersByServices();

//     // Build the Professional dropdown items with the “Any” rule:
//     // - 0 matches: ['Any']
//     // - 1 match: [singleName]
//     // - >1 matches: ['Any', ...names]
//     // final List<String> proItems = _loadingMembers
//     //     ? <String>[]
//     //     : (() {
//     //         final names = matched
//     //             .map((m) =>
//     //                 "${m['firstName']} ${m['lastName'] ?? ''}".trim())
//     //             .toList();
//     //         if (names.isEmpty) return <String>['Any'];
//     //         if (names.length == 1) return names;
//     //         return <String>['Any', ...names];
//     //       })();

// final List<String> proItems = _loadingMembers
//     ? <String>[]
//     : (() {
//         final names = matched
//             .map((m) =>
//                 "${m['firstName']} ${m['lastName'] ?? ''}".trim())
//             .toList();

//         // Always include "Any" at the top
//         return <String>['Any', ...names];
//       })();

//     final proHint = _loadingMembers
//         ? 'Loading...'
//         : (_selectedServiceId == null
//             ? 'Choose'
//             : (proItems.length == 1 && proItems.first != 'Any'
//                 ? 'Choose'
//                 : 'Choose / Any'));

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Add Booking'),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Client Name
//                 Text(
//                     'Salon & Branch Id: ${widget.salonId ?? '-'} / ${widget.branchId ?? '-'}'),
//                 const _FieldLabel('Client Name *'),
//                 TextFormField(
//                   controller: _clientNameCtrl,
//                   decoration: _inputDecoration('Client name'),
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty) ? 'Required' : null,
//                 ),
//                 const SizedBox(height: 16),

//                 // Mobile
//                 const _FieldLabel('Mobile Number *'),
//                 TextFormField(
//                   controller: _mobileCtrl,
//                   keyboardType: TextInputType.phone,
//                   decoration: _inputDecoration('Enter mobile number'),
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty) ? 'Required' : null,
//                 ),
//                 const SizedBox(height: 16),

//                 // Service (hierarchical) + Professional
//                 Row(
//                   children: [
//                     // Left: Services *
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const _FieldLabel('Services *'),
//                           InkWell(
//                             onTap: _loadingServices || _svcTree.isEmpty
//                                 ? null
//                                 : _showServicePicker,
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 12, vertical: 14),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                     color: Colors.grey.shade300),
//                               ),
//                               child: Row(
//                                 children: [
//                                   const Icon(Icons.design_services, size: 18),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       _selectedServiceId == null
//                                           ? 'Choose'
//                                           : (_branchServices.firstWhere(
//                                                   (e) =>
//                                                       e['id'] ==
//                                                       _selectedServiceId)['path']
//                                               as String),
//                                       style: const TextStyle(fontSize: 16),
//                                     ),
//                                   ),
//                                   const Icon(Icons.keyboard_arrow_down),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),

//                     // Right: Professional *
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const _FieldLabel('Professional *'),
//                           _Dropdown<String>(
//                             value: _professional,
//                             hint: proHint,
//                             items: proItems,
//                             // Always pass a callback (no-op when disabled) to satisfy non-nullable type
//                             onChanged:
//                                 (_selectedServiceId == null || _loadingMembers)
//                                     ? (_) {}
//                                     : (v) => setState(() => _professional = v),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 // ⬇️ ⬇️ ⬇️  SHOW SELECTED SERVICES **ONLY AFTER** PROFESSIONAL IS CHOSEN (including "Any")
//                 if (_selectedServices.isNotEmpty && _professional != null) ...[
//                   const SizedBox(height: 16),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: -8,
//                     children: _selectedServices.map((s) {
//                       final name = (s['name'] ?? '').toString();
//                       final qty = (s['qty'] ?? 1) as int;
//                       final dur = s['durationMin'] != null
//                           ? '${s['durationMin']}m'
//                           : '';
//                       final price =
//                           s['price'] != null ? '₹${s['price']}' : '';
//                       // Also show chosen professional label on the chip
//                       final pro = _professional ?? '';
//                       final meta = [
//                         if (dur.isNotEmpty) dur,
//                         if (price.isNotEmpty) price,
//                         if (pro.isNotEmpty) pro, // show pro/Any to the right
//                       ].join(' • ');

//                       return Chip(
//                         label: Text(meta.isEmpty
//                             ? '$name x$qty'
//                             : '$name x$qty  —  $meta'),
//                         onDeleted: () {
//                           setState(() {
//                             final removedId = s['id'] as int;
//                             _selectedServices
//                                 .removeWhere((e) => e['id'] == removedId);

//                             if (_selectedServiceId == removedId) {
//                               _selectedServiceId =
//                                   _selectedServices.isNotEmpty
//                                       ? _selectedServices.last['id'] as int
//                                       : null;
//                               _selectedServiceName =
//                                   _selectedServices.isNotEmpty
//                                       ? _selectedServices.last['name'] as String
//                                       : null;
//                               _staffRole = _selectedServiceName;
//                               // Keep _professional as is; chips will re-evaluate condition
//                               if (_selectedServiceId == null) {
//                                 // If no services left, also clear pro
//                                 _professional = null;
//                               }
//                             }
//                           });
//                         },
//                       );
//                     }).toList(),
//                   ),
//                 ],

//                 const SizedBox(height: 20),
// // NEW: Date picker (placed above Start/End Time)
//                 const _FieldLabel('Date *'),
//                 InkWell(
//                   onTap: _pickDate,
//                   child: _TimeBox(
//                     text: _selectedDate == null
//                         ? 'Select date'
//                         : _formatDate(_selectedDate),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 // Start / End time
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const _FieldLabel('Start Time *'),
//                           InkWell(
//                             onTap: () => _pickTime(isStart: true),
//                             child: _TimeBox(
//                                 text: _startTime == null
//                                     ? 'Start Time'
//                                     : _formatTimeOfDay(_startTime)),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const _FieldLabel('End Time *'),
//                           InkWell(
//                             onTap: () => _pickTime(isStart: false),
//                             child: _TimeBox(
//                                 text: _endTime == null
//                                     ? 'End Time'
//                                     : _formatTimeOfDay(_endTime)),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 24),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: _save,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       padding:
//                           const EdgeInsets.symmetric(vertical: 14),
//                     ),
//                     child: const Text('Save',
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _FieldLabel extends StatelessWidget {
//   final String text;
//   const _FieldLabel(this.text, {Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6.0),
//       child: Text(
//         text,
//         style: const TextStyle(fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }

// InputDecoration _inputDecoration(String hint) => InputDecoration(
//       hintText: hint,
//       filled: true,
//       fillColor: Colors.white,
//       contentPadding:
//           const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       border:
//           OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: Colors.grey.shade300),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: Colors.orange),
//       ),
//     );

// class _Dropdown<T> extends StatelessWidget {
//   final T? value;
//   final List<T> items;
//   final ValueChanged<T?> onChanged; // keep non-nullable
//   final String hint;

//   const _Dropdown({
//     Key? key,
//     required this.value,
//     required this.items,
//     required this.onChanged,
//     required this.hint,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final isDisabled = items.isEmpty;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         color: isDisabled ? Colors.grey.shade100 : Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<T>(
//           value: value,
//           isExpanded: true,
//           hint: Row(
//             children: [
//               const SizedBox(width: 6),
//               Text(hint),
//             ],
//           ),
//           items: items
//               .map((e) => DropdownMenuItem<T>(
//                     value: e,
//                     child: Text(e.toString()),
//                   ))
//               .toList(),
//           onChanged: isDisabled ? (_) {} : onChanged, // use no-op when disabled
//         ),
//       ),
//     );
//   }
// }

// class _TimeBox extends StatelessWidget {
//   final String text;
//   const _TimeBox({Key? key, required this.text}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 48,
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.calendar_today, size: 18),
//           const SizedBox(width: 8),
//           Expanded(child: Text(text.isEmpty ? 'Select' : text)),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SelectServices.dart';
import '../utils/api_service.dart';

class AddBookingScreen extends StatefulWidget {
  final int? salonId; // needed for SelectServicesModal
  final int? branchId; // future use when posting appointment

  const AddBookingScreen({Key? key, this.salonId, this.branchId})
      : super(key: key);

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _clientIdCtrl = TextEditingController();
  final TextEditingController _clientfNameCtrl = TextEditingController();
  final TextEditingController _clientlNameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  // Keep existing names so your payload stays the same.
  String? _staffRole; // we'll sync this to the selected service name
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Selected services from modal: each {id, name, price, qty, durationMin}
  List<Map<String, dynamic>> _selectedServices = [];

  // Services tree for the modal and flat list for lookup.
  List<Map<String, dynamic>> _svcTree = []; // nodes: {name, services[], subs[]}
  List<Map<String, dynamic>> _branchServices = []; // flat items: {id, name, priceMinor, durationMin, path}
  bool _loadingServices = true;

  // Focused/active service (drives Professional filtering)
  int? _selectedServiceId;
  String? _selectedServiceName;

  // Team members
  List<Map<String, dynamic>> _teamMembers = [];
  bool _loadingMembers = false;

  /// NEW: per-service professional selection (key = serviceId, value = professional name or "Any")
  final Map<int, String> _professionalByService = {};

  String? get _activeProfessional {
    final sid = _selectedServiceId;
    if (sid == null) return null;
    return _professionalByService[sid];
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _clientfNameCtrl.dispose();
    _clientlNameCtrl.dispose();
    _clientIdCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    if (widget.branchId == null) return;
    try {
      final data = await ApiService().getBranchServiceDetail(widget.branchId!);

      final List<Map<String, dynamic>> flat = [];
      final List<Map<String, dynamic>> tree = [];
      final categories = data['categories'] as List? ?? [];

      for (final cat in categories) {
        final catName = (cat['displayName'] ?? '').toString().trim();
        final List catServices = cat['services'] as List? ?? [];
        final List subCats = cat['subCategories'] as List? ?? [];

        final catNode = {
          'name': catName,
          'services': <Map<String, dynamic>>[],
          'subs': <Map<String, dynamic>>[],
        };

        // services directly under category
        for (final svc in catServices) {
          final svcMap = {
            'id': svc['id'],
            'name': (svc['displayName'] ?? '').toString(),
            'priceMinor': svc['priceMinor'],
            'durationMin': svc['durationMin'],
            'path': [catName, (svc['displayName'] ?? '').toString()]
                .where((e) => (e as String).isNotEmpty)
                .join(' • '),
          };
          flat.add(svcMap);
          (catNode['services'] as List).add(svcMap);
        }

        // subcategories
        for (final sub in subCats) {
          final subName = (sub['displayName'] ?? '').toString().trim();
          final List subServices = sub['services'] as List? ?? [];
          final subNode = {
            'name': subName,
            'services': <Map<String, dynamic>>[],
          };
          for (final svc in subServices) {
            final svcMap = {
              'id': svc['id'],
              'name': (svc['displayName'] ?? '').toString(),
              'priceMinor': svc['priceMinor'],
              'durationMin': svc['durationMin'],
              'path': [catName, subName, (svc['displayName'] ?? '').toString()]
                  .where((e) => (e as String).isNotEmpty)
                  .join(' • '),
            };
            flat.add(svcMap);
            (subNode['services'] as List).add(svcMap);
          }
          (catNode['subs'] as List).add(subNode);
        }

        tree.add(catNode);
      }

      setState(() {
        _branchServices = flat; // quick lookup/totals
        _svcTree = tree; // for the modal UI
        _loadingServices = false;
      });
    } catch (e) {
      print("Error fetching services: $e");
      setState(() {
        _branchServices = [];
        _svcTree = [];
        _loadingServices = false;
      });
    }
  }
// Method to show search modal
void _showCustomerSearch() {
  showDialog(
    context: context,
    builder: (ctx) {
      final phoneCtrl = TextEditingController();
      String countryCode = "+91"; // default
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Search Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Country Code
                DropdownButton<String>(
                  value: countryCode,
                  items: ["+91", "+1", "+44"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) countryCode = v;
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      hintText: "Enter phone number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                if (phone.length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter 10-digit number")));
                  return;
                }

            try {
  final result = await ApiService()
      .resolveWalkinNumber(widget.branchId!, countryCode, phone);

 if (result['success'] == true && result['data'] != null) {
  final data = result['data'];

  // Customer exists in branch
  if (data is Map<String, dynamic> && data.containsKey('user')) {
    final user = data['user'] as Map<String, dynamic>;
    print("👤 User Map received: $user");
    Navigator.pop(ctx);
    _showCustomerDetails(user);
  }
  // Customer not found, OTP sent
  else if (data is Map<String, dynamic> && data['status'] == "OTP_SENT") {
    print("📲 OTP flow triggered");
    Navigator.pop(ctx);
    _showOtpBox(phone, countryCode);
  }
  else {
    print("⚠️ Unexpected data format: $data");
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Unexpected response from server")),
    );
  }
}
 else {
    Navigator.pop(ctx);
    _showOtpBox(phone, countryCode);
  }
} catch (e) {
  print("❌ Error: $e");
}

              },
              child: const Text("Search"),
            ),
          ],
        ),
      );
    },
  );
}

// Show Customer details modal
void _showCustomerDetails(Map<String, dynamic> customer) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Customer Found"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("ID: ${customer['id']}"),
          Text("First Name: ${customer['firstName']}"),
          Text("Last Name: ${customer['lastName']}"),
          Text("Email: ${customer['email']}"),
          Text("Phone: ${customer['fullPhoneNumber']}"),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // ✅ Fill controllers when OK is pressed
            setState(() {
              _clientIdCtrl.text   = (customer['id'] ?? '').toString();
              _clientfNameCtrl.text = (customer['firstName'] ?? '').toString();
              _clientlNameCtrl.text = (customer['lastName'] ?? '').toString();
              _mobileCtrl.text      = (customer['fullPhoneNumber'] ?? '').toString();
              _emailCtrl.text = customer['email'] != null ? customer['email'] : '';
            });

            Navigator.pop(ctx); // close modal
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

// Show OTP entry modal
void _showOtpBox(String phone, String countryCode) {
  final otpCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Enter OTP"),
      content: TextField(
        controller: otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: "Enter 6-digit OTP",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            print("➡️ OTP entered: ${otpCtrl.text}");
            Navigator.pop(ctx);
          },
          child: const Text("Verify"),
        ),
      ],
    ),
  );
}
  void _showServicePicker() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bool locked = false; // multi-select allowed at all times

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.design_services),
                      const SizedBox(width: 8),
                      const Text('Select Service',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: _svcTree.length,
                      itemBuilder: (_, i) {
                        final cat = _svcTree[i];
                        final catName = (cat['name'] ?? '').toString();
                        final List catSvcs =
                            (cat['services'] as List?) ?? const [];
                        final List subs = (cat['subs'] as List?) ?? const [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                catName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            for (final s in catSvcs)
                              _serviceTile(ctx, s, leftPad: 12, locked: locked),
                            for (final sub in subs) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 8, 0, 4),
                                child: Text(
                                  (sub['name'] ?? '').toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              for (final s in (sub['services'] as List))
                                _serviceTile(ctx, s,
                                    leftPad: 24, locked: locked),
                            ],
                            const Divider(height: 20),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      final v = picked['id'] as int;
      final name = (picked['name'] ?? '').toString();

      setState(() {
        final already = _selectedServices.any((s) => s['id'] == v);

        if (already) {
          // Deselect (remove)
          _selectedServices.removeWhere((s) => s['id'] == v);
          _professionalByService.remove(v); // drop its professional as well

          // If it was the active service, move focus to another selected one (or none)
          if (_selectedServiceId == v) {
            _selectedServiceId = _selectedServices.isNotEmpty
                ? _selectedServices.last['id'] as int
                : null;
            _selectedServiceName = _selectedServices.isNotEmpty
                ? _selectedServices.last['name'] as String
                : null;
            _staffRole = _selectedServiceName;
          }
        } else {
          // Add (select) this service
          _selectedServices.add({
            'id': v,
            'name': name,
            'price': picked['priceMinor'],
            'qty': 1,
            'durationMin': picked['durationMin'],
          });

          // Make the newly tapped service the ACTIVE one for pro filtering
          _selectedServiceId = v;
          _selectedServiceName = name;
          _staffRole = name;

          // Do NOT touch other services/professionals.
          // Just prompt the user to choose a pro for the new service.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Select Professional for "$name"')),
          );
        }
      });
    }
  }

  // Service row in the bottom sheet.
  Widget _serviceTile(
    BuildContext ctx,
    Map<String, dynamic> svc, {
    double leftPad = 0,
    bool locked = false,
  }) {
    final int svcId = svc['id'] as int;
    final String name = (svc['name'] ?? '').toString();
    final int? duration = svc['durationMin'] as int?;
    final num? priceMinor = svc['priceMinor'] as num?;
    final String priceText =
        priceMinor == null ? '' : '₹${priceMinor.toString()}';
    final String meta = [
      if (duration != null && duration > 0) '${duration} min',
      if (priceText.isNotEmpty) priceText,
    ].join(' • ');

    final bool isActive = _selectedServiceId == svcId;
    final bool isSelected =
        _selectedServices.any((e) => (e['id'] as int) == svcId);

    // Icon logic: active > selected > none
    final Widget trailing = isActive
        ? const Icon(Icons.radio_button_checked, color: Colors.orange)
        : (isSelected
            ? const Icon(Icons.check_box, color: Colors.grey)
            : const Icon(Icons.check_box_outline_blank, color: Colors.grey));

    return Padding(
      padding: EdgeInsets.only(left: leftPad),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8, right: 8),
        leading: const Icon(Icons.cut),
        title:
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: meta.isNotEmpty ? Text(meta) : null,
        trailing: trailing,
        onTap: () => Navigator.pop<Map<String, dynamic>>(ctx, svc),
      ),
    );
  }

  Future<void> _loadTeamMembers() async {
    if (widget.branchId == null) return;
    setState(() => _loadingMembers = true);

    try {
      final response = await ApiService.getTeamMembers(widget.branchId!);
      if (response['success'] == true) {
        final List members = response['data'] ?? [];
        setState(() {
          _teamMembers = members.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print("Error loading team members: $e");
    } finally {
      setState(() => _loadingMembers = false);
    }
  }

  List<Map<String, dynamic>> _filterMembersByServices() {
    final int? currentBranchId = widget.branchId;
    final int? selectedId = _selectedServiceId; // strict match by ID

    if (selectedId == null) return [];

    final matches = _teamMembers.where((member) {
      final branches = member['userBranches'] as List? ?? [];
      for (final ub in branches) {
        final b = ub['branch'] as Map<String, dynamic>?;
        final int? bId = b?['id'] as int?;
        if (currentBranchId != null && bId != currentBranchId) continue;

        final services = ub['userBranchServices'] as List? ?? [];
        for (final s in services) {
          final bs = s['branchService'] as Map<String, dynamic>?;
          final int? serviceId = bs?['id'] as int?;
          if (serviceId == selectedId) return true;
        }
      }
      return false;
    }).toList();

    return matches;
  }

  Map<int, int> _selectedQtyMap() {
    final map = <int, int>{};
    for (final s in _selectedServices) {
      final id = s['id'] as int;
      final int qty = (s['qty'] ?? 0) as int;
      if (qty > 0) map[id] = qty;
    }
    return map;
  }

  double get _servicesTotal {
    double sum = 0;
    for (final s in _selectedServices) {
      final num price = (s['price'] ?? 0) as num; // in rupees already
      final int qty = (s['qty'] ?? 0) as int;
      sum += (price * qty).toDouble();
    }
    return sum;
  }

  String _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }
  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('EEE, MMM d, yyyy').format(d);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day), // today onwards
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime =
        (isStart ? _startTime : _endTime) ??
            const TimeOfDay(hour: 9, minute: 0);
    final picked =
        await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Ensure end >= start
          if (_endTime != null) {
            final s = _toMinutes(_startTime!);
            final e = _toMinutes(_endTime!);
            if (e <= s) {
              _endTime = TimeOfDay(
                  hour: picked.hour, minute: (picked.minute + 30) % 60);
            }
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // void _save() {
  //   if (!_formKey.currentState!.validate()) return;

  //   if (_selectedServiceId == null || _selectedServices.isEmpty) {
  //     _showError('Please select Service');
  //     return;
  //   }

  //   // ENFORCE: Each selected service must have a professional
  //   final missing = _selectedServices
  //       .where((s) => !_professionalByService.containsKey(s['id']))
  //       .map((s) => (s['name'] ?? '').toString())
  //       .toList();
  //   if (missing.isNotEmpty) {
  //     _showError('Please select Professional for: ${missing.join(", ")}');
  //     return;
  //   }

  //   // validate date/time
  //   if (_selectedDate == null) {
  //     _showError('Please select a date');
  //     return;
  //   }
  //   if (_startTime == null || _endTime == null) {
  //     _showError('Please select start and end time');
  //     return;
  //   }

  //   // Back-compat (single-service)
  //   String? legacyProfessional;
  //   if (_selectedServices.length == 1) {
  //     final onlyId = _selectedServices.first['id'] as int;
  //     legacyProfessional = _professionalByService[onlyId];
  //   }

  //   final payload = {
  //     'clientfName': _clientfNameCtrl.text.trim(),
  //     'clientlName': _clientlNameCtrl.text.trim(),
  //     'clientId': _clientIdCtrl.text.trim(),
  //     'phone': _mobileCtrl.text.trim(),
  //     'email': _emailCtrl.text.trim(),
  //     'staffRole': _staffRole,
  //     'professional': legacyProfessional, // legacy single-service field
  //     'professionalsByService': _professionalByService, // preferred
  //     'date': _formatDate(_selectedDate),
  //     'dateISO': _selectedDate!.toIso8601String(),
  //     'startTime': _formatTimeOfDay(_startTime),
  //     'endTime': _formatTimeOfDay(_endTime),
  //     'services': _selectedServices,
  //     'salonId': widget.salonId,
  //     'branchId': widget.branchId,
  //     'servicesTotal': _servicesTotal,
  //   };

  //   Navigator.pop(context, payload);
  // }
void _save() async {
  if (!_formKey.currentState!.validate()) return;

  if (_selectedServiceId == null || _selectedServices.isEmpty) {
    _showError('Please select Service');
    return;
  }

  final missing = _selectedServices
      .where((s) => !_professionalByService.containsKey(s['id']))
      .map((s) => (s['name'] ?? '').toString())
      .toList();
  if (missing.isNotEmpty) {
    _showError('Please select Professional for: ${missing.join(", ")}');
    return;
  }

  if (_selectedDate == null) {
    _showError('Please select a date');
    return;
  }
  if (_startTime == null || _endTime == null) {
    _showError('Please select start and end time');
    return;
  }

  // build startAt (ISO date + start time)
  final startDateTime = DateTime(
    _selectedDate!.year,
    _selectedDate!.month,
    _selectedDate!.day,
    _startTime!.hour,
    _startTime!.minute,
  );

  final payload = {
    "userId": int.tryParse(_clientIdCtrl.text.trim()) ?? 0,
    "startAt": startDateTime.toIso8601String(),
    "services": _selectedServices.map((s) {
      return {
        "branchServiceId": s['id'],
        "assignedUserBranchId": 0, // update if you have staff assignment
      };
    }).toList(),
  };

  try {
    final result = await ApiService()
        .createAppointment(widget.branchId!, payload);

    print("✅ Appointment Created: $result");

    Navigator.pop(context, result); // send back API response
  } catch (e) {
    _showError("Failed to create appointment: $e");
  }
}

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final matched = _filterMembersByServices();
    final List<String> proItems = _loadingMembers
        ? <String>[]
        : (() {
            final names = matched
                .map((m) =>
                    "${m['firstName']} ${m['lastName'] ?? ''}".trim())
                .toList();
            // Always include "Any" at the top
            return <String>['Any', ...names];
          })();

    final proHint = _loadingMembers
        ? 'Loading...'
        : (_selectedServiceId == null
            ? 'Choose'
            : (proItems.length == 1 && proItems.first != 'Any'
                ? 'Choose'
                : 'Choose / Any'));

    // Chips should show only for services that already have a professional
    final chipServices = _selectedServices
        .where((s) => _professionalByService.containsKey(s['id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Booking'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name
                Text(
                    'Salon & Branch Id: ${widget.salonId ?? '-'} / ${widget.branchId ?? '-'}'),
                const _FieldLabel('Add Customer *'),
ElevatedButton(
  onPressed: _showCustomerSearch,
  child: const Text("Add Customer"),
),  
                const SizedBox(height: 16),
                //ID
                const _FieldLabel('Customer ID'),
                TextFormField(
                  controller: _clientIdCtrl,
                  decoration: _inputDecoration('Customer ID'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Client Name (First + Last side by side)
Row(
  children: [
    // First Name
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('First Name *'),
          TextFormField(
            controller: _clientfNameCtrl,
            decoration: _inputDecoration('First name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    ),
    const SizedBox(width: 12), // spacing between fields
    // Last Name
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Last Name *'),
          TextFormField(
            controller: _clientlNameCtrl,
            decoration: _inputDecoration('Last name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    ),
  ],
),

                const SizedBox(height: 16),

                // Mobile
                const _FieldLabel('Mobile Number *'),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Enter mobile number'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                 // Email
                const _FieldLabel('Email *'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Enter Email'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Service (hierarchical) + Professional (per active service)
                Row(
                  children: [
                    // Left: Services *
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Services *'),
                          InkWell(
                            onTap: _loadingServices || _svcTree.isEmpty
                                ? null
                                : _showServicePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.design_services, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedServiceId == null
                                          ? 'Choose'
                                          : (_branchServices.firstWhere(
                                                  (e) =>
                                                      e['id'] ==
                                                      _selectedServiceId)['path']
                                              as String),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Right: Professional * (applies to ACTIVE service)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Professional *'),
                          _Dropdown<String>(
                            value: _activeProfessional,
                            hint: proHint,
                            items: proItems,
                            // If no active service or members loading, disable change
                            onChanged:
                                (_selectedServiceId == null || _loadingMembers)
                                    ? (_) {}
                                    : (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _professionalByService[_selectedServiceId!] = v;
                                        });
                                      },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // SHOW CHIPS: only for services which already have a professional
                if (chipServices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: chipServices.map((s) {
                      final id = s['id'] as int;
                      final name = (s['name'] ?? '').toString();
                      final qty = (s['qty'] ?? 1) as int;
                      final dur = s['durationMin'] != null
                          ? '${s['durationMin']}m'
                          : '';
                      final price =
                          s['price'] != null ? '₹${s['price']}' : '';
                      final pro = _professionalByService[id] ?? '';
                      final meta = [
                        if (dur.isNotEmpty) dur,
                        if (price.isNotEmpty) price,
                        if (pro.isNotEmpty) pro,
                      ].join(' • ');

                      return Chip(
                        label: Text(
                          meta.isEmpty ? '$name x$qty' : '$name x$qty  —  $meta',
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedServices
                                .removeWhere((e) => e['id'] == id);
                            _professionalByService.remove(id);

                            if (_selectedServiceId == id) {
                              _selectedServiceId =
                                  _selectedServices.isNotEmpty
                                      ? _selectedServices.last['id'] as int
                                      : null;
                              _selectedServiceName =
                                  _selectedServices.isNotEmpty
                                      ? _selectedServices.last['name'] as String
                                      : null;
                              _staffRole = _selectedServiceName;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 20),
                // Date picker (above Start/End Time)
                const _FieldLabel('Date *'),
                InkWell(
                  onTap: _pickDate,
                  child: _TimeBox(
                    text: _selectedDate == null
                        ? 'Select date'
                        : _formatDate(_selectedDate),
                  ),
                ),
                const SizedBox(height: 12),

                // Start / End time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Start Time *'),
                          InkWell(
                            onTap: () => _pickTime(isStart: true),
                            child: _TimeBox(
                                text: _startTime == null
                                    ? 'Start Time'
                                    : _formatTimeOfDay(_startTime)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('End Time *'),
                          InkWell(
                            onTap: () => _pickTime(isStart: false),
                            child: _TimeBox(
                                text: _endTime == null
                                    ? 'End Time'
                                    : _formatTimeOfDay(_endTime)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
    );

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged; // keep non-nullable
  final String hint;

  const _Dropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDisabled = items.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              const SizedBox(width: 6),
              Text(hint),
            ],
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          onChanged: isDisabled ? (_) {} : onChanged, // use no-op when disabled
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String text;
  const _TimeBox({Key? key, required this.text}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? 'Select' : text)),
        ],
      ),
    );
  }
}
