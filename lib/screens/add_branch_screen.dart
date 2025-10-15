import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'add_location_screen.dart';
import 'package:flutter/services.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/colors.dart';
import 'AddSalonServices.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';

enum _BranchField { name, phone, startTime, endTime, description }

class _CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    final buffer = StringBuffer();
    var madeUppercase = false;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (!madeUppercase && char.trim().isNotEmpty) {
        buffer.write(char.toUpperCase());
        madeUppercase = true;
      } else {
        buffer.write(char);
      }
    }

    final capitalized = buffer.toString();
    if (capitalized == text) {
      return newValue;
    }

    return newValue.copyWith(text: capitalized, selection: newValue.selection);
  }
}

class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({super.key, required this.salonId});

  final int salonId;

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
  final Map<_BranchField, bool> _fieldValidationVisibility = {
    for (final field in _BranchField.values) field: false,
  };

  @override
  void initState() {
    super.initState();
      _startTimeController.text = "08:00 AM";
  _endTimeController.text = "08:00 PM";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddBranchCubit>().loadSavedPhone();
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
    final files = await _picker.pickMultiImage();
    if (!mounted || files == null) return;
    final images = files.map((file) => File(file.path)).toList();
    context.read<AddBranchCubit>().setImages(images);
  }

  void _resetFieldError(_BranchField field) {
    if (!mounted) {
      return;
    }
    if (!(_fieldValidationVisibility[field] ?? false)) {
      return;
    }
    setState(() {
      _fieldValidationVisibility[field] = false;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _selectTime(
  _BranchField field,
  TextEditingController controller,
) async {
  // ⏰ Determine default time (based on field)
  final defaultTime = field == _BranchField.startTime
      ? const TimeOfDay(hour: 8, minute: 0)
      : const TimeOfDay(hour: 20, minute: 0);

  final picked = await showTimePicker(
    context: context,
    initialTime: defaultTime, // ✅ start with 8:00 or 20:00
  );

  if (picked != null) {
    controller.text = picked.format(context);
    _resetFieldError(field);
  }
}


  Future<void> _chooseLocation(AddBranchState state) async {
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
    context.read<AddBranchCubit>().updateAddress(
          BranchAddress(
            buildingName: result['buildingName'] as String? ?? '',
            city: result['city'] as String? ?? '',
            pincode: result['pincode'] as String? ?? '',
            state: result['state'] as String? ?? '',
            latitude: (result['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (result['longitude'] as num?)?.toDouble() ?? 0,
          ),
        );
  }

  // void _submit(AddBranchState state) {
  //   final form = _formKey.currentState;
  //   if (form == null) {
  //     return;
  //   }

  //   setState(() {
  //     for (final key in _fieldValidationVisibility.keys) {
  //       _fieldValidationVisibility[key] = true;
  //     }
  //   });

  //   final isValid = form.validate();
  //   if (!isValid) {
  //     return;
  //   }

  //   if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //           content: Text(translateText('Please select start and end time.'))),
  //     );
  //     return;
  //   }

  //   context.read<AddBranchCubit>().submit(
  //         AddBranchFormData(
  //           name: _branchNameController.text.trim(),
  //           phone: _phoneController.text.trim(),
  //           startTime: _startTimeController.text.trim(),
  //           endTime: _endTimeController.text.trim(),
  //           description: _descriptionController.text.trim(),
  //         ),
  //       );
  // }
void _submit(AddBranchState state) {
  final form = _formKey.currentState;
  if (form == null) return;

  setState(() {
    for (final key in _fieldValidationVisibility.keys) {
      _fieldValidationVisibility[key] = true;
    }
  });

  final isValid = form.validate();
  if (!isValid) return;

  if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translateText('Please select start and end time.')),
      ),
    );
    return;
  }

  if (state.address == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translateText('Please choose a branch location.')),
      ),
    );
    return;
  }

  // ✅ Create the form data object
  final branchFormData = AddBranchFormData(
    name: _branchNameController.text.trim(),
    phone: _phoneController.text.trim(),
    startTime: _startTimeController.text.trim(),
    endTime: _endTimeController.text.trim(),
    description: _descriptionController.text.trim(),
  );

  // ✅ Navigate to AddSalonServices instead of calling API
 Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AddSalonCubit(SalonRepository()),
        ),
        BlocProvider.value(
          value: context.read<AddBranchCubit>(),
        ),
      ],
      child: AddSalonServices(
        branchFormData: branchFormData,
        branchAddress: state.address!,
        branchImages: state.images,
         salonId: widget.salonId,
      ),
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
        if (state.savedPhone != null) {
          _phoneController.text = state.savedPhone!;
          _resetFieldError(_BranchField.phone);
        }

        if (state.status == BranchFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }

        if (state.status == BranchFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateText('Branch added successfully'))),
          );
          Navigator.pop(context, true);
        }
      },
      builder: (context, state) {
        final images = state.images;
        final address = state.address;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              translateText('Add Branch'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.starColor,
                    AppColors.getStartedButton,
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
                        field: _BranchField.name,
                        controller: _branchNameController,
                        label: 'Branch Name *',
                        hint: 'Enter branch name',
                        inputFormatters: [
                          _CapitalizeFirstLetterFormatter(),
                        ],
                      ),
                      _buildTextField(
                        field: _BranchField.phone,
                        controller: _phoneController,
                        label: 'Phone Number *',
                        hint: 'Enter phone number',
                        maxLength: 10,
                        enabled: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
     IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          children: [
            _buildTimePickerField(
              field: _BranchField.startTime,
              controller: _startTimeController,
              label: 'Start Time *',
              onTap: () => _selectTime(
                _BranchField.startTime,
                _startTimeController,
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          children: [
            _buildTimePickerField(
              field: _BranchField.endTime,
              controller: _endTimeController,
              label: 'End Time *',
              onTap: () => _selectTime(
                _BranchField.endTime,
                _endTimeController,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
                      SizedBox(height: 20),
                      Text(
                        translateText('Branch Address'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
// ✅ Case: No address -> show bordered box with "Add Location"
                      if (address == null)
                        InkWell(
                          onTap: () => _chooseLocation(state),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.darkGrey, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    translateText("Add Location"),
                                    style: const TextStyle(
                                      color: AppColors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        // ✅ Case: Address exists -> your existing design
                        InkWell(
                          onTap: () => _chooseLocation(state),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.darkGrey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.buildingName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4),
                                      Text('${address.city}, ${address.state}'),
                                      Text('Pincode: ${address.pincode}'),
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
                        field: _BranchField.description,
                        controller: _descriptionController,
                        label: 'Description *',
                        hint: 'Enter description',
                        maxLines: 1,
                        inputFormatters: [
                          _CapitalizeFirstLetterFormatter(),
                        ],
                      ),

                      SizedBox(height: 20),
                      Text(
                        translateText('Branch Images(Optional)'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final image in images)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                image,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
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
              if (state.status == BranchFormStatus.loading)
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
  }) {
    final localizedLabel = translateText(label);
    final localizedHint = translateText(hint);

    // if label has '*', we show red star and also require validation
    final isRequired = localizedLabel.contains('*');

    final sanitizedField =
        localizedLabel.replaceAll('*', '').replaceAll(':', '').trim();
    final fieldForMessage =
        sanitizedField.isEmpty ? localizedLabel : sanitizedField;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        autovalidateMode: AutovalidateMode.disabled,
        onChanged: (value) {
          _resetFieldError(field);
          onChanged?.call(value);
        },
        validator: (value) {
          if (!(_fieldValidationVisibility[field] ?? false)) {
            return null;
          }
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return translateText('{field} is required',
                params: {'field': fieldForMessage});
          }
          return null;
        },
        decoration: InputDecoration(
          counterText: '',
          // ⬇️ use `label:` so we can color the star red
          label: _requiredLabel(localizedLabel, required: isRequired),
          hintText: localizedHint,
          labelStyle: const TextStyle(color: AppColors.darkGrey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.darkGrey, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
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
          errorStyle: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _requiredLabel(String text, {bool required = true}) {
    final t = translateText(text).replaceAll('*', '').trim(); // keep clean text
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.darkGrey, fontSize: 16),
        children: [
          TextSpan(text: t),
          if (required) const TextSpan(text: ' '),
          if (required)
            const TextSpan(
              text: '*',
              style: TextStyle(color: Colors.red),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(
          field: field,
          controller: controller,
          label: label,
          hint: 'Select time',
        ),
      ),
    );
  }
}
