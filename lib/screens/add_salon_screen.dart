import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'add_location_screen.dart';

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

  void _submit(AddSalonState state) {
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

    context.read<AddSalonCubit>().submit(
      AddSalonFormData(
        name: _salonNameController.text.trim(),
        phone: _phoneController.text.trim(),
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddSalonCubit, AddSalonState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.savedPhone != null && _phoneController.text.isEmpty) {
          _phoneController.text = state.savedPhone!;
        }

        if (state.status == AddSalonStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }

        if (state.status == AddSalonStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salon added successfully')),
          );
          Navigator.pop(context, true);
        }
      },
      builder: (context, state) {
        final images = state.images;
        final address = state.address;

        return Scaffold(
          appBar: AppBar(title: const Text('Add Salon')),
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
                        label: 'Salon Name *',
                        hint: 'Enter your salon name',
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number *',
                        hint: 'Enter phone number',
                        enabled: false,
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
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description *',
                        hint: 'Enter a description about your salon',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Salon Address',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _chooseLocation(state),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: address == null
                              ? const Text('Tap to select salon location')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address.buildingName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${address.city}, ${address.state}'),
                                    Text('Pincode: ${address.pincode}'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Salon Images',
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
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.orange,
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
                            backgroundColor: Colors.orange,
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
                              : const Text('+ Add Salon'),
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
                    child: CircularProgressIndicator(color: Colors.orange),
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
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
