import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../services/language_listener.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _submitted = false;
  bool _savedPhoneApplied = false;
  List<Map<String, dynamic>> _sourceBranches = const [];
  List<String> _existingImageUrls = const <String>[];
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

  String _formatDisplayTime(
    dynamic value, {
    String fallback = '',
  }) {
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

    final twelveHourMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
            caseSensitive: false)
        .firstMatch(text);
    if (twelveHourMatch != null) {
      return formatParts(
        twelveHourMatch.group(1)!,
        twelveHourMatch.group(2)!,
        twelveHourMatch.group(3)!,
      );
    }

    final twentyFourHourMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
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

  Map<String, List<Map<String, String>>> _extractInitialSchedule(
    Map<String, dynamic>? branch,
  ) {
    final result = <String, List<Map<String, String>>>{};
    final rawSchedule = branch?['schedule'];
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
            .map((slot) => <String, String>{
                  'startTime': _formatDisplayTime(
                    _firstNonEmptyValue([slot['startTime'], slot['start']]),
                  ),
                  'endTime': _formatDisplayTime(
                    _firstNonEmptyValue([slot['endTime'], slot['end']]),
                  ),
                })
            .where((slot) =>
                slot['startTime']!.isNotEmpty && slot['endTime']!.isNotEmpty)
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
            .map((slot) => <String, String>{
                  'startTime': _formatDisplayTime(
                    _firstNonEmptyValue([slot['startTime'], slot['start']]),
                  ),
                  'endTime': _formatDisplayTime(
                    _firstNonEmptyValue([slot['endTime'], slot['end']]),
                  ),
                })
            .where((slot) =>
                slot['startTime']!.isNotEmpty && slot['endTime']!.isNotEmpty)
            .toList();
      }
    }

    return result;
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

  String _addressWithoutManualParts(
    String address,
    List<String> manualParts,
  ) {
    final manualPartsLower = manualParts
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (manualPartsLower.isEmpty) return address.trim();
    return address
        .split(',')
        .map((part) => part.trim())
        .where((part) =>
            part.isNotEmpty && !manualPartsLower.contains(part.toLowerCase()))
        .join(', ');
  }

  String _composeAddressLine1(BranchAddress address) {
    final leadingParts = [
      address.city.trim(),
      address.pincode.trim(),
    ].where((part) => part.isNotEmpty).toList();
    final leadingPartsLower =
        leadingParts.map((part) => part.toLowerCase()).toSet();
    final baseParts = address.buildingName
        .split(',')
        .map((part) => part.trim())
        .where((part) =>
            part.isNotEmpty && !leadingPartsLower.contains(part.toLowerCase()))
        .toList();
    return [...leadingParts, ...baseParts].join(', ');
  }

  BranchAddress? _extractInitialAddress(Map<String, dynamic> branch) {
    final address = _asStringKeyedMap(branch['address']) ?? branch;

    final completeAddress = <String>[];
    for (final key in const [
      'line1',
      'line2',
      'village',
      'district',
      'city',
      'state',
      'country',
      'postalCode',
    ]) {
      final value = (address[key] ?? '').toString().trim();
      if (value.isNotEmpty && !completeAddress.contains(value)) {
        completeAddress.add(value);
      }
    }

    final scoFlatHouse = _firstNonEmptyValue([
      address['line2'],
      address['village'],
    ]);
    final streetSectorArea = _firstNonEmptyValue([
      address['district'],
      address['city'],
      address['state'],
      address['postalCode'],
    ]);

    if (completeAddress.isEmpty &&
        scoFlatHouse.isEmpty &&
        streetSectorArea.isEmpty) {
      return null;
    }

    return BranchAddress(
      buildingName: _addressWithoutManualParts(
        completeAddress.join(', '),
        [scoFlatHouse, streetSectorArea],
      ),
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
    _startTimeController.text = "08:00 AM";
    _endTimeController.text = "08:00 PM";
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
        _startTimeController.text = _formatDisplayTime(
          startTime,
          fallback: _startTimeController.text,
        );
      }
      if (endTime.isNotEmpty) {
        _endTimeController.text = _formatDisplayTime(
          endTime,
          fallback: _endTimeController.text,
        );
      }
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
    super.dispose();
  }

  Future<void> _pickImages() async {
    final existing = context.read<AddBranchCubit>().state.images;
    final remainingSlots = 10 - existing.length;
    if (remainingSlots <= 0) {
      _showImageLimitSnackBar();
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
      _showImageLimitSnackBar();
    }
    final images = [
      ...existing,
      ...files.map((file) => File(file.path)),
    ].take(10).toList();
    context.read<AddBranchCubit>().setImages(images);
  }

  void _showImageLimitSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translateText(
            'You can add up to 10 photos. Remove a photo before choosing another.',
          ),
        ),
      ),
    );
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

  Future<void> _selectTime(
    _BranchField field,
    TextEditingController controller,
  ) async {
    final defaultTime = field == _BranchField.startTime
        ? const TimeOfDay(hour: 8, minute: 0)
        : const TimeOfDay(hour: 20, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: defaultTime,
    );

    if (picked != null) {
      if (!mounted) return;
      controller.text = picked.format(context);
      _resetFieldError(field);
    }
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
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          initialCompleteAddress: existing?.buildingName,
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
            : _addressWithoutManualParts(
                completeAddress,
                [scoFlatHouse, streetSectorArea],
              ),
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

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      for (final key in _fieldValidationVisibility.keys) {
        _fieldValidationVisibility[key] = true;
      }
    });

    final isValid = form.validate();
    if (!isValid) return;

    if (widget.isEdit &&
        (_startTimeController.text.isEmpty ||
            _endTimeController.text.isEmpty)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(translateText('Please select start and end time.')),
        ),
      );
      return;
    }

    // 🟢 Require address completeness based on new flow
    if (!_isAddressComplete(state.address)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(translateText('Please choose a branch location.')),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final branchCubit = context.read<AddBranchCubit>();
    final images = state.images;
    final existingImageUrls = List<String>.from(_existingImageUrls);
    final existingImageUrl =
        existingImageUrls.isEmpty ? '' : existingImageUrls.first;

    if (!mounted) return;

    if (widget.isEdit && widget.initialBranch != null) {
      final branchId = (widget.initialBranch!['id'] as num?)?.toInt();
      if (branchId == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(translateText('Missing branch id'))),
        );
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

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SetWeeklyScheduleScreen(
            title: 'Edit Branch',
            detailsStepLabel: 'Branch Details',
            initialStartTime: _startTimeController.text.trim(),
            initialEndTime: _endTimeController.text.trim(),
            initialSchedule: _extractInitialSchedule(widget.initialBranch),
            totalSteps: 2,
            submitLabel: 'Save',
            onSubmit: saveBranchEdit,
          ),
        ),
      );
      if (!mounted || saved != true) return;

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(translateText('Branch updated successfully'))),
      );
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

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SetWeeklyScheduleScreen(
          title: 'Add Branch',
          detailsStepLabel: 'Branch Details',
          initialStartTime: _startTimeController.text.trim(),
          initialEndTime: _endTimeController.text.trim(),
          initialSchedule: const <String, List<Map<String, String>>>{},
          totalSteps: 3,
          onContinue: (scheduleResult) async {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => AddSalonCubit(SalonRepository()),
                    ),
                    BlocProvider.value(
                      value: branchCubit,
                    ),
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
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    return BlocConsumer<AddBranchCubit, AddBranchState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }

        if (state.status == BranchFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                translateText(
                  widget.isEdit
                      ? 'Branch updated successfully'
                      : 'Branch added successfully',
                ),
              ),
            ),
          );
          Navigator.pop(context, true);
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
                                  _FirstLetterUpperFormatter()
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTimePickerField(
                                        field: _BranchField.startTime,
                                        controller: _startTimeController,
                                        label: 'Start Time *',
                                        onTap: () => _selectTime(
                                          _BranchField.startTime,
                                          _startTimeController,
                                        ),
                                        bottomSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTimePickerField(
                                        field: _BranchField.endTime,
                                        controller: _endTimeController,
                                        label: 'End Time *',
                                        onTap: () => _selectTime(
                                          _BranchField.endTime,
                                          _endTimeController,
                                        ),
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
                                  _FirstLetterUpperFormatter()
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
                              _buildImageGrid(
                                images,
                                _existingImageUrls,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: state.isSubmitting
                                ? null
                                : () => _submit(state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B6500),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: state.isSubmitting
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
                                        translateText(widget.isEdit
                                            ? 'Save Changes'
                                            : 'Next Step'),
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

  Widget _buildAddressField(BranchAddress? address, AddBranchState state) {
    final hasAddress =
        address != null && address.buildingName.trim().isNotEmpty;
    final displayAddress = hasAddress
        ? _composeAddressLine1(address)
        : translateText('Add Location');
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
                  color: const Color(0xFFD3A94C),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_rounded,
                    color: Color(0xFF8B6500),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: hasAddress
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF3B332B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            translateText('Add Location'),
                            style: const TextStyle(
                              color: Color(0xFF7A4A09),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
    String? prefixText,
    IconData? prefixIconData,
    IconData? suffixIconData,
    bool reserveCounterSpace = false,
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
    final shouldReserveCounterSpace = hasInsideCounter || reserveCounterSpace;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Stack(
                children: [
                  TextFormField(
                    controller: controller,
                    maxLines: maxLines,
                    maxLength: maxLength,
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
                    inputFormatters: inputFormatters,
                    textCapitalization: textCapitalization,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    onChanged: (changedValue) {
                      _resetFieldError(field);
                      onChanged?.call(changedValue);
                    },
                    validator: (inputValue) {
                      if (!(_fieldValidationVisibility[field] ?? false)) {
                        return null;
                      }
                      if (isRequired &&
                          (inputValue == null || inputValue.trim().isEmpty)) {
                        return translateText('{field} is required',
                            params: {'field': fieldForMessage});
                      }
                      return null;
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
                                  right: BorderSide(color: Color(0xFFE4DDD8)),
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
                                      right:
                                          BorderSide(color: Color(0xFFE4DDD8)),
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
                        hasInsideCounter
                            ? 82
                            : suffixIconData == null
                                ? 16
                                : 4,
                        shouldReserveCounterSpace ? 30 : 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Color(0xFFD1A24A), width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppColors.red, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppColors.red, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorStyle: const TextStyle(color: AppColors.red),
                    ),
                  ),
                  if (hasInsideCounter)
                    Positioned(
                      right: 12,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Text(
                          '${value.text.length} / $maxLength',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8178),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerField({
    required _BranchField field,
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
    double bottomSpacing = 18,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(
          field: field,
          controller: controller,
          label: label,
          hint: 'Select time',
          suffixIconData: Icons.access_time_rounded,
          bottomSpacing: bottomSpacing,
        ),
      ),
    );
  }
}
