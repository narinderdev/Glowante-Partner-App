// lib/screens/AddTeam.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'add_location_screen.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:image_picker/image_picker.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../screens/AddTeamChooseTimeSlots.dart';
import '../utils/api_service.dart';
import '../utils/aws_s3_uploader.dart';
import '../utils/colors.dart';
import '../utils/input_validation.dart';
import '../widgets/multi_step_flow_header.dart';
import 'package:fluttertoast/fluttertoast.dart';

const Color _teamMemberAccent = Color(0xFF8B6500);
const Color _teamMemberSoftFill = Color(0xFFECE7E1);
const Color _teamMemberSoftBorder = Color(0xFFD8C7B3);

class AddTeamScreen extends StatefulWidget {
  final int branchId;
  final int salonId;
  final String? salonName;
  final bool isEdit;
  final Map<String, dynamic>? initialMember;

  const AddTeamScreen({
    super.key,
    required this.branchId,
    required this.salonId,
    required this.salonName,
    this.isEdit = false,
    this.initialMember,
  });

  @override
  State<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _showGlobalErrors = false;

  bool _suppressPhoneError = false;
  bool _suppressVerifyError = false;
  bool _suppressFirstNameError = false;
  bool _suppressLastNameError = false;
  bool _suppressEmailError = false;
  bool _suppressOtpError = false;
  bool _suppressAddressError = false;
  bool _suppressGenderError = false;
  bool _suppressRolesError = false;
  bool _suppressSpecsError = false;
  bool _suppressDateError = false;
  bool _suppressExperienceError = false;
  bool _suppressBriefError = false;
  final Color _errorColor = AppColors.red;
  final Color _verifyWarnColor = AppColors.red;
  final Color _successColor = Colors.green;

  List<Map<String, dynamic>> _allRoles = [];
  List<Map<String, dynamic>> _allSpecs = [];

  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _briefCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _brieftFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();

  late FlutterGooglePlacesSdk _places;

  DateTime? _joiningDate;
  String _gender = '';

  final List<String> _selectedRoles = [];
  final List<String> _selectedSpecs = [];
  List<Map<String, String>>? _rememberedSchedules;
  List<int>? _rememberedBranchServiceIds;

  bool _phoneVerified = false;
  bool _isVerifying = false;
  bool _isSubmitting = false;
  bool _isSelectingAddress = false;

  final Color _fieldFill = const Color(0xFFFAF9F8);
  final BorderRadius _radius = BorderRadius.circular(12);
  final RegExp _emailRegExp =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  final RegExp _nameRegExp = RegExp(r'^[A-Za-z ]+$');

  File? _cameraImage;
  String? imageUrl;
  String? _existingImageUrl;

  List<AutocompletePrediction> _addressPredictions = [];
  Map<String, dynamic>? _selectedAddress;

  List<int> _normalizeServiceIds(dynamic rawSelected) {
    final ids = <int>[];

    if (rawSelected is List) {
      for (final item in rawSelected) {
        final parsed = item is int
            ? item
            : item is num
                ? item.toInt()
                : int.tryParse('${item ?? ''}');
        if (parsed != null) {
          ids.add(parsed);
        }
      }
    }

    return ids;
  }

  List<Map<String, String>> _normalizeSchedules(dynamic rawSchedules) {
    if (rawSchedules is! List) return const [];

    return rawSchedules
        .whereType<Map>()
        .map((item) => Map<String, String>.from(item))
        .toList();
  }

  @override
  void initState() {
    super.initState();

    _places = FlutterGooglePlacesSdk(
      dotenv.env['GOOGLE_API_KEY'] ?? '',
    );

    _fetchRolesAndSpecializations();
    _prefillFromInitialMember();
    _joiningDate ??= _todayDateOnly();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _briefCtrl.dispose();
    _addressCtrl.dispose();
    _experienceCtrl.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _brieftFocus.dispose();
    _addressFocus.dispose();

    super.dispose();
  }

  String? _vPhone(String? v) {
    if (_suppressPhoneError) return null;

    final phone = (v ?? '').trim();

    if (phone.isEmpty) return translateText('Phone number is required');
    if (phone.length != 10) {
      return translateText('Phone number must be 10 digits.');
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return translateText('Enter a valid mobile number.');
    }

    return null;
  }

  String? _vExperience(String? v) {
    if (_suppressExperienceError) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('Experience is required');

    final exp = int.tryParse(x);
    if (exp == null) return translateText('Enter valid experience');

    if (exp < 0) return translateText('Experience cannot be negative');

    return null;
  }

  String? _vFirstName(String? v) {
    if (_suppressFirstNameError) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('First Name is required');
    if (!_nameRegExp.hasMatch(x)) {
      return translateText('Only letters and spaces are allowed.');
    }

    return null;
  }

  String? _vLastName(String? v) {
    if (_suppressLastNameError) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('Last Name is required');
    if (!_nameRegExp.hasMatch(x)) {
      return translateText('Only letters and spaces are allowed.');
    }

    return null;
  }

  String? _vBrief(String? v) {
    if (_suppressBriefError) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) {
      return translateText('Brief about team member is required');
    }

    return null;
  }

  String? _vEmail(String? v) {
    if (_suppressEmailError) return null;

    final x = (v ?? '').trim();

    if (x.isEmpty) return translateText('Email is required.');
    if (!_isValidEmail(x)) {
      return translateText('Enter a valid email address.');
    }

    return null;
  }

  bool _isValidEmail(String value) {
    if (!_emailRegExp.hasMatch(value)) return false;
    if (value.contains('..')) return false;

    final parts = value.split('@');
    if (parts.length != 2) return false;

    final local = parts.first;
    final domain = parts.last.toLowerCase();
    if (local.startsWith('.') || local.endsWith('.')) return false;

    final domainLabels = domain.split('.');
    if (domainLabels.length < 2) return false;
    for (final label in domainLabels) {
      if (label.isEmpty || label.startsWith('-') || label.endsWith('-')) {
        return false;
      }
    }

    final tld = domainLabels.last;
    return RegExp(r'^[a-z]{2,10}$').hasMatch(tld);
  }

  String? _vAddress() {
    if (_suppressAddressError) return null;

    final address = _addressCtrl.text.trim();

    if (address.isEmpty) {
      return translateText('Address is required');
    }

    if (_selectedAddress == null) {
      return translateText('Please select address from suggestions');
    }

    return null;
  }

  String? _vGender() {
    if (_suppressGenderError) return null;

    return _gender.isEmpty ? translateText('Select gender') : null;
  }

  String? _vJoiningDate() {
    if (_suppressDateError) return null;

    return _joiningDate == null
        ? translateText('Joining Date is required')
        : null;
  }

  String? _vRoles() {
    if (_suppressRolesError) return null;

    return _selectedRoles.isEmpty ? translateText('Select role') : null;
  }

  String? _vSpecs() {
    if (_suppressSpecsError) return null;

    return _selectedSpecs.isEmpty
        ? translateText('Select specialization')
        : null;
  }

  void _clearPhoneValidation() {
    if (!mounted) return;
    setState(() {
      _suppressPhoneError = true;
      _suppressVerifyError = true;
    });
  }

  void _clearFirstNameValidation() {
    if (!mounted) return;
    setState(() => _suppressFirstNameError = true);
  }

  void _clearLastNameValidation() {
    if (!mounted) return;
    setState(() => _suppressLastNameError = true);
  }

  void _clearEmailValidation() {
    if (!mounted) return;
    setState(() => _suppressEmailError = true);
  }

  void _setGender(String value) {
    if (!mounted) return;
    setState(() {
      _gender = value;
      _suppressGenderError = true;
    });
    _refreshValidationIfNeeded();
  }

  void _clearExperienceValidation() {
    if (!mounted) return;
    setState(() => _suppressExperienceError = true);
  }

  void _clearBriefValidation() {
    if (!mounted) return;
    setState(() => _suppressBriefError = true);
  }

  void _refreshValidationIfNeeded() {
    if (!mounted || !_showGlobalErrors) return;
    _formKey.currentState?.validate();
  }

  Future<void> _fetchRolesAndSpecializations() async {
    try {
      final data = await ApiService().getRolesAndSpecializations(
        branchId: widget.branchId,
      );

      if (!mounted) return;

      setState(() {
        _allRoles = _readOptionMaps(data['roles'])
            .where((role) => role['branchId'] != null)
            .where((role) => !_isOwnerRoleOption(role))
            .toList();
        _allSpecs = _readOptionMaps(
          data['specialities'] ?? data['specializations'],
        );
        _normalizeSelectedOptions(_selectedRoles, _allRoles);
        _selectedRoles.removeWhere(_isOwnerRoleText);
        _normalizeSelectedOptions(_selectedSpecs, _allSpecs);
      });
    } catch (e) {
      debugPrint('Error fetching roles/specs: $e');
    }
  }

  List<Map<String, dynamic>> _readOptionMaps(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  void _prefillFromInitialMember() {
    final member = widget.initialMember;
    if (member == null) return;

    final branchAssignment = _branchAssignment(member);

    _phoneCtrl.text =
        (member['phoneNumber'] ?? member['phone'] ?? '').toString().trim();
    _firstNameCtrl.text = (member['firstName'] ?? '').toString().trim();
    _lastNameCtrl.text = (member['lastName'] ?? '').toString().trim();
    _emailCtrl.text = (member['email'] ?? '').toString().trim();
    _gender = _normalizeGender(
      _firstTextValue(
        [branchAssignment, member],
        const ['gender', 'sex'],
      ),
    );
    _briefCtrl.text = _firstTextValue(
      [branchAssignment, member],
      const [
        'info',
        'brief',
        'description',
        'about',
        'bio',
        'aboutMe',
        'profileSummary',
        'professionalSummary',
        'professionalBio',
      ],
    );
    final exp = branchAssignment?['experience'] ?? member['experience'];
    _experienceCtrl.text = exp?.toString() ?? '';
    _existingImageUrl =
        (member['profilePictureUrl'] ?? '').toString().trim().isEmpty
            ? null
            : (member['profilePictureUrl'] ?? '').toString().trim();

    _phoneVerified = widget.isEdit;

    final joiningDateRaw =
        branchAssignment?['joiningDate'] ?? member['joiningDate'];
    if (joiningDateRaw is String && joiningDateRaw.trim().isNotEmpty) {
      _joiningDate = DateTime.tryParse(joiningDateRaw.trim());
    }

    _selectedRoles
      ..clear()
      ..addAll(
        _extractLabels(
          _firstListValue(
            [branchAssignment, member],
            const ['roles', 'roleCodes', 'roleIds'],
          ),
        ),
      );

    _selectedSpecs
      ..clear()
      ..addAll(
        _extractLabels(
          _firstListValue(
            [branchAssignment, member],
            const [
              'specialities',
              'specializations',
              'specialties',
              'specialitiesList',
              'specializationsList',
              'specialtiesList',
              'specialityCodes',
              'specializationCodes',
              'specialtyCodes',
              'specialityIds',
              'specializationIds',
              'specialtyIds',
            ],
          ),
        ),
      );

    final existingAddress = _normalizedAddress(
      member['address'] ?? branchAssignment?['address'],
    );

    if (existingAddress != null) {
      _selectedAddress = existingAddress;
      _addressCtrl.text = _addressDisplayText(existingAddress);
    }
  }

  Map<String, dynamic>? _branchAssignment(Map<String, dynamic> member) {
    final rawAssignments = member['userBranches'];

    if (rawAssignments is! List) {
      return null;
    }

    for (final assignment in rawAssignments) {
      if (assignment is! Map) continue;

      final branch = assignment['branch'];
      final branchId = branch is Map ? branch['id'] : assignment['branchId'];

      if (branchId?.toString() == widget.branchId.toString()) {
        return Map<String, dynamic>.from(assignment);
      }
    }

    if (rawAssignments.isNotEmpty && rawAssignments.first is Map) {
      return Map<String, dynamic>.from(rawAssignments.first as Map);
    }

    return null;
  }

  String _firstTextValue(
    List<Map<String, dynamic>?> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
    }
    return '';
  }

  List<dynamic> _firstListValue(
    List<Map<String, dynamic>?> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        if (value is List && value.isNotEmpty) return value;
        if (value is String && value.trim().isNotEmpty) {
          return value
              .split(',')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();
        }
      }
    }
    return const [];
  }

  List<int> _branchServiceIdsFromAssignment(Map<String, dynamic>? assignment) {
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

    final directIds = assignment?['branchServiceIds'];
    if (directIds is List) {
      for (final id in directIds) {
        addId(id);
      }
    }

    final userBranchServices = assignment?['userBranchServices'];
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

  List<String> _extractLabels(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .map((entry) {
          if (entry is Map) {
            return (entry['label'] ??
                    entry['name'] ??
                    entry['displayName'] ??
                    entry['code'] ??
                    entry['id'] ??
                    '')
                .toString()
                .trim();
          }
          return entry.toString().trim();
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _optionLabel(Map<String, dynamic> option) {
    return (option['label'] ?? option['name'] ?? option['displayName'] ?? '')
        .toString()
        .trim();
  }

  bool _isOwnerRoleOption(Map<String, dynamic> option) {
    return _optionKeys(option).any(_isOwnerRoleText);
  }

  bool _isOwnerRoleText(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

    return normalized
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .join(' ') ==
        'salon owner';
  }

  Set<String> _optionKeys(Map<String, dynamic> option) {
    return [
      option['label'],
      option['name'],
      option['displayName'],
      option['code'],
      option['id'],
    ]
        .map((value) => value?.toString().trim().toLowerCase() ?? '')
        .where((value) => value.isNotEmpty && value != 'null')
        .toSet();
  }

  void _normalizeSelectedOptions(
    List<String> selectedValues,
    List<Map<String, dynamic>> source,
  ) {
    if (selectedValues.isEmpty || source.isEmpty) return;

    final normalized = <String>[];
    for (final selected in selectedValues) {
      final selectedKey = selected.trim().toLowerCase();
      if (selectedKey.isEmpty) continue;

      String? matchedLabel;
      for (final option in source) {
        if (_optionKeys(option).contains(selectedKey)) {
          final label = _optionLabel(option);
          matchedLabel = label.isNotEmpty ? label : selected.trim();
          break;
        }
      }

      final value = matchedLabel ?? selected.trim();
      final exists = normalized.any(
        (current) => current.trim().toLowerCase() == value.toLowerCase(),
      );
      if (value.isNotEmpty && !exists) {
        normalized.add(value);
      }
    }

    selectedValues
      ..clear()
      ..addAll(normalized);
  }

  List<String> _resolveCodes(
    List<String> selectedValues,
    List<Map<String, dynamic>> source,
  ) {
    return selectedValues.map((selected) {
      final normalizedSelected = selected.trim().toLowerCase();

      for (final option in source) {
        if (_optionKeys(option).contains(normalizedSelected)) {
          final code =
              (option['code'] ?? _optionLabel(option)).toString().trim();
          return code.isEmpty ? selected.trim() : code;
        }
      }

      return normalizedSelected.replaceAll(' ', '_');
    }).toList();
  }

  Map<String, dynamic>? _normalizedAddress(dynamic rawAddress) {
    if (rawAddress is! Map) {
      return null;
    }

    final normalized = <String, dynamic>{};

    for (final entry in rawAddress.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;

      normalized[key] = value;
    }

    return normalized.isEmpty ? null : normalized;
  }

  String _addressDisplayText(Map<String, dynamic> address) {
    final parts = <String>[];

    void push(dynamic value) {
      final text = value?.toString().trim() ?? '';

      if (text.isEmpty || text.toLowerCase() == 'null') return;
      if (parts.contains(text)) return;

      parts.add(text);
    }

    // Show manual address first, same as salon flow
    push(address['line2']);
    push(address['line1']);
    push(address['village']);
    push(address['district']);
    push(address['city']);
    push(address['state']);
    push(address['postalCode']);
    push(address['country']);

    return parts.join(', ');
  }

  Future<void> _getAddressPredictions(String input) async {
    final query = input.trim();

    if (query.length < 2) {
      if (mounted) {
        setState(() => _addressPredictions = []);
      }
      return;
    }

    try {
      final result = await _places.findAutocompletePredictions(
        query,
        countries: const ['IN'],
      );

      if (!mounted) return;

      setState(() {
        _addressPredictions =
            List<AutocompletePrediction>.from(result.predictions);
      });
    } catch (e) {
      debugPrint('Address prediction error: $e');

      if (mounted) {
        setState(() => _addressPredictions = []);
      }
    }
  }

  String _componentValue(
    List<AddressComponent> components,
    List<String> wantedTypes,
  ) {
    for (final component in components) {
      final types = component.types;
      final matched = wantedTypes.any((type) => types.contains(type));

      if (matched) {
        return component.name.trim();
      }
    }

    return '';
  }

  Future<void> _selectAddressPrediction(
    AutocompletePrediction prediction,
  ) async {
    final placeId = prediction.placeId;
    final fallbackText = prediction.fullText.trim();

    if (placeId.isEmpty) return;

    _isSelectingAddress = true;

    try {
      final details = await _places.fetchPlace(
        placeId,
        fields: [
          PlaceField.Name,
          PlaceField.Address,
          PlaceField.AddressComponents,
          PlaceField.Location,
        ],
      );

      final place = details.place;
      final components = place?.addressComponents ?? const <AddressComponent>[];

      final formattedAddress = (place?.address ?? '').trim().isNotEmpty
          ? place!.address!.trim()
          : fallbackText;

      final city = _componentValue(
        components,
        const [
          'locality',
          'administrative_area_level_3',
          'sublocality',
          'sublocality_level_1',
        ],
      );

      final state = _componentValue(
        components,
        const ['administrative_area_level_1'],
      );

      final country = _componentValue(
        components,
        const ['country'],
      );

      final postalCode = _componentValue(
        components,
        const ['postal_code'],
      );

      final district = _componentValue(
        components,
        const ['administrative_area_level_2'],
      );

      final lat = place?.latLng?.lat;
      final lng = place?.latLng?.lng;

      final addressPayload = <String, dynamic>{
        'line1': formattedAddress,
        'line2': '',
        'village': '',
        'district': district,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'placeId': placeId,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      };

      if (!mounted) return;

      setState(() {
        _selectedAddress = addressPayload;
        _addressCtrl.text = formattedAddress;
        _addressPredictions = [];
        _suppressAddressError = true;
      });

      _addressFocus.unfocus();

      debugPrint('SELECTED TEAM ADDRESS = $addressPayload');
    } catch (e) {
      debugPrint('Address fetchPlace error: $e');

      if (!mounted) return;

      setState(() {
        _selectedAddress = {
          'line1': fallbackText,
          'placeId': placeId,
        };
        _addressCtrl.text = fallbackText;
        _addressPredictions = [];
        _suppressAddressError = true;
      });

      _addressFocus.unfocus();
    } finally {
      _isSelectingAddress = false;
    }
  }

  void _clearAddress() {
    setState(() {
      _addressCtrl.clear();
      _selectedAddress = null;
      _addressPredictions = [];
      _suppressAddressError = false;
    });

    _addressFocus.requestFocus();
  }

  // Map<String, dynamic>? _teamAddressPayload() {
  //   final selected = _selectedAddress;

  //   if (selected == null) return null;

  //   final address = Map<String, dynamic>.from(selected);

  //   address.removeWhere((key, value) {
  //     if (value == null) return true;
  //     if (value is String && value.trim().isEmpty) return true;
  //     return false;
  //   });

  //   return address.isEmpty ? null : address;
  // }
  // Map<String, dynamic>? _teamAddressPayload() {
  //   final selected = _selectedAddress;

  //   if (selected == null) return null;

  //   return {
  //     'line1': (selected['line1'] ?? '').toString(),
  //     'line2': (selected['line2'] ?? '').toString(),
  //     'village': (selected['village'] ?? '').toString(),
  //     'district': (selected['district'] ?? '').toString(),
  //     'city': (selected['city'] ?? '').toString(),
  //     'state': (selected['state'] ?? '').toString(),
  //     'country': (selected['country'] ?? '').toString(),
  //     'postalCode': (selected['postalCode'] ?? '').toString(),
  //   };
  // }

  Map<String, dynamic>? _teamAddressPayload() {
    final selected = _selectedAddress;

    if (selected == null) return null;

    return {
      'line1': (selected['line1'] ?? '').toString(),
      'line2': (selected['line2'] ?? '').toString(),
      'village': (selected['village'] ?? '').toString(),
      'district': (selected['district'] ?? '').toString(),
      'city': (selected['city'] ?? '').toString(),
      'state': (selected['state'] ?? '').toString(),
      'country': (selected['country'] ?? '').toString(),
      'postalCode': (selected['postalCode'] ?? '').toString(),
      if (selected['latitude'] != null) 'latitude': selected['latitude'],
      if (selected['longitude'] != null) 'longitude': selected['longitude'],
    };
  }

  String _normalizeGender(String value) {
    switch (value.trim().toLowerCase()) {
      case 'male':
      case 'm':
      case '1':
        return 'Male';
      case 'female':
      case 'f':
      case '2':
        return 'Female';
      case 'other':
      case 'o':
      case '3':
      case 'non-binary':
      case 'nonbinary':
        return 'Other';
      default:
        return value.trim();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      _cameraImage = File(picked.path);
    });

    _toast('Uploading image...');

    final uploaded =
        await AwsS3Uploader().uploadImageResult(picked, folder: 'uploads/team');

    if (uploaded != null) {
      setState(() {
        imageUrl = uploaded.cdnUrl ?? uploaded.publicUrl;
      });
      _toast('Image uploaded successfully');
    } else {
      _toast('❌ Failed to upload image');
    }
  }

  InputDecoration _decor({
    String? hint,
    Widget? prefix,
    Widget? suffix,
    EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8D867F), fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFE2D3BF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: _teamMemberAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        color: AppColors.red,
        fontSize: 12,
        height: 1.15,
      ),
      counterStyle: const TextStyle(
        color: Color(0xFF8D867F),
        fontSize: 12,
        height: 1.15,
      ),
    );
  }

  Widget _reqLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5E564F),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          '*',
          style: TextStyle(
            color: AppColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    Fluttertoast.showToast(msg: msg);
  }

  String _friendlyErrorMessage(Object error) {
    var text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd > jsonStart) {
      final jsonText = text.substring(jsonStart, jsonEnd + 1);
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map && decoded['message'] != null) {
          final message = decoded['message'];
          if (message is List) return message.join('\n');
          return message.toString();
        }
      } catch (_) {}
    }

    text = text
        .replaceFirst(RegExp(r'^Failed to update team member:\s*'), '')
        .replaceFirst(RegExp(r'^Failed to add team member:\s*'), '')
        .trim();
    return text.isEmpty ? translateText('Something went wrong') : text;
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    _firstNameFocus.unfocus();
    _lastNameFocus.unfocus();
    _emailFocus.unfocus();
    _brieftFocus.unfocus();
    _addressFocus.unfocus();
  }

  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Future<void> _pickJoiningDate() async {
  //   _dismissKeyboard();

  //   final now = DateTime.now();
  //   final today = DateTime(now.year, now.month, now.day);

  //   final res = await showDatePicker(
  //     context: context,
  //     firstDate: today,
  //     lastDate: DateTime(now.year + 5),
  //     initialDate: _joiningDate != null && _joiningDate!.isAfter(today)
  //         ? _joiningDate!
  //         : today,
  //     builder: (ctx, child) {
  //       return Theme(
  //         data: Theme.of(ctx).copyWith(
  //           colorScheme: const ColorScheme.light(
  //             primary: Colors.black,
  //             onPrimary: Colors.white,
  //             onSurface: Colors.black87,
  //           ),
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );

  //   _dismissKeyboard();

  //   if (res != null) {
  //     setState(() {
  //       _joiningDate = res;
  //       _suppressDateError = true;
  //     });
  //   }
  // }
  Future<void> _pickJoiningDate() async {
    _dismissKeyboard();

    final today = _todayDateOnly();
    final firstDate = DateTime(today.year - 50, today.month, today.day);
    final lastDate = DateTime(today.year + 5, today.month, today.day);
    final initialDate = _joiningDate == null
        ? today
        : _joiningDate!.isBefore(firstDate)
            ? firstDate
            : (_joiningDate!.isAfter(lastDate) ? lastDate : _joiningDate!);

    final res = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    _dismissKeyboard();

    if (res != null) {
      setState(() {
        _joiningDate = res;
        _suppressDateError = true;
      });
      _refreshValidationIfNeeded();
    }
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<Map<String, dynamic>> source,
    required List<String> target,
  }) async {
    _dismissKeyboard();

    final temp = [...target];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: source.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = source[i];
                        final itemName =
                            (item['label'] ?? item['name'] ?? '').toString();
                        final checked = temp.contains(itemName);

                        return CheckboxListTile(
                          value: checked,
                          activeColor: _teamMemberAccent,
                          checkColor: Colors.white,
                          onChanged: (v) {
                            if (v == true && !temp.contains(itemName)) {
                              temp.add(itemName);
                            } else if (v == false) {
                              temp.remove(itemName);
                            }
                            setModalState(() {});
                          },
                          title: Text(itemName),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    text: translateText('Done'),
                    onPressed: () {
                      setState(() {
                        target
                          ..clear()
                          ..addAll(temp);
                        if (target.isNotEmpty) {
                          if (identical(target, _selectedRoles)) {
                            _suppressRolesError = true;
                          } else if (identical(target, _selectedSpecs)) {
                            _suppressSpecsError = true;
                          }
                        }
                      });
                      _refreshValidationIfNeeded();

                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    _dismissKeyboard();
  }

  Future<void> _showValidationDialog(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8D8C3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 42),
                      child: Text(
                        translateText('Required Fields'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2D2926),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF5E564F),
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(errors.length, (index) {
                    final message = errors[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == errors.length - 1 ? 0 : 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•',
                            style: TextStyle(
                              color: AppColors.red,
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _afterRebuild() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  Future<bool> _validateFormAndShowAlert() async {
    setState(() {
      _showGlobalErrors = true;

      _suppressPhoneError = false;
      _suppressVerifyError = false;
      _suppressFirstNameError = false;
      _suppressLastNameError = false;
      _suppressEmailError = false;
      _suppressOtpError = false;
      _suppressAddressError = false;
      _suppressGenderError = false;
      _suppressRolesError = false;
      _suppressSpecsError = false;
      _suppressDateError = false;
      _suppressExperienceError = false;
      _suppressBriefError = false;
    });

    await _afterRebuild();

    _formKey.currentState?.validate();

    final errors = <String>[];

    void push(String? e) {
      if (e != null && e.trim().isNotEmpty) {
        errors.add(e);
      }
    }

    push(_vPhone(_phoneCtrl.text));
    push(_vFirstName(_firstNameCtrl.text));
    push(_vLastName(_lastNameCtrl.text));
    push(_vEmail(_emailCtrl.text));
    push(_vAddress());
    push(_vGender());
    push(_vRoles());
    push(_vSpecs());
    push(_vJoiningDate());
    push(_vBrief(_briefCtrl.text));
    push(_vExperience(_experienceCtrl.text));
    if (errors.isNotEmpty) {
      await _showValidationDialog(errors);
      return false;
    }

    return true;
  }

  Future<bool> _validateUniqueTeamContact() async {
    final phone = _normalizePhoneForContact(_phoneCtrl.text);
    final email = _emailCtrl.text.trim().toLowerCase();

    String? phoneToValidate = phone.isEmpty ? null : phone;
    String? emailToValidate = email.isEmpty ? null : email;

    if (widget.isEdit) {
      final originalPhone = _normalizePhoneForContact(_initialPhoneNumber());
      final originalEmail = _initialEmail().trim().toLowerCase();
      final phoneChanged = phone != originalPhone;
      final emailChanged = email != originalEmail;

      if (!phoneChanged && !emailChanged) return true;

      if (!phoneChanged) phoneToValidate = null;
      if (!emailChanged) emailToValidate = null;
    }

    if (phoneToValidate == null && emailToValidate == null) return true;

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService().validateTeamMemberContact(
        widget.branchId,
        email: emailToValidate,
        phoneNumber: phoneToValidate,
      );

      if (!mounted) return false;

      final data = response['data'];
      final messageFromResponse = () {
        if (data is Map<String, dynamic>) {
          final reason = data['reason']?.toString().trim();
          if (reason != null && reason.isNotEmpty) return reason;

          final dataMessage = data['message']?.toString().trim();
          if (dataMessage != null && dataMessage.isNotEmpty) return dataMessage;
        }

        final message = response['message']?.toString().trim();
        return message != null && message.isNotEmpty
            ? message
            : translateText(
                'Unable to validate phone or email right now. Please try again.');
      }();

      final recommendedAction = data is Map<String, dynamic>
          ? data['recommendedAction']?.toString().trim()
          : '';
      final canProceed =
          data is Map<String, dynamic> ? data['canProceed'] == true : false;

      if (response['success'] == true &&
          recommendedAction == 'ADD_TEAM_MEMBER' &&
          canProceed) {
        return true;
      }

      _toast(messageFromResponse);
      return false;
    } catch (error) {
      debugPrint('Team contact validation failed: $error');
      if (mounted) {
        _toast(_friendlyErrorMessage(error));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _normalizePhoneForContact(String value) {
    final digits = _digitsOnly(value);
    if (digits.length > 10 && digits.startsWith('91')) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _initialPhoneNumber() {
    final member = widget.initialMember;
    if (member == null) return '';
    return _firstTextValue(
      [member],
      const [
        'phoneNumber',
        'phone',
        'mobile',
        'mobileNumber',
        'contactNumber',
        'fullPhoneNumber',
      ],
    );
  }

  String _initialEmail() {
    final member = widget.initialMember;
    if (member == null) return '';
    return _firstTextValue(
      [member],
      const ['email', 'emailAddress'],
    );
  }

  Future<void> _submitEditMember() async {
    if (!await _validateFormAndShowAlert()) return;
    if (!await _validateUniqueTeamContact()) return;
    if (!mounted) return;

    final userId = (widget.initialMember?['id'] as num?)?.toInt();
    if (userId == null) {
      _toast('Missing member id');
      return;
    }

    String capitalizeFirst(String value) =>
        value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value;

    setState(() => _isSubmitting = true);

    try {
      final branchAssignment =
          _branchAssignment(widget.initialMember ?? const {});
      final branchServiceIds = _branchServiceIdsFromAssignment(
        branchAssignment ?? widget.initialMember,
      );

      final payload = <String, dynamic>{
        'countryCode': '+91',
        'phoneNumber': _phoneCtrl.text.trim(),
        'firstName': capitalizeFirst(_firstNameCtrl.text.trim()),
        'lastName': capitalizeFirst(_lastNameCtrl.text.trim()),
        'email': _emailCtrl.text.trim(),
        'gender': _gender.toLowerCase(),
        'experience': int.parse(_experienceCtrl.text.trim()),
        if (_joiningDate != null)
          'joiningDate':
              '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
        'info': capitalizeFirst(_briefCtrl.text.trim()),
        'roles': _resolveCodes(_selectedRoles, _allRoles),
        'specialities': _resolveCodes(_selectedSpecs, _allSpecs),
        'profilePictureUrl': imageUrl ?? _existingImageUrl,
        'schedules': branchAssignment?['schedules'] ??
            widget.initialMember?['schedules'] ??
            const [],
        'branchServiceIds': branchServiceIds,
        'userBranchServices': branchAssignment?['userBranchServices'] ??
            widget.initialMember?['userBranchServices'] ??
            const [],
        'allowOnlineBooking': branchAssignment?['allowOnlineBooking'] ??
            widget.initialMember?['allowOnlineBooking'] ??
            true,
        if (_teamAddressPayload() != null) 'address': _teamAddressPayload(),
      }..removeWhere((key, value) => value == null);

      await ApiService().updateTeamMember(
        branchId: widget.branchId,
        userId: userId,
        payload: payload,
      );

      if (!mounted) return;

      Fluttertoast.showToast(
          msg: translateText('Team member updated successfully'));

      Navigator.pop(context, true);
    } catch (error) {
      _toast(_friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _goToScheduleStep() async {
    _dismissKeyboard();

    if (!await _validateFormAndShowAlert()) return;
    if (!await _validateUniqueTeamContact()) return;
    if (!mounted) return;

    String capitalizeFirst(String value) =>
        value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value;

    final branchAssignment =
        _branchAssignment(widget.initialMember ?? const {});

    final branchServiceIds = _rememberedBranchServiceIds ??
        _branchServiceIdsFromAssignment(
          branchAssignment ?? widget.initialMember,
        );

    final schedules = _rememberedSchedules ??
        _normalizeSchedules(
          branchAssignment?['schedules'] ?? widget.initialMember?['schedules'],
        );

    final userId = (widget.initialMember?['id'] as num?)?.toInt();

    final payload = <String, dynamic>{
      'isEdit': widget.isEdit,
      if (widget.isEdit && userId != null) 'userId': userId,
      if (widget.isEdit) 'originalPhoneNumber': _initialPhoneNumber(),
      if (widget.isEdit) 'originalEmail': _initialEmail(),
      'countryCode': '+91',
      'phoneNumber': _phoneCtrl.text.trim(),
      'firstName': capitalizeFirst(_firstNameCtrl.text.trim()),
      'lastName': capitalizeFirst(_lastNameCtrl.text.trim()),
      'email': _emailCtrl.text.trim(),
      'gender': _gender.toLowerCase(),
      if (_joiningDate != null)
        'joiningDate':
            '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
      'brief': capitalizeFirst(_briefCtrl.text.trim()),
      'info': capitalizeFirst(_briefCtrl.text.trim()),
      'roles': _resolveCodes(_selectedRoles, _allRoles),
      'specializations': _resolveCodes(_selectedSpecs, _allSpecs),
      'specialities': _resolveCodes(_selectedSpecs, _allSpecs),
      'experience': int.parse(_experienceCtrl.text.trim()),
      'profilePictureUrl': imageUrl ?? _existingImageUrl,
      'allowOnlineBooking': branchAssignment?['allowOnlineBooking'] ??
          widget.initialMember?['allowOnlineBooking'] ??
          true,
      'branchServiceIds': branchServiceIds,
      if (widget.isEdit)
        'userBranchServices': branchAssignment?['userBranchServices'] ??
            widget.initialMember?['userBranchServices'] ??
            const [],
      'schedules': schedules,
      if (_teamAddressPayload() != null) 'address': _teamAddressPayload(),
    };

    _dismissKeyboard();

    debugPrint('Sending to Choose time slots: $payload');

    final refresh = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTeamChooseTimeSlot(
          formData: {
            'salonId': widget.salonId,
            'branchId': widget.branchId,
            'salonName': widget.salonName,
            ...payload,
          },
        ),
      ),
    );

    if (!mounted) return;

    if (refresh is Map) {
      _rememberedBranchServiceIds =
          _normalizeServiceIds(refresh['selectedServiceIds']);
      _rememberedSchedules = _normalizeSchedules(refresh['schedules']);

      if (refresh['completed'] == true) {
        Navigator.pop(context, true);
      }
      return;
    }

    if (refresh is List) {
      _rememberedSchedules = _normalizeSchedules(refresh);
      return;
    }

    if (refresh == true) {
      Navigator.pop(context, true);
    }
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2D3BF))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            translateText(text).toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8D867F),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
              height: 1.25,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2D3BF))),
      ],
    );
  }

  Widget _optionalLabel(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          translateText(text).toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5E564F),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Text(
          translateText('Optional').toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF8D867F),
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _promoCard() {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: const DecorationImage(
          image: AssetImage('assets/images/add team logo.png'),
          fit: BoxFit.cover,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.58),
              _teamMemberAccent.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translateText('Empowering Your Talent'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              translateText(
                'Assign services and roles to help your team members shine in their expertise.',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _addressField() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _reqLabel(translateText('Address')),
  //       const SizedBox(height: 8),
  //       TextFormField(
  //         controller: _addressCtrl,
  //         focusNode: _addressFocus,
  //         autovalidateMode: _showGlobalErrors
  //             ? AutovalidateMode.onUserInteraction
  //             : AutovalidateMode.disabled,
  //         decoration: _decor(
  //           hint: translateText('Search address'),
  //           prefix: const Icon(
  //             Icons.location_on_outlined,
  //             color: Color(0xFF8D867F),
  //           ),
  //           suffix: _addressCtrl.text.trim().isEmpty
  //               ? null
  //               : IconButton(
  //                   icon: const Icon(
  //                     Icons.close_rounded,
  //                     color: Color(0xFF8D867F),
  //                   ),
  //                   onPressed: _clearAddress,
  //                 ),
  //         ),
  //         validator: (_) => _vAddress(),
  //         onChanged: (value) {
  //           if (_isSelectingAddress) return;

  //           setState(() {
  //             _selectedAddress = null;
  //             _suppressAddressError = true;
  //           });

  //           _getAddressPredictions(value);
  //         },
  //       ),
  //       if (_addressPredictions.isNotEmpty) ...[
  //         const SizedBox(height: 6),
  //         Container(
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(color: const Color(0xFFE2D3BF)),
  //             boxShadow: const [
  //               BoxShadow(
  //                 color: Color(0x12000000),
  //                 blurRadius: 12,
  //                 offset: Offset(0, 4),
  //               ),
  //             ],
  //           ),
  //           child: ListView.separated(
  //             shrinkWrap: true,
  //             physics: const NeverScrollableScrollPhysics(),
  //             itemCount: _addressPredictions.length,
  //             separatorBuilder: (_, __) => const Divider(height: 1),
  //             itemBuilder: (context, index) {
  //               final prediction = _addressPredictions[index];

  //               return ListTile(
  //                 dense: true,
  //                 leading: const Icon(
  //                   Icons.location_on_outlined,
  //                   color: _teamMemberAccent,
  //                   size: 20,
  //                 ),
  //                 title: Text(
  //                   prediction.primaryText,
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                   style: const TextStyle(
  //                     fontSize: 13,
  //                     fontWeight: FontWeight.w700,
  //                   ),
  //                 ),
  //                 subtitle: Text(
  //                   prediction.secondaryText,
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                   style: const TextStyle(fontSize: 12),
  //                 ),
  //                 onTap: () => _selectAddressPrediction(prediction),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ],
  //   );
  // }
  Widget _addressField() {
    final hasAddress = _selectedAddress != null &&
        _addressDisplayText(_selectedAddress!).trim().isNotEmpty;
    final hasError = _showGlobalErrors && _vAddress() != null;

    final displayAddress = hasAddress
        ? _addressDisplayText(_selectedAddress!)
        : translateText('Add Location');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reqLabel(translateText('Address')),
        const SizedBox(height: 8),
        InkWell(
          onTap: _chooseTeamLocation,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? AppColors.red : const Color(0xFFD3A94C),
                width: 1,
              ),
              boxShadow: hasError
                  ? [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_location_alt_rounded,
                  color: _teamMemberAccent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayAddress,
                    maxLines: hasAddress ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasAddress
                          ? const Color(0xFF3B332B)
                          : const Color(0xFF7A4A09),
                      fontWeight:
                          hasAddress ? FontWeight.w700 : FontWeight.w600,
                      fontSize: hasAddress ? 13 : 14,
                    ),
                  ),
                ),
                if (hasAddress)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8D867F),
                    ),
                    onPressed: _clearAddress,
                  ),
              ],
            ),
          ),
        ),
        if (_showGlobalErrors && _vAddress() != null) ...[
          const SizedBox(height: 6),
          Text(
            _vAddress()!,
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseTeamLocation() async {
    _dismissKeyboard();

    final selected = _selectedAddress;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          initialCompleteAddress:
              selected == null ? null : _addressDisplayText(selected),
          initialScoFlatHouse: selected?['line2']?.toString(),
          initialStreetSectorArea: [
            selected?['district']?.toString() ?? '',
            selected?['city']?.toString() ?? '',
            selected?['state']?.toString() ?? '',
            selected?['postalCode']?.toString() ?? '',
          ].where((part) => part.trim().isNotEmpty).join(', '),
        ),
      ),
    );

    if (!mounted || result == null) return;

    final completeAddress =
        (result['completeAddress'] as String?)?.trim() ?? '';
    final baseCompleteAddress =
        (result['baseCompleteAddress'] as String?)?.trim() ?? '';
    final scoFlatHouse = (result['scoFlatHouse'] as String?)?.trim() ?? '';
    final streetSectorArea =
        (result['streetSectorArea'] as String?)?.trim() ?? '';
    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();

    final line1 =
        baseCompleteAddress.isNotEmpty ? baseCompleteAddress : completeAddress;

    final line2 = [
      scoFlatHouse,
      streetSectorArea,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    setState(() {
      _selectedAddress = {
        'line1': line1,
        'line2': line2,
        'village': '',
        'district': '',
        'city': '',
        'state': '',
        'country': 'India',
        'postalCode': '',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

      _addressCtrl.text = _addressDisplayText(_selectedAddress!);
      _addressPredictions = [];
      _suppressAddressError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText(
          widget.isEdit ? 'Edit Team Member' : 'Add Team Member',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _teamMemberAccent, width: 1.4),
              ),
              child: ClipOval(
                child: Image(
                  image: (_existingImageUrl != null &&
                          _existingImageUrl!.isNotEmpty)
                      ? NetworkImage(_existingImageUrl!)
                      : const AssetImage('assets/images/person1.jpg')
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _teamMemberAccent;
              }
              if (states.contains(WidgetState.disabled)) {
                return _teamMemberSoftBorder;
              }
              return const Color(0xFFF0E3C8);
            }),
            checkColor: WidgetStateProperty.all(Colors.white),
            side: const BorderSide(color: Color(0xFFD9C8AB)),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: _teamMemberAccent,
            selectionColor: Color(0x33D3A94C),
            selectionHandleColor: _teamMemberAccent,
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (_, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MultiStepFlowHeader(
                          currentStep: 1,
                          useIcons: true,
                          activeColor: _teamMemberAccent,
                          inactiveFillColor: _teamMemberSoftFill,
                          inactiveBorderColor: _teamMemberSoftBorder,
                          steps: const [
                            FlowStepItem(
                              stepNumber: 1,
                              label: 'Personal',
                              icon: Icons.person_outline_rounded,
                            ),
                            FlowStepItem(stepNumber: 2, label: 'Schedule'),
                            FlowStepItem(stepNumber: 3, label: 'Services'),
                            FlowStepItem(stepNumber: 4, label: 'Availability'),
                          ],
                        ),
                        const SizedBox(height: 34),
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFD8C7B3),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _cameraImage == null
                                        ? (_existingImageUrl != null
                                            ? Image.network(
                                                _existingImageUrl!,
                                                fit: BoxFit.cover,
                                                width: 104,
                                                height: 104,
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.camera_alt_outlined,
                                                    color: Color(0xFF8D867F),
                                                    size: 28,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    translateText(
                                                        'Upload\nPhoto'),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Color(0xFF8D867F),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ))
                                        : Image.file(
                                            _cameraImage!,
                                            fit: BoxFit.cover,
                                            width: 104,
                                            height: 104,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: 8,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _teamMemberAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x26000000),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        _sectionTitle('Personal\nInformation'),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Phone Number')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneCtrl,
                          maxLength: AppInputRules.phoneMaxLength,
                          enabled: widget.isEdit || !_phoneVerified,
                          keyboardType: TextInputType.phone,
                          autovalidateMode: _showGlobalErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          textCapitalization: TextCapitalization.none,
                          decoration: _decor(
                            hint: translateText('Enter phone number'),
                            prefix: Container(
                              width: 64,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Color(0xFFE2D3BF)),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+91',
                                    style: TextStyle(
                                      color: Color(0xFF2D2926),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: Color(0xFF8D867F),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          validator: _vPhone,
                          onChanged: (_) {
                            _clearPhoneValidation();
                            _refreshValidationIfNeeded();
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_phoneVerified && !widget.isEdit)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              translateText('Phone verified'),
                              style: TextStyle(
                                color: _successColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (_showGlobalErrors)
                          FormField<bool>(
                            autovalidateMode: AutovalidateMode.always,
                            builder: (state) => state.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: _verifyWarnColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 8),
                        _reqLabel(translateText('First Name')),
                        const SizedBox(height: 8),
                        TextFormField(
                          focusNode: _firstNameFocus,
                          controller: _firstNameCtrl,
                          maxLength: AppInputRules.nameMaxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: AppInputRules.nameFormatters,
                          autovalidateMode: _showGlobalErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          decoration: _decor(
                            hint: translateText('Enter first name'),
                          ),
                          validator: _vFirstName,
                          onChanged: (value) {
                            _clearFirstNameValidation();
                            _refreshValidationIfNeeded();
                          },
                        ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Last Name')),
                        const SizedBox(height: 8),
                        TextFormField(
                          focusNode: _lastNameFocus,
                          controller: _lastNameCtrl,
                          maxLength: AppInputRules.nameMaxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: AppInputRules.nameFormatters,
                          autovalidateMode: _showGlobalErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          decoration: _decor(
                            hint: translateText('Enter last name'),
                          ),
                          validator: _vLastName,
                          onChanged: (value) {
                            _clearLastNameValidation();
                            _refreshValidationIfNeeded();
                          },
                        ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Email')),
                        const SizedBox(height: 8),
                        TextFormField(
                          focusNode: _emailFocus,
                          controller: _emailCtrl,
                          maxLength: AppInputRules.emailMaxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: AppInputRules.emailFormatters,
                          autovalidateMode: _showGlobalErrors
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          decoration: _decor(
                            hint: translateText('Enter email address'),
                            suffix: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFF8D867F),
                            ),
                          ),
                          validator: _vEmail,
                          onChanged: (_) {
                            _clearEmailValidation();
                            _refreshValidationIfNeeded();
                          },
                        ),
                        const SizedBox(height: 16),
                        _addressField(),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Gender')),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'Male',
                              groupValue: _gender,
                              activeColor: _teamMemberAccent,
                              onChanged: (v) => _setGender(v ?? ''),
                            ),
                            Text(translateText('Male')),
                            const SizedBox(width: 16),
                            Radio<String>(
                              value: 'Female',
                              groupValue: _gender,
                              activeColor: _teamMemberAccent,
                              onChanged: (v) => _setGender(v ?? ''),
                            ),
                            Text(translateText('Female')),
                            const SizedBox(width: 16),
                            Radio<String>(
                              value: 'Other',
                              groupValue: _gender,
                              activeColor: _teamMemberAccent,
                              onChanged: (v) => _setGender(v ?? ''),
                            ),
                            Text(translateText('Other')),
                          ],
                        ),
                        if (_showGlobalErrors)
                          FormField<String>(
                            autovalidateMode: AutovalidateMode.always,
                            validator: (_) => _vGender(),
                            builder: (state) => state.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 22),
                        _sectionTitle('Professional\nRoles'),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Roles')),
                        const SizedBox(height: 8),
                        _PickField(
                          hint: translateText('Select Roles'),
                          values: _selectedRoles,
                          hasError: _showGlobalErrors && _vRoles() != null,
                          onTap: () => _openMultiSelect(
                            title: translateText('Select Roles'),
                            source: _allRoles,
                            target: _selectedRoles,
                          ),
                        ),
                        if (_showGlobalErrors)
                          FormField<List<String>>(
                            autovalidateMode: AutovalidateMode.always,
                            validator: (_) => _vRoles(),
                            builder: (state) => state.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Specializations')),
                        const SizedBox(height: 8),
                        _PickField(
                          hint: translateText('Select Specializations'),
                          values: _selectedSpecs,
                          hasError: _showGlobalErrors && _vSpecs() != null,
                          onTap: () => _openMultiSelect(
                            title: translateText('Select Specializations'),
                            source: _allSpecs,
                            target: _selectedSpecs,
                          ),
                        ),
                        if (_showGlobalErrors)
                          FormField<List<String>>(
                            autovalidateMode: AutovalidateMode.always,
                            validator: (_) => _vSpecs(),
                            builder: (state) => state.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Joining Date')),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickJoiningDate,
                          child: AbsorbPointer(
                              child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: _joiningDate == null
                                  ? ''
                                  : '${_joiningDate!.day.toString().padLeft(2, '0')}/${_joiningDate!.month.toString().padLeft(2, '0')}/${_joiningDate!.year}',
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _decor(
                              hint: translateText('dd/mm/yyyy'),
                              suffix: const Icon(
                                Icons.calendar_month_outlined,
                                color: Color(0xFF8D867F),
                              ),
                            ),
                            validator: (_) => null,
                          )),
                        ),
                        if (_showGlobalErrors)
                          FormField<DateTime>(
                            autovalidateMode: AutovalidateMode.always,
                            validator: (_) => _vJoiningDate(),
                            builder: (state) => state.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Experience')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _experienceCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) {
                            return Text(
                              '$currentLength/$maxLength',
                              style: const TextStyle(
                                color: Color(0xFF8D867F),
                                fontSize: 12,
                                height: 1.15,
                              ),
                            );
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: _decor(
                            hint: translateText('Enter experience in years'),
                          ),
                          validator: _vExperience,
                          onChanged: (_) {
                            _clearExperienceValidation();
                            _refreshValidationIfNeeded();
                          },
                        ),
                        const SizedBox(height: 16),
                        _reqLabel(translateText('Brief About Team Member')),
                        const SizedBox(height: 8),
                        TextFormField(
                          focusNode: _brieftFocus,
                          controller: _briefCtrl,
                          maxLines: 4,
                          maxLength: AppInputRules.mediumTextMaxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters:
                              AppInputRules.generalTextFormatters(),
                          decoration: _decor(
                            hint: translateText(
                              "Tell us about the team member's experience and expertise...",
                            ),
                          ).copyWith(
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          validator: _vBrief,
                          onChanged: (_) {
                            _clearBriefValidation();
                            _refreshValidationIfNeeded();
                          },
                        ),
                        const SizedBox(height: 34),
                        _promoCard(),
                        const SizedBox(height: 28),
                        _PrimaryButton(
                          text: '${translateText('Next Step')}  →',
                          height: 54,
                          flowStyle: true,
                          isLoading: _isSubmitting,
                          onPressed: _goToScheduleStep,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PickField extends StatelessWidget {
  const _PickField({
    required this.hint,
    required this.values,
    required this.onTap,
    this.hasError = false,
  });

  final String hint;
  final List<String> values;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final text = values.isEmpty ? hint : values.join(', ');
    final hasValue = values.isNotEmpty;
    final controller = TextEditingController(text: text);
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: controller,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFFAF9F8),
            hintStyle: TextStyle(
              color:
                  hasValue ? const Color(0xFF2D2926) : const Color(0xFF8D867F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            suffixIcon: const Icon(
              Icons.unfold_more_rounded,
              color: Color(0xFF8D867F),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.red : const Color(0xFFE2D3BF),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.red : const Color(0xFFE2D3BF),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.red : _teamMemberAccent,
                width: 1.5,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.red),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.red, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 50,
    this.flowStyle = false,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final bool flowStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled && !isLoading ? onPressed : null;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _teamMemberAccent,
          foregroundColor: Colors.white,
          elevation: flowStyle ? 4 : 0,
          shadowColor: const Color(0x33000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(flowStyle ? 8 : 14),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: flowStyle ? 22 : 20,
                height: flowStyle ? 22 : 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: flowStyle ? 2.5 : 2,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontWeight: flowStyle ? FontWeight.w600 : FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
