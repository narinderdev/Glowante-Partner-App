// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/services.dart';
// import '../utils/colors.dart';
// import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';
// import '../utils/api_service.dart';
// import 'bottom_nav.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
// import 'dart:io';

// class AddSalonServices extends StatefulWidget {
//   const AddSalonServices({
//     super.key,
//     this.initialCodes = const <String>[],
//     this.formData, // ✅ for salon flow
//     this.branchFormData, // ✅ for branch flow
//     this.branchAddress,
//     this.branchImages = const [],
//      this.salonId,
//   });

//   final AddSalonFormData? formData; // ✅ Keep this for salon
//   final AddBranchFormData? branchFormData;
//   final BranchAddress? branchAddress;
//   final List<File> branchImages;
//   final List<String> initialCodes;
//    final int? salonId;

//   @override
//   State<AddSalonServices> createState() => _AddSalonServicesState();
// }

// class _AddSalonServicesState extends State<AddSalonServices> {
//   List<dynamic> _services = <dynamic>[];
//   late List<String> _selectedCodes;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _selectedCodes = List<String>.from(widget.initialCodes);
//     fetchServiceCatalog();
//   }

// Future<void> fetchServiceCatalog() async {
//   try {
//     final token = await ApiService().getAuthToken();
//     final url = Uri.parse('${ApiService.baseUrl}${ApiService.serviceCatalog}');

//     final response = await http.get(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token',
//       },
//     );

//     if (response.statusCode == 200) {
//       final body = jsonDecode(response.body) as Map<String, dynamic>;
//       final data = (body['data'] as List<dynamic>?) ?? <dynamic>[];

//       // ✅ Pre-cache images before building UI (for smooth scroll)
//       for (final service in data) {
//         final imageUrl = (service['image_url'] ?? '') as String;
//         if (imageUrl.isNotEmpty && mounted) {
//           // Precache with small delay to avoid blocking UI thread
//           precacheImage(CachedNetworkImageProvider(imageUrl), context);
//         }
//       }

//       setState(() {
//         _services = data;
//         _isLoading = false;
//       });
//     } else {
//       throw Exception('Failed to fetch service catalog: ${response.body}');
//     }
//   } catch (e, stack) {
//     debugPrint('Failed to load service catalog: $e');
//     debugPrintStack(stackTrace: stack);
//     if (mounted) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Unable to load services: $e')),
//       );
//     }
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     return BlocConsumer<AddSalonCubit, AddSalonState>(
//       listenWhen: (previous, current) => previous.status != current.status,
//       listener: (context, state) {
//         if (state.status == AddSalonStatus.failure &&
//             state.errorMessage != null) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(state.errorMessage!)),
//           );
//         }

//         if (state.status == AddSalonStatus.success) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(translateText('Salon added successfully'))),
//           );
//           Future.microtask(() => context.read<AddSalonCubit>().resetStatus());
//           Navigator.of(context).pushAndRemoveUntil(
//             MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
//             (route) => false,
//           );
//         }
//       },
//       builder: (context, state) {
//         final isSubmitting = state.status == AddSalonStatus.submitting;
//         return Scaffold(
//           backgroundColor: Colors.white,
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             systemOverlayStyle: SystemUiOverlayStyle.light,
//             iconTheme: const IconThemeData(color: Colors.white),
//             title: Text(
//               translateText('Select Services'),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
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
//           body: _isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       Text(
//                         translateText(
//                           'Choose the services that best describe your salon.\nYou can select multiple options.',
//                         ),
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey,
//                             fontWeight: FontWeight.w500),
//                       ),
//                       const SizedBox(height: 24),
//                       Expanded(
//                         child: GridView.builder(
//                           gridDelegate:
//                               const SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: 3,
//                             childAspectRatio: 0.9,
//                             crossAxisSpacing: 16,
//                             mainAxisSpacing: 16,
//                           ),
//                           itemCount: _services.length,
//                           itemBuilder: (context, index) {
//                             final service =
//                                 _services[index] as Map<String, dynamic>;
//                             final name = (service['name'] ?? '') as String;
//                             final imageUrl =
//                                 (service['image_url'] ?? '') as String;
//                             final code = (service['code'] ?? '') as String;
//                             final isSelected = _selectedCodes.contains(code);

//                             return GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   if (isSelected) {
//                                     _selectedCodes.remove(code);
//                                   } else {
//                                     _selectedCodes.add(code);
//                                   }
//                                 });
//                               },
//                               child: Column(
//                                 children: [
//                                   Stack(
//                                     alignment: Alignment.center,
//                                     children: [
//                                       Container(
//                                         width: 75,
//                                         height: 75,
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//                                           border: Border.all(
//                                             color: isSelected
//                                                 ? AppColors.starColor
//                                                 : Colors.transparent,
//                                             width: 3,
//                                           ),
//                                           boxShadow: const [
//                                             BoxShadow(
//                                               color: Colors.black12,
//                                               blurRadius: 6,
//                                             ),
//                                           ],
//                                         ),
//                                         // child: ClipOval(
//                                         //   child: imageUrl.isEmpty
//                                         //       ? const Icon(
//                                         //           Icons.image_not_supported)
//                                         //       : Image.network(
//                                         //           imageUrl,
//                                         //           fit: BoxFit.cover,
//                                         //           errorBuilder: (context, error,
//                                         //                   stackTrace) =>
//                                         //               const Icon(Icons
//                                         //                   .image_not_supported),
//                                         //         ),
//                                         // ),
//                                   child: ClipOval(
//   child: imageUrl.isEmpty
//       ? const Icon(Icons.image_not_supported)
//       : CachedNetworkImage(
//           imageUrl: imageUrl,
//           fit: BoxFit.cover,
//           fadeInDuration: const Duration(milliseconds: 300),
//           memCacheWidth: 200, // ✅ reduce memory footprint for thumbnails
//           memCacheHeight: 200,
//           placeholder: (context, url) => const Center(
//             child: SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(strokeWidth: 1.8),
//             ),
//           ),
//           errorWidget: (context, url, error) =>
//               const Icon(Icons.image_not_supported),
//         ),
// ),

//                                       ),

//                                       /// ✅ Tick overlay when selected
//                                       if (isSelected)
//                                         Container(
//                                           width: 75,
//                                           height: 75,
//                                           decoration: BoxDecoration(
//                                             color:
//                                                 Colors.black.withOpacity(0.35),
//                                             shape: BoxShape.circle,
//                                           ),
//                                           child: const Icon(
//                                             Icons.check_circle,
//                                             color: Colors.white,
//                                             size: 32,
//                                           ),
//                                         ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     name,
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(
//                                       fontSize: 10,
//                                       fontWeight: FontWeight.w500,
//                                       color: isSelected
//                                           ? Colors.black
//                                           : Colors.grey[700],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                       const SizedBox(height: 10),

//                       /// 🔹 Full-width curved button with simple loader
//                       SizedBox(
//                         width: double.infinity,
//                         height: 52,
//                         child: ElevatedButton(
//                           onPressed: _selectedCodes.isEmpty || isSubmitting
//                               ? null
//                               : () => _submitSelection(context),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.starColor,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             elevation: 3,
//                           ),
//                           child: AnimatedSwitcher(
//                             duration: const Duration(milliseconds: 300),
//                             transitionBuilder: (child, animation) =>
//                                 FadeTransition(
//                               opacity: animation,
//                               child: child,
//                             ),
//                             child: isSubmitting
//                                 ? const SizedBox(
//                                     key: ValueKey('loader'),
//                                     width: 22,
//                                     height: 22,
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 2.5,
//                                       color: Colors.white,
//                                     ),
//                                   )
//                                 : Text(
//                                     translateText('Submit'),
//                                     key: const ValueKey('text'),
//                                     style: const TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 16),
//                     ],
//                   ),
//                 ),
//         );
//       },
//     );
//   }

//   // Future<void> _submitSelection(BuildContext context) async {
//   //   if (_selectedCodes.isEmpty) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text(
//   //           translateText('Please select at least one service.'),
//   //         ),
//   //       ),
//   //     );
//   //     return;
//   //   }

//   //   FocusScope.of(context).unfocus();
//   //   final cubit = context.read<AddSalonCubit>();
//   //   cubit.updateSelectedServiceCodes(List<String>.from(_selectedCodes));
//   //   await cubit.submit(widget.formData);
//   // }
//  Future<void> _submitSelection(BuildContext context) async {
//   if (_selectedCodes.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(translateText('Please select at least one service.'))),
//     );
//     return;
//   }

//   FocusScope.of(context).unfocus();

//   final salonCubit = context.read<AddSalonCubit>();
//   salonCubit.updateSelectedServiceCodes(List<String>.from(_selectedCodes));

//   // ✅ Branch flow (with passed salonId)
//   if (widget.branchFormData != null && widget.salonId != null) {
//     final branchCubit = context.read<AddBranchCubit>();
//     final branch = widget.branchFormData!;
//     final address = widget.branchAddress!;
//     final images = widget.branchImages;

//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(translateText('Adding branch...'))),
//       );

//       await branchCubit.repository.addBranch(
//         salonId: widget.salonId!,
//         name: branch.name,
//         phone: branch.phone,
//         startTime: branch.startTime,
//         endTime: branch.endTime,
//         description: branch.description,
//         address: address.toJson(),
//         latitude: address.latitude,
//         longitude: address.longitude,
//         images: images,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(translateText('Branch added successfully!'))),
//       );

//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
//         (route) => false,
//       );
//     } catch (e) {
//       debugPrint('❌ Failed to add branch: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(translateText('Failed to add branch: $e'))),
//       );
//     }

//     return;
//   }

//   // ✅ Salon flow (no change)
//   if (widget.formData != null) {
//     await salonCubit.submit(widget.formData!);
//   }
// }

// }

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/colors.dart';
import '../utils/api_service.dart';
import '../utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../widgets/salon_flow_step_header.dart';
import 'bottom_nav.dart';

import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';

class AddSalonServices extends StatefulWidget {
  const AddSalonServices({
    super.key,
    this.initialCodes = const <String>[],
    this.formData, // for salon flow
    this.branchFormData, // for branch flow
    this.branchAddress,
    this.branchImages = const [],
    this.salonId,
    this.branchImageUrl,
    this.sourceBranches = const <Map<String, dynamic>>[],
    this.initialSourceBranchId,
    this.onSubmit,
    this.submitLabel = 'Submit',
  });

  final AddSalonFormData? formData;
  final AddBranchFormData? branchFormData;
  final BranchAddress? branchAddress;
  final List<File> branchImages;
  final List<String> initialCodes;
  final int? salonId;
  final String? branchImageUrl;
  final List<Map<String, dynamic>> sourceBranches;
  final int? initialSourceBranchId;
  final Future<void> Function(List<String> selectedCodes, int? sourceBranchId)?
      onSubmit;
  final String submitLabel;

  @override
  State<AddSalonServices> createState() => _AddSalonServicesState();
}

class _AddSalonServicesState extends State<AddSalonServices> {
  List<dynamic> _services = <dynamic>[];
  late List<String> _selectedCodes;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final Map<String, ImageProvider> _imageProviders = {};
  int? _selectedSourceBranchId;

  @override
  void initState() {
    super.initState();
    _selectedCodes = List<String>.from(widget.initialCodes);
    _selectedSourceBranchId = widget.initialSourceBranchId;
    fetchServiceCatalog();
  }

  Future<void> fetchServiceCatalog() async {
    try {
      final token = await ApiService().getAuthToken();
      final url =
          Uri.parse('${ApiService.baseUrl}${ApiService.serviceCatalog}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? <dynamic>[];

        final Map<String, ImageProvider> providers = {};
        for (final service in data) {
          final imageUrl = (service['image_url'] ?? '') as String;
          if (imageUrl.isEmpty) continue;
          providers.putIfAbsent(
            imageUrl,
            () => CachedNetworkImageProvider(imageUrl),
          );
        }

        if (!mounted) return;
        setState(() {
          _services = data;
          _imageProviders.addAll(providers);
          _isLoading = false;
        });

        for (final provider in providers.values) {
          if (mounted) {
            precacheImage(provider, context);
          }
        }
      } else {
        throw Exception('Failed to fetch service catalog: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('Failed to load service catalog: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load services: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool copyServicesSelected =
        widget.branchFormData != null && _selectedSourceBranchId != null;
    return BlocConsumer<AddSalonCubit, AddSalonState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AddSalonStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }

        if (state.status == AddSalonStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateText('Salon added successfully'))),
          );
          Future.microtask(() => context.read<AddSalonCubit>().resetStatus());
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: buildProfileSubpageAppBar(
            title: translateText('Select Services'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SalonFlowStepHeader(
                          currentStep: 3,
                          detailsLabel: translateText(
                            widget.branchFormData != null
                                ? 'Branch Details'
                                : 'Salon Details',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          translateText(
                            'Choose the services that best describe your salon.\nYou can select multiple options.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.branchFormData != null &&
                            widget.sourceBranches.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              translateText(
                                'Copy services from an existing branch',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: widget.sourceBranches.map((branch) {
                              final branchId = (branch['id'] as num?)?.toInt();
                              final isSelected = branchId != null &&
                                  branchId == _selectedSourceBranchId;
                              final branchName =
                                  (branch['name'] ?? '').toString().trim();
                              return ChoiceChip(
                                label: Text(
                                  branchName.isEmpty
                                      ? translateText('Unnamed Branch')
                                      : branchName,
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFFDE7C3),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.starColor
                                      : const Color(0xFFD1D5DB),
                                ),
                                onSelected: branchId == null
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _selectedSourceBranchId =
                                              selected ? branchId : null;
                                          if (selected) {
                                            _selectedCodes.clear();
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        AbsorbPointer(
                          absorbing: copyServicesSelected,
                          child: Opacity(
                            opacity: copyServicesSelected ? 0.45 : 1,
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _services.length,
                              itemBuilder: (context, index) {
                                final service =
                                    _services[index] as Map<String, dynamic>;
                                final name = (service['name'] ?? '') as String;
                                final imageUrl =
                                    (service['image_url'] ?? '') as String;
                                final code = (service['code'] ?? '') as String;
                                final isSelected =
                                    _selectedCodes.contains(code);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedCodes.remove(code);
                                      } else {
                                        _selectedCodes.add(code);
                                      }
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 75,
                                            height: 75,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.starColor
                                                    : Colors.transparent,
                                                width: 3,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: imageUrl.isEmpty
                                                  ? const Icon(
                                                      Icons.image_not_supported)
                                                  : Image(
                                                      image: _imageProviders
                                                          .putIfAbsent(
                                                        imageUrl,
                                                        () =>
                                                            CachedNetworkImageProvider(
                                                                imageUrl),
                                                      ),
                                                      fit: BoxFit.cover,
                                                      gaplessPlayback: true,
                                                      filterQuality:
                                                          FilterQuality.high,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Container(
                                              width: 75,
                                              height: 75,
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.35),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide.none,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  foregroundColor: const Color(0xFF374151),
                                ),
                                child: Text(translateText('Back')),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _submitSelection(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.starColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            key: ValueKey('loader'),
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            translateText(widget.submitLabel),
                                            key: const ValueKey('text'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _submitSelection(BuildContext context) async {
    final copyServicesSelected =
        widget.branchFormData != null && _selectedSourceBranchId != null;
    if (!copyServicesSelected && _selectedCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(translateText('Please select at least one service.'))),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    final salonCubit = context.read<AddSalonCubit>();
    salonCubit.updateSelectedServiceCodes(List<String>.from(_selectedCodes));

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(
          List<String>.from(_selectedCodes),
          _selectedSourceBranchId,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      // ✅ Branch Flow
      if (widget.branchFormData != null && widget.salonId != null) {
        final branchCubit = context.read<AddBranchCubit>();
        final branch = widget.branchFormData!;
        final address = widget.branchAddress!;
        final images = widget.branchImages;

        await branchCubit.repository.addBranch(
          salonId: widget.salonId!,
          name: branch.name,
          phone: branch.phone,
          startTime: branch.startTime,
          endTime: branch.endTime,
          description: branch.description,
          schedule: branch.schedule,
          address: address.toJson(),
          latitude: address.latitude,
          longitude: address.longitude,
          images: images,
          imageUrl: branch.imageUrl ?? widget.branchImageUrl,
          selectedCategoryCodes: _selectedCodes, // ✅ FIXED
          sourceBranchId: _selectedSourceBranchId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateText('Branch added successfully!'))),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
          (route) => false,
        );
        return;
      }

      // ✅ Salon Flow (unchanged)
      if (widget.formData != null) {
        await salonCubit.submit(widget.formData!);
      }
    } catch (e) {
      debugPrint('❌ Failed to add branch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateText('Failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
