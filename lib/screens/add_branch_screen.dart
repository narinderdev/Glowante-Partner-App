import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'add_location_screen.dart';
import 'package:flutter/services.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/colors.dart';
import 'AddSalonServices.dart';
import 'set_weekly_schedule_screen.dart';
import '../widgets/salon_flow_step_header.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import '../utils/aws_s3_uploader.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import 'bottom_nav.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum _BranchField { name, phone, startTime, endTime, description }

class _FirstLetterUpperFormatter extends TextInputFormatter {
  const _FirstLetterUpperFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final regExp = RegExp(r'[A-Za-z]');
    final match = regExp.firstMatch(text);
    if (match == null) return newValue;

    final index = match.start;
    final upper = text[index].toUpperCase();
    if (text[index] == upper) return newValue;

    final updated = text.replaceRange(index, index + 1, upper);
    return newValue.copyWith(text: updated);
  }
}

class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({
    super.key,
    required this.salonId,
    this.initialBranch,
    this.isEdit = false,
  });

  final int salonId;
  final Map<String, dynamic>? initialBranch;
  final bool isEdit;

  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  static const int _timeMinuteStep = 10;

  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _openingBufferController = TextEditingController();
  final _lastVisibleBufferController = TextEditingController();
  final _overflowGraceController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _submitted = false;
  bool _isNavigatingNext = false;
  bool _savedPhoneApplied = false;
  List<Map<String, dynamic>> _sourceBranches = const [];
  List<String> _existingImageUrls = const <String>[];
  Map<String, List<Map<String, String>>> _draftWeeklySchedule = {};
  // The Start/End Time that was in effect when _draftWeeklySchedule was
  // last generated — lets the schedule screen tell whether the user has
  // since edited Start/End Time on this step, so it knows whether to keep
  // the cached per-day hours or regenerate them from the fresh values.
  String? _draftScheduleBaseStartTime;
  String? _draftScheduleBaseEndTime;
  int _draftOpeningBufferMinutes = 30;
  int _draftLastBookingBufferMinutes = 30;
  int _draftLastSlotOverflowGraceMinutes = 10;
  final Map<_BranchField, bool> _fieldValidationVisibility = {
    for (final field in _BranchField.values) field: false,
  };

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, dynamic nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }
    return null;
  }

  String _firstNonEmptyValue(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  String _cleanImageUrl(dynamic value) {
    if (value is Map) {
      return _firstNonEmptyValue([
        value['url'],
        value['imageUrl'],
        value['publicUrl'],
        value['cdnUrl'],
      ]);
    }
    return _firstNonEmptyValue([value]);
  }

  List<String> _extractImageUrls(dynamic source) {
    final urls = <String>[];
    void add(dynamic value) {
      final url = _cleanImageUrl(value);
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    if (source is List) {
      for (final entry in source) {
        add(entry);
      }
    } else {
      add(source);
    }

    return urls.take(10).toList();
  }

  String _formatDisplayTime(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;

    String formatParts(String hourText, String minuteText, [String? suffix]) {
      var hour = int.tryParse(hourText) ?? 0;
      final minute = int.tryParse(minuteText) ?? 0;
      if (suffix != null) {
        final normalizedSuffix = suffix.toUpperCase();
        if (normalizedSuffix == 'PM' && hour != 12) hour += 12;
        if (normalizedSuffix == 'AM' && hour == 12) hour = 0;
      }
      final displaySuffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = ((hour + 11) % 12) + 1;
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $displaySuffix';
    }

    final twelveHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (twelveHourMatch != null) {
      return formatParts(
        twelveHourMatch.group(1)!,
        twelveHourMatch.group(2)!,
        twelveHourMatch.group(3)!,
      );
    }

    final twentyFourHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
    ).firstMatch(text);
    if (twentyFourHourMatch != null) {
      return formatParts(
        twentyFourHourMatch.group(1)!,
        twentyFourHourMatch.group(2)!,
      );
    }

    final isoTimeMatch = RegExp(r'T(\d{1,2}):(\d{2})').firstMatch(text);
    if (isoTimeMatch != null) {
      return formatParts(isoTimeMatch.group(1)!, isoTimeMatch.group(2)!);
    }

    return fallback.isNotEmpty ? fallback : text;
  }

  double _readDoubleValue(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse((value ?? '').toString().trim());
      if (parsed != null) return parsed;
    }
    return 0;
  }

  int? _readPositiveIntValue(List<dynamic> values) {
    final parsed = _readIntValue(values);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  int? _readIntValue(List<dynamic> values) {
    for (final value in values) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse((value ?? '').toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, List<Map<String, String>>> _extractInitialSchedule(
    Map<String, dynamic>? branch,
  ) {
    final result = <String, List<Map<String, String>>>{};
    final rawSchedule = _extractScheduleSource(branch);
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    if (rawSchedule is Map || rawSchedule is List) {
      for (final day in days) {
        result[day] = <Map<String, String>>[];
      }
    }

    if (rawSchedule is Map) {
      for (final entry in rawSchedule.entries) {
        final day = entry.key.toString().toLowerCase();
        final slots = entry.value;
        if (slots is! List) continue;
        result[day] = slots
            .whereType<Map>()
            .map(
              (slot) => <String, String>{
                'startTime': _formatDisplayTime(
                  _firstNonEmptyValue([slot['startTime'], slot['start']]),
                ),
                'endTime': _formatDisplayTime(
                  _firstNonEmptyValue([slot['endTime'], slot['end']]),
                ),
              },
            )
            .where(
              (slot) =>
                  slot['startTime']!.isNotEmpty && slot['endTime']!.isNotEmpty,
            )
            .toList();
      }
    } else if (rawSchedule is List) {
      for (final rawEntry in rawSchedule.whereType<Map>()) {
        final day = (rawEntry['day'] ?? '').toString().toLowerCase();
        if (day.isEmpty) continue;
        final slots = rawEntry['slots'];
        if (slots is! List) continue;
        result[day] = slots
            .whereType<Map>()
            .map(
              (slot) => <String, String>{
                'startTime': _formatDisplayTime(
                  _firstNonEmptyValue([slot['startTime'], slot['start']]),
                ),
                'endTime': _formatDisplayTime(
                  _firstNonEmptyValue([slot['endTime'], slot['end']]),
                ),
              },
            )
            .where(
              (slot) =>
                  slot['startTime']!.isNotEmpty && slot['endTime']!.isNotEmpty,
            )
            .toList();
      }
    }

    return result;
  }

  dynamic _extractScheduleSource(dynamic value) {
    if (value is! Map) return value;

    final map = Map<String, dynamic>.from(value);

    for (final key in const ['schedule', 'schedules', 'workingHours']) {
      if (map[key] != null) return map[key];
    }

    for (final key in const ['data', 'branch', 'salon']) {
      final nested = map[key];
      if (nested is Map) {
        final schedule = _extractScheduleSource(nested);
        if (schedule != null) return schedule;
      }
    }

    return null;
  }

  String _normalizePhone(dynamic value) {
    final digits =
        value == null ? '' : value.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 10) return digits;
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits.substring(digits.length - 10);
  }

  String? _validatePhoneNumber(String? value) {
    final phone = _normalizePhone(value);
    if (phone.isEmpty) {
      return translateText('Phone number is required');
    }
    if (phone.length != 10) {
      return translateText('Phone number must be 10 digits.');
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return translateText('Enter a valid mobile number.');
    }
    return null;
  }

  String _addressWithoutManualParts(String address, List<String> manualParts) {
    final manualPartsLower = manualParts
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (manualPartsLower.isEmpty) return address.trim();
    return address
        .split(',')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty && !manualPartsLower.contains(part.toLowerCase()),
        )
        .join(', ');
  }

  List<String> _splitAddressParts(String value) {
    final seen = <String>{};
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => seen.add(part.toLowerCase()))
        .toList();
  }

  List<String> _splitAddressPartsKeepingDuplicates(String value) {
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  bool _startsWithParts(List<String> source, List<String> prefix) {
    if (prefix.isEmpty || source.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (source[index].toLowerCase() != prefix[index].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  String _deriveStreetSectorArea(
    String completeAddress, {
    String? line2,
    String scoFlatHouse = '',
  }) {
    final line2Parts = _splitAddressParts(line2 ?? '');
    if (line2Parts.length > 1) {
      return line2Parts.skip(1).join(', ');
    }

    final remaining = _splitAddressParts(
      _addressWithoutManualParts(
        completeAddress,
        [scoFlatHouse],
      ),
    );
    if (remaining.length >= 3) {
      return remaining.skip(1).take(2).join(', ');
    }
    if (remaining.length >= 2) {
      return remaining.skip(1).join(', ');
    }
    return '';
  }

  String _composeAddressLine1(BranchAddress address) {
    final leadingParts = [
      address.city.trim(),
      address.pincode.trim(),
    ].where((part) => part.isNotEmpty).toList();
    final baseParts = _splitAddressPartsKeepingDuplicates(
      address.buildingName,
    );
    if (leadingParts.length > 1 && _startsWithParts(baseParts, leadingParts)) {
      baseParts.removeRange(0, leadingParts.length);
    }
    return [...leadingParts, ...baseParts].join(', ');
  }

  BranchAddress? _extractInitialAddress(Map<String, dynamic> branch) {
    final address = _asStringKeyedMap(branch['address']) ?? branch;

    // line1 = House/Flat No, line2 = Street/Area (see BranchAddress.toJson)
    // — the searched/current-location text lives in formattedAddress
    // rather than being folded into line1.
    final scoFlatHouse = _firstNonEmptyValue([address['line1']]);
    final streetSectorArea = _firstNonEmptyValue([address['line2']]);
    final baseAddress = _firstNonEmptyValue([
      address['formattedAddress'],
      address['addressLine1'],
      address['buildingName'],
    ]);

    final completeAddress = <String>[
      if (scoFlatHouse.isNotEmpty) scoFlatHouse,
      if (streetSectorArea.isNotEmpty) streetSectorArea,
    ];
    final seenAddressParts =
        completeAddress.map((part) => part.toLowerCase()).toSet();
    for (final part in _splitAddressParts(baseAddress)) {
      if (seenAddressParts.add(part.toLowerCase())) {
        completeAddress.add(part);
      }
    }
    for (final key in const [
      'village',
      'district',
      'city',
      'state',
      'country',
      'postalCode',
    ]) {
      for (final part in _splitAddressParts((address[key] ?? '').toString())) {
        if (seenAddressParts.add(part.toLowerCase())) {
          completeAddress.add(part);
        }
      }
    }

    if (completeAddress.isEmpty &&
        scoFlatHouse.isEmpty &&
        streetSectorArea.isEmpty) {
      return null;
    }

    final completeAddressText = completeAddress.join(', ');

    return BranchAddress(
      buildingName: baseAddress.isNotEmpty ? baseAddress : completeAddressText,
      city: scoFlatHouse,
      pincode: streetSectorArea,
      state: _firstNonEmptyValue([address['state']]),
      latitude: _readDoubleValue([
        address['latitude'],
        address['lat'],
        branch['latitude'],
        branch['lat'],
      ]),
      longitude: _readDoubleValue([
        address['longitude'],
        address['lng'],
        address['lon'],
        branch['longitude'],
        branch['lng'],
        branch['lon'],
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _startTimeController.clear();
    _endTimeController.clear();
    final initialBranch = widget.initialBranch;
    if (initialBranch != null) {
      _branchNameController.text = _firstNonEmptyValue([
        initialBranch['name'],
        initialBranch['branchName'],
        initialBranch['displayName'],
        initialBranch['title'],
      ]);
      _phoneController.text = _normalizePhone(
        _firstNonEmptyValue([
          initialBranch['phone'],
          initialBranch['phoneNumber'],
          initialBranch['contactNumber'],
        ]),
      );
      _descriptionController.text = _firstNonEmptyValue([
        initialBranch['description'],
        initialBranch['branchDescription'],
        initialBranch['about'],
        initialBranch['details'],
      ]);
      final startTime = _firstNonEmptyValue([initialBranch['startTime']]);
      final endTime = _firstNonEmptyValue([initialBranch['endTime']]);
      if (startTime.isNotEmpty) {
        _startTimeController.text = _normalizeDisplayTime(
          startTime,
          fallback: '',
        );
      }
      if (endTime.isNotEmpty) {
        _endTimeController.text = _normalizeDisplayTime(
          endTime,
          fallback: '',
        );
      }
      _draftOpeningBufferMinutes =
          _readPositiveIntValue([initialBranch['openingBufferMinutes']]) ?? 30;

      _draftLastBookingBufferMinutes =
          _readPositiveIntValue([initialBranch['lastBookingBufferMinutes']]) ??
              30;

      _draftLastSlotOverflowGraceMinutes = _readPositiveIntValue([
            initialBranch['lastSlotOverflowGraceMinutes'],
          ]) ??
          10;
      _openingBufferController.text = _draftOpeningBufferMinutes.toString();
      _lastVisibleBufferController.text =
          _draftLastBookingBufferMinutes.toString();
      _overflowGraceController.text =
          _draftLastSlotOverflowGraceMinutes.toString();
      _existingImageUrls = [
        ..._extractImageUrls(initialBranch['imageUrls']),
        ..._extractImageUrls(initialBranch['imageUrl']),
      ]
          .fold<List<String>>(
            <String>[],
            (urls, url) => urls.contains(url) ? urls : (urls..add(url)),
          )
          .take(10)
          .toList();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddBranchCubit>().loadSavedPhone();
      final initialBranch = widget.initialBranch;
      final initialAddress =
          initialBranch == null ? null : _extractInitialAddress(initialBranch);
      if (initialAddress != null) {
        context.read<AddBranchCubit>().updateAddress(initialAddress);
      }
      if (!widget.isEdit) {
        _loadSourceBranches();
      }
    });
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _phoneController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _openingBufferController.dispose();
    _lastVisibleBufferController.dispose();
    _overflowGraceController.dispose();
    super.dispose();
  }

  int _parseBufferMinutes(String value, {required int fallback}) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  void _syncBufferDraftsFromInputs() {
    _draftOpeningBufferMinutes = _parseBufferMinutes(
      _openingBufferController.text,
      fallback: _draftOpeningBufferMinutes,
    );
    _draftLastBookingBufferMinutes = _parseBufferMinutes(
      _lastVisibleBufferController.text,
      fallback: _draftLastBookingBufferMinutes,
    );
    _draftLastSlotOverflowGraceMinutes = _parseBufferMinutes(
      _overflowGraceController.text,
      fallback: _draftLastSlotOverflowGraceMinutes,
    );
  }

  Future<void> _pickImages() async {
    final source = await _chooseImageSource();
    if (source == null) return;

    if (source == ImageSource.camera) {
      await _pickSingleImage(source);
      return;
    }

    await _pickGalleryImages();
  }

  Future<ImageSource?> _chooseImageSource() async {
    if (!mounted) return null;

    return showDialog<ImageSource>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  translateText('Add photo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1B18),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translateText('Choose from gallery or take a new photo.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F665E),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(translateText('Take from camera')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(translateText('Choose from gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Future<void> _pickSingleImage(ImageSource source) async {
    final existing = context.read<AddBranchCubit>().state.images;
    final remainingSlots = 10 - existing.length;
    if (remainingSlots <= 0) {
      _showImageLimitToast();
      return;
    }

    final file = await _picker.pickImage(source: source);
    if (!mounted) return;
    if (file == null) return;
    final images = [...existing, File(file.path)].take(10).toList();
    context.read<AddBranchCubit>().setImages(images);
  }

  Future<void> _pickGalleryImages() async {
    final existing = context.read<AddBranchCubit>().state.images;
    final remainingSlots = 10 - existing.length;
    if (remainingSlots <= 0) {
      _showImageLimitToast();
      return;
    }

    final List<XFile> files;
    if (remainingSlots == 1) {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      files = file == null ? <XFile>[] : <XFile>[file];
    } else {
      files = await _picker.pickMultiImage(limit: remainingSlots);
    }

    if (!mounted) return;
    if (files.isEmpty) return;
    if (files.length > remainingSlots) {
      _showImageLimitToast();
    }
    final images = [
      ...existing,
      ...files.map((file) => File(file.path)),
    ].take(10).toList();
    context.read<AddBranchCubit>().setImages(images);
  }

  void _showImageLimitToast() {
    Fluttertoast.showToast(
        msg: translateText(
      'You can add up to 10 photos. Remove a photo before choosing another.',
    ));
  }

  Future<List<String>> _uploadSelectedImageUrls(List<File> images) async {
    final uploadedUrls = <String>[];
    final uploader = AwsS3Uploader();

    for (final image in images.take(10)) {
      final result = await uploader
          .uploadImageResult(XFile(image.path))
          .timeout(const Duration(seconds: 45), onTimeout: () => null);
      final url = result?.cdnUrl ?? result?.publicUrl;
      if (url != null && url.trim().isNotEmpty) {
        uploadedUrls.add(url.trim());
      }
    }

    return uploadedUrls;
  }

  Future<void> _loadSourceBranches() async {
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] != true || response['data'] is! List) {
        return;
      }
      final salons = (response['data'] as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      final salon = salons.firstWhere(
        (entry) => entry['id'] == widget.salonId,
        orElse: () => <String, dynamic>{},
      );
      final branches = (salon['branches'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      if (!mounted) return;
      setState(() {
        _sourceBranches = branches;
      });
    } catch (error, stack) {
      debugPrint('Failed to load source branches: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  void _resetFieldError(_BranchField field) {
    if (!mounted) return;
    if (!(_fieldValidationVisibility[field] ?? false)) return;
    setState(() {
      _fieldValidationVisibility[field] = false;
    });
    _formKey.currentState?.validate();
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final twelveHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (twelveHourMatch != null) {
      var hour = int.tryParse(twelveHourMatch.group(1)!) ?? 0;
      final minute = int.tryParse(twelveHourMatch.group(2)!) ?? 0;
      final suffix = twelveHourMatch.group(3)!.toUpperCase();
      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final twentyFourHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
    ).firstMatch(text);
    if (twentyFourHourMatch != null) {
      final hour = int.tryParse(twentyFourHourMatch.group(1)!) ?? 0;
      final minute = int.tryParse(twentyFourHourMatch.group(2)!) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  int _snapMinuteToStep(int minute) {
    final snapped =
        ((minute.clamp(0, 59) + (_timeMinuteStep ~/ 2)) ~/ _timeMinuteStep) *
            _timeMinuteStep;
    return snapped > 59 ? 50 : snapped;
  }

  TimeOfDay _snapTimeToStep(TimeOfDay time) {
    return TimeOfDay(
      hour: time.hour.clamp(0, 23),
      minute: _snapMinuteToStep(time.minute),
    );
  }

  String _formatTimeOfDayDisplay(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }

  String _normalizeDisplayTime(dynamic value, {String fallback = ''}) {
    final display = _formatDisplayTime(value, fallback: fallback);
    final parsed = _parseTimeOfDay(display);
    if (parsed == null) return display;
    return _formatTimeOfDayDisplay(_snapTimeToStep(parsed));
  }

  int _timeToMinutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  List<String> _timeOptions() {
    final options = <String>[];
    for (var minutes = 0; minutes < 24 * 60; minutes += _timeMinuteStep) {
      options.add(
        _formatTimeOfDayDisplay(
          TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        ),
      );
    }
    return options;
  }

  List<String> _timeOptionsForField(_BranchField field) {
    final options = _timeOptions();
    final startTime = _parseTimeOfDay(_startTimeController.text);
    final endTime = _parseTimeOfDay(_endTimeController.text);

    if (field == _BranchField.endTime) {
      if (startTime == null) return const <String>[];
      final startMinutes = _timeToMinutesOfDay(startTime);
      return options.where((option) {
        final minutes = _timeToMinutesOfDay(_parseTimeOfDay(option)!);
        return minutes > startMinutes;
      }).toList();
    }

    if (field == _BranchField.startTime && endTime != null) {
      final endMinutes = _timeToMinutesOfDay(endTime);
      return options.where((option) {
        final minutes = _timeToMinutesOfDay(_parseTimeOfDay(option)!);
        return minutes < endMinutes;
      }).toList();
    }

    return options;
  }

  void _updateTimeSelection(
    _BranchField field,
    String value, {
    required TextEditingController controller,
    TextEditingController? pairedController,
  }) {
    final selectedTime = _parseTimeOfDay(value);
    if (selectedTime == null) return;

    controller.text = _formatTimeOfDayDisplay(_snapTimeToStep(selectedTime));

    if (pairedController == null) {
      _resetFieldError(field);
      return;
    }

    if (field == _BranchField.startTime) {
      final endTime = _parseTimeOfDay(pairedController.text);
      if (endTime != null &&
          _timeToMinutesOfDay(endTime) <= _timeToMinutesOfDay(selectedTime)) {
        pairedController.clear();
      }
    } else {
      final startTime = _parseTimeOfDay(pairedController.text);
      if (startTime != null &&
          _timeToMinutesOfDay(selectedTime) <= _timeToMinutesOfDay(startTime)) {
        pairedController.clear();
      }
    }

    _resetFieldError(field);
  }

  String? _timeFieldErrorText(_BranchField field) {
    if (!_submitted) return null;

    final startEmpty = _startTimeController.text.trim().isEmpty;
    final endEmpty = _endTimeController.text.trim().isEmpty;

    if (field == _BranchField.startTime) {
      return startEmpty ? translateText('Select start time') : null;
    }

    if (!endEmpty) return null;
    return startEmpty
        ? translateText('Select start time first')
        : translateText('Select end time');
  }

  // ✅ Minimal back-compat helper: require complete address (stored in buildingName) + coordinates
  bool _isAddressComplete(BranchAddress? address) {
    if (address == null) return false;
    final hasCompleteAddress =
        address.buildingName.trim().isNotEmpty; // holds complete address
    final hasValidCoordinates =
        address.latitude != 0.0 || address.longitude != 0.0;
    if (widget.isEdit) {
      return hasCompleteAddress;
    }
    return hasCompleteAddress && hasValidCoordinates;
  }

  Future<void> _chooseLocation(AddBranchState state) async {
    final existing = state.address;
    final branchCubit = context.read<AddBranchCubit>();
    final initialCompleteAddress =
        existing == null ? null : _composeAddressLine1(existing);
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          initialCompleteAddress: initialCompleteAddress,
          initialScoFlatHouse: existing?.city,
          initialStreetSectorArea: existing?.pincode,
        ), // no legacy params needed
      ),
    );

    if (!mounted || result == null) return;

    // 🟢 Read new keys from AddLocationScreen
    final completeAddress =
        (result['completeAddress'] as String?)?.trim() ?? '';
    final baseCompleteAddress =
        (result['baseCompleteAddress'] as String?)?.trim() ?? '';
    final scoFlatHouse = (result['scoFlatHouse'] as String?)?.trim() ?? '';
    final streetSectorArea =
        (result['streetSectorArea'] as String?)?.trim() ?? '';
    final latitude = (result['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (result['longitude'] as num?)?.toDouble() ?? 0;

    // 🟢 Store completeAddress into buildingName (back-compat with existing model)
    branchCubit.updateAddress(
      BranchAddress(
        buildingName: baseCompleteAddress.isNotEmpty
            ? baseCompleteAddress
            : _addressWithoutManualParts(completeAddress, [
                scoFlatHouse,
                streetSectorArea,
              ]),
        city: scoFlatHouse, // optional mapping to keep the value
        pincode: streetSectorArea, // optional mapping to keep the value
        state: '', // not used in new flow
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<void> _submit(AddBranchState state) async {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    if (form == null) return;

    setState(() {
      for (final key in _fieldValidationVisibility.keys) {
        _fieldValidationVisibility[key] = true;
      }
    });

    final isValid = form.validate();
    if (!isValid) return;
    _syncBufferDraftsFromInputs();

    final phoneError = _validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      Fluttertoast.showToast(msg: phoneError);
      return;
    }

    if (widget.isEdit &&
        (_startTimeController.text.isEmpty ||
            _endTimeController.text.isEmpty)) {
      Fluttertoast.showToast(
          msg: translateText('Please select start and end time.'));
      return;
    }
    debugPrint('BRANCH ADDRESS = ${state.address?.toJson()}');
    debugPrint('LAT = ${state.address?.latitude}');
    debugPrint('LNG = ${state.address?.longitude}');
    // 🟢 Require address completeness based on new flow
    if (!_isAddressComplete(state.address)) {
      Fluttertoast.showToast(
          msg: translateText('Please choose a branch location.'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isNavigatingNext = true);
    // Let the loader actually paint before building the next (heavier)
    // screen — otherwise the button's setState and the route push both
    // land in the same synchronous stretch of work and the spinner never
    // gets a frame to render before the transition starts.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final branchCubit = context.read<AddBranchCubit>();
    final images = state.images;
    final existingImageUrls = List<String>.from(_existingImageUrls);
    final existingImageUrl =
        existingImageUrls.isEmpty ? '' : existingImageUrls.first;

    if (!mounted) return;

    if (widget.isEdit && widget.initialBranch != null) {
      final branchId = (widget.initialBranch!['id'] as num?)?.toInt();
      if (branchId == null) {
        setState(() => _isNavigatingNext = false);
        Fluttertoast.showToast(msg: translateText('Missing branch id'));
        return;
      }
      Future<void> saveBranchEdit(ScheduleStepResult scheduleResult) async {
        var imageUrl = existingImageUrl;
        var imageUrls = List<String>.from(existingImageUrls);
        if (images.isNotEmpty) {
          final uploadedImageUrls = await _uploadSelectedImageUrls(images);
          for (final uploadedUrl in uploadedImageUrls) {
            if (!imageUrls.contains(uploadedUrl)) {
              imageUrls.add(uploadedUrl);
            }
          }
          imageUrls = imageUrls.take(10).toList();
          if (imageUrls.isNotEmpty) imageUrl = imageUrls.first;
        }
        await branchCubit.repository.updateBranch(
          branchId: branchId,
          name: _branchNameController.text.trim(),
          phone: _normalizePhone(_phoneController.text),
          startTime: scheduleResult.startTime,
          endTime: scheduleResult.endTime,
          description: _descriptionController.text.trim(),
          schedule: scheduleResult.schedule,
          address: state.address!.toJson(),
          latitude: state.address!.latitude,
          longitude: state.address!.longitude,
          imageUrl: imageUrl,
          imageUrls: imageUrls,
        );
      }

      final pushBranchSchedule = Navigator.push<Object?>(
        context,
        MaterialPageRoute(
          builder: (_) => SetWeeklyScheduleScreen(
            title: 'Edit Branch',
            detailsStepLabel: 'Branch Details',
            initialStartTime: _startTimeController.text.trim(),
            initialEndTime: _endTimeController.text.trim(),
            // Compare against the Start/End Time that was actually in
            // effect the last time the schedule was (re)generated, not
            // just the originally-persisted value — otherwise a second
            // edit to Start/End Time on a later visit goes undetected
            // and the stale cached per-day hours silently win.
            previousBaseStartTime: _draftScheduleBaseStartTime ??
                _formatDisplayTime(
                  _firstNonEmptyValue([widget.initialBranch?['startTime']]),
                ),
            previousBaseEndTime: _draftScheduleBaseEndTime ??
                _formatDisplayTime(
                  _firstNonEmptyValue([widget.initialBranch?['endTime']]),
                ),
            initialSchedule: _draftWeeklySchedule.isNotEmpty
                ? _draftWeeklySchedule
                : _extractInitialSchedule(widget.initialBranch),
            initialOpeningBufferMinutes: _draftOpeningBufferMinutes,
            initialLastBookingBufferMinutes: _draftLastBookingBufferMinutes,
            initialLastSlotOverflowGraceMinutes:
                _draftLastSlotOverflowGraceMinutes,
            totalSteps: 2,
            submitLabel: 'Save',
            onSubmit: saveBranchEdit,
          ),
        ),
      );
      // Stop the button's loader as soon as the next screen has been
      // scheduled to appear, rather than waiting for it to be popped later.
      if (mounted) setState(() => _isNavigatingNext = false);
      final saved = await pushBranchSchedule;
      if (!mounted) return;

      if (saved is ScheduleStepResult) {
        _draftWeeklySchedule = saved.schedule;
        _draftScheduleBaseStartTime = _startTimeController.text.trim();
        _draftScheduleBaseEndTime = _endTimeController.text.trim();
        _draftOpeningBufferMinutes = saved.openingBufferMinutes;
        _draftLastBookingBufferMinutes = saved.lastBookingBufferMinutes;
        _draftLastSlotOverflowGraceMinutes = saved.lastSlotOverflowGraceMinutes;
        return;
      }

      if (saved != true) return;

      if (!mounted) return;
      Fluttertoast.showToast(msg: translateText('Branch updated successfully'));
      Navigator.pop(context, true);
      return;
    }

    final branchFormData = AddBranchFormData(
      name: _branchNameController.text.trim(),
      phone: _normalizePhone(_phoneController.text),
      startTime: _startTimeController.text.trim(),
      endTime: _endTimeController.text.trim(),
      description: _descriptionController.text.trim(),
      schedule: const <String, List<Map<String, String>>>{},
      imageUrl: null,
    );

    if (!mounted) return;

    final pushAddBranchSchedule = Navigator.push<ScheduleStepResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => SetWeeklyScheduleScreen(
          title: 'Add Branch',
          detailsStepLabel: 'Branch Details',
          initialStartTime: _startTimeController.text.trim(),
          initialEndTime: _endTimeController.text.trim(),
          previousBaseStartTime: _draftScheduleBaseStartTime,
          previousBaseEndTime: _draftScheduleBaseEndTime,
          initialSchedule: _draftWeeklySchedule,
          initialOpeningBufferMinutes: _draftOpeningBufferMinutes,
          initialLastBookingBufferMinutes: _draftLastBookingBufferMinutes,
          initialLastSlotOverflowGraceMinutes:
              _draftLastSlotOverflowGraceMinutes,
          totalSteps: 3,
          onContinue: (scheduleResult) async {
            _draftWeeklySchedule = scheduleResult.schedule;
            _draftScheduleBaseStartTime = _startTimeController.text.trim();
            _draftScheduleBaseEndTime = _endTimeController.text.trim();
            _draftOpeningBufferMinutes = scheduleResult.openingBufferMinutes;
            _draftLastBookingBufferMinutes =
                scheduleResult.lastBookingBufferMinutes;
            _draftLastSlotOverflowGraceMinutes =
                scheduleResult.lastSlotOverflowGraceMinutes;
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => AddSalonCubit(SalonRepository()),
                    ),
                    BlocProvider.value(value: branchCubit),
                  ],
                  child: AddSalonServices(
                    title: 'Add Branch',
                    branchFormData: AddBranchFormData(
                      name: branchFormData.name,
                      phone: branchFormData.phone,
                      startTime: scheduleResult.startTime,
                      endTime: scheduleResult.endTime,
                      description: branchFormData.description,
                      schedule: scheduleResult.schedule,
                      imageUrl: branchFormData.imageUrl,
                      imageUrls: branchFormData.imageUrls,
                    ),
                    branchAddress: state.address!,
                    branchImages: images,
                    salonId: widget.salonId,
                    branchImageUrl: branchFormData.imageUrl,
                    sourceBranches: _sourceBranches,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (mounted) setState(() => _isNavigatingNext = false);
    final draftResult = await pushAddBranchSchedule;

    if (draftResult != null) {
      _draftWeeklySchedule = draftResult.schedule;
      _draftScheduleBaseStartTime = _startTimeController.text.trim();
      _draftScheduleBaseEndTime = _endTimeController.text.trim();
      _draftOpeningBufferMinutes = draftResult.openingBufferMinutes;
      _draftLastBookingBufferMinutes = draftResult.lastBookingBufferMinutes;
      _draftLastSlotOverflowGraceMinutes =
          draftResult.lastSlotOverflowGraceMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    return BlocConsumer<AddBranchCubit, AddBranchState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        if (!widget.isEdit &&
            !_savedPhoneApplied &&
            state.savedPhone != null &&
            _phoneController.text.isEmpty) {
          _savedPhoneApplied = true;
          _phoneController.text = state.savedPhone!;
          _resetFieldError(_BranchField.phone);
        }

        if (state.status == BranchFormStatus.failure &&
            state.errorMessage != null) {
          Fluttertoast.showToast(
            msg: extractErrorMessage(state.errorMessage!),
          );
        }

        if (state.status == BranchFormStatus.success) {
          Fluttertoast.showToast(
              msg: translateText(
            widget.isEdit
                ? 'Branch updated successfully'
                : 'Branch added successfully',
          ));
          if (widget.isEdit) {
            Navigator.pop(context, true);
            return;
          }

          final savedSelection =
              await StylistBranchSelectionStore.saveFromBranchCreateResponse(
            salonId: widget.salonId,
            response: state.createdBranchResponse,
            fallbackBranchName: _branchNameController.text.trim(),
          );
          if (!context.mounted) return;
          if (savedSelection) {
            await _refreshSalonListForCreatedSelection(context);
            if (!context.mounted) return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const BottomNav(tabIndex: 3)),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        final images = state.images;
        final address = state.address;

        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F8),
          appBar: buildProfileSubpageAppBar(
            title: translateText(widget.isEdit ? 'Edit Branch' : 'Add Branch'),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SalonFlowStepHeader(
                          currentStep: 1,
                          detailsLabel: translateText('Branch Details'),
                          totalSteps: widget.isEdit ? 2 : 3,
                        ),
                        const SizedBox(height: 22),
                        _buildHeroCard(
                          quote:
                              '"Every branch should deliver the same signature experience."',
                        ),
                        const SizedBox(height: 34),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translateText('Branch Information'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF161616),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildTextField(
                                field: _BranchField.name,
                                controller: _branchNameController,
                                label: 'Branch Name *',
                                hint: 'Enter branch name',
                                enabled: true,
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLength: 50,
                                inputFormatters: const [
                                  _FirstLetterUpperFormatter(),
                                ],
                              ),
                              _buildTextField(
                                field: _BranchField.phone,
                                controller: _phoneController,
                                label: 'Phone Number *',
                                hint: 'Enter phone no',
                                maxLength: 10,
                                enabled: true,
                                keyboardType: TextInputType.phone,
                                prefixText: '+91',
                                validator: _validatePhoneNumber,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTimeDropdownField(
                                        field: _BranchField.startTime,
                                        controller: _startTimeController,
                                        label: 'Start Time *',
                                        bottomSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTimeDropdownField(
                                        field: _BranchField.endTime,
                                        controller: _endTimeController,
                                        label: 'End Time *',
                                        bottomSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildAddressField(address, state),
                              _buildTextField(
                                field: _BranchField.description,
                                controller: _descriptionController,
                                label: 'Description *',
                                hint: "Tell us more...",
                                maxLines: 1,
                                maxLength: 250,
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: const [
                                  _FirstLetterUpperFormatter(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: translateText('Branch Images'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF161616),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' (${translateText('Optional')})',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF7F7974),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildImageGrid(images, _existingImageUrls),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: state.isSubmitting || _isNavigatingNext
                                ? null
                                : () => _submit(state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B6500),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: state.isSubmitting || _isNavigatingNext
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        translateText(
                                          widget.isEdit
                                              ? 'Save Changes'
                                              : 'Next Step',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.status == BranchFormStatus.loading)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard({required String quote}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 178,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/salonImage.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(color: Colors.black.withValues(alpha: 0.52)),
            Image.asset(
              'assets/images/salonImage.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
            Container(color: Colors.black.withValues(alpha: 0.24)),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
                child: Text(
                  translateText(quote),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFEAE0D7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFieldLabel(String label) {
    final normalizedLabel = label.replaceAll('*', '').trim();
    final translatedLabel = translateText(normalizedLabel);
    final localizedLabel =
        translatedLabel != normalizedLabel ? translatedLabel : normalizedLabel;
    final hasAsterisk = label.contains('*');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: localizedLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF463E37),
          ),
          children: hasAsterisk
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFF7B1E11)),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // Widget _buildAddressField(BranchAddress? address, AddBranchState state) {
  //   final hasAddress =
  //       address != null && address.buildingName.trim().isNotEmpty;
  //   final displayAddress = hasAddress
  //       ? _composeAddressLine1(address)
  //       : translateText('Add Location');
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 18),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         _buildFieldLabel('Branch Address *'),
  //         InkWell(
  //           onTap: () => _chooseLocation(state),
  //           borderRadius: BorderRadius.circular(8),
  //           child: Container(
  //             width: double.infinity,
  //             constraints: const BoxConstraints(minHeight: 58),
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(
  //                 color: const Color(0xFFD3A94C),
  //                 width: 1,
  //               ),
  //             ),
  //             child: Row(
  //               children: [
  //                 const Icon(
  //                   Icons.add_location_alt_rounded,
  //                   color: Color(0xFF8B6500),
  //                   size: 22,
  //                 ),
  //                 const SizedBox(width: 12),
  //                 Expanded(
  //                   child: hasAddress
  //                       ? Column(
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Text(
  //                               displayAddress,
  //                               maxLines: 2,
  //                               overflow: TextOverflow.ellipsis,
  //                               style: const TextStyle(
  //                                 color: Color(0xFF3B332B),
  //                                 fontWeight: FontWeight.w700,
  //                                 fontSize: 13,
  //                               ),
  //                             ),
  //                           ],
  //                         )
  //                       : Text(
  //                           translateText('Add Location'),
  //                           style: const TextStyle(
  //                             color: Color(0xFF7A4A09),
  //                             fontWeight: FontWeight.w600,
  //                             fontSize: 14,
  //                           ),
  //                         ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildAddressField(BranchAddress? address, AddBranchState state) {
    final hasAddressText =
        address != null && address.buildingName.trim().isNotEmpty;

    final hasCompleteAddress = _isAddressComplete(address);

    final displayAddress = hasAddressText
        ? _composeAddressLine1(address)
        : translateText('Add Location');

    final showError = _submitted && !hasCompleteAddress;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Branch Address *'),
          InkWell(
            onTap: () => _chooseLocation(state),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: showError ? AppColors.red : const Color(0xFFD3A94C),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_location_alt_rounded,
                    color: showError ? AppColors.red : const Color(0xFF8B6500),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: hasAddressText
                        ? Text(
                            displayAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3B332B),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          )
                        : Text(
                            translateText('Add Location'),
                            style: TextStyle(
                              color: showError
                                  ? AppColors.red
                                  : const Color(0xFF7A4A09),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            Text(
              translateText('Branch Address is required'),
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<File> images, List<String> existingImageUrls) {
    final slots = <Widget>[];
    final selectedImages = images.take(10).toList();
    final visibleExistingUrls = images.isEmpty
        ? existingImageUrls.take(10).toList()
        : existingImageUrls.take(10 - selectedImages.length).toList();
    final visibleItemCount = visibleExistingUrls.length + selectedImages.length;
    final canAddMore = visibleItemCount < 10;

    slots.add(_buildImageSlot(isAddSlot: true, isEnabled: canAddMore));

    for (final url in visibleExistingUrls) {
      slots.add(_buildImageSlot(networkUrl: url));
    }
    for (final image in selectedImages) {
      slots.add(_buildImageSlot(file: image));
    }

    while (slots.length < 4) {
      slots.add(_buildImageSlot());
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: slots,
    );
  }

  Widget _buildImageSlot({
    File? file,
    String? networkUrl,
    bool isAddSlot = false,
    bool isEnabled = true,
  }) {
    final hasImage = file != null || (networkUrl ?? '').isNotEmpty;
    return GestureDetector(
      onTap: isAddSlot && isEnabled ? _pickImages : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isAddSlot ? const Color(0xFFD3A94C) : const Color(0xFFE8E1DC),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (file != null)
                      Image.file(file, fit: BoxFit.cover)
                    else
                      Image.network(networkUrl!, fit: BoxFit.cover),
                    if (file != null || networkUrl != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            if (file != null) {
                              context.read<AddBranchCubit>().removeImage(file);
                              return;
                            }
                            final url = networkUrl;
                            if (url == null) return;
                            setState(() {
                              _existingImageUrls = _existingImageUrls
                                  .where((existingUrl) => existingUrl != url)
                                  .toList();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: isAddSlot
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: isEnabled
                                  ? const Color(0xFF7A4A09)
                                  : const Color(0xFFCFC8C2),
                              size: 30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              translateText(
                                isEnabled ? 'Add Photo' : 'Max 10 Photos',
                              ),
                              style: TextStyle(
                                color: isEnabled
                                    ? const Color(0xFF6A4A20)
                                    : const Color(0xFFAAA39C),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: Color(0xFFD9D6D3),
                          size: 42,
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required _BranchField field,
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    String? prefixText,
    IconData? prefixIconData,
    IconData? suffixIconData,
    double bottomSpacing = 18,
  }) {
    final normalizedLabel = label.replaceAll('*', '').trim();
    final normalizedHint = hint.trim();
    final translatedLabel = translateText(normalizedLabel);
    final translatedHint = translateText(normalizedHint);
    final localizedLabel =
        translatedLabel != normalizedLabel ? translatedLabel : normalizedLabel;
    final localizedHint =
        translatedHint != normalizedHint ? translatedHint : normalizedHint;
    final isRequired = label.contains('*');

    final sanitizedField = label.replaceAll('*', '').replaceAll(':', '').trim();
    final fieldForMessage =
        sanitizedField.isEmpty ? localizedLabel : translateText(sanitizedField);
    final hasInsideCounter = maxLength != null;
    final effectiveInputFormatters = <TextInputFormatter>[
      if (inputFormatters != null) ...inputFormatters,
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, _, __) {
              return FormField<String>(
                initialValue: controller.text,
                autovalidateMode: _submitted
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                validator: (value) {
                  if (!(_fieldValidationVisibility[field] ?? false)) {
                    return null;
                  }

                  final text = (value ?? '').trim();
                  if (isRequired && text.isEmpty) {
                    return translateText(
                      '{field} is required',
                      params: {'field': fieldForMessage},
                    );
                  }
                  return validator?.call(value);
                },
                builder: (fieldState) {
                  final errorText = fieldState.errorText;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        maxLines: maxLines,
                        maxLength: maxLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        enabled: enabled,
                        readOnly: false,
                        showCursor: true,
                        cursorColor: const Color(0xFF7A4A09),
                        cursorWidth: 1.6,
                        style: const TextStyle(
                          color: Color(0xFF201A16),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        keyboardType: keyboardType,
                        inputFormatters: effectiveInputFormatters,
                        textCapitalization: textCapitalization,
                        onChanged: (changedValue) {
                          _resetFieldError(field);
                          fieldState.didChange(changedValue);
                          onChanged?.call(changedValue);
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: localizedHint,
                          hintStyle: const TextStyle(
                            color: Color(0xFF948C84),
                            fontSize: 13,
                          ),
                          prefixIcon: prefixText != null
                              ? Container(
                                  width: 48,
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Color(0xFFE4DDD8),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    prefixText,
                                    style: const TextStyle(
                                      color: Color(0xFF5B5149),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : prefixIconData == null
                                  ? null
                                  : Container(
                                      width: 48,
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Color(0xFFE4DDD8),
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        prefixIconData,
                                        color: const Color(0xFF8B6500),
                                        size: 19,
                                      ),
                                    ),
                          suffixIcon: suffixIconData == null
                              ? null
                              : Icon(
                                  suffixIconData,
                                  color: const Color(0xFF8B6500),
                                  size: 19,
                                ),
                          filled: true,
                          fillColor:
                              enabled ? Colors.white : const Color(0xFFF1EEEE),
                          contentPadding: EdgeInsets.fromLTRB(
                            16,
                            14,
                            suffixIconData == null ? 16 : 4,
                            14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE3DCD7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFD1A24A),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Color(0xFFE3DCD7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Color(0xFFE3DCD7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.red,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.red,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                        ),
                      ),
                      if (errorText != null || hasInsideCounter) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: errorText == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      errorText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                            if (hasInsideCounter)
                              Text(
                                '${controller.text.characters.length} / $maxLength',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A8178),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDropdownField({
    required _BranchField field,
    required TextEditingController controller,
    required String label,
    double bottomSpacing = 18,
  }) {
    final options = _timeOptionsForField(field);
    final currentValue = controller.text.trim();
    final selectedValue = options.contains(currentValue) ? currentValue : null;
    final isEnabled = field == _BranchField.startTime || options.isNotEmpty;
    final startTime = _parseTimeOfDay(_startTimeController.text);
    final errorText = _timeFieldErrorText(field);

    final dropdown = Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : const Color(0xFFF1EEEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    errorText != null ? AppColors.red : const Color(0xFFE3DCD7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF8B6500),
                ),
                dropdownColor: Colors.white,
                hint: Text(
                  translateText('Select time'),
                  style: const TextStyle(
                    color: Color(0xFF948C84),
                    fontSize: 13,
                  ),
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          style: const TextStyle(
                            color: Color(0xFF201A16),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isEnabled
                    ? (selected) {
                        if (selected == null) return;
                        setState(() {
                          _updateTimeSelection(
                            field,
                            selected,
                            controller: controller,
                            pairedController: field == _BranchField.startTime
                                ? _endTimeController
                                : _startTimeController,
                          );
                        });
                      }
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: errorText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      errorText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    if (isEnabled) return dropdown;

    return InkWell(
      onTap: () {
        Fluttertoast.showToast(
          msg: translateText(
            startTime == null
                ? 'Please select start time to select end time.'
                : 'No valid end time is available for the selected start time.',
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: AbsorbPointer(child: dropdown),
    );
  }

  Future<void> _refreshSalonListForCreatedSelection(
    BuildContext context,
  ) async {
    try {
      final selection = await StylistBranchSelectionStore.load();
      if (!context.mounted) return;
      final salonId = selection.salonId;
      final branchId = selection.branchId;
      final salonCubit = context.read<SalonListCubit>();
      await salonCubit.loadSalons();
      if (!context.mounted) return;

      final selected = _selectionFromFreshSalonList(
            salonCubit.state.salons,
            salonId: salonId,
            branchId: branchId,
          ) ??
          (salonId != null && branchId != null
              ? {
                  'salonId': salonId,
                  'salonName': selection.salonName,
                  'branchId': branchId,
                  'branchName': selection.branchName,
                }
              : null);

      if (selected != null) {
        salonCubit.setSelectedSalon(selected);
      }
      StylistBranchSelectionStore.notifySalonCatalogChanged();
    } catch (_) {
      // Catalog also reads the persisted branch selection when it opens.
    }
  }

  Map<String, dynamic>? _selectionFromFreshSalonList(
    List<Map<String, dynamic>> salons, {
    required int? salonId,
    required int? branchId,
  }) {
    if (salonId == null || branchId == null) return null;

    for (final salon in salons) {
      final currentSalonId = _selectionInt(salon['id']);
      if (currentSalonId != salonId) continue;

      final branches = salon['branches'];
      if (branches is! List) continue;
      for (final rawBranch in branches) {
        if (rawBranch is! Map) continue;
        final branch = Map<String, dynamic>.from(rawBranch);
        final currentBranchId = _selectionInt(branch['id']);
        if (currentBranchId != branchId) continue;

        return {
          'salonId': currentSalonId,
          'salonName': salon['name'],
          'branchId': currentBranchId,
          'branchName': branch['name'] ?? salon['name'],
        };
      }
    }

    return null;
  }

  int? _selectionInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
