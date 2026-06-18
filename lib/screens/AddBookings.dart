// ignore_for_file: file_names

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/api_service.dart';
import 'package:flutter/services.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/price_formatter.dart';
import 'view_all_client_owner.dart';

const Color _bookingGold = Color(0xFF8B6500);
const Color _bookingGoldLight = Color(0xFFD0A244);
const Color _bookingInk = Color(0xFF1F1B18);
const Color _bookingMuted = Color(0xFF6F665E);
const Color _bookingBorder = Color(0xFFE8DED6);
const Color _bookingFieldFill = Color(0xFFF7F4F3);
final RegExp _customerNamePattern = RegExp(r'^[A-Za-z ]+$');
final RegExp _customerPhonePattern = RegExp(r'^[6-9][0-9]{9}$');

class AddBookingScreen extends StatefulWidget {
  final int? salonId; // needed for SelectServicesModal
  final int? branchId; // future use when posting appointment

  const AddBookingScreen({super.key, this.salonId, this.branchId});

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
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TimeOfDay? _branchStartTime;
  TimeOfDay? _branchEndTime;
  String? _serviceError;

  bool get _hasCustomerDetails {
    return _clientIdCtrl.text.trim().isNotEmpty ||
        _clientfNameCtrl.text.trim().isNotEmpty ||
        _clientlNameCtrl.text.trim().isNotEmpty;
  }

  List<int> _selectedProfessionalUserIds() {
    final ids = <int>{};

    for (final service in _selectedServices) {
      final serviceId = service['id'];

      if (serviceId is! int) continue;

      final selectedName = _professionalByService[serviceId];

      if (selectedName == null || selectedName.trim().isEmpty) continue;

      final options = _membersForService(serviceId);

      for (final option in options) {
        if (option['label'] == selectedName) {
          final id = option['userId'];

          if (id is int) {
            ids.add(id);
          }

          break;
        }
      }
    }

    return ids.toList();
  }

  List<int> _selectedProfessionalUserBranchIds() {
    final ids = <int>{};

    for (final service in _selectedServices) {
      final serviceId = service['id'];

      if (serviceId is! int) continue;

      final selectedName = _professionalByService[serviceId];

      if (selectedName == null || selectedName.trim().isEmpty) continue;

      final options = _membersForService(serviceId);

      for (final option in options) {
        if (option['label'] == selectedName) {
          final id = option['userBranchId'];

          if (id is int) {
            ids.add(id);
          }

          break;
        }
      }
    }

    return ids.toList();
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

  List<Map<String, dynamic>> _teamMembers = [];

  /// Per-service professional selection (key = serviceId, value = assigned professional name)
  final Map<int, String> _professionalByService = {};

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
            'masterServiceId': svc['masterService'] is Map
                ? (svc['masterService'] as Map)['id']
                : null,
            'masterServiceName': svc['masterService'] is Map
                ? (svc['masterService'] as Map)['name']
                : null,
            'masterServiceCode': svc['masterService'] is Map
                ? (svc['masterService'] as Map)['code']
                : null,
            'path': [catName, (svc['displayName'] ?? '').toString()]
                .where((e) => e.isNotEmpty)
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
              'masterServiceId': svc['masterService'] is Map
                  ? (svc['masterService'] as Map)['id']
                  : null,
              'masterServiceName': svc['masterService'] is Map
                  ? (svc['masterService'] as Map)['name']
                  : null,
              'masterServiceCode': svc['masterService'] is Map
                  ? (svc['masterService'] as Map)['code']
                  : null,
              'path': [catName, subName, (svc['displayName'] ?? '').toString()]
                  .where((e) => e.isNotEmpty)
                  .join(' • '),
            };
            flat.add(svcMap);
            (subNode['services'] as List).add(svcMap);
          }
          if ((subNode['services'] as List).isNotEmpty) {
            (catNode['subs'] as List).add(subNode);
          }
        }

        if ((catNode['services'] as List).isNotEmpty ||
            (catNode['subs'] as List).isNotEmpty) {
          tree.add(catNode);
        }
      }

      setState(() {
        _branchServices = flat; // quick lookup/totals
        _svcTree = tree; // for the modal UI
        _loadingServices = false;
      });
    } catch (e) {
      debugPrint("Error fetching services: $e");
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
    if (base['customer'] is Map) {
      final customer = Map<String, dynamic>.from(base['customer'] as Map);
      for (final entry in base.entries) {
        customer.putIfAbsent(entry.key, () => entry.value);
      }

      final fullName = (customer['name'] ??
              customer['displayName'] ??
              customer['fullName'] ??
              '')
          .toString()
          .trim();
      if (fullName.isNotEmpty) {
        customer['displayName'] = fullName;
        final nameParts = fullName.split(RegExp(r'\s+'));
        customer.putIfAbsent('firstName', () => nameParts.first);
        customer.putIfAbsent(
          'lastName',
          () => nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        );
      }

      return customer;
    }
    if (base['user'] is Map) {
      final user = Map<String, dynamic>.from(base['user'] as Map);
      for (final entry in base.entries) {
        user.putIfAbsent(entry.key, () => entry.value);
      }
      return user;
    }
    return base;
  }

  int? _extractUserId(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    for (final key in const ['userId', 'id']) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    for (final key in const ['user', 'customer', 'client', 'data']) {
      final nested = map[key];
      final parsed = _extractUserId(nested);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractBranchClients(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => _normalizeCustomer(item))
          .toList();
    }

    if (raw is Map) {
      final customerRows = raw['customerManagement']?['table']?['rows'];
      if (customerRows != null) {
        final extracted = _extractBranchClients(customerRows);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }

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

  Future<List<Map<String, dynamic>>> _fetchBranchCustomers() async {
    if (widget.branchId == null) return const [];
    final response =
        await ApiService().getBranchCustomersList(widget.branchId!);
    return _extractBranchClients(response['data']);
  }

  String _customerDisplayName(Map<String, dynamic> customer) {
    final explicitName = (customer['displayName'] ??
            customer['name'] ??
            customer['fullName'] ??
            customer['customerName'] ??
            '')
        .toString()
        .trim();
    if (explicitName.isNotEmpty) return explicitName;

    final nestedCustomer = customer['customer'];
    if (nestedCustomer is Map) {
      final nestedName = (nestedCustomer['displayName'] ??
              nestedCustomer['name'] ??
              nestedCustomer['fullName'] ??
              '')
          .toString()
          .trim();
      if (nestedName.isNotEmpty) return nestedName;
    }

    final firstName = (customer['firstName'] ?? '').toString().trim();
    final lastName = (customer['lastName'] ?? '').toString().trim();
    return '$firstName $lastName'.trim();
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
    var firstName =
        (customer['firstName'] ?? fallbackFirstName ?? '').toString().trim();
    var lastName =
        (customer['lastName'] ?? fallbackLastName ?? '').toString().trim();
    if (firstName.isEmpty && lastName.isEmpty) {
      final displayName = _customerDisplayName(customer);
      if (displayName.isNotEmpty) {
        final nameParts = displayName.split(RegExp(r'\s+'));
        firstName = nameParts.first;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }
    }
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
    });
  }

  void _clearCustomerSelection() {
    setState(() {
      _clientIdCtrl.clear();
      _clientfNameCtrl.clear();
      _clientlNameCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
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
      if (!_isActiveEntity(member)) continue;
      final branches = member['userBranches'] as List? ?? const [];
      for (final entry in branches) {
        if (entry is! Map) continue;
        final branchEntry = Map<String, dynamic>.from(entry);
        if (!_isActiveEntity(branchEntry)) continue;
        final branch = branchEntry['branch'];
        final branchMap =
            branch is Map ? Map<String, dynamic>.from(branch) : {};
        final branchId = branchMap['id'] is int
            ? branchMap['id'] as int
            : int.tryParse('${branchMap['id'] ?? ''}');
        if (currentBranchId != null && branchId != currentBranchId) continue;

        final hasService =
            _hasAssignedServiceForSelection(member, branchEntry, serviceId);
        if (!hasService) continue;

        final name =
            "${member['firstName'] ?? ''} ${member['lastName'] ?? ''}".trim();

        final userBranchId = _resolveUserBranchAssignmentId(
          branchEntry: branchEntry,
          member: member,
          branchId: branchId,
        );
        final assignedBranchUserId =
            _resolveAssignedBranchUserIdFromBranchServices(
                branchEntry, serviceId);
        debugPrint(
          "TEAM OPTION name=$name userId=${member['id']} userBranchId=$userBranchId",
        );
        debugPrint('TEAM BRANCH ENTRY keys=${branchEntry.keys.toList()}');
        debugPrint('TEAM BRANCH ENTRY raw=$branchEntry');

        if (name.isEmpty) continue;

        members.add({
          'label': name,
          'userBranchId': userBranchId,
          'assignedBranchUserId': assignedBranchUserId,
          'userId': member['id'] is int
              ? member['id'] as int
              : int.tryParse('${member['id'] ?? ''}'),
        });
        break;
      }
    }

    return members;
  }

  int? _resolveAssignedBranchUserIdFromBranchServices(
    Map<String, dynamic> branchEntry,
    int serviceId,
  ) {
    final userBranchServices =
        branchEntry['userBranchServices'] as List? ?? const [];

    for (final raw in userBranchServices) {
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);
      final branchService = item['branchService'];

      final branchServiceId = branchService is Map
          ? _intValue(branchService['id'])
          : _intValue(item['branchServiceId']);

      if (branchServiceId == serviceId) {
        return _intValue(item['id']);
      }
    }

    return null;
  }

  int? _resolveAssignedBranchUserId(int serviceId) {
    final selectedProfessional = _professionalByService[serviceId];

    if (selectedProfessional == null || selectedProfessional.isEmpty) {
      return null;
    }

    for (final option in _membersForService(serviceId)) {
      if (option['label'] == selectedProfessional) {
        return _intValue(option['assignedBranchUserId']) ??
            _intValue(option['userBranchId']);
      }
    }

    return null;
  }

  bool _idsMatch(dynamic value, int expected) {
    final parsed = _intValue(value);
    return parsed != null && parsed == expected;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  List<dynamic> _listValue(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  bool _isActiveEntity(Map<String, dynamic> map) {
    return map['active'] != false;
  }

  Map<String, dynamic>? _serviceById(int serviceId) {
    for (final service in _branchServices) {
      if (_idsMatch(service['id'], serviceId)) return service;
    }
    for (final service in _selectedServices) {
      if (_idsMatch(service['id'], serviceId)) return service;
    }
    return null;
  }

  bool _hasAssignedServiceForSelection(
    Map<String, dynamic> member,
    Map<String, dynamic> branchEntry,
    int serviceId,
  ) {
    final service = _serviceById(serviceId);
    final masterServiceId = _intValue(service?['masterServiceId']);
    final serviceName =
        (service?['name'] ?? '').toString().trim().toLowerCase();
    final masterServiceName =
        (service?['masterServiceName'] ?? '').toString().trim().toLowerCase();
    final masterServiceCode =
        (service?['masterServiceCode'] ?? '').toString().trim().toLowerCase();

    bool matchesId(dynamic value) {
      return _idsMatch(value, serviceId) ||
          (masterServiceId != null && _idsMatch(value, masterServiceId));
    }

    bool matchesText(dynamic value) {
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text.isEmpty) return false;
      return text == serviceName ||
          (masterServiceName.isNotEmpty && text == masterServiceName) ||
          (masterServiceCode.isNotEmpty && text == masterServiceCode);
    }

    bool matchesItem(dynamic item) {
      if (item is int || item is num || item is String) {
        return matchesId(item) || matchesText(item);
      }
      if (item is! Map) return false;
      final map = Map<String, dynamic>.from(item);
      for (final key in const [
        'branchServiceId',
        'branch_service_id',
        'serviceId',
        'service_id',
        'masterServiceId',
        'master_service_id',
        'id',
        'code',
        'name',
        'displayName',
      ]) {
        if (matchesId(map[key]) || matchesText(map[key])) return true;
      }

      for (final key in const [
        'branchService',
        'service',
        'masterService',
      ]) {
        final nested = map[key];
        if (nested is Map && matchesItem(nested)) return true;
      }

      return false;
    }

    final assignments = <dynamic>[
      ..._listValue(branchEntry['userBranchServices']),
      ..._listValue(branchEntry['services']),
      ..._listValue(branchEntry['branchServices']),
      ..._listValue(branchEntry['assignedServices']),
      ..._listValue(branchEntry['assignedBranchServices']),
      ..._listValue(branchEntry['serviceIds']),
      ..._listValue(branchEntry['branchServiceIds']),
      ..._listValue(branchEntry['assignedServiceIds']),
      ..._listValue(branchEntry['assignedBranchServiceIds']),
      ..._listValue(member['userBranchServices']),
      ..._listValue(member['services']),
      ..._listValue(member['branchServices']),
      ..._listValue(member['assignedServices']),
      ..._listValue(member['assignedBranchServices']),
      ..._listValue(member['serviceIds']),
      ..._listValue(member['branchServiceIds']),
      ..._listValue(member['assignedServiceIds']),
      ..._listValue(member['assignedBranchServiceIds']),
    ];

    return assignments.any(matchesItem);
  }

  int? _resolveUserBranchAssignmentId({
    required Map<String, dynamic> branchEntry,
    required Map<String, dynamic> member,
    required int? branchId,
  }) {
    final branch = branchEntry['branch'];
    final branchMap = branch is Map ? Map<String, dynamic>.from(branch) : {};
    final memberId = _intValue(member['id']);
    final candidates = [
      branchEntry['assignedBranchUserId'],
      branchEntry['assigned_branch_user_id'],
      branchEntry['branchUserId'],
      branchEntry['branch_user_id'],
      branchEntry['userBranchId'],
      branchEntry['user_branch_id'],
      branchEntry['assignedUserBranchId'],
      branchEntry['assigned_user_branch_id'],
      branchEntry['id'],
    ];

    for (final candidate in candidates) {
      final id = _intValue(candidate);
      if (id == null) continue;
      if (branchId != null && id == branchId) continue;
      if (memberId != null && id == memberId) continue;
      if (_idsMatch(id, branchMap['id'])) continue;
      return id;
    }

    return null;
  }

  bool _isValidProfessionalForService(int serviceId) {
    final selectedProfessional = _professionalByService[serviceId];
    if (selectedProfessional == null || selectedProfessional.isEmpty) {
      return false;
    }
    return _membersForService(serviceId).any(
      (member) => member['label'] == selectedProfessional,
    );
  }

  void _removeInvalidProfessionalSelections() {
    _professionalByService.removeWhere(
      (serviceId, _) => !_isValidProfessionalForService(serviceId),
    );
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

  Widget _dialogRequiredLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          text: translateText(label).toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF4B4038),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        translateText(label).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF4B4038),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? prefixText,
    double height = 56,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              color: _bookingInk,
              fontSize: 13,
              height: 1.0,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: translateText(hint),
              hintStyle: const TextStyle(
                fontSize: 13,
                height: 1.0,
                color: _bookingMuted,
                fontWeight: FontWeight.w500,
              ),

              // Hide Flutter default counter
              counterText: '',

              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(
                prefixText == null ? 12 : 12,
                14,
                maxLength == null ? 12 : 54,
                maxLength == null ? 14 : 24,
              ),

              prefixIcon: prefixText == null
                  ? null
                  : SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          prefixText.trim(),
                          style: const TextStyle(
                            color: _bookingInk,
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
              prefixIconConstraints: prefixText == null
                  ? null
                  : const BoxConstraints(
                      minWidth: 48,
                      maxWidth: 48,
                      minHeight: 46,
                      maxHeight: 46,
                    ),

              filled: true,
              fillColor: _bookingFieldFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: _bookingBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: _bookingBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: _bookingGoldLight,
                  width: 1.2,
                ),
              ),
            ),
          ),
          if (maxLength != null)
            Positioned(
              right: 10,
              bottom: 6,
              child: IgnorePointer(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        color: value.text.length >= maxLength
                            ? Colors.red
                            : _bookingMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _customerAvatar(Map<String, dynamic> customer) {
    final firstName = (customer['firstName'] ?? '').toString().trim();
    final lastName = (customer['lastName'] ?? '').toString().trim();
    final explicitInitials = (customer['initials'] ?? '').toString().trim();
    final initials = [
      if (firstName.isNotEmpty) firstName.characters.first,
      if (lastName.isNotEmpty) lastName.characters.first,
    ].join().toUpperCase().trim();
    final imageUrl = (customer['profilePictureUrl'] ?? '').toString().trim();

    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF5EAD2),
        backgroundImage: NetworkImage(imageUrl),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFF5EAD2),
      child: Text(
        explicitInitials.isNotEmpty
            ? explicitInitials.toUpperCase()
            : initials.isEmpty
                ? 'G'
                : initials,
        style: const TextStyle(
          color: _bookingGold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _showOtpBox(
    String phone, {
    required String firstName,
    required String lastName,
  }) async {
    final otpCtrl = TextEditingController();
    bool isVerifying = false;
    String? otpError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> verifyOtp() async {
            final otp = otpCtrl.text.trim();
            if (otp.length != 6) {
              setDialogState(() {
                otpError = translateText("Enter 6-digit OTP");
              });
              return;
            }

            setDialogState(() {
              isVerifying = true;
              otpError = null;
            });
            try {
              final response = await ApiService().verifyOTP(phone, otp);
              Map<String, dynamic> customer = {};
              final data = response['data'];
              if (data is Map) {
                customer = _normalizeCustomer(data);
              }
              final verifiedUserId =
                  _extractUserId(data) ?? _extractUserId(response);
              if (verifiedUserId != null && widget.branchId != null) {
                final linkResponse = await ApiService().linkBranchClient(
                  branchId: widget.branchId!,
                  userId: verifiedUserId,
                );
                final linkedData = linkResponse['data'];
                if (linkedData is Map && linkedData.isNotEmpty) {
                  customer = {
                    ...customer,
                    ..._normalizeCustomer(linkedData),
                  };
                }
                customer['id'] = verifiedUserId;
                customer['userId'] = verifiedUserId;
              }
              if (customer.isEmpty && widget.branchId != null) {
                final clients = await _fetchBranchCustomers();
                customer = clients.firstWhere(
                  (item) =>
                      _digitsOnly(
                        (item['phoneNumber'] ?? item['fullPhoneNumber'] ?? '')
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
                if (!customer.containsKey('phoneNumber')) 'phoneNumber': phone,
                if (!customer.containsKey('firstName')) 'firstName': firstName,
                if (!customer.containsKey('lastName')) 'lastName': lastName,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            } catch (e) {
              setDialogState(() {
                otpError = _extractApiErrorMessage(e);
                if (otpError == null || otpError!.trim().isEmpty) {
                  otpError = translateText('Invalid OTP');
                }
              });
            } finally {
              if (ctx.mounted) {
                setDialogState(() => isVerifying = false);
              }
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5EAD2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: _bookingGold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      translateText('Verify OTP'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _bookingInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${translateText('Enter the 6-digit code sent to')} +91 $phone',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _bookingMuted,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: otpCtrl,
                      enabled: !isVerifying,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _bookingInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setDialogState(() => otpError = null),
                      onSubmitted: (_) => isVerifying ? null : verifyOtp(),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: const TextStyle(
                          color: Color(0xFFCDBFAF),
                          letterSpacing: 7,
                        ),
                        filled: true,
                        fillColor: _bookingFieldFill,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: _bookingBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: _bookingBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: _bookingGoldLight,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            isVerifying || otpCtrl.text.trim().length != 6
                                ? null
                                : verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bookingGold,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD8CEC5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0x338B6500),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                translateText('Verify & Continue')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    if (otpError != null) ...[
                      const SizedBox(height: 8),
                      Center(child: _errorText(otpError!)),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                      child: Text(
                        translateText('Cancel'),
                        style: const TextStyle(
                          color: _bookingMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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

  Future<void> _showAddCustomerModal({String initialPhone = ''}) async {
    final phoneCtrl = TextEditingController(text: _digitsOnly(initialPhone));
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    bool isSubmitting = false;
    String? firstNameError;
    String? lastNameError;
    String? phoneError;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDialogHeight = MediaQuery.of(context).size.height -
                MediaQuery.of(context).viewInsets.bottom -
                48;

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              backgroundColor: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxDialogHeight),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translateText('Add New Customer'),
                        style: const TextStyle(
                          color: _bookingInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        translateText(
                          'Register a new guest to continue with this booking process.',
                        ),
                        style: const TextStyle(
                          color: _bookingMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _dialogRequiredLabel('First Name'),
                      _dialogTextField(
                        controller: firstCtrl,
                        hint: "Enter guest's first name",
                        textCapitalization: TextCapitalization.words,
                        maxLength: 30,
                        height: 56,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z ]')),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        onChanged: (_) {
                          if (firstNameError != null) {
                            setDialogState(() => firstNameError = null);
                          }
                        },
                      ),
                      if (firstNameError != null) _errorText(firstNameError!),
                      const SizedBox(height: 14),
                      _dialogRequiredLabel('Last Name'),
                      _dialogTextField(
                        controller: lastCtrl,
                        hint: "Enter guest's last name",
                        textCapitalization: TextCapitalization.words,
                        maxLength: 30,
                        height: 56,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z ]')),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        onChanged: (_) {
                          if (lastNameError != null) {
                            setDialogState(() => lastNameError = null);
                          }
                        },
                      ),
                      if (lastNameError != null) _errorText(lastNameError!),
                      const SizedBox(height: 14),
                      _dialogRequiredLabel('Phone Number'),
                      _dialogTextField(
                        controller: phoneCtrl,
                        hint: 'Enter phone no',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        height: 56,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        prefixText: '+91  ',
                        onChanged: (_) {
                          if (phoneError != null) {
                            setDialogState(() => phoneError = null);
                          }
                        },
                      ),
                      if (phoneError != null) _errorText(phoneError!),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final firstName = firstCtrl.text.trim();
                                      final lastName = lastCtrl.text.trim();
                                      final phone =
                                          _digitsOnly(phoneCtrl.text.trim());

                                      setDialogState(() {
                                        firstNameError = _validateCustomerName(
                                          firstName,
                                          translateText('First name'),
                                        );
                                        lastNameError = _validateCustomerName(
                                          lastName,
                                          translateText('Last name'),
                                        );
                                        phoneError = phone.isEmpty
                                            ? translateText(
                                                'Phone number is required')
                                            : !_customerPhonePattern
                                                    .hasMatch(phone)
                                                ? translateText(
                                                    'Enter a valid 10-digit phone number starting with 6, 7, 8, or 9')
                                                : null;
                                      });

                                      if (firstNameError != null ||
                                          lastNameError != null ||
                                          phoneError != null) {
                                        return;
                                      }

                                      setDialogState(() => isSubmitting = true);

                                      try {
                                        await ApiService().registerCustomer(
                                          phoneNumber: phone,
                                          firstName: firstName,
                                          lastName: lastName,
                                        );

                                        if (!ctx.mounted) return;

                                        Navigator.pop(ctx);

                                        Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () {
                                          if (!mounted) return;

                                          _showOtpBox(
                                            phone,
                                            firstName: firstName,
                                            lastName: lastName,
                                          );
                                        });

                                        return;
                                      } catch (e) {
                                        _showError(e.toString());
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                              () => isSubmitting = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _bookingGold,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0x338B6500),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
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
                                  : Text(
                                      translateText('Continue').toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          translateText(
                            '"Excellence begins with understanding our guests."',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB9A999),
                            fontSize: 12,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
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
    } finally {
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   phoneCtrl.dispose();
      //   firstCtrl.dispose();
      //   lastCtrl.dispose();
      // });
    }
  }

  Future<void> _showCustomerSearch() async {
    if (widget.branchId == null) return;

    List<Map<String, dynamic>> clients = [];
    bool isLoadingClients = true;
    String? clientsError;
    bool loadStarted = false;
    final searchCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!loadStarted) {
            loadStarted = true;
            Future.microtask(() async {
              try {
                final loadedClients = await _fetchBranchCustomers();
                for (final customer in _branchClientsCache) {
                  final normalized = _normalizeCustomer(customer);
                  final id = (normalized['id'] ?? '').toString().trim();
                  final phone = _digitsOnly(
                    (normalized['phoneNumber'] ??
                            normalized['fullPhoneNumber'] ??
                            '')
                        .toString(),
                  );
                  final alreadyExists = loadedClients.any((existing) {
                    final existingId = (existing['id'] ?? '').toString().trim();
                    final existingPhone = _digitsOnly(
                      (existing['phoneNumber'] ??
                              existing['fullPhoneNumber'] ??
                              '')
                          .toString(),
                    );
                    return (id.isNotEmpty && existingId == id) ||
                        (phone.isNotEmpty && existingPhone == phone);
                  });
                  if (!alreadyExists) {
                    loadedClients.insert(0, normalized);
                  }
                }
                clients = loadedClients;
                _branchClientsCache = List<Map<String, dynamic>>.from(clients);
                if (ctx.mounted) {
                  setDialogState(() {
                    isLoadingClients = false;
                    clientsError = null;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() {
                    isLoadingClients = false;
                    clientsError = _extractApiErrorMessage(e);
                  });
                }
              }
            });
          }

          final query = searchCtrl.text.trim().toLowerCase();
          final queryDigits = _digitsOnly(query);
          final filteredClients = clients.where((client) {
            if (query.isEmpty) return true;
            final firstName =
                (client['firstName'] ?? '').toString().toLowerCase();
            final lastName =
                (client['lastName'] ?? '').toString().toLowerCase();
            final fullName = _customerDisplayName(client).toLowerCase();
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            backgroundColor: Colors.white,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: SizedBox(
                width: 520,
                height: 520,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
                                  translateText('Select Customer'),
                                  style: const TextStyle(
                                    color: _bookingInk,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  translateText(
                                    'Find an existing profile or create a new one.',
                                  ),
                                  style: const TextStyle(
                                    color: _bookingMuted,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: searchCtrl,
                        // maxLength: 60,
                        onChanged: (_) => setDialogState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: translateText('Search customer...'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _bookingGold,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _bookingFieldFill,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: _bookingBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(color: _bookingBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(
                              color: _bookingGoldLight,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            translateText('Recent Customers').toUpperCase(),
                            style: const TextStyle(
                              color: _bookingMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: widget.branchId == null
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    final selected = await Navigator.of(
                                      this.context,
                                    ).push<Map<String, dynamic>>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ViewAllClientOwnerScreen(
                                          branchId: widget.branchId!,
                                          initialCustomers: clients,
                                        ),
                                      ),
                                    );
                                    if (selected == null || !mounted) return;
                                    _fillCustomerFields(selected);
                                    _upsertBranchClientCache(selected);
                                  },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: _bookingGold,
                            ),
                            child: Text(
                              translateText('View All').toUpperCase(),
                              style: const TextStyle(
                                color: _bookingGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: isLoadingClients
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: _bookingGold,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : clientsError != null
                                ? Center(
                                    child: Text(
                                      clientsError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : filteredClients.isEmpty
                                    ? Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          translateText(
                                              'No existing customer found'),
                                          style: const TextStyle(
                                            color: _bookingMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: filteredClients.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (_, index) {
                                          final customer =
                                              filteredClients[index];
                                          final name =
                                              _customerDisplayName(customer);
                                          return InkWell(
                                            onTap: () {
                                              _fillCustomerFields(customer);
                                              _upsertBranchClientCache(
                                                  customer);
                                              Navigator.pop(ctx);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                              child: Row(
                                                children: [
                                                  _customerAvatar(customer),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          name.isEmpty
                                                              ? translateText(
                                                                  'Unnamed customer',
                                                                )
                                                              : name,
                                                          style:
                                                              const TextStyle(
                                                            color: _bookingInk,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          _customerDisplayPhone(
                                                            customer,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                _bookingMuted,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _showAddCustomerModal(
                              initialPhone: queryDigits,
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: Text(
                            translateText('Add New Customer'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bookingGold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            elevation: 7,
                            shadowColor: const Color(0x338B6500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            translateText('Cancel'),
                            style: const TextStyle(
                              color: _bookingMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showServicePicker() async {
    final searchCtrl = TextEditingController();
    final pendingIds = _selectedServices
        .map((service) => service['id'])
        .whereType<int>()
        .toSet();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: translateText('Select Services'),
      barrierColor: const Color(0x55000000),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (dialogContext, _, __) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final visibleCategories = _svcTree.where((cat) {
            final catName = (cat['name'] ?? '').toString().toLowerCase();
            final catServices = (cat['services'] as List?) ?? const [];
            final subs = (cat['subs'] as List?) ?? const [];
            if (catServices.isEmpty && subs.isEmpty) return false;
            if (query.isEmpty) return true;
            final serviceMatch = catServices.any(
              (svc) =>
                  (svc['name'] ?? '').toString().toLowerCase().contains(query),
            );
            final subMatch = subs.any((sub) {
              final subName = (sub['name'] ?? '').toString().toLowerCase();
              final subServices = (sub['services'] as List?) ?? const [];
              return subName.contains(query) ||
                  subServices.any(
                    (svc) => (svc['name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(query),
                  );
            });
            return catName.contains(query) || serviceMatch || subMatch;
          }).toList();

          final selectedTotal = _branchServices.fold<num>(0, (sum, service) {
            final id = service['id'];
            final price = service['priceMinor'];
            if (id is int && pendingIds.contains(id) && price is num) {
              return sum + price;
            }
            return sum;
          });

          return SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 28,
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: _bookingGold,
                              ),
                              splashRadius: 18,
                            ),
                            Expanded(
                              child: Text(
                                translateText('Select Services'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _bookingGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const Divider(height: 1, color: _bookingBorder),
                        const SizedBox(height: 14),
                        Text(
                          translateText('Select Services'),
                          style: const TextStyle(
                            color: _bookingInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          translateText(
                            'Choose the services that best describe the luxury experience for your client. Multi-selection enabled.',
                          ),
                          style: const TextStyle(
                            color: _bookingMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: searchCtrl,
                          // maxLength: 60,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            hintText: translateText('Search services...'),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _bookingGold,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: _bookingFieldFill,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                                  const BorderSide(color: _bookingBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                                  const BorderSide(color: _bookingBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide: const BorderSide(
                                color: _bookingGoldLight,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: visibleCategories.length,
                            itemBuilder: (_, i) {
                              final cat = visibleCategories[i];
                              return _serviceCategoryBlock(
                                category: cat,
                                query: query,
                                pendingIds: pendingIds,
                                onToggle: (service) {
                                  final id = service['id'];
                                  if (id is! int) return;
                                  setSheetState(() {
                                    if (pendingIds.contains(id)) {
                                      pendingIds.remove(id);
                                    } else {
                                      pendingIds.add(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${translateText('Total Selected')}: ${pendingIds.length}',
                              style: const TextStyle(
                                color: _bookingInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatServicePrice(selectedTotal),
                              style: const TextStyle(
                                color: _bookingGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              _applyPickedServices(pendingIds);
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bookingGold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0x338B6500),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  translateText('Add Services'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _serviceCategoryBlock({
    required Map<String, dynamic> category,
    required String query,
    required Set<int> pendingIds,
    required void Function(Map<String, dynamic> service) onToggle,
  }) {
    final catName = (category['name'] ?? '').toString();
    final catServices = (category['services'] as List?) ?? const [];
    final subs = (category['subs'] as List?) ?? const [];
    final normalizedQuery = query.toLowerCase();
    final catMatches =
        normalizedQuery.isNotEmpty && catName.toLowerCase().contains(query);

    bool serviceVisible(Map service) =>
        normalizedQuery.isEmpty ||
        catMatches ||
        (service['name'] ?? '').toString().toLowerCase().contains(query);
    bool subVisible(Map sub) {
      final subName = (sub['name'] ?? '').toString().toLowerCase();
      final subMatches =
          normalizedQuery.isNotEmpty && subName.contains(normalizedQuery);
      final services =
          ((sub['services'] as List?) ?? const []).whereType<Map>();
      return services.any(
        (service) =>
            normalizedQuery.isEmpty ||
            catMatches ||
            subMatches ||
            (service['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(normalizedQuery),
      );
    }

    final visibleCatServices =
        catServices.whereType<Map>().where(serviceVisible).toList();
    final visibleSubs = subs.whereType<Map>().where(subVisible).toList();
    if (visibleCatServices.isEmpty && visibleSubs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: query.isNotEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: _bookingGold,
              collapsedIconColor: _bookingGold,
              leading: const Icon(Icons.spa_outlined, color: _bookingGold),
              title: Text(
                catName.isEmpty ? translateText('Services') : catName,
                style: const TextStyle(
                  color: _bookingInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                for (final service in visibleCatServices)
                  _serviceSheetTile(
                    Map<String, dynamic>.from(service),
                    pendingIds,
                    onToggle,
                  ),
                for (final sub in visibleSubs) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          color: _bookingGold,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (sub['name'] ?? '').toString(),
                          style: const TextStyle(
                            color: _bookingInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final service in ((sub['services'] as List?) ?? const [])
                      .whereType<Map>())
                    if (serviceVisible(service))
                      _serviceSheetTile(
                        Map<String, dynamic>.from(service),
                        pendingIds,
                        onToggle,
                      ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _bookingBorder),
        ],
      ),
    );
  }

  Widget _serviceSheetTile(
    Map<String, dynamic> service,
    Set<int> pendingIds,
    void Function(Map<String, dynamic> service) onToggle,
  ) {
    final id = service['id'];
    final name = (service['name'] ?? '').toString();
    final duration = service['durationMin'];
    final price = service['priceMinor'];
    final selected = id is int && pendingIds.contains(id);
    return InkWell(
      onTap: () => onToggle(service),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _bookingGoldLight : _bookingBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _bookingInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (duration is num && duration > 0)
                        '${duration.toInt()} min',
                      if (price is num) _formatServicePrice(price),
                    ].join('  •  '),
                    style: const TextStyle(
                      color: _bookingMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _bookingGold : const Color(0xFFD8CEC5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _applyPickedServices(Set<int> pickedIds) {
    setState(() {
      _selectedServices = _branchServices
          .where((service) {
            final id = service['id'];
            return id is int && pickedIds.contains(id);
          })
          .map((service) => {
                'id': service['id'],
                'name': service['name'],
                'price': service['priceMinor'],
                'qty': 1,
                'durationMin': service['durationMin'],
                'masterServiceId': service['masterServiceId'],
                'masterServiceName': service['masterServiceName'],
                'masterServiceCode': service['masterServiceCode'],
              })
          .toList();

      final validIds = _selectedServices
          .map((service) => service['id'])
          .whereType<int>()
          .toSet();
      _professionalByService.removeWhere((id, _) => !validIds.contains(id));
      _removeInvalidProfessionalSelections();
      _selectedServiceId = _selectedServices.isNotEmpty
          ? _selectedServices.first['id'] as int
          : null;
      _serviceError = null;
      _syncEndTimeWithDuration();
    });
  }

  Future<void> _loadTeamMembers() async {
    if (widget.branchId == null) return;

    try {
      final response = await ApiService.getTeamMembers(widget.branchId!);
      if (response['success'] == true) {
        final List members = response['data'] ?? [];
        setState(() {
          _teamMembers = members.cast<Map<String, dynamic>>();
          _removeInvalidProfessionalSelections();
        });
      }
    } catch (e) {
      debugPrint("Error loading team members: $e");
    }
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

  int? _resolveAssignedUserId(int serviceId) {
    final selectedProfessional = _professionalByService[serviceId];
    if (selectedProfessional == null || selectedProfessional.isEmpty) {
      return null;
    }

    for (final option in _membersForService(serviceId)) {
      if (option['label'] == selectedProfessional) {
        return option['userId'] as int?;
      }
    }
    return null;
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

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _save() async {
    await _submitBooking(popOnSuccess: true);
  }

  Future<Map<String, dynamic>?> _submitBooking({
    required bool popOnSuccess,
  }) async {
    if (_isSaving) return null;
    if (!_formKey.currentState!.validate()) return null;

    final userId = int.tryParse(_clientIdCtrl.text.trim());
    if (userId == null) {
      setState(() {
        _serviceError = null;
      });
      _showError(translateText('Please select or verify a customer first'));
      return null;
    }

    if (_selectedServiceId == null || _selectedServices.isEmpty) {
      setState(() {
        _serviceError = null;
      });
      _showError(translateText('Service is required'));
      return null;
    } else {
      setState(() {
        _serviceError = null;
      });
    }

    if (_selectedDate == null) {
      _showError(translateText('Please select a date'));
      return null;
    }
    if (_startTime == null || _endTime == null) {
      _showError(translateText('Please select start and end time'));
      return null;
    }
    for (final service in _selectedServices) {
      final serviceId = service['id'];

      if (serviceId is! int) continue;
      final assignedBranchUserId = _resolveAssignedBranchUserId(serviceId);

      if (assignedBranchUserId == null) {
        _showError(
          translateText(
            'Selected team member branch assignment is missing. Please reselect team member.',
          ),
        );
        return null;
      }
    }
    final payload = {
      "userId": userId,
      "date": DateFormat('yyyy-MM-dd').format(_selectedDate!),
      "startAt":
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      "endAt":
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      "services": _selectedServices.map((s) {
        final serviceId = s['id'] as int;
        final servicePayload = <String, dynamic>{
          "branchServiceId": serviceId,
        };
        final assignedBranchUserId = _resolveAssignedBranchUserId(serviceId);

        if (assignedBranchUserId != null) {
          servicePayload['assignedBranchUserId'] = assignedBranchUserId;
        }
        return servicePayload;
      }).toList(),
    };
    debugPrint('SELECTED PROFESSIONAL BY SERVICE = $_professionalByService');
    debugPrint('SELECTED USER IDS = ${_selectedProfessionalUserIds()}');
    debugPrint(
      'SELECTED USER BRANCH IDS = ${_selectedProfessionalUserBranchIds()}',
    );
    debugPrint("Booking payload: $payload");
    setState(() {
      _isSaving = true;
    });
    try {
      final result =
          await ApiService().createManualBooking(widget.branchId!, payload);

      debugPrint("✅ Appointment Created: $result");

      if (!mounted) return null;
      final resultMap = Map<String, dynamic>.from(result);
      if (popOnSuccess) {
        Navigator.pop(context, result); // send back API response
      }
      return resultMap;
    } catch (e) {
      _showError(_extractApiErrorMessage(e));
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _validateBeforeSchedule() {
    if (!_formKey.currentState!.validate()) return false;

    final userId = int.tryParse(_clientIdCtrl.text.trim());
    if (userId == null) {
      setState(() => _serviceError = null);
      _showError(translateText('Please select or verify a customer first'));
      return false;
    }

    if (_selectedServices.isEmpty) {
      setState(() => _serviceError = null);
      _showError(translateText('Service is required'));
      return false;
    }

    setState(() {
      _serviceError = null;
    });
    return true;
  }

  Future<void> _continueToSchedule() async {
    if (_isSaving || !_validateBeforeSchedule()) return;

    final serviceMembers = <int, List<Map<String, dynamic>>>{};
    for (final service in _selectedServices) {
      final serviceId = service['id'];
      if (serviceId is int) {
        serviceMembers[serviceId] = _membersForService(serviceId);
      }
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _BookingScheduleScreen(
          customerName: _customerFullName(),
          customerPhone: _mobileCtrl.text.trim(),
          services: _selectedServices,
          professionals: Map<int, String>.from(_professionalByService),
          serviceMembers: serviceMembers,
          selectedUserBranchIds: _selectedProfessionalUserBranchIds(),
          selectedUserIds: _selectedProfessionalUserIds(),
          branchId: widget.branchId,
          totalPrice: _selectedTotalPrice(),
          initialDate: _selectedDate,
          initialStartTime: _startTime,
          branchStartTime: _branchStartTime,
          branchEndTime: _branchEndTime,
          durationMinutes: _totalSelectedDurationMinutes(),
          selectedProfessionals: _selectedProfessionalLabels(),
          onProfessionalsChanged: (professionals) {
            setState(() {
              _professionalByService
                ..clear()
                ..addAll(professionals);
            });
          },
          onConfirmBooking: (schedule) async {
            if (!mounted) return null;
            setState(() {
              _selectedDate = schedule.date;
              _startTime = schedule.startTime;
              _endTime = schedule.endTime;
            });
            return _submitBooking(popOnSuccess: false);
          },
        ),
      ),
    );
    if (result == null || !mounted) return;
    Navigator.pop(context, result);
  }

  List<String> _selectedProfessionalLabels() {
    return _selectedServices
        .map((service) => _professionalByService[service['id'] as int] ?? '')
        .where((label) => label.trim().isNotEmpty)
        .toSet()
        .toList();
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
      'Failed OTP:',
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
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Add Booking'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookingHero(),
                  const SizedBox(height: 18),
                  _sectionLabel('Customer Details *'),
                  _selectionCard(
                    icon: Icons.person_add_alt_1_rounded,
                    title: _hasCustomerDetails
                        ? _customerFullName()
                        : translateText('Select Customer'),
                    subtitle: _hasCustomerDetails
                        ? _mobileCtrl.text.trim()
                        : translateText('Tap to search or add new'),
                    onTap: _showCustomerSearch,
                    onClear:
                        _hasCustomerDetails ? _clearCustomerSelection : null,
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Services *'),
                  _selectionCard(
                    icon: Icons.content_cut_rounded,
                    title: _selectedServices.isEmpty
                        ? translateText('Choose salon services')
                        : _selectedServicesSummaryLabel(),
                    subtitle: _selectedServices.isEmpty
                        ? translateText('Select services and team members')
                        : translateText(
                            '${_selectedServices.length} service(s) selected',
                          ),
                    onTap: _loadingServices || _svcTree.isEmpty
                        ? null
                        : _showServicePicker,
                    trailingIcon: Icons.content_cut_rounded,
                  ),
                  if (_serviceError != null) _errorText(_serviceError!),
                  if (_selectedServices.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildSelectedServicesSection(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _continueToSchedule,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        translateText('Schedule Appointment'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bookingGold,
                        foregroundColor: Colors.white,
                        elevation: 9,
                        shadowColor: const Color(0x338B6500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/salonImage.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xAA211406), Color(0x113A240B)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText('New Session').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE8DED6),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translateText('Scheduling Experience'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    VoidCallback? onClear,
    IconData? trailingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bookingBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EAD2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _bookingGold, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _bookingGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _bookingMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: _bookingMuted,
                splashRadius: 18,
              )
            else
              Icon(
                trailingIcon ?? Icons.chevron_right_rounded,
                color: _bookingGold,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedServicesSection() {
    return _bookingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _selectedServices.length; index++) ...[
            _selectedServiceSummaryRow(_selectedServices[index]),
            if (index != _selectedServices.length - 1)
              const Divider(height: 22, color: _bookingBorder),
          ],
          const Divider(height: 26, color: _bookingBorder),
          Row(
            children: [
              Expanded(
                child: Text(
                  translateText(
                    '${_selectedServices.length} ${_selectedServices.length == 1 ? 'Service' : 'Services'} selected',
                  ),
                  style: const TextStyle(
                    color: _bookingMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${translateText('Total')}: ${_formatServicePrice(_selectedTotalPrice())}',
                style: const TextStyle(
                  color: _bookingGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _branchTimingNote(),
        ],
      ),
    );
  }

  Widget _selectedServiceSummaryRow(Map<String, dynamic> service) {
    final id = service['id'] as int;
    final name = (service['name'] ?? '').toString();
    final duration = _serviceDurationMinutes(service);
    final price = _servicePrice(service);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _bookingInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                [
                  if (duration > 0) '$duration min',
                  if (price != null) _formatServicePrice(price),
                ].join('  •  '),
                style: const TextStyle(
                  color: _bookingInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _removeSelectedService(id),
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: Icon(
              Icons.close_rounded,
              color: _bookingMuted,
              size: 17,
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchTimingNote() {
    final start = _formatTimeOfDay(
      _branchStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    final end = _formatTimeOfDay(
      _branchEndTime ?? const TimeOfDay(hour: 18, minute: 30),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: _bookingFieldFill,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: _bookingGoldLight, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _bookingGold,
            size: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${translateText('Branch timings')}: $start - $end.\n${translateText('Please ensure the services fit within this window.')}',
              style: const TextStyle(
                color: _bookingInk,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildScheduleSection() {
    final selectedDate = _selectedDate ?? DateTime.now();
    return _bookingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(selectedDate),
                style: const TextStyle(
                  color: _bookingInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                color: _bookingGold,
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _dateChips(),
          const SizedBox(height: 22),
          Text(
            translateText('Available Slots'),
            style: const TextStyle(
              color: _bookingInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _timeSlotGrid(),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: Image.asset(
                'assets/images/salon2.jpeg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            translateText('Treatment Focus').toUpperCase(),
            style: const TextStyle(
              color: _bookingGold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translateText(
              'Ensure your client arrives 15 minutes before the selected time slot.',
            ),
            style: const TextStyle(
              color: _bookingMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSummarySection() {
    return _bookingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText('Summary'),
            style: const TextStyle(
              color: _bookingInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow(
              'Customer', _hasCustomerDetails ? _customerFullName() : '-'),
          _summaryRow('Services', '${_selectedServices.length}'),
          _summaryRow('Date', _formatDate(_selectedDate)),
          _summaryRow('Time', _formatTimeOfDay(_startTime)),
          _summaryRow('Duration', '${_totalSelectedDurationMinutes()} min'),
          _summaryRow('Total', _formatServicePrice(_selectedTotalPrice())),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bookingGold,
                foregroundColor: Colors.white,
                elevation: 9,
                shadowColor: const Color(0x338B6500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 17),
                        const SizedBox(width: 8),
                        Text(
                          translateText('Schedule Appointment'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChips() {
    final today = DateTime.now();
    final selected =
        _selectedDate ?? DateTime(today.year, today.month, today.day);
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: days.map((day) {
          final isSelected = DateUtils.isSameDay(day, selected);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedDate = day),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _bookingGold : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected ? _bookingGold : _bookingBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.white : _bookingMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('d').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.white : _bookingInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _timeSlotGrid() {
    final slots = _availableTimeSlots();
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: slots.map((slot) {
        final selected =
            _startTime != null && _toMinutes(_startTime!) == _toMinutes(slot);
        return InkWell(
          onTap: _selectedServices.isEmpty
              ? null
              : () {
                  setState(() {
                    _startTime = slot;
                    _syncEndTimeWithDuration();
                  });
                },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 94,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _bookingGold : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? _bookingGold : _bookingBorder,
              ),
            ),
            child: Text(
              _formatTimeOfDay(slot),
              style: TextStyle(
                color: selected ? Colors.white : _bookingInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<TimeOfDay> _availableTimeSlots() {
    final start = _branchStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    final end = _branchEndTime ?? const TimeOfDay(hour: 18, minute: 30);
    final endMinutes = _toMinutes(end);
    final duration = _totalSelectedDurationMinutes();
    final slots = <TimeOfDay>[];
    for (var minutes = _toMinutes(start);
        minutes + duration <= endMinutes && slots.length < 12;
        minutes += 90) {
      slots.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    }
    if (slots.isEmpty) {
      slots.add(start);
    }
    return slots;
  }

  Widget _bookingPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _bookingBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Text(
            translateText(label),
            style: const TextStyle(
              color: _bookingMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: _bookingInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        translateText(text).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF4B4038),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  String _customerFullName() {
    final name = [
      _clientfNameCtrl.text.trim(),
      _clientlNameCtrl.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? translateText('Selected Customer') : name;
  }

  String? _validateCustomerName(String value, String label) {
    if (value.isEmpty) return translateText('$label is required');
    if (!_customerNamePattern.hasMatch(value)) {
      return translateText('$label should contain alphabets only');
    }
    return null;
  }

  String _selectedServicesSummaryLabel() {
    if (_selectedServices.length == 1) {
      return (_selectedServices.first['name'] ?? '').toString();
    }
    return translateText('${_selectedServices.length} services selected');
  }

  num _selectedTotalPrice() {
    return _selectedServices.fold<num>(0, (sum, service) {
      final price = service['price'];
      return sum + (price is num ? price : 0);
    });
  }

  int _serviceDurationMinutes(Map<String, dynamic> service) {
    final duration = service['durationMin'];
    if (duration is int) return duration;
    if (duration is num) return duration.toInt();
    return int.tryParse('${duration ?? ''}') ?? 0;
  }

  num? _servicePrice(Map<String, dynamic> service) {
    final price = service['price'];
    if (price is num) return price;
    return num.tryParse('${price ?? ''}');
  }

  String _formatServicePrice(num price) {
    return formatMinorAmount(price);
  }

  void _removeSelectedService(int id) {
    setState(() {
      _selectedServices.removeWhere((service) => service['id'] == id);
      _professionalByService.remove(id);
      if (_selectedServiceId == id) {
        _selectedServiceId = _selectedServices.isNotEmpty
            ? _selectedServices.first['id'] as int
            : null;
      }
      _syncEndTimeWithDuration();
    });
  }
}

class _BookingScheduleSelection {
  const _BookingScheduleSelection({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
}

class _BookedInterval {
  const _BookedInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _BookingScheduleScreen extends StatefulWidget {
  const _BookingScheduleScreen({
    required this.customerName,
    required this.customerPhone,
    required this.services,
    required this.professionals,
    required this.serviceMembers,
    required this.selectedUserBranchIds,
    required this.selectedUserIds,
    required this.branchId,
    required this.totalPrice,
    required this.initialDate,
    required this.initialStartTime,
    required this.branchStartTime,
    required this.branchEndTime,
    required this.durationMinutes,
    required this.selectedProfessionals,
    required this.onProfessionalsChanged,
    required this.onConfirmBooking,
  });

  final String customerName;
  final String customerPhone;
  final List<Map<String, dynamic>> services;
  final Map<int, String> professionals;
  final Map<int, List<Map<String, dynamic>>> serviceMembers;
  final List<int> selectedUserBranchIds;
  final List<int> selectedUserIds;
  final int? branchId;
  final num totalPrice;
  final DateTime? initialDate;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? branchStartTime;
  final TimeOfDay? branchEndTime;
  final int durationMinutes;
  final List<String> selectedProfessionals;

  final void Function(Map<int, String> professionals) onProfessionalsChanged;

  final Future<Map<String, dynamic>?> Function(_BookingScheduleSelection)
      onConfirmBooking;

  @override
  State<_BookingScheduleScreen> createState() => _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends State<_BookingScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleWeekStart;
  TimeOfDay? _selectedTime;
  bool _loadingAppointments = false;
  List<_BookedInterval> _bookedIntervals = [];
  late final Map<int, String> _selectedProfessionals;

  @override
  void initState() {
    super.initState();

    _selectedProfessionals = Map<int, String>.from(widget.professionals);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _selectedDate =
        widget.initialDate == null ? today : _dateOnly(widget.initialDate!);

    _visibleWeekStart = _selectedDate.isAfter(today) ? _selectedDate : today;
    _selectedTime = widget.initialStartTime;

    _loadAppointmentsForDate();
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';

    final now = DateTime.now();

    return DateFormat('h:mm a').format(
      DateTime(now.year, now.month, now.day, time.hour, time.minute),
    );
  }

  TimeOfDay _endTimeFor(TimeOfDay start) {
    final totalMinutes = _toMinutes(start) + widget.durationMinutes;

    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  DateTime _dateWithMinutes(int minutes) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  int? _idFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  bool _validateTeamMembersForEveryService() {
    for (final service in widget.services) {
      final serviceId = _idFrom(service['id']);
      final serviceName = (service['name'] ?? '').toString();

      if (serviceId == null) continue;

      final members =
          widget.serviceMembers[serviceId] ?? const <Map<String, dynamic>>[];

      if (members.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translateText('No team member available for $serviceName'),
            ),
          ),
        );
        return false;
      }

      final selected = _selectedProfessionals[serviceId];

      if (selected == null || selected.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translateText('Please select team member for $serviceName'),
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }

  DateTime? _parseAppointmentDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';

    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _isActiveAppointment(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? '').toString().toUpperCase();

    return !const {
      'CANCELLED',
      'CANCELED',
      'COMPLETED',
      'NO_SHOW',
    }.contains(status);
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<_BookedInterval> _extractBookedIntervals(dynamic responseData) {
    final selectedUserBranchIds = widget.selectedUserBranchIds.toSet();
    final selectedUserIds = widget.selectedUserIds.toSet();

    final appointments = responseData is List
        ? responseData
        : responseData is Map && responseData['data'] is List
            ? responseData['data'] as List
            : const [];

    final intervals = <_BookedInterval>[];

    for (final rawAppointment in appointments) {
      if (rawAppointment is! Map) continue;

      final appointment = Map<String, dynamic>.from(rawAppointment);

      if (!_isActiveAppointment(appointment)) continue;

      final items = appointment['items'] is List
          ? appointment['items'] as List
          : const [];

      for (final rawItem in items) {
        if (rawItem is! Map) continue;

        final item = Map<String, dynamic>.from(rawItem);
        final assignedMap = _mapFrom(item['assignedUserBranch']);
        final assignedUserMap = _mapFrom(assignedMap['user']);
        final professionalMap = _mapFrom(item['professional']);

        final assignedUserBranchId = _idFrom(assignedMap['id']);
        final assignedUserId = _idFrom(assignedUserMap['id']);
        final professionalUserId = _idFrom(professionalMap['id']);

        final itemUserBranchId =
            assignedUserBranchId ?? _idFrom(item['assignedUserBranchId']);

        final itemUserId = assignedUserId ??
            _idFrom(item['assignedUserId']) ??
            professionalUserId;

        final hasSelectedProfessionals =
            selectedUserBranchIds.isNotEmpty || selectedUserIds.isNotEmpty;

        final matchesSelectedProfessional = !hasSelectedProfessionals ||
            (itemUserBranchId != null &&
                selectedUserBranchIds.contains(itemUserBranchId)) ||
            (itemUserId != null && selectedUserIds.contains(itemUserId));

        if (!matchesSelectedProfessional) continue;

        final start = _parseAppointmentDate(item['startAt']);
        final end = _parseAppointmentDate(item['endAt']);

        if (start == null || end == null || !end.isAfter(start)) continue;

        intervals.add(_BookedInterval(start, end));
      }

      if (items.isEmpty &&
          selectedUserBranchIds.isEmpty &&
          selectedUserIds.isEmpty) {
        final start = _parseAppointmentDate(appointment['startAt']);
        final end = _parseAppointmentDate(appointment['endAt']);

        if (start != null && end != null && end.isAfter(start)) {
          intervals.add(_BookedInterval(start, end));
        }
      }
    }

    return intervals;
  }

  Future<void> _loadAppointmentsForDate() async {
    final branchId = widget.branchId;

    if (branchId == null) return;

    setState(() => _loadingAppointments = true);

    try {
      final response = await ApiService().fetchAppointments(
        branchId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
      );

      if (!mounted) return;

      final intervals = _extractBookedIntervals(response['data']);

      setState(() {
        _bookedIntervals = intervals;
        _loadingAppointments = false;

        final current = _selectedTime;

        if (current != null && !_isSlotAvailable(current)) {
          _selectedTime = null;
        }
      });
    } catch (e) {
      debugPrint('[AddBookingSlots] failed=$e');

      if (!mounted) return;

      setState(() {
        _bookedIntervals = [];
        _loadingAppointments = false;
      });
    }
  }

  bool _isSlotAvailable(TimeOfDay slot) {
    final duration = widget.durationMinutes <= 0 ? 30 : widget.durationMinutes;
    final startMinutes = _toMinutes(slot);

    final proposedStart = _dateWithMinutes(startMinutes);
    final proposedEnd = proposedStart.add(Duration(minutes: duration));

    return !_bookedIntervals.any(
      (booked) =>
          proposedStart.isBefore(booked.end) &&
          proposedEnd.isAfter(booked.start),
    );
  }

  List<TimeOfDay> _availableSlots() {
    final start = widget.branchStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    final end = widget.branchEndTime ?? const TimeOfDay(hour: 18, minute: 30);

    final duration = widget.durationMinutes <= 0 ? 30 : widget.durationMinutes;

    final slots = <TimeOfDay>[];

    for (var minutes = _toMinutes(start);
        minutes + duration <= _toMinutes(end);
        minutes += 30) {
      final slot = TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      );

      if (_isSlotAvailable(slot)) {
        slots.add(slot);
      }
    }

    return slots;
  }

  Future<void> _confirm() async {
    if (!_validateTeamMembersForEveryService()) return;

    final start = _selectedTime;

    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translateText('Please select a time slot')),
        ),
      );
      return;
    }

    final endTime = _endTimeFor(start);

    final schedule = _BookingScheduleSelection(
      date: _selectedDate,
      startTime: start,
      endTime: endTime,
    );

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _BookingSummaryScreen(
          customerName: widget.customerName,
          customerPhone: widget.customerPhone,
          services: widget.services,
          professionals: Map<int, String>.from(_selectedProfessionals),
          date: _selectedDate,
          startTime: start,
          endTime: endTime,
          totalPrice: widget.totalPrice,
          durationMinutes: widget.durationMinutes,
          onConfirmBooking: () => widget.onConfirmBooking(schedule),
        ),
      ),
    );

    if (result == null || !mounted) return;

    Navigator.pop(context, result);
  }

  void _selectScheduleDate(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _selectedTime = null;
    });

    _loadAppointmentsForDate();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _shiftVisibleWeek(int dayDelta) {
    final today = _dateOnly(DateTime.now());
    final nextStart = _dateOnly(
      DateTime(
        _visibleWeekStart.year,
        _visibleWeekStart.month,
        _visibleWeekStart.day + dayDelta,
      ),
    );
    setState(() {
      _visibleWeekStart = nextStart.isBefore(today) ? today : nextStart;
    });
  }

  Widget _calendarArrowButton(
    IconData icon, {
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _bookingBorder),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? _bookingMuted : _bookingMuted.withValues(alpha: .35),
        ),
      ),
    );
  }

  num? _servicePrice(Map<String, dynamic> service) {
    final price = service['price'];
    if (price is num) return price;
    return num.tryParse('${price ?? ''}');
  }

  String _formatServicePrice(num price) {
    return formatMinorAmount(price);
  }

  Widget _selectedServicesTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translateText('Selected Services & Team').toUpperCase(),
          style: const TextStyle(
            color: _bookingInk,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        for (final service in widget.services)
          _selectedServiceTeamCard(service),
      ],
    );
  }

  Widget _selectedServiceTeamCard(Map<String, dynamic> service) {
    final serviceId = _idFrom(service['id']);
    final name = (service['name'] ?? '').toString();
    final price = _servicePrice(service);
    final members = serviceId == null
        ? const <Map<String, dynamic>>[]
        : widget.serviceMembers[serviceId] ?? const <Map<String, dynamic>>[];
    final selectedMember =
        serviceId == null ? null : _selectedProfessionals[serviceId];
    final validSelectedMember = members.any(
      (member) => member['label'] == selectedMember,
    )
        ? selectedMember
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bookingBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bookingInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 10),
                Text(
                  _formatServicePrice(price),
                  style: const TextStyle(
                    color: _bookingGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _bookingFieldFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bookingBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validSelectedMember,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFBDB7B1),
                  size: 22,
                ),
                hint: Text(
                  translateText('Select Team Member'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bookingMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                items: members
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member['label'] as String,
                        child: Text(
                          member['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _bookingInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: serviceId == null || members.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          if (value == null || value.isEmpty) {
                            _selectedProfessionals.remove(serviceId);
                          } else {
                            _selectedProfessionals[serviceId] = value;
                          }
                        });

                        widget.onProfessionalsChanged(
                          Map<int, String>.from(_selectedProfessionals),
                        );
                      },
                selectedItemBuilder: (_) => members
                    .map(
                      (member) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          member['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _bookingInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            validSelectedMember == null
                ? translateText('No team member selected.')
                : translateText('Team member selected.'),
            style: const TextStyle(
              color: _bookingMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                translateText('No team member available for this service.'),
                style: const TextStyle(
                  color: _bookingMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _availableSlots();
    final today = _dateOnly(DateTime.now());
    final canGoBack = _visibleWeekStart.isAfter(today);
    final days = List.generate(
      7,
      (index) => DateTime(
        _visibleWeekStart.year,
        _visibleWeekStart.month,
        _visibleWeekStart.day + index,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: buildProfileSubpageAppBar(title: translateText('Select Time')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        color: _bookingInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _calendarArrowButton(
                    Icons.chevron_left_rounded,
                    enabled: canGoBack,
                    onTap: () => _shiftVisibleWeek(-7),
                  ),
                  const SizedBox(width: 6),
                  _calendarArrowButton(
                    Icons.chevron_right_rounded,
                    onTap: () => _shiftVisibleWeek(7),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: days.map((day) {
                    final selected = DateUtils.isSameDay(day, _selectedDate);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          if (DateUtils.isSameDay(day, _selectedDate)) {
                            return;
                          }
                          _selectScheduleDate(day);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? _bookingGold : Colors.white,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: selected ? _bookingGold : _bookingBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('E').format(day),
                                style: TextStyle(
                                  color:
                                      selected ? Colors.white : _bookingMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('d').format(day),
                                style: TextStyle(
                                  color: selected ? Colors.white : _bookingInk,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _selectedServicesTeamSection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    translateText('Available Slots'),
                    style: const TextStyle(
                      color: _bookingInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.wb_sunny_outlined,
                      size: 13, color: _bookingMuted),
                  const SizedBox(width: 5),
                  Text(
                    translateText('Morning & Afternoon'),
                    style: const TextStyle(
                      color: _bookingMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingAppointments)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _bookingBorder),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _bookingGold,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              else if (slots.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _bookingBorder),
                  ),
                  child: Text(
                    translateText(
                      'No available slots for the selected date and artisan.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _bookingMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const columns = 3;
                    const gap = 9.0;
                    final slotWidth =
                        (constraints.maxWidth - (gap * (columns - 1))) /
                            columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 9,
                      children: slots.map((slot) {
                        final selected = _selectedTime != null &&
                            _toMinutes(_selectedTime!) == _toMinutes(slot);
                        return InkWell(
                          onTap: () => setState(() => _selectedTime = slot),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: slotWidth,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? _bookingGold : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selected ? _bookingGold : _bookingBorder,
                              ),
                            ),
                            child: Text(
                              _formatTime(slot),
                              style: TextStyle(
                                color: selected ? Colors.white : _bookingInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bookingBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/salon2.jpeg',
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translateText('Treatment Focus').toUpperCase(),
                            style: const TextStyle(
                              color: _bookingGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            translateText(
                              'Ensure your client arrives 15 minutes before the selected time slot.',
                            ),
                            style: const TextStyle(
                              color: _bookingMuted,
                              fontSize: 12,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bookingBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EAD2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: _bookingGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translateText('Duration').toUpperCase(),
                                style: const TextStyle(
                                  color: _bookingMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${translateText('Total')}: ${widget.durationMinutes} min',
                                style: const TextStyle(
                                  color: _bookingInk,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _bookingInk,
                              side: const BorderSide(color: _bookingBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            child: Text(translateText('Back')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _confirm,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(translateText('Confirm Time')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bookingGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSummaryScreen extends StatefulWidget {
  const _BookingSummaryScreen({
    required this.customerName,
    required this.customerPhone,
    required this.services,
    required this.professionals,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.durationMinutes,
    required this.onConfirmBooking,
  });

  final String customerName;
  final String customerPhone;
  final List<Map<String, dynamic>> services;
  final Map<int, String> professionals;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final num totalPrice;
  final int durationMinutes;
  final Future<Map<String, dynamic>?> Function() onConfirmBooking;

  @override
  State<_BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<_BookingSummaryScreen> {
  bool _submitting = false;

  String get customerName => widget.customerName;
  String get customerPhone => widget.customerPhone;
  List<Map<String, dynamic>> get services => widget.services;
  Map<int, String> get professionals => widget.professionals;
  DateTime get date => widget.date;
  TimeOfDay get startTime => widget.startTime;
  TimeOfDay get endTime => widget.endTime;
  num get totalPrice => widget.totalPrice;
  int get durationMinutes => widget.durationMinutes;

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    return DateFormat('h:mm a').format(
      DateTime(now.year, now.month, now.day, time.hour, time.minute),
    );
  }

  Future<void> _handleConfirmBooking() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.onConfirmBooking();
      if (!mounted || result == null) return;
      Navigator.pop(context, result);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar:
          buildProfileSubpageAppBar(title: translateText('Booking Summary')),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
              child: Column(
                children: [
                  _summaryCard(
                    title: translateText('Client Identity'),
                    trailing: Icons.person_rounded,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFF5EAD2),
                          child: Text(
                            customerName.isNotEmpty
                                ? customerName.characters.first.toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              color: _bookingGold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  color: _bookingInk,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                customerPhone,
                                style: const TextStyle(
                                  color: _bookingMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryCard(
                    title: translateText('Assigned Artisan'),
                    titleTrailing:
                        professionals.isEmpty ? null : _verifiedBadge(),
                    child: _assignedArtisanServices(),
                  ),
                  const SizedBox(height: 12),
                  _summaryCard(
                    title: translateText('Schedule'),
                    trailing: Icons.calendar_month_rounded,
                    child: Column(
                      children: [
                        _summaryBlock(
                          translateText('Date'),
                          DateFormat('EEEE, MMM d\nyyyy').format(date),
                        ),
                        _summaryBlock(
                          translateText('Commences'),
                          _formatTime(startTime),
                        ),
                        _summaryBlock(
                          translateText('Concludes'),
                          _formatTime(endTime),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryCard(
                    title: translateText('Services Portfolio'),
                    subtitle: '$durationMinutes min total',
                    child: Column(
                      children: [
                        for (final service in services) _serviceLine(service),
                        const Divider(height: 24, color: _bookingBorder),
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              translateText('Total Investment').toUpperCase(),
                              style: const TextStyle(
                                color: _bookingMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatMinorAmount(totalPrice),
                            style: const TextStyle(
                              color: _bookingGold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _handleConfirmBooking,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _submitting
                            ? translateText('Confirming...')
                            : translateText('Confirm Booking'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bookingGold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0x338B6500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: .12),
                child: const Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      color: _bookingGold,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required Widget child,
    IconData? trailing,
    String? subtitle,
    Widget? titleTrailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _bookingBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _bookingMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              if (subtitle != null) ...[
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _bookingMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (titleTrailing != null) ...[
                if (subtitle != null) const SizedBox(width: 8),
                titleTrailing,
              ],
              if (trailing != null)
                Icon(trailing, size: 15, color: _bookingGold),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8EF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        translateText('Verified').toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF168546),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _summaryBlock(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bookingFieldFill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _bookingMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: _bookingInk,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatServicePrice(num price) {
    return formatMinorAmount(price);
  }

  Widget _assignedArtisanServices() {
    return Column(
      children: [
        for (var index = 0; index < services.length; index++) ...[
          _assignedArtisanLine(services[index]),
          if (index != services.length - 1)
            const Divider(height: 20, color: _bookingBorder),
        ],
      ],
    );
  }

  Widget _assignedArtisanLine(Map<String, dynamic> service) {
    final serviceId = service['id'] is int
        ? service['id'] as int
        : int.tryParse('${service['id'] ?? ''}');
    final artisan = serviceId == null ? '' : professionals[serviceId] ?? '';
    final hasArtisan = artisan.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              hasArtisan ? const Color(0xFFF5EAD2) : _bookingFieldFill,
          child: Icon(
            hasArtisan ? Icons.person_rounded : Icons.person_off_rounded,
            color: hasArtisan ? _bookingGold : _bookingMuted,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (service['name'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _bookingInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasArtisan ? artisan : translateText('No team member selected'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasArtisan ? _bookingGold : _bookingMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serviceLine(Map<String, dynamic> service) {
    final price = service['price'];
    final duration = service['durationMin'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _bookingFieldFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: _bookingGold,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (service['name'] ?? '').toString(),
                  style: const TextStyle(
                    color: _bookingInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  duration is num ? '${duration.toInt()} min session' : '',
                  style: const TextStyle(
                    color: _bookingMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price is num ? formatMinorAmount(price) : '',
            style: const TextStyle(
              color: _bookingGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
