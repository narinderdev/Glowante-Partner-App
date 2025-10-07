import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/api_service.dart';
import 'bottom_nav.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddSalonServices extends StatefulWidget {
  const AddSalonServices({
    super.key,
    this.initialCodes = const <String>[],
    required this.formData,
  });

  final AddSalonFormData formData;
  final List<String> initialCodes;

  @override
  State<AddSalonServices> createState() => _AddSalonServicesState();
}

class _AddSalonServicesState extends State<AddSalonServices> {
  List<dynamic> _services = <dynamic>[];
  late List<String> _selectedCodes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCodes = List<String>.from(widget.initialCodes);
    fetchServiceCatalog();
  }

  // Future<void> fetchServiceCatalog() async {
  //   try {
  //     final token = await ApiService().getAuthToken();
  //     final url =
  //         Uri.parse('${ApiService.baseUrl}${ApiService.serviceCatalog}');

  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final body = jsonDecode(response.body) as Map<String, dynamic>;
  //       setState(() {
  //         _services = (body['data'] as List<dynamic>?) ?? <dynamic>[];
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
Future<void> fetchServiceCatalog() async {
  try {
    final token = await ApiService().getAuthToken();
    final url = Uri.parse('${ApiService.baseUrl}${ApiService.serviceCatalog}');

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

      // ✅ Pre-cache images before building UI (for smooth scroll)
      for (final service in data) {
        final imageUrl = (service['image_url'] ?? '') as String;
        if (imageUrl.isNotEmpty && mounted) {
          // Precache with small delay to avoid blocking UI thread
          precacheImage(CachedNetworkImageProvider(imageUrl), context);
        }
      }

      setState(() {
        _services = data;
        _isLoading = false;
      });
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
        final isSubmitting = state.status == AddSalonStatus.submitting;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              translateText('Select Services'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        translateText(
                          'Choose the services that best describe your salon.\nYou can select multiple options.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: GridView.builder(
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
                            final isSelected = _selectedCodes.contains(code);

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
                                        // child: ClipOval(
                                        //   child: imageUrl.isEmpty
                                        //       ? const Icon(
                                        //           Icons.image_not_supported)
                                        //       : Image.network(
                                        //           imageUrl,
                                        //           fit: BoxFit.cover,
                                        //           errorBuilder: (context, error,
                                        //                   stackTrace) =>
                                        //               const Icon(Icons
                                        //                   .image_not_supported),
                                        //         ),
                                        // ),
                                  child: ClipOval(
  child: imageUrl.isEmpty
      ? const Icon(Icons.image_not_supported)
      : CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          memCacheWidth: 200, // ✅ reduce memory footprint for thumbnails
          memCacheHeight: 200,
          placeholder: (context, url) => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ),
          errorWidget: (context, url, error) =>
              const Icon(Icons.image_not_supported),
        ),
),


                                      ),

                                      /// ✅ Tick overlay when selected
                                      if (isSelected)
                                        Container(
                                          width: 75,
                                          height: 75,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.35),
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
                      const SizedBox(height: 10),

                      /// 🔹 Full-width curved button with simple loader
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _selectedCodes.isEmpty || isSubmitting
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
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                            child: isSubmitting
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
                                    translateText('Submit'),
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

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _submitSelection(BuildContext context) async {
    if (_selectedCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translateText('Please select at least one service.'),
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final cubit = context.read<AddSalonCubit>();
    cubit.updateSelectedServiceCodes(List<String>.from(_selectedCodes));
    await cubit.submit(widget.formData);
  }
}
