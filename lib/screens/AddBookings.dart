import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SelectServices.dart';
import '../utils/api_service.dart';
import 'package:flutter/services.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

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
  List<Map<String, dynamic>> _branchClientsCache = [];

  // Keep existing names so your payload stays the same.
  String? _staffRole; // we'll sync this to the selected service name
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TimeOfDay? _branchStartTime;
  TimeOfDay? _branchEndTime;
  String? _serviceError;
  String? _professionalError;
  String? _firstNameError;
  String? _lastNameError;

  bool get _hasCustomerDetails {
    return _clientIdCtrl.text.trim().isNotEmpty ||
        _clientfNameCtrl.text.trim().isNotEmpty ||
        _clientlNameCtrl.text.trim().isNotEmpty;
  }

  // Selected services from modal: each {id, name, price, qty, durationMin}
  List<Map<String, dynamic>> _selectedServices = [];

  // Services tree for the modal and flat list for lookup.
  List<Map<String, dynamic>> _svcTree = []; // nodes: {name, services[], subs[]}
  List<Map<String, dynamic>> _branchServices =
      []; // flat items: {id, name, priceMinor, durationMin, path}
  bool _loadingServices = true;
  bool _isSaving = false;

  // Focused/active service (drives Professional filtering)
  int? _selectedServiceId;
  String? _selectedServiceName;

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
    _loadBranchTiming();

    // Set default date to today
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Set default times
    _startTime = const TimeOfDay(hour: 8, minute: 0); // 08:00 AM
    _endTime = const TimeOfDay(hour: 8, minute: 30); // 08:00 PM
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

  TimeOfDay? _parseApiTimeOfDay(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _loadBranchTiming() async {
    final branchId = widget.branchId;
    if (branchId == null) return;
    try {
      final response = await ApiService().getBranchDetail(branchId);
      final data = response['data'];
      if (data is! Map) return;
      final details = Map<String, dynamic>.from(data);
      final start = _parseApiTimeOfDay(details['startTime']);
      final end = _parseApiTimeOfDay(details['endTime']);
      if (!mounted) return;
      setState(() {
        _branchStartTime = start;
        _branchEndTime = end;
        if (start != null) {
          _startTime = start;
          _syncEndTimeWithDuration();
        }
      });
    } catch (_) {
      // Fallback to default values when branch details are unavailable.
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  Map<String, dynamic> _normalizeCustomer(dynamic raw) {
    final base =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (base['user'] is Map) {
      final user = Map<String, dynamic>.from(base['user'] as Map);
      for (final entry in base.entries) {
        user.putIfAbsent(entry.key, () => entry.value);
      }
      return user;
    }
    return base;
  }

  List<Map<String, dynamic>> _extractBranchClients(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => _normalizeCustomer(item))
          .toList();
    }

    if (raw is Map) {
      for (final key in const ['clients', 'items', 'results', 'data']) {
        final nested = raw[key];
        if (nested != null) {
          final extracted = _extractBranchClients(nested);
          if (extracted.isNotEmpty) {
            return extracted;
          }
        }
      }
      return raw.isEmpty
          ? const []
          : <Map<String, dynamic>>[_normalizeCustomer(raw)];
    }

    return const [];
  }

  String _customerDisplayPhone(Map<String, dynamic> customer) {
    final fullPhone = (customer['fullPhoneNumber'] ?? '').toString().trim();
    if (fullPhone.isNotEmpty) return fullPhone;
    final digits = _digitsOnly((customer['phoneNumber'] ?? '').toString());
    if (digits.isEmpty) return '';
    return digits.startsWith('91') && digits.length > 10
        ? '+$digits'
        : '+91$digits';
  }

  void _fillCustomerFields(
    Map<String, dynamic> customer, {
    String? fallbackPhone,
    String? fallbackFirstName,
    String? fallbackLastName,
  }) {
    final firstName =
        (customer['firstName'] ?? fallbackFirstName ?? '').toString();
    final lastName =
        (customer['lastName'] ?? fallbackLastName ?? '').toString();
    final phoneDigits = _digitsOnly(
      (customer['phoneNumber'] ??
              customer['fullPhoneNumber'] ??
              fallbackPhone ??
              '')
          .toString(),
    );
    final fullPhone = _customerDisplayPhone(customer);

    setState(() {
      _clientIdCtrl.text = (customer['id'] ?? '').toString();
      _clientfNameCtrl.text = firstName;
      _clientlNameCtrl.text = lastName;
      _mobileCtrl.text = fullPhone.isNotEmpty ? fullPhone : phoneDigits;
      _emailCtrl.text = (customer['email'] ?? '').toString();
      _firstNameError = null;
      _lastNameError = null;
    });
  }

  void _clearCustomerSelection() {
    setState(() {
      _clientIdCtrl.clear();
      _clientfNameCtrl.clear();
      _clientlNameCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
      _firstNameError = null;
      _lastNameError = null;
    });
  }

  int _totalSelectedDurationMinutes() {
    var total = 0;
    for (final service in _selectedServices) {
      final duration = service['durationMin'];
      if (duration is int) {
        total += duration;
      } else if (duration is num) {
        total += duration.toInt();
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _membersForService(int serviceId) {
    final members = <Map<String, dynamic>>[];
    final currentBranchId = widget.branchId;

    for (final member in _teamMembers) {
      final branches = member['userBranches'] as List? ?? const [];
      for (final entry in branches) {
        if (entry is! Map) continue;
        final branchEntry = Map<String, dynamic>.from(entry);
        final branch = branchEntry['branch'];
        final branchMap =
            branch is Map ? Map<String, dynamic>.from(branch) : {};
        final branchId = branchMap['id'] is int
            ? branchMap['id'] as int
            : int.tryParse('${branchMap['id'] ?? ''}');
        if (currentBranchId != null && branchId != currentBranchId) continue;

        final services = branchEntry['userBranchServices'] as List? ?? const [];
        final hasService = services.any((item) {
          if (item is! Map) return false;
          final branchService = item['branchService'];
          if (branchService is! Map) return false;
          final id = branchService['id'];
          if (id is int) return id == serviceId;
          if (id is num) return id.toInt() == serviceId;
          return int.tryParse('$id') == serviceId;
        });
        if (!hasService) continue;

        final name =
            "${member['firstName'] ?? ''} ${member['lastName'] ?? ''}".trim();
        final userBranchId = branchEntry['id'] is int
            ? branchEntry['id'] as int
            : int.tryParse('${branchEntry['id'] ?? ''}') ??
                (member['id'] is int
                    ? member['id'] as int
                    : int.tryParse('${member['id'] ?? ''}'));
        if (name.isEmpty || userBranchId == null) continue;

        members.add({
          'label': name,
          'userBranchId': userBranchId,
        });
        break;
      }
    }

    return members;
  }

  void _syncEndTimeWithDuration() {
    final start = _startTime;
    if (start == null) return;

    final totalDuration = _totalSelectedDurationMinutes();
    final startMinutes = _toMinutes(start);
    final computedEndMinutes = startMinutes + totalDuration;
    final branchEndMinutes =
        _branchEndTime == null ? null : _toMinutes(_branchEndTime!);

    if (branchEndMinutes != null && computedEndMinutes > branchEndMinutes) {
      _endTime = null;
      return;
    }

    _endTime = TimeOfDay(
      hour: (computedEndMinutes ~/ 60) % 24,
      minute: computedEndMinutes % 60,
    );
  }

  String _branchTimingLabel() {
    if (_branchStartTime == null || _branchEndTime == null) {
      return '';
    }
    return '${_formatTimeOfDay(_branchStartTime)} - ${_formatTimeOfDay(_branchEndTime)}';
  }

  void _upsertBranchClientCache(Map<String, dynamic> customer) {
    if (customer.isEmpty) return;
    final id = (customer['id'] ?? '').toString().trim();
    final phone = _digitsOnly(
      (customer['phoneNumber'] ?? customer['fullPhoneNumber'] ?? '').toString(),
    );
    final matchIndex = _branchClientsCache.indexWhere((existing) {
      final existingId = (existing['id'] ?? '').toString().trim();
      final existingPhone = _digitsOnly(
        (existing['phoneNumber'] ?? existing['fullPhoneNumber'] ?? '')
            .toString(),
      );
      return (id.isNotEmpty && existingId == id) ||
          (phone.isNotEmpty && existingPhone == phone);
    });

    if (matchIndex >= 0) {
      _branchClientsCache[matchIndex] = customer;
    } else {
      _branchClientsCache.insert(0, customer);
    }
  }

  Future<void> _showOtpBox(
    String phone, {
    required String firstName,
    required String lastName,
  }) async {
    final otpCtrl = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(translateText("Verify OTP")),
          content: TextField(
            controller: otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: translateText("Enter 6-digit OTP"),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(ctx),
              child: Text(translateText("Cancel")),
            ),
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final otp = otpCtrl.text.trim();
                      if (otp.length != 6) {
                        _showError(translateText("Enter 6-digit OTP"));
                        return;
                      }

                      setDialogState(() => isVerifying = true);
                      try {
                        final response =
                            await ApiService().verifyOTP(phone, otp);
                        Map<String, dynamic> customer = {};
                        final data = response['data'];
                        if (data is Map) {
                          customer = _normalizeCustomer(data);
                        }
                        if (customer.isEmpty && widget.branchId != null) {
                          final clientsResponse = await ApiService()
                              .getBranchClients(widget.branchId!);
                          final clients =
                              _extractBranchClients(clientsResponse['data']);
                          customer = clients.firstWhere(
                            (item) =>
                                _digitsOnly(
                                  (item['phoneNumber'] ??
                                          item['fullPhoneNumber'] ??
                                          '')
                                      .toString(),
                                ) ==
                                phone,
                            orElse: () => <String, dynamic>{},
                          );
                        }
                        _fillCustomerFields(
                          customer,
                          fallbackPhone: phone,
                          fallbackFirstName: firstName,
                          fallbackLastName: lastName,
                        );
                        _upsertBranchClientCache({
                          ...customer,
                          if (!customer.containsKey('phoneNumber'))
                            'phoneNumber': phone,
                          if (!customer.containsKey('firstName'))
                            'firstName': firstName,
                          if (!customer.containsKey('lastName'))
                            'lastName': lastName,
                        });
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      } catch (e) {
                        _showError(e.toString());
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isVerifying = false);
                        }
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(translateText("Verify")),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCustomerModal({String initialPhone = ''}) async {
    final phoneCtrl = TextEditingController(text: _digitsOnly(initialPhone));
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(translateText("Add New Customer")),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: firstCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: translateText("First Name"),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: translateText("Last Name"),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: translateText("Phone Number"),
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(translateText("Cancel")),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final firstName = firstCtrl.text.trim();
                      final lastName = lastCtrl.text.trim();
                      final phone = _digitsOnly(phoneCtrl.text.trim());
                      if (firstName.isEmpty || lastName.isEmpty) {
                        _showError(translateText(
                            "First name and last name are required"));
                        return;
                      }
                      if (phone.length != 10) {
                        _showError(translateText("Enter a valid phone number"));
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ApiService().registerCustomer(
                          phoneNumber: phone,
                          firstName: firstName,
                          lastName: lastName,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _showOtpBox(
                          phone,
                          firstName: firstName,
                          lastName: lastName,
                        );
                      } catch (e) {
                        _showError(e.toString());
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(translateText("Continue")),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerSearch() async {
    if (widget.branchId == null) return;

    List<Map<String, dynamic>> clients = [];
    try {
      final response = await ApiService().getBranchClients(widget.branchId!);
      clients = _extractBranchClients(response['data']);
      for (final customer in _branchClientsCache) {
        final normalized = _normalizeCustomer(customer);
        final id = (normalized['id'] ?? '').toString().trim();
        final phone = _digitsOnly(
          (normalized['phoneNumber'] ?? normalized['fullPhoneNumber'] ?? '')
              .toString(),
        );
        final alreadyExists = clients.any((existing) {
          final existingId = (existing['id'] ?? '').toString().trim();
          final existingPhone = _digitsOnly(
            (existing['phoneNumber'] ?? existing['fullPhoneNumber'] ?? '')
                .toString(),
          );
          return (id.isNotEmpty && existingId == id) ||
              (phone.isNotEmpty && existingPhone == phone);
        });
        if (!alreadyExists) {
          clients.insert(0, normalized);
        }
      }
      _branchClientsCache = List<Map<String, dynamic>>.from(clients);
    } catch (e) {
      _showError(e.toString());
    }
    if (!mounted) return;

    final searchCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final queryDigits = _digitsOnly(query);
          final filteredClients = clients.where((client) {
            if (query.isEmpty) return true;
            final firstName =
                (client['firstName'] ?? '').toString().toLowerCase();
            final lastName =
                (client['lastName'] ?? '').toString().toLowerCase();
            final fullName = '$firstName $lastName'.trim();
            final phone = _digitsOnly(
              (client['phoneNumber'] ?? client['fullPhoneNumber'] ?? '')
                  .toString(),
            );
            final matchesName = firstName.contains(query) ||
                lastName.contains(query) ||
                fullName.contains(query);
            final matchesPhone =
                queryDigits.isNotEmpty && phone.contains(queryDigits);
            return matchesName || matchesPhone;
          }).toList();

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 520,
              height: 420,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText("Select Customer"),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: translateText("Search customer..."),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filteredClients.isNotEmpty) ...[
                      Text(
                        translateText("Existing Customers"),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredClients.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final customer = filteredClients[index];
                            final name =
                                "${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}"
                                    .trim();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                name.isEmpty
                                    ? translateText("Unnamed customer")
                                    : name,
                              ),
                              subtitle: Text(_customerDisplayPhone(customer)),
                              onTap: () {
                                _fillCustomerFields(customer);
                                _upsertBranchClientCache(customer);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            translateText("No existing customer found"),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showAddCustomerModal(
                              initialPhone: queryDigits);
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(translateText("Add New Customer")),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(translateText("Cancel")),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                      Icon(Icons.design_services),
                      SizedBox(width: 8),
                      Text(translateText('Select Service'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
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
                              padding: const EdgeInsets.symmetric(vertical: 6),
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
                                padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
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

    // if (picked != null) {
    //   final v = picked['id'] as int;
    //   final name = (picked['name'] ?? '').toString();

    //   setState(() {
    //     final already = _selectedServices.any((s) => s['id'] == v);

    //     if (already) {
    //       // Deselect (remove)
    //       _selectedServices.removeWhere((s) => s['id'] == v);
    //       _professionalByService.remove(v); // drop its professional as well

    //       // If it was the active service, move focus to another selected one (or none)
    //       if (_selectedServiceId == v) {
    //         _selectedServiceId = _selectedServices.isNotEmpty
    //             ? _selectedServices.last['id'] as int
    //             : null;
    //         _selectedServiceName = _selectedServices.isNotEmpty
    //             ? _selectedServices.last['name'] as String
    //             : null;
    //         _staffRole = _selectedServiceName;
    //       }
    //     } else {
    //       // Add (select) this service
    //       _selectedServices.add({
    //         'id': v,
    //         'name': name,
    //         'price': picked['priceMinor'],
    //         'qty': 1,
    //         'durationMin': picked['durationMin'],
    //       });

    //       // Make the newly tapped service the ACTIVE one for pro filtering
    //       _selectedServiceId = v;
    //       _selectedServiceName = name;
    //       _staffRole = name;

    //       // Do NOT touch other services/professionals.
    //       // Just prompt the user to choose a pro for the new service.
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(content: Text(translateText('Select Professional for {name}', params: {'name': name}))),
    //       );
    //     }
    //   });
    // }
    if (picked != null) {
      final v = picked['id'] as int;
      final name = (picked['name'] ?? '').toString();

      setState(() {
        final already = _selectedServices.any((s) => s['id'] == v);

        if (already) {
          // Deselect (remove)
          _selectedServices.removeWhere((s) => s['id'] == v);
          _professionalByService.remove(v);

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

          _selectedServiceId = v;
          _selectedServiceName = name;
          _staffRole = name;
        }

        // ✅ Clear the service error when user selects/deselects a service
        _serviceError = null;
        _professionalError = null;
        _syncEndTimeWithDuration();
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

    final bool isSelected =
        _selectedServices.any((e) => (e['id'] as int) == svcId);

    final Widget trailing = Icon(
      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
      color: isSelected ? Colors.orange : Colors.grey,
    );

    return Padding(
      padding: EdgeInsets.only(left: leftPad),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8, right: 8),
        leading: Icon(Icons.cut),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  int? _resolveAssignedUserBranchId(int serviceId) {
    final selectedProfessional = _professionalByService[serviceId];
    if (selectedProfessional == null || selectedProfessional.isEmpty) {
      return null;
    }

    for (final option in _membersForService(serviceId)) {
      if (option['label'] == selectedProfessional) {
        return option['userBranchId'] as int?;
      }
    }
    return null;
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
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate != null && !_selectedDate!.isBefore(today)
        ? _selectedDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today, // today onwards
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    if (!isStart) return;

    final initialTime =
        _startTime ?? _branchStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked =
        await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      final pickedMinutes = _toMinutes(picked);
      final branchStartMinutes =
          _branchStartTime == null ? null : _toMinutes(_branchStartTime!);
      final branchEndMinutes =
          _branchEndTime == null ? null : _toMinutes(_branchEndTime!);
      final computedEndMinutes =
          pickedMinutes + _totalSelectedDurationMinutes();

      if (branchStartMinutes != null && pickedMinutes < branchStartMinutes) {
        _showError(translateText('Start time must be within branch timings'));
        return;
      }
      if (branchEndMinutes != null && computedEndMinutes > branchEndMinutes) {
        _showError(translateText('Selected time exceeds branch timings'));
        return;
      }

      setState(() {
        _startTime = picked;
        _syncEndTimeWithDuration();
      });
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServiceId == null || _selectedServices.isEmpty) {
      setState(() {
        _serviceError = translateText('Service is required');
      });
      _showError(translateText('Please select Service'));
      return;
    } else {
      setState(() {
        _serviceError = null;
      });
    }

    if (_selectedDate == null) {
      _showError(translateText('Please select a date'));
      return;
    }
    final userId = int.tryParse(_clientIdCtrl.text.trim());
    if (userId == null) {
      _showError(translateText('Please select or verify a customer first'));
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showError(translateText('Please select start and end time'));
      return;
    }
    if (_selectedServices.any(
      (service) => (_professionalByService[service['id'] as int] ?? '').isEmpty,
    )) {
      setState(() {
        _professionalError =
            translateText('Please select team member for every service');
      });
      _showError(translateText('Please select team member for every service'));
      return;
    }

    final payload = {
      "userId": userId,
      "date": DateFormat('yyyy-MM-dd').format(_selectedDate!),
      "startAt":
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      "endAt":
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      "services": _selectedServices.map((s) {
        return {
          "branchServiceId": s['id'],
          "assignedUserBranchId": _resolveAssignedUserBranchId(s['id'] as int),
        };
      }).toList(),
    };
    print("Booking payload: $payload");
    setState(() {
      _isSaving = true;
    });
    try {
      final result =
          await ApiService().createManualBooking(widget.branchId!, payload);

      print("✅ Appointment Created: $result");

      Navigator.pop(context, result); // send back API response
    } catch (e) {
      _showError(_extractApiErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  String _extractApiErrorMessage(Object error) {
    var text = error.toString().trim();
    const exceptionPrefix = 'Exception:';
    if (text.startsWith(exceptionPrefix)) {
      text = text.substring(exceptionPrefix.length).trim();
    }

    for (final prefix in const [
      'Failed to create manual booking:',
      'Failed to create appointment:',
    ]) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        final errorValue = decoded['error'];
        if (errorValue is String && errorValue.trim().isNotEmpty) {
          return errorValue.trim();
        }
      }
    } catch (_) {
      // Leave the original text when the payload is not JSON.
    }

    return text;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final chipServices = _selectedServices;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('Add Booking'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child:
//              Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Client Name
//                 Text(
//                     'Salon & Branch Id: ${widget.salonId ?? '-'} / ${widget.branchId ?? '-'}'),
//                 const _FieldLabel('Add Customer *'),
// ElevatedButton(
//   onPressed: _showCustomerSearch,
//   child: Text("Add Customer"),
// ),
//                 SizedBox(height: 16),
                Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salon & Branch info
                // Text(
                //   'Salon & Branch Id: ${widget.salonId ?? '-'} / ${widget.branchId ?? '-'}',
                //   style: const TextStyle(
                //     fontSize: 16,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
                // SizedBox(height: 16),

                if (_hasCustomerDetails)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  _clientfNameCtrl.text.trim(),
                                  _clientlNameCtrl.text.trim(),
                                ].where((part) => part.isNotEmpty).join(' '),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              if (_mobileCtrl.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _mobileCtrl.text.trim(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _clearCustomerSelection,
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showCustomerSearch,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/plusIcn.png',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            translateText("Add Customer"),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Mobile
                // const _FieldLabel('Mobile Number *'),
                // TextFormField(
                //   controller: _mobileCtrl,
                //   keyboardType: TextInputType.phone,
                //   decoration: _inputDecoration('Enter mobile number'),
                //   validator: (v) =>
                //       (v == null || v.trim().isEmpty) ? 'Moblile Number is Required' : null,
                // ),
                // SizedBox(height: 16),
                //  // Email
                // const _FieldLabel('Email *'),
                // TextFormField(
                //   controller: _emailCtrl,
                //   keyboardType: TextInputType.phone,
                //   decoration: _inputDecoration('Enter Email'),
                //   validator: (v) =>
                //       (v == null || v.trim().isEmpty) ? 'Email is Required' : null,
                // ),
                // SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(translateText('Services *')),
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
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedServiceId == null
                                    ? translateText('Choose')
                                    : (_branchServices.firstWhere((e) =>
                                        e['id'] ==
                                        _selectedServiceId)['path'] as String),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                    ),
                    if (_serviceError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          _serviceError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                if (chipServices.isNotEmpty) ...[
                  SizedBox(height: 16),
                  ...chipServices.map((s) {
                    final id = s['id'] as int;
                    final name = (s['name'] ?? '').toString();
                    final dur = s['durationMin'] != null
                        ? '${s['durationMin']} min'
                        : '';
                    final price = s['price'] != null ? 'Rs ${s['price']}' : '';
                    final members = _membersForService(id);
                    final selectedMember = _professionalByService[id];

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (dur.isNotEmpty) dur,
                                        if (price.isNotEmpty) price,
                                      ].join(', '),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedServices.removeWhere(
                                      (e) => e['id'] == id,
                                    );
                                    _professionalByService.remove(id);
                                    _syncEndTimeWithDuration();

                                    if (_selectedServiceId == id) {
                                      _selectedServiceId = _selectedServices
                                              .isNotEmpty
                                          ? _selectedServices.last['id'] as int
                                          : null;
                                      _selectedServiceName =
                                          _selectedServices.isNotEmpty
                                              ? _selectedServices.last['name']
                                                  as String
                                              : null;
                                      _staffRole = _selectedServiceName;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedMember,
                                isExpanded: true,
                                hint: Text(translateText('Select Team Member')),
                                items: members
                                    .map(
                                      (member) => DropdownMenuItem<String>(
                                        value: member['label'] as String,
                                        child: Text(member['label'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == null) {
                                      _professionalByService.remove(id);
                                    } else {
                                      _professionalByService[id] = value;
                                    }
                                    _professionalError = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (members.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Text(
                                translateText('No team members found'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_professionalError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _professionalError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],

                SizedBox(height: 20),
                // Date picker (above Start/End Time)
                // const _FieldLabel('Date *'),
                // InkWell(
                //   // onTap: _pickDate,
                //     onTap: null,
                //   child: _TimeBox(
                //     text: _selectedDate == null
                //         ? 'Select date'
                //         : _formatDate(_selectedDate),
                //   ),
                // ),
                _FieldLabel(translateText('Date *')),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? translateText('Select date')
                                : _formatDate(_selectedDate),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),

                if (_branchTimingLabel().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${translateText('Branch timings')}: ${_branchTimingLabel()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(translateText('Start Time *')),
                          InkWell(
                            onTap: chipServices.isEmpty
                                ? null
                                : () => _pickTime(isStart: true),
                            child: _TimeBox(
                              text: _startTime == null
                                  ? translateText('Start Time')
                                  : _formatTimeOfDay(_startTime),
                              enabled: chipServices.isNotEmpty,
                            ),
                          ),
                          if (chipServices.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              translateText(
                                  'Select at least one service to choose start time'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(translateText('End Time *')),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _TimeBox(
                              text: _endTime == null
                                  ? translateText('End Time')
                                  : _formatTimeOfDay(_endTime),
                              enabled: false,
                              trailingText: translateText('Auto'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Text(
                          //   translateText(
                          //       'End time is auto-adjusted from start time and selected services'),
                          //   style: const TextStyle(
                          //     fontSize: 12,
                          //     color: Color(0xFF6B7280),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),
                if (chipServices.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(translateText('Total Duration')),
                            const Spacer(),
                            Text('${_totalSelectedDurationMinutes()} min'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(translateText('Total Price')),
                            const Spacer(),
                            Text(
                                'Rs ${chipServices.fold<num>(0, (sum, service) {
                              final price = service['price'];
                              return sum + ((price is num) ? price : 0);
                            })}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (chipServices.isNotEmpty) const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            translateText('Save'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              SizedBox(width: 6),
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
  final bool enabled;
  final String? trailingText;
  const _TimeBox({
    Key? key,
    required this.text,
    this.enabled = true,
    this.trailingText,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final borderColor =
        enabled ? Colors.grey.shade300 : const Color(0xFFD1D5DB);
    final backgroundColor = enabled ? Colors.white : const Color(0xFFF3F4F6);
    final iconColor = enabled ? Colors.black87 : const Color(0xFF9CA3AF);
    final textColor = enabled ? Colors.black87 : const Color(0xFF6B7280);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? 'Select' : text,
              style: TextStyle(color: textColor),
            ),
          ),
          if (trailingText != null && trailingText!.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              trailingText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
