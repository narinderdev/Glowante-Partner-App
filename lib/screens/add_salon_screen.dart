import 'dart:io';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'add_location_screen.dart';
import '../screens/bottom_nav.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'AddSalonServices.dart';

class AddSalonScreen extends StatefulWidget {
  const AddSalonScreen({
    super.key,
    this.id,
    this.phoneNumber,
    this.fullPhoneNumber,
    this.firstName,
    this.lastName,
    this.email,
    this.isProceedFrom,
    this.buildingName,
    this.city,
    this.pincode,
    this.state,
    this.latitude,
    this.longitude,
  });

  final String? id;
  final String? phoneNumber;
  final String? fullPhoneNumber;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? isProceedFrom;
  final String? buildingName;
  final String? city;
  final String? pincode;
  final String? state;
  final double? latitude;
  final double? longitude;

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

  @override
  void initState() {
    super.initState();

    // Set default start and end time
    _startTimeController.text = "08:00 AM";
    _endTimeController.text = "08:00 PM";

    final phone = widget.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }

    final names = [widget.firstName, widget.lastName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      _salonNameController.text = names.join(' ');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latitude = widget.latitude;
      final longitude = widget.longitude;
      if (widget.buildingName != null &&
          widget.city != null &&
          widget.pincode != null &&
          widget.state != null &&
          latitude != null &&
          longitude != null) {
        context.read<AddSalonCubit>().updateAddress(
              AddSalonAddress(
                buildingName: widget.buildingName ?? '',
                city: widget.city ?? '',
                pincode: widget.pincode ?? '',
                state: widget.state ?? '',
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
    final files = await _picker.pickMultiImage();
    if (!mounted || files == null) return;
    final images = files.map((file) => File(file.path)).toList();
    context.read<AddSalonCubit>().setImages(images);
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formatted = picked.format(context);
      controller.text = formatted;
    }
  }

  Future<void> _chooseLocation(AddSalonState state) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          buildingName: state.address?.buildingName ?? '',
          city: state.address?.city ?? '',
          pincode: state.address?.pincode ?? '',
          state: state.address?.state ?? '',
        ),
      ),
    );

    if (!mounted || result == null) return;
    context.read<AddSalonCubit>().updateAddress(
          AddSalonAddress(
            buildingName: result['buildingName'] as String? ?? '',
            city: result['city'] as String? ?? '',
            pincode: result['pincode'] as String? ?? '',
            state: result['state'] as String? ?? '',
            latitude: (result['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (result['longitude'] as num?)?.toDouble() ?? 0,
          ),
        );
  }

  Future<void> _submit(AddSalonState state) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(translateText('Please select start and end time.'))),
      );
      return;
    }
    String _capitalizeWords(String value) {
      return value
          .split(' ')
          .map((word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
          .join(' ');
    }

    if (state.address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(translateText('Please add the salon location.'))),
      );
      return;
    }

    final formData = AddSalonFormData(
      name: _capitalizeWords(_salonNameController.text.trim()),
      phone: _phoneController.text.trim(),
      startTime: _startTimeController.text.trim(),
      endTime: _endTimeController.text.trim(),
      description: _capitalizeWords(_descriptionController.text.trim()),
    );

    final cubit = context.read<AddSalonCubit>();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AddSalonServices(
            initialCodes: state.selectedServiceCodes,
            formData: formData,
          ),
        ),
      ),
    );
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

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            // Let the gradient show through:
            backgroundColor: Colors.transparent,
            elevation: 0,
            // Ensure status bar + icons look good on the gradient:
            systemOverlayStyle: SystemUiOverlayStyle.light,
            iconTheme: const IconThemeData(
              color: Colors.white, // back button color
            ),
            title: Text(
              translateText('Add Salon'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Paint the gradient here:
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.starColor, // your start color
                    AppColors.getStartedButton, // your end color
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _salonNameController,
                        textCapitalization: TextCapitalization.words,
                        label: 'Salon Name *',
                        hint: 'Enter your salon name',
                         forceCapitalize: true,
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number *',
                        maxLength: 10,
                        hint: 'Enter phone number',
                        enabled: true,
                        keyboardType:
                            TextInputType.phone, // ✅ phone-optimized keyboard
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ], // ✅ digits only
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerField(
                              controller: _startTimeController,
                              label: 'Start Time *',
                              onTap: () => _selectTime(_startTimeController),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildTimePickerField(
                              controller: _endTimeController,
                              label: 'End Time *',
                              onTap: () => _selectTime(_endTimeController),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        translateText('Salon Address'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _chooseLocation(state),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppColors.darkGrey, width: 1),
                          ),
                          child: (address == null ||
                                  (address?.buildingName?.isEmpty ?? true) ||
                                  (address?.city?.isEmpty ?? true) ||
                                  (address?.state?.isEmpty ?? true) ||
                                  (address?.pincode?.isEmpty ??
                                      true)) // Using null-aware operators
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    RichText(
  text: TextSpan(
    children: [
      TextSpan(
        text: translateText('Add Location'),
        style: const TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      const TextSpan(
        text: ' *',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  ),
),

                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            address?.buildingName ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.darkGrey,
                                            ),
                                          ),
                                          if ((address?.city?.isNotEmpty ??
                                                  false) &&
                                              (address?.state?.isNotEmpty ??
                                                  false))
                                            Text(
                                              '${address?.city}, ${address?.state}',
                                              style: const TextStyle(
                                                  color: AppColors.darkGrey),
                                            ),
                                          if (address?.pincode?.isNotEmpty ??
                                              false)
                                            Text(
                                              'Pincode: ${address?.pincode}',
                                              style: const TextStyle(
                                                  color: AppColors.darkGrey),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.edit, color: AppColors.darkGrey),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.words,
                        label: 'Description *',
                        hint: 'Enter a description about your salon',
                        maxLines: 1,
                         forceCapitalize: true,
                         maxWords: 250, 
                      ),
                      SizedBox(height: 20),
                      Text(
                        translateText('Salon Images(Optional)'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // for (final image in images)
                          //   ClipRRect(
                          //     borderRadius: BorderRadius.circular(8),
                          //     child: Image.file(
                          //       image,
                          //       width: 80,
                          //       height: 80,
                          //       fit: BoxFit.cover,
                          //     ),
                          //   ),
                          for (final image in images)
  Stack(
    clipBehavior: Clip.none,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          image,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      ),
      // ❌ Remove button
      Positioned(
        top: -6,
        right: -6,
        child: GestureDetector(
          onTap: () {
            setState(() {
              context.read<AddSalonCubit>().removeImage(image);
            });
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(3),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    ],
  ),

                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.darkGrey),
                              ),
                              child: Icon(
                                Icons.add,
                                color: AppColors.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              state.isSubmitting ? null : () => _submit(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.starColor,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: state.isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(translateText('Next')),
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
}) {
// ✅ Localize the label and hint
// ✅ Clean label text before translation (remove * and any spaces around it)
final normalizedLabel = label.replaceAll('*', '').trim();
final normalizedHint = hint.trim();

// ✅ Try translating the cleaned label and hint
final translatedLabel = translateText(normalizedLabel);
final translatedHint = translateText(normalizedHint);

// ✅ Fallback to original English if translation not found
final localizedLabel =
    translatedLabel != normalizedLabel ? translatedLabel : normalizedLabel;
final localizedHint =
    translatedHint != normalizedHint ? translatedHint : normalizedHint;

// ✅ Detect if original label contained '*' (even with space before/after)
final bool hasAsterisk = label.contains('*');

// ✅ Clean label text for error messages
final String cleanLabel = localizedLabel.trim();


  // ✅ Optional capitalization listener
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
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
  final text = value?.trim() ?? '';

  // ✅ Required field validation with placeholder translation
  if (text.isEmpty) {
    return translateText('{field} is required').replaceAll('{field}', cleanLabel);
  }

  // ✅ Phone number validation
  if (label.toLowerCase().contains('phone') ||
      label.toLowerCase().contains('mobile')) {
    if (text.length != 10) {
      return translateText('Phone number must be 10 digits');
    }
    if (RegExp(r'^(\d)\1{9}$').hasMatch(text)) {
      return translateText('Invalid phone number');
    }
  }

  // ✅ Word count validation
  if (maxWords != null &&
      text.split(RegExp(r'\s+')).length > maxWords) {
    return translateText('Maximum $maxWords words allowed');
  }

  return null;
},

      decoration: InputDecoration(
        counterText: '',
        hintText: localizedHint,
        label: RichText(
          text: TextSpan(
            text: cleanLabel,
            style: const TextStyle(
              color: AppColors.darkGrey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            children: hasAsterisk
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        errorStyle: const TextStyle(
          color: AppColors.red,
        ),
      ),
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
        ),
      ),
    );
  }
}
