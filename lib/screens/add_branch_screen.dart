import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'add_location_screen.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _selectTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      controller.text = picked.format(context);
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

  void _submit(AddBranchState state) {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end time.')),
      );
      return;
    }

    context.read<AddBranchCubit>().submit(
      AddBranchFormData(
        name: _branchNameController.text.trim(),
        phone: _phoneController.text.trim(),
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddBranchCubit, AddBranchState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.savedPhone != null) {
          _phoneController.text = state.savedPhone!;
        }

        if (state.status == BranchFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }

        if (state.status == BranchFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch added successfully')),
          );
          Navigator.pop(context, true);
        }
      },
      builder: (context, state) {
        final images = state.images;
        final address = state.address;

        return Scaffold(
          backgroundColor: AppColors.white,
         appBar: AppBar(
    backgroundColor: AppColors.grey, // AppBar background
    // centerTitle: true, // center the title
    iconTheme: const IconThemeData(
      color: AppColors.black, // back button color
    ),
    title: const Text(
      'Add Branch',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: AppColors.black, // title text color
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
                        controller: _branchNameController,
                        label: 'Branch Name *',
                        hint: 'Enter branch name',
                      ),
               _buildTextField(
  controller: _phoneController,
  label: 'Phone Number *',
  hint: 'Enter phone number',
  maxLength: 10,
  enabled: false,
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimePickerField(
                              controller: _endTimeController,
                              label: 'End Time *',
                              onTap: () => _selectTime(_endTimeController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                Text(
  'Branch Address',
  style: Theme.of(context).textTheme.titleMedium,
),
const SizedBox(height: 8),
// ✅ Case: No address -> show bordered box with "Add Location"
if (address == null)
  InkWell(
    onTap: () => _chooseLocation(state),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.darkGrey, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          "Add Location",
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.buildingName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${address.city}, ${address.state}'),
                Text('Pincode: ${address.pincode}'),
              ],
            ),
          ),
          const Icon(Icons.edit, color: AppColors.darkGrey),
        ],
      ),
    ),
  ),

                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description *',
                        hint: 'Enter description',
                        maxLines: 1,
                      ),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Branch Images(Optional)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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
                              child: const Icon(
                                Icons.add,
                                color:  AppColors.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: state.isSubmitting
                              ? null
                              : () => _submit(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black,
                            foregroundColor: AppColors.white,
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
                              : const Text('Add Branch'),
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
  required TextEditingController controller,
  required String label,
  required String hint,
  int maxLines = 1,
  int? maxLength, // ✅ allow passing maxLength
  bool enabled = true,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters, // ✅ optional
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength, // ✅ applied here
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.sentences,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: "", // ✅ hides the default counter if you don’t want it
        labelStyle: const TextStyle(color: AppColors.darkGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
        errorStyle: const TextStyle(
          color: Colors.red,
          // fontWeight: FontWeight.bold,
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
