// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';
// import '../utils/colors.dart';
// import '../services/language_listener.dart';
// import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
// import 'add_location_screen.dart';
// import 'package:flutter/services.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';
// import '../utils/colors.dart';
// import 'AddSalonServices.dart';
// import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
// import 'package:bloc_onboarding/repositories/salon_repository.dart';

// enum _BranchField { name, phone, startTime, endTime, description }

// class _FirstLetterUpperFormatter extends TextInputFormatter {
//   const _FirstLetterUpperFormatter();

//   @override
//   TextEditingValue formatEditUpdate(
//     TextEditingValue oldValue,
//     TextEditingValue newValue,
//   ) {
//     final text = newValue.text;
//     if (text.isEmpty) return newValue;

//     final regExp = RegExp(r'[A-Za-z]');
//     final match = regExp.firstMatch(text);
//     if (match == null) return newValue;

//     final index = match.start;
//     final upper = text[index].toUpperCase();
//     if (text[index] == upper) return newValue;

//     final updated = text.replaceRange(index, index + 1, upper);
//     return newValue.copyWith(text: updated);
//   }
// }

// class AddBranchScreen extends StatefulWidget {
//   const AddBranchScreen({super.key, required this.salonId});

//   final int salonId;

//   @override
//   State<AddBranchScreen> createState() => _AddBranchScreenState();
// }

// class _AddBranchScreenState extends State<AddBranchScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _branchNameController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _startTimeController = TextEditingController();
//   final _endTimeController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final ImagePicker _picker = ImagePicker();
//   bool _submitted = false;
//   final Map<_BranchField, bool> _fieldValidationVisibility = {
//     for (final field in _BranchField.values) field: false,

//   };

//   @override
//   void initState() {
//     super.initState();
//       _startTimeController.text = "08:00 AM";
//   _endTimeController.text = "08:00 PM";
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<AddBranchCubit>().loadSavedPhone();
//     });
//   }

//   @override
//   void dispose() {
//     _branchNameController.dispose();
//     _phoneController.dispose();
//     _startTimeController.dispose();
//     _endTimeController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }

//   Future<void> _pickImages() async {
//     final files = await _picker.pickMultiImage();
//     if (!mounted || files == null) return;
//     final images = files.map((file) => File(file.path)).toList();
//     context.read<AddBranchCubit>().setImages(images);
//   }

//   void _resetFieldError(_BranchField field) {
//     if (!mounted) {
//       return;
//     }
//     if (!(_fieldValidationVisibility[field] ?? false)) {
//       return;
//     }
//     setState(() {
//       _fieldValidationVisibility[field] = false;
//     });
//     _formKey.currentState?.validate();
//   }

//   Future<void> _selectTime(
//   _BranchField field,
//   TextEditingController controller,
// ) async {
//   // ⏰ Determine default time (based on field)
//   final defaultTime = field == _BranchField.startTime
//       ? const TimeOfDay(hour: 8, minute: 0)
//       : const TimeOfDay(hour: 20, minute: 0);

//   final picked = await showTimePicker(
//     context: context,
//     initialTime: defaultTime, // ✅ start with 8:00 or 20:00
//   );

//   if (picked != null) {
//     controller.text = picked.format(context);
//     _resetFieldError(field);
//   }
// }

//   Future<void> _chooseLocation(AddBranchState state) async {
//     final result = await Navigator.push<Map<String, dynamic>?>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddLocationScreen(
//           buildingName: state.address?.buildingName ?? '',
//           city: state.address?.city ?? '',
//           pincode: state.address?.pincode ?? '',
//           state: state.address?.state ?? '',
//         ),
//       ),
//     );

//     if (!mounted || result == null) return;
//     context.read<AddBranchCubit>().updateAddress(
//           BranchAddress(
//             buildingName: result['buildingName'] as String? ?? '',
//             city: result['city'] as String? ?? '',
//             pincode: result['pincode'] as String? ?? '',
//             state: result['state'] as String? ?? '',
//             latitude: (result['latitude'] as num?)?.toDouble() ?? 0,
//             longitude: (result['longitude'] as num?)?.toDouble() ?? 0,
//           ),
//         );
//   }

//   // void _submit(AddBranchState state) {
//   //   final form = _formKey.currentState;
//   //   if (form == null) {
//   //     return;
//   //   }

//   //   setState(() {
//   //     for (final key in _fieldValidationVisibility.keys) {
//   //       _fieldValidationVisibility[key] = true;
//   //     }
//   //   });

//   //   final isValid = form.validate();
//   //   if (!isValid) {
//   //     return;
//   //   }

//   //   if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //           content: Text(translateText('Please select start and end time.'))),
//   //     );
//   //     return;
//   //   }

//   //   context.read<AddBranchCubit>().submit(
//   //         AddBranchFormData(
//   //           name: _branchNameController.text.trim(),
//   //           phone: _phoneController.text.trim(),
//   //           startTime: _startTimeController.text.trim(),
//   //           endTime: _endTimeController.text.trim(),
//   //           description: _descriptionController.text.trim(),
//   //         ),
//   //       );
//   // }
// void _submit(AddBranchState state) {
//     setState(() => _submitted = true);
//   final form = _formKey.currentState;
//   if (form == null) return;

//   setState(() {
//     for (final key in _fieldValidationVisibility.keys) {
//       _fieldValidationVisibility[key] = true;
//     }
//   });

//   final isValid = form.validate();
//   if (!isValid) return;

//   if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(translateText('Please select start and end time.')),
//       ),
//     );
//     return;
//   }

//   if (state.address == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(translateText('Please choose a branch location.')),
//       ),
//     );
//     return;
//   }

//   // ✅ Create the form data object
//   final branchFormData = AddBranchFormData(
//     name: _branchNameController.text.trim(),
//     phone: _phoneController.text.trim(),
//     startTime: _startTimeController.text.trim(),
//     endTime: _endTimeController.text.trim(),
//     description: _descriptionController.text.trim(),
//   );

//   // ✅ Navigate to AddSalonServices instead of calling API
//  Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (_) => MultiBlocProvider(
//       providers: [
//         BlocProvider(
//           create: (_) => AddSalonCubit(SalonRepository()),
//         ),
//         BlocProvider.value(
//           value: context.read<AddBranchCubit>(),
//         ),
//       ],
//       child: AddSalonServices(
//         branchFormData: branchFormData,
//         branchAddress: state.address!,
//         branchImages: state.images,
//          salonId: widget.salonId,
//       ),
//     ),
//   ),
// );
// }

//   @override
//   Widget build(BuildContext context) {
//     context.watch<LanguageListener>();
//     return BlocConsumer<AddBranchCubit, AddBranchState>(
//       listenWhen: (previous, current) => previous.status != current.status,
//       listener: (context, state) {
//         if (state.savedPhone != null) {
//           _phoneController.text = state.savedPhone!;
//           _resetFieldError(_BranchField.phone);
//         }

//         if (state.status == BranchFormStatus.failure &&
//             state.errorMessage != null) {
//           ScaffoldMessenger.of(
//             context,
//           ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
//         }

//         if (state.status == BranchFormStatus.success) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(translateText('Branch added successfully'))),
//           );
//           Navigator.pop(context, true);
//         }
//       },
//       builder: (context, state) {
//         final images = state.images;
//         final address = state.address;

//         return Scaffold(
//           backgroundColor: Colors.white,
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             systemOverlayStyle: SystemUiOverlayStyle.light,
//             iconTheme: const IconThemeData(color: Colors.white),
//             title: Text(
//               translateText('Add Branch'),
//               style: const TextStyle(
//                   color: Colors.white, fontWeight: FontWeight.bold),
//             ),
//             flexibleSpace: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.starColor,
//                     AppColors.getStartedButton,
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//           ),
//           body: Stack(
//             children: [
//               SingleChildScrollView(
//                 padding: const EdgeInsets.all(16),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                     _buildTextField(
//   field: _BranchField.name,
//   controller: _branchNameController,
//   label: 'Branch Name *',
//   hint: 'Enter branch name',
//   keyboardType: TextInputType.text,
//   textCapitalization: TextCapitalization.sentences,
//   maxLength: 30, // ✅ required for counter
//   inputFormatters: const [_FirstLetterUpperFormatter()],
// ),

//                       _buildTextField(
//                         field: _BranchField.phone,
//                         controller: _phoneController,
//                         label: 'Phone Number *',
//                         hint: 'Enter phone number',
//                         maxLength: 10,
//                         enabled: false,
//                         keyboardType: TextInputType.number,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly,
//                         ],
//                       ),
//      IntrinsicHeight(
//   child: Row(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Expanded(
//         child: Column(
//           children: [
//             _buildTimePickerField(
//               field: _BranchField.startTime,
//               controller: _startTimeController,
//               label: 'Start Time *',
//               onTap: () => _selectTime(
//                 _BranchField.startTime,
//                 _startTimeController,
//               ),
//             ),
//           ],
//         ),
//       ),
//       SizedBox(width: 12),
//       Expanded(
//         child: Column(
//           children: [
//             _buildTimePickerField(
//               field: _BranchField.endTime,
//               controller: _endTimeController,
//               label: 'End Time *',
//               onTap: () => _selectTime(
//                 _BranchField.endTime,
//                 _endTimeController,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ],
//   ),
// ),
//                       SizedBox(height: 20),
//                       Text(
//                         translateText('Branch Address'),
//                         style: Theme.of(context).textTheme.titleMedium,
//                       ),
//                       SizedBox(height: 8),
// // ✅ Case: No address -> show bordered box with "Add Location"
//                       if (address == null)
//                         InkWell(
//                           onTap: () => _chooseLocation(state),
//                           child: Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.symmetric(
//                                 vertical: 16, horizontal: 12),
//                             decoration: BoxDecoration(
//                               border: Border.all(
//                                   color: AppColors.darkGrey, width: 1),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Center(
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Text(
//                                     translateText("Add Location"),
//                                     style: const TextStyle(
//                                       color: AppColors.black,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 4),
//                                   const Text(
//                                     '*',
//                                     style: TextStyle(
//                                         color: Colors.red,
//                                         fontWeight: FontWeight.bold),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         )
//                       else
//                         // ✅ Case: Address exists -> your existing design
//                         InkWell(
//                           onTap: () => _chooseLocation(state),
//                           child: Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: AppColors.darkGrey),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         address.buildingName,
//                                         style: const TextStyle(
//                                             fontWeight: FontWeight.bold),
//                                       ),
//                                       SizedBox(height: 4),
//                                       Text('${address.city}, ${address.state}'),
//                                       Text('Pincode: ${address.pincode}'),
//                                     ],
//                                   ),
//                                 ),
//                                 Icon(Icons.edit, color: AppColors.darkGrey),
//                               ],
//                             ),
//                           ),
//                         ),

//                       SizedBox(height: 20),
//                       _buildTextField(
//                         field: _BranchField.description,
//                         controller: _descriptionController,
//                         label: 'Description *',
//                         hint: 'Enter description',
//                         maxLines: 1,
//                         maxLength: 50,
//                        keyboardType: TextInputType.text,
//   textCapitalization: TextCapitalization.sentences,
//                         inputFormatters: const [_FirstLetterUpperFormatter()],
//                       ),

//                       SizedBox(height: 20),
//                       Text(
//                         translateText('Branch Images(Optional)'),
//                         style: Theme.of(context).textTheme.titleMedium,
//                       ),
//                       SizedBox(height: 8),
//                       Wrap(
//                         spacing: 8,
//                         runSpacing: 8,
//                         children: [
//                           for (final image in images)
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.file(
//                                 image,
//                                 width: 80,
//                                 height: 80,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                           GestureDetector(
//                             onTap: _pickImages,
//                             child: Container(
//                               width: 80,
//                               height: 80,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: AppColors.darkGrey),
//                               ),
//                               child: Icon(
//                                 Icons.add,
//                                 color: AppColors.darkGrey,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 32),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 48,
//                         child: ElevatedButton(
//                           onPressed:
//                               state.isSubmitting ? null : () => _submit(state),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.starColor,
//                             foregroundColor: AppColors.white,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                           ),
//                           child: state.isSubmitting
//                               ? SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     color: Colors.white,
//                                   ),
//                                 )
//                               : Text(translateText('Next')),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               if (state.status == BranchFormStatus.loading)
//                 const ColoredBox(
//                   color: Colors.black54,
//                   child: Center(
//                     child: CircularProgressIndicator(color: Colors.white),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//   Widget _buildTextField({
//     required _BranchField field,
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     int maxLines = 1,
//     int? maxLength,
//     bool enabled = true,
//     TextCapitalization textCapitalization = TextCapitalization.sentences,
//     TextInputType keyboardType = TextInputType.text,
//     List<TextInputFormatter>? inputFormatters,
//     ValueChanged<String>? onChanged,
//   }) {
//     final localizedLabel = translateText(label);
//     final localizedHint = translateText(hint);

//     // if label has '*', we show red star and also require validation
//     final isRequired = localizedLabel.contains('*');

//     final sanitizedField =
//         localizedLabel.replaceAll('*', '').replaceAll(':', '').trim();
//     final fieldForMessage =
//         sanitizedField.isEmpty ? localizedLabel : sanitizedField;
// controller.addListener(() {
//   setState(() {}); // ✅ Always rebuild on typing
// });

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       child: TextFormField(
//         controller: controller,
//         maxLines: maxLines,
//         maxLength: maxLength,
//         enabled: enabled,
//         keyboardType: keyboardType,
//         inputFormatters: inputFormatters,
//         textCapitalization: textCapitalization,
//      autovalidateMode: _submitted
//           ? AutovalidateMode.always
//           : AutovalidateMode.disabled,
//         onChanged: (value) {
//           _resetFieldError(field);
//           onChanged?.call(value);
//         },
//         validator: (value) {
//           if (!(_fieldValidationVisibility[field] ?? false)) {
//             return null;
//           }
//           if (isRequired && (value == null || value.trim().isEmpty)) {
//             return translateText('{field} is required',
//                 params: {'field': fieldForMessage});
//           }
//           return null;
//         },
//        decoration: InputDecoration(
//   // ✅ Inline counter (optional: remove counterText if using suffix)
// counterText: '',
//   // ✅ Inline character counter inside the field (shows bottom-right)
//   suffixIcon: (maxLength != null)
//     ? Padding(
//         padding: const EdgeInsets.only(right: 10, top: 14),
//         child: Text(
//           '${controller.text.length}/$maxLength',
//           style: TextStyle(
//             fontSize: 12,
//             color: controller.text.length >= (maxLength ?? 0)
//                 ? Colors.red
//                 : Colors.grey,
//           ),
//         ),
//       )
//     : null,

//   // ✅ Label with required star
//   label: _requiredLabel(localizedLabel, required: isRequired),

//   hintText: localizedHint,
//   labelStyle: const TextStyle(color: AppColors.darkGrey),

//   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//   focusedBorder: OutlineInputBorder(
//     borderSide: const BorderSide(color: AppColors.darkGrey, width: 2),
//     borderRadius: BorderRadius.circular(8),
//   ),
//   enabledBorder: OutlineInputBorder(
//     borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//     borderRadius: BorderRadius.circular(8),
//   ),
//   errorBorder: OutlineInputBorder(
//     borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//     borderRadius: BorderRadius.circular(8),
//   ),
//   focusedErrorBorder: OutlineInputBorder(
//     borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//     borderRadius: BorderRadius.circular(8),
//   ),

//   // ✅ Clean, readable error text
//   errorStyle: const TextStyle(
//     color: Colors.red,
//     fontSize: 13,
//   ),
// ),

//       ),
//     );
//   }

//   Widget _requiredLabel(String text, {bool required = true}) {
//     final t = translateText(text).replaceAll('*', '').trim(); // keep clean text
//     return RichText(
//       text: TextSpan(
//         style: const TextStyle(color: AppColors.darkGrey, fontSize: 16),
//         children: [
//           TextSpan(text: t),
//           if (required) const TextSpan(text: ' '),
//           if (required)
//             const TextSpan(
//               text: '*',
//               style: TextStyle(color: Colors.red),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTimePickerField({
//     required _BranchField field,
//     required TextEditingController controller,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: _buildTextField(
//           field: field,
//           controller: controller,
//           label: label,
//           hint: 'Select time',
//         ),
//       ),
//     );
//   }
// }
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
  bool _isNextLoading = false;
  List<Map<String, dynamic>> _sourceBranches = const [];
  String? _existingImageUrl;
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

    if (rawSchedule is Map) {
      for (final entry in rawSchedule.entries) {
        final day = entry.key.toString().toLowerCase();
        final slots = entry.value;
        if (slots is! List) continue;
        result[day] = slots
            .whereType<Map>()
            .map((slot) => <String, String>{
                  'startTime':
                      _firstNonEmptyValue([slot['startTime'], slot['start']]),
                  'endTime':
                      _firstNonEmptyValue([slot['endTime'], slot['end']]),
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
                  'startTime':
                      _firstNonEmptyValue([slot['startTime'], slot['start']]),
                  'endTime':
                      _firstNonEmptyValue([slot['endTime'], slot['end']]),
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
      buildingName: completeAddress.join(', '),
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
      _branchNameController.text =
          (initialBranch['name'] ?? '').toString().trim();
      _phoneController.text = _normalizePhone(
        _firstNonEmptyValue([
          initialBranch['phone'],
          initialBranch['phoneNumber'],
          initialBranch['contactNumber'],
        ]),
      );
      _descriptionController.text =
          (initialBranch['description'] ?? '').toString().trim();
      final startTime = _firstNonEmptyValue([initialBranch['startTime']]);
      final endTime = _firstNonEmptyValue([initialBranch['endTime']]);
      if (startTime.isNotEmpty) {
        _startTimeController.text = startTime;
      }
      if (endTime.isNotEmpty) {
        _endTimeController.text = endTime;
      }
      final imageUrl = (initialBranch['imageUrl'] ?? '').toString().trim();
      if (imageUrl.isNotEmpty) {
        _existingImageUrl = imageUrl;
      }
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
    final files = await _picker.pickMultiImage();
    if (!mounted) return;
    if (files.isEmpty) return;
    final images = files.map((file) => File(file.path)).toList();
    context.read<AddBranchCubit>().setImages(images);
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
    final scoFlatHouse = (result['scoFlatHouse'] as String?)?.trim() ?? '';
    final streetSectorArea =
        (result['streetSectorArea'] as String?)?.trim() ?? '';
    final latitude = (result['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (result['longitude'] as num?)?.toDouble() ?? 0;

    // 🟢 Store completeAddress into buildingName (back-compat with existing model)
    branchCubit.updateAddress(
      BranchAddress(
        buildingName: completeAddress, // complete address here
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

    final images = state.images;
    String? imageUrl = _existingImageUrl;

    if (images.isNotEmpty) {
      setState(() => _isNextLoading = true);
      try {
        final result = await AwsS3Uploader()
            .uploadImageResult(XFile(images.first.path))
            .timeout(const Duration(seconds: 45), onTimeout: () => null);
        imageUrl = result?.cdnUrl ?? result?.publicUrl;
      } catch (error, stack) {
        debugPrint('❌ Branch image upload failed: $error');
        debugPrintStack(stackTrace: stack);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                translateText(
                    'Unable to upload branch image right now. We will retry on submit.'),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isNextLoading = false);
        }
      }
    }

    if (widget.isEdit && widget.initialBranch != null) {
      final branchId = (widget.initialBranch!['id'] as num?)?.toInt();
      if (branchId == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(translateText('Missing branch id'))),
        );
        return;
      }
      final scheduleResult = await Navigator.push<ScheduleStepResult>(
        context,
        MaterialPageRoute(
          builder: (_) => SetWeeklyScheduleScreen(
            detailsStepLabel: 'Branch Details',
            initialStartTime: _startTimeController.text.trim(),
            initialEndTime: _endTimeController.text.trim(),
            initialSchedule: _extractInitialSchedule(widget.initialBranch),
            totalSteps: 2,
            submitLabel: 'Save',
          ),
        ),
      );
      if (!mounted || scheduleResult == null) return;
      await context.read<AddBranchCubit>().repository.updateBranch(
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
          );

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
      imageUrl: imageUrl,
    );

    if (!mounted) return;

    final scheduleResult = await Navigator.push<ScheduleStepResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SetWeeklyScheduleScreen(
          detailsStepLabel: 'Branch Details',
          initialStartTime: _startTimeController.text.trim(),
          initialEndTime: _endTimeController.text.trim(),
          initialSchedule: const <String, List<Map<String, String>>>{},
          totalSteps: 3,
        ),
      ),
    );
    if (!mounted || scheduleResult == null) return;

    await Navigator.push(
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
            branchFormData: AddBranchFormData(
              name: branchFormData.name,
              phone: branchFormData.phone,
              startTime: scheduleResult.startTime,
              endTime: scheduleResult.endTime,
              description: branchFormData.description,
              schedule: scheduleResult.schedule,
              imageUrl: branchFormData.imageUrl,
            ),
            branchAddress: state.address!,
            branchImages: images,
            salonId: widget.salonId,
            branchImageUrl: imageUrl,
            sourceBranches: _sourceBranches,
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
        if (!widget.isEdit &&
            state.savedPhone != null &&
            _phoneController.text.isEmpty) {
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
          backgroundColor: Colors.white,
          appBar: buildProfileSubpageAppBar(
            title: translateText(widget.isEdit ? 'Edit Branch' : 'Add Branch'),
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
                      SalonFlowStepHeader(
                        currentStep: 1,
                        detailsLabel: translateText('Branch Details'),
                        totalSteps: widget.isEdit ? 2 : 3,
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        field: _BranchField.name,
                        controller: _branchNameController,
                        label: translateText('Branch Name *'),
                        hint: translateText('Enter Branch Name'),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 30,
                        inputFormatters: const [_FirstLetterUpperFormatter()],
                      ),
                      _buildTextField(
                        field: _BranchField.phone,
                        controller: _phoneController,
                        label: translateText('Phone Number *'),
                        hint: translateText('Enter phone number'),
                        maxLength: 10,
                        enabled: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      if (widget.isEdit) ...[
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
                              const SizedBox(width: 12),
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
                        const SizedBox(height: 20),
                      ],
                      Text(
                        translateText('Branch Address'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),

                      // 🟢 If no address, prompt to add
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        // 🟢 If address exists, show the complete address only
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
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkGrey,
                                        ),
                                      ),

// Line 2: Optional fields if present (we stored them in city & pincode)
                                      if (address.city.trim().isNotEmpty ||
                                          address.pincode.trim().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            [
                                              address.city
                                                  .trim(), // SCO / Flat / House
                                              address.pincode
                                                  .trim(), // Street / Sector / Area
                                            ]
                                                .where((s) => s.isNotEmpty)
                                                .join(', '),
                                            style: const TextStyle(
                                                color: AppColors.darkGrey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit,
                                    color: AppColors.darkGrey),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      _buildTextField(
                        field: _BranchField.description,
                        controller: _descriptionController,
                        label: translateText('Description *'),
                        hint: translateText('Enter description'),
                        maxLines: 1,
                        maxLength: 50,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: const [_FirstLetterUpperFormatter()],
                      ),

                      const SizedBox(height: 20),
                      Text(
                        translateText('Branch Images(Optional)'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (images.isEmpty &&
                              (_existingImageUrl?.isNotEmpty ?? false))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _existingImageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
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
                                color: AppColors.darkGrey,
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
                          onPressed: (state.isSubmitting || _isNextLoading)
                              ? null
                              : () => _submit(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.starColor,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: (state.isSubmitting || _isNextLoading)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  translateText(
                                    widget.isEdit ? 'Save' : 'Next',
                                  ),
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
    final isRequired = localizedLabel.contains('*');

    final sanitizedField =
        localizedLabel.replaceAll('*', '').replaceAll(':', '').trim();
    final fieldForMessage =
        sanitizedField.isEmpty ? localizedLabel : sanitizedField;

    controller.addListener(() {
      setState(() {}); // live counter color update
    });

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
        autovalidateMode:
            _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
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
          suffixIcon: (maxLength != null)
              ? Padding(
                  padding: const EdgeInsets.only(right: 10, top: 14),
                  child: Text(
                    '${controller.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: controller.text.length >= maxLength
                          ? Colors.red
                          : Colors.grey,
                    ),
                  ),
                )
              : null,
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
          errorStyle: const TextStyle(
            color: Colors.red,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _requiredLabel(String text, {bool required = true}) {
    final t = translateText(text).replaceAll('*', '').trim();
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
