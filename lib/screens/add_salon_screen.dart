import 'dart:io';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'add_location_screen.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../screens/bottom_nav.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'AddSalonServices.dart';
import 'set_weekly_schedule_screen.dart';
import '../widgets/salon_flow_step_header.dart';
import '../utils/aws_s3_uploader.dart'; // ✅ make sure this import is present

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

class AddSalonScreen extends StatefulWidget {
  const AddSalonScreen({
    super.key,
    this.id,
    this.phoneNumber,
    this.fullPhoneNumber,
    this.firstName,
    this.lastName,
    this.imageUrl,
    this.email,
    this.isProceedFrom,

    // legacy inputs – safe to keep for back-compat
    this.buildingName,
    this.city,
    this.pincode,
    this.state,
    this.latitude,
    this.longitude,
    this.initialSalon,
    this.isEdit = false,
  });

  final String? id;
  final String? phoneNumber;
  final String? fullPhoneNumber;
  final String? firstName;
  final String? lastName;
  final String? imageUrl;
  final String? email;
  final String? isProceedFrom;

  // legacy inputs (we’ll continue mapping completeAddress into buildingName)
  final String? buildingName;
  final String? city;
  final String? pincode;
  final String? state;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? initialSalon;
  final bool isEdit;

  @override
  State<AddSalonScreen> createState() => _AddSalonScreenState();
}

class _AddSalonScreenState extends State<AddSalonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salonNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _submitted = false;
  final Set<String> _removedExistingImageUrls = <String>{};

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, dynamic nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }
    return null;
  }

  Map<String, dynamic>? _resolvePrimaryBranch(Map<String, dynamic> salon) {
    final branches = (salon['branches'] as List<dynamic>? ?? const [])
        .map(_asStringKeyedMap)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (branches.isEmpty) return null;

    for (final branch in branches) {
      if (branch['isMain'] == true) {
        return branch;
      }
    }

    return branches.first;
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

    return urls
        .where((url) => !_removedExistingImageUrls.contains(url))
        .take(10)
        .toList();
  }

  List<String> _resolveExistingImageUrls() {
    final salon = widget.initialSalon;
    final primaryBranch = salon == null ? null : _resolvePrimaryBranch(salon);
    final urls = <String>[];
    void addAll(Iterable<String> values) {
      for (final url in values) {
        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }

    if (salon != null) {
      addAll(_extractImageUrls(salon['imageUrls']));
      addAll(_extractImageUrls(salon['imageUrl']));
    }
    if (primaryBranch != null) {
      addAll(_extractImageUrls(primaryBranch['imageUrls']));
      addAll(_extractImageUrls(primaryBranch['imageUrl']));
    }
    addAll(_extractImageUrls(widget.imageUrl));

    return urls.take(10).toList();
  }

  String _composeAddressLine1(AddSalonAddress address) {
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

  Map<String, dynamic>? _addressPayload(AddSalonAddress? address) {
    if (address == null) return null;
    return {
      'line1': _composeAddressLine1(address),
      'line2': [
        address.city.trim(),
        address.pincode.trim(),
      ].where((part) => part.isNotEmpty).join(', '),
      'village': '',
      'district': '',
      'city': '',
      'state': address.state,
      'country': 'India',
      'postalCode': '',
    };
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
    Map<String, dynamic>? salon,
  ) {
    final result = <String, List<Map<String, String>>>{};
    final primaryBranch = salon == null ? null : _resolvePrimaryBranch(salon);
    final rawSchedule = primaryBranch?['schedule'] ?? salon?['schedule'];

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

  AddSalonAddress? _extractInitialAddress(Map<String, dynamic> salon) {
    final primaryBranch = _resolvePrimaryBranch(salon);
    final address = _asStringKeyedMap(
          salon['address'],
        ) ??
        _asStringKeyedMap(primaryBranch?['address']) ??
        primaryBranch;

    if (address == null) return null;

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

    return AddSalonAddress(
      buildingName: completeAddress.join(', '),
      city: scoFlatHouse,
      pincode: streetSectorArea,
      state: _firstNonEmptyValue([
        address['state'],
      ]),
      latitude: _readDoubleValue([
        address['latitude'],
        address['lat'],
        primaryBranch?['latitude'],
        primaryBranch?['lat'],
        salon['latitude'],
        salon['lat'],
      ]),
      longitude: _readDoubleValue([
        address['longitude'],
        address['lng'],
        address['lon'],
        primaryBranch?['longitude'],
        primaryBranch?['lng'],
        primaryBranch?['lon'],
        salon['longitude'],
        salon['lng'],
        salon['lon'],
      ]),
    );
  }

  @override
  void initState() {
    super.initState();

    _startTimeController.text = "08:00 AM";
    _endTimeController.text = "08:00 PM";

    final phone = widget.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = _normalizePhone(phone);
    }

    final proceedContext = widget.isProceedFrom?.toLowerCase().trim();
    final shouldPrefillSalonName = proceedContext != 'onboarding';
    if (shouldPrefillSalonName) {
      final names = [widget.firstName, widget.lastName]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        _salonNameController.text = names.join(' ');
      }
    }

    final initialSalon = widget.initialSalon;
    if (initialSalon != null) {
      final primaryBranch = _resolvePrimaryBranch(initialSalon);
      _salonNameController.text = _firstNonEmptyValue([
        initialSalon['name'],
        initialSalon['salonName'],
        initialSalon['businessName'],
        initialSalon['displayName'],
        initialSalon['title'],
      ]);
      _descriptionController.text = _firstNonEmptyValue(
        [
          initialSalon['description'],
          initialSalon['salonDescription'],
          initialSalon['about'],
          initialSalon['details'],
          primaryBranch?['description'],
          primaryBranch?['branchDescription'],
        ],
      );
      _phoneController.text = _normalizePhone(
        _firstNonEmptyValue([
          initialSalon['phone'],
          primaryBranch?['phone'],
          widget.phoneNumber,
        ]),
      );
      final startTime = _firstNonEmptyValue([
        initialSalon['startTime'],
        primaryBranch?['startTime'],
      ]);
      final endTime = _firstNonEmptyValue([
        initialSalon['endTime'],
        primaryBranch?['endTime'],
      ]);
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
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialSalon = widget.initialSalon;
      final initialAddress =
          initialSalon == null ? null : _extractInitialAddress(initialSalon);

      // 🟢 CHANGED: treat legacy buildingName as a completeAddress holder
      final completeAddress = widget.buildingName?.trim() ?? '';

      final latitude = widget.latitude;
      final longitude = widget.longitude;
      final bool hasCoordinates = latitude != null &&
          longitude != null &&
          (latitude != 0.0 || longitude != 0.0);

      if (initialAddress != null) {
        context.read<AddSalonCubit>().updateAddress(initialAddress);
      } else if (completeAddress.isNotEmpty && hasCoordinates) {
        context.read<AddSalonCubit>().updateAddress(
              AddSalonAddress(
                // We store completeAddress in buildingName for back-compat
                buildingName: completeAddress,
                city: '', // not used now
                pincode: '', // not used now
                state: '', // not used now
                latitude: latitude,
                longitude: longitude,
              ),
            );
      }

      context.read<AddSalonCubit>().loadSavedPhone(
            initialPhone: widget.phoneNumber,
          );
    });
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _descriptionController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final existing = context.read<AddSalonCubit>().state.images;
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
    context.read<AddSalonCubit>().setImages(images);
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

  // 🟢 CHANGED: Now “complete” means we have a completeAddress (in buildingName) and coordinates
  bool _isAddressComplete(AddSalonAddress? address) {
    if (address == null) return false;

    final hasCompleteAddress =
        address.buildingName.trim().isNotEmpty; // completeAddress stored here
    final hasValidCoordinates =
        address.latitude != 0.0 || address.longitude != 0.0;

    return hasCompleteAddress && hasValidCoordinates;
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      final formatted = picked.format(context);
      controller.text = formatted;
    }
  }

  // Future<void> _chooseLocation(AddSalonState state) async {
  //   final result = await Navigator.push<Map<String, dynamic>?>(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => const AddLocationScreen(
  //         // we can pass initialCompleteAddress if we later extend state to carry it,
  //         // current AddLocationScreen accepts legacy params too, but they’re unused.
  //       ),
  //     ),
  //   );

  //   if (!mounted || result == null) return;

  //   // 🟢 CHANGED: Read new keys from AddLocationScreen
  //   final completeAddress   = (result['completeAddress'] as String?)?.trim() ?? '';
  //   final scoFlatHouse      = (result['scoFlatHouse'] as String?)?.trim() ?? '';
  //   final streetSectorArea  = (result['streetSectorArea'] as String?)?.trim() ?? '';
  //   final latitude          = (result['latitude'] as num?)?.toDouble() ?? 0;
  //   final longitude         = (result['longitude'] as num?)?.toDouble() ?? 0;

  //   // For now, keep using AddSalonAddress but store the full address
  //   // in buildingName (back-compat with existing Cubit/Model).
  //   // If you want, I can extend the model to add dedicated fields.
  //   context.read<AddSalonCubit>().updateAddress(
  //     AddSalonAddress(
  //       buildingName: completeAddress, // 🟢 store full address here
  //       city: scoFlatHouse,            // optional mapping (so you don’t lose it)
  //       pincode: streetSectorArea,     // optional mapping (so you don’t lose it)
  //       state: '',                     // not used in new flow
  //       latitude: latitude,
  //       longitude: longitude,
  //     ),
  //   );
  // }
  Future<void> _chooseLocation(AddSalonState state) async {
    final addr = state.address;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          // If your AddLocationScreen supports these:
          initialCompleteAddress:
              addr?.buildingName, // complete address (line1)
          initialScoFlatHouse:
              addr?.city, // 🟢 we repurposed 'city' to store SCO/Flat/House
          initialStreetSectorArea: addr
              ?.pincode, // 🟢 we repurposed 'pincode' to store Street/Sector/Area
        ),
      ),
    );

    if (!mounted || result == null) return;

    final completeAddress =
        (result['completeAddress'] as String?)?.trim() ?? '';
    final scoFlatHouse = (result['scoFlatHouse'] as String?)?.trim() ?? '';
    final streetSectorArea =
        (result['streetSectorArea'] as String?)?.trim() ?? '';
    final latitude = (result['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (result['longitude'] as num?)?.toDouble() ?? 0;

    context.read<AddSalonCubit>().updateAddress(
          AddSalonAddress(
            buildingName: completeAddress, // line1
            city: scoFlatHouse, // line2 part A (SCO/Flat/House)
            pincode: streetSectorArea, // line2 part B (Street/Sector/Area)
            state: '', // unused in the new flow
            latitude: latitude,
            longitude: longitude,
          ),
        );
  }

  Future<void> _submit(AddSalonState state) async {
    setState(() => _submitted = true);

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (widget.isEdit &&
        (_startTimeController.text.isEmpty ||
            _endTimeController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(translateText('Please select start and end time.'))),
      );
      return;
    }

    // 🟢 CHANGED: use new completeness check
    final address = state.address;
    if (!widget.isEdit && !_isAddressComplete(address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(translateText('Please add the salon location.'))),
      );
      return;
    }

    final cubit = context.read<AddSalonCubit>();
    cubit.setSubmitting(true);

    try {
      final images = cubit.state.images;
      final existingImageUrls = _resolveExistingImageUrls();
      final existingImageUrl =
          existingImageUrls.isEmpty ? '' : existingImageUrls.first;

      if (!mounted) return;
      if (widget.isEdit && widget.initialSalon != null) {
        final salonId = (widget.initialSalon!['id'] as num?)?.toInt();
        if (salonId == null) {
          throw Exception('Missing salon id');
        }
        Future<void> saveSalonEdit(ScheduleStepResult scheduleResult) async {
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
          final name = _salonNameController.text.trim();
          final phone = _normalizePhone(_phoneController.text);
          final description = _descriptionController.text.trim();
          final addressPayload = _addressPayload(address);
          try {
            await cubit.repository.updateSalon(
              salonId: salonId,
              name: name,
              phone: phone,
              startTime: scheduleResult.startTime,
              endTime: scheduleResult.endTime,
              description: description,
              schedule: scheduleResult.schedule,
              imageUrl: imageUrl,
              imageUrls: imageUrls,
              address: addressPayload,
              latitude: address?.latitude,
              longitude: address?.longitude,
            );
          } catch (error) {
            final primaryBranch = _resolvePrimaryBranch(widget.initialSalon!);
            final branchId = _readIntValue([
              primaryBranch?['id'],
              widget.initialSalon!['branchId'],
              widget.initialSalon!['mainBranchId'],
            ]);
            final isForbidden = error.toString().contains('Forbidden') ||
                error.toString().contains('Access denied') ||
                error.toString().contains('403');
            if (!isForbidden || branchId == null || addressPayload == null) {
              rethrow;
            }
            await cubit.repository.updateBranch(
              branchId: branchId,
              name: name,
              phone: phone,
              startTime: scheduleResult.startTime,
              endTime: scheduleResult.endTime,
              description: description,
              schedule: scheduleResult.schedule,
              address: addressPayload,
              latitude: address?.latitude ?? 0,
              longitude: address?.longitude ?? 0,
              imageUrl: imageUrl,
              imageUrls: imageUrls,
            );
          }
        }

        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SetWeeklyScheduleScreen(
              title: 'Edit Salon',
              detailsStepLabel: 'Salon Details',
              initialStartTime: _startTimeController.text.trim(),
              initialEndTime: _endTimeController.text.trim(),
              initialSchedule: _extractInitialSchedule(widget.initialSalon),
              totalSteps: 2,
              submitLabel: 'Save',
              onSubmit: saveSalonEdit,
            ),
          ),
        );
        if (!mounted || saved != true) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translateText('Salon updated successfully')),
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      final formData = AddSalonFormData(
        name: _salonNameController.text.trim(),
        phone: _normalizePhone(_phoneController.text),
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
        description: _descriptionController.text.trim(),
        schedule: const <String, List<Map<String, String>>>{},
        imageUrl: existingImageUrl.isEmpty ? null : existingImageUrl,
      );

      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SetWeeklyScheduleScreen(
            title: 'Add Salon',
            detailsStepLabel: 'Salon Details',
            initialStartTime: _startTimeController.text.trim(),
            initialEndTime: _endTimeController.text.trim(),
            initialSchedule: const <String, List<Map<String, String>>>{},
            totalSteps: 3,
            onContinue: (scheduleResult) async {
              if (!mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: AddSalonServices(
                      title: 'Add Salon',
                      initialCodes: state.selectedServiceCodes,
                      formData: AddSalonFormData(
                        name: formData.name,
                        phone: formData.phone,
                        startTime: scheduleResult.startTime,
                        endTime: scheduleResult.endTime,
                        description: formData.description,
                        schedule: scheduleResult.schedule,
                        imageUrl: formData.imageUrl,
                        imageUrls: formData.imageUrls,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      cubit.setSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();
    return BlocConsumer<AddSalonCubit, AddSalonState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.savedPhone != null && _phoneController.text.isEmpty) {
          _phoneController.text = state.savedPhone!;
        }

        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;

        if (state.status == AddSalonStatus.failure &&
            state.errorMessage != null &&
            isCurrent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }

        if (state.status == AddSalonStatus.success && isCurrent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateText('Salon added successfully'))),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BottomNav(tabIndex: 1),
            ),
          );
        }
      },
      builder: (context, state) {
        final images = state.images;
        final address = state.address;
        final existingImageUrls = _resolveExistingImageUrls();

        return Scaffold(
          backgroundColor: const Color(0xFFFBFAF8),
          appBar: buildProfileSubpageAppBar(
            title: translateText(widget.isEdit ? 'Edit Salon' : 'Add Salon'),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SalonFlowStepHeader(
                        currentStep: 1,
                        detailsLabel: translateText('Salon Details'),
                        totalSteps: widget.isEdit ? 2 : 3,
                      ),
                      const SizedBox(height: 22),
                      _buildHeroCard(
                        quote:
                            '"The foundation of luxury is the precision of your process."',
                      ),
                      const SizedBox(height: 34),
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translateText('Basic Information'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF161616),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildTextField(
                              controller: _salonNameController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.sentences,
                              label: 'Salon Name *',
                              hint: 'Enter your business name',
                              enabled: true,
                              maxLength: 50,
                              inputFormatters: const [
                                _FirstLetterUpperFormatter()
                              ],
                            ),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number *',
                              maxLength: 10,
                              hint: '9855096207',
                              enabled: true,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTimePickerField(
                                    controller: _startTimeController,
                                    label: 'Start Time *',
                                    onTap: () =>
                                        _selectTime(_startTimeController),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTimePickerField(
                                    controller: _endTimeController,
                                    label: 'End Time *',
                                    onTap: () =>
                                        _selectTime(_endTimeController),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildAddressField(address, state),
                            _buildTextField(
                              controller: _descriptionController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.sentences,
                              label: 'Description *',
                              hint: "Tell us more...",
                              maxLines: 1,
                              maxLength: 250,
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
                                text: translateText('Salon Images'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF161616),
                                ),
                                children: [
                                  TextSpan(
                                    text: ' (${translateText('Optional')})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8A8178),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildImageGrid(images, existingImageUrls),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildEmpireCard(),
                      const SizedBox(height: 18),
                      _buildProTipCard(),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              state.isSubmitting ? null : () => _submit(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B6500),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0x338B6500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
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
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 20),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.status == AddSalonStatus.loading)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
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

  Widget _buildAddressField(AddSalonAddress? address, AddSalonState state) {
    final hasAddress =
        address != null && address.buildingName.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Salon Address *'),
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
                    Icons.location_on_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: hasAddress
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address.buildingName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF3B332B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (address.city.trim().isNotEmpty ||
                                  address.pincode.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    [
                                      address.city.trim(),
                                      address.pincode.trim(),
                                    ]
                                        .where((part) => part.isNotEmpty)
                                        .join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF8A8178),
                                      fontSize: 12,
                                    ),
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
            style: isAddSlot ? BorderStyle.solid : BorderStyle.solid,
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
                              context.read<AddSalonCubit>().removeImage(file);
                              return;
                            }
                            final url = networkUrl;
                            if (url == null) return;
                            setState(() {
                              _removedExistingImageUrls.add(url);
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
                                  ? Color(0xFF7A4A09)
                                  : Color(0xFFCFC8C2),
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

  Widget _buildEmpireCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFD0A947),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF5D4200)),
          ),
          const SizedBox(height: 18),
          Text(
            translateText('Build Your Empire'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2A2117),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            translateText(
              "Your vision, our platform. Let's create a space where beauty meets business excellence.",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF4B3825),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Divider(color: Color(0x55FFFFFF)),
          ),
          _buildEmpireBenefit('Optimized Search Presence'),
          _buildEmpireBenefit('Premium Booking Experience'),
          _buildEmpireBenefit('Inventory & Staff Management'),
        ],
      ),
    );
  }

  Widget _buildEmpireBenefit(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              translateText(label),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2A2117),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAE0D7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              color: Color(0xFF7A4A09), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Pro Tip'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  translateText(
                    'Salons with clear descriptions and high-quality photos receive 40% more bookings.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF5F5A55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool forceCapitalize = false,
    int? maxWords,
    String? prefixText,
    bool reserveCounterSpace = false,
  }) {
    final normalizedLabel = label.replaceAll('*', '').trim();
    final normalizedHint = hint.trim();

    final translatedLabel = translateText(normalizedLabel);
    final translatedHint = translateText(normalizedHint);

    final localizedLabel =
        translatedLabel != normalizedLabel ? translatedLabel : normalizedLabel;
    final localizedHint =
        translatedHint != normalizedHint ? translatedHint : normalizedHint;

    final String cleanLabel = localizedLabel.trim();
    final hasInsideCounter = maxLength != null;
    final shouldReserveCounterSpace = hasInsideCounter || reserveCounterSpace;

    if (forceCapitalize) {
      controller.addListener(() {
        final text = controller.text;
        final capitalized = text
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '')
            .join(' ');
        if (text != capitalized) {
          final cursor = controller.selection;
          controller.value = TextEditingValue(
            text: capitalized,
            selection: cursor,
          );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
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
                    textCapitalization: textCapitalization,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return translateText('{field} is required')
                            .replaceAll('{field}', cleanLabel);
                      }

                      if (label.toLowerCase().contains('phone') ||
                          label.toLowerCase().contains('mobile')) {
                        if (text.length != 10) {
                          return translateText(
                              'Phone number must be 10 digits');
                        }
                        if (RegExp(r'^(\d)\1{9}$').hasMatch(text)) {
                          return translateText('Invalid phone number');
                        }
                      }

                      if (maxWords != null &&
                          text.split(RegExp(r'\s+')).length > maxWords) {
                        return translateText('Maximum $maxWords words allowed');
                      }

                      return null;
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: localizedHint,
                      hintStyle: const TextStyle(
                        color: Color(0xFF948C84),
                        fontSize: 13,
                        height: 1.6,
                      ),
                      prefixIcon: prefixText == null
                          ? null
                          : Container(
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
                            ),
                      filled: true,
                      fillColor:
                          enabled ? Colors.white : const Color(0xFFF1EEEE),
                      contentPadding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        hasInsideCounter ? 82 : 16,
                        shouldReserveCounterSpace ? 30 : 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE3DCD7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFFD1A24A),
                          width: 1.2,
                        ),
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
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(
          controller: controller,
          label: label,
          hint: 'Select time',
          reserveCounterSpace: true,
        ),
      ),
    );
  }
}
