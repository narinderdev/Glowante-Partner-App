import 'dart:convert';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

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
    this.title,
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
  final String? title;

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
          context.read<AddSalonCubit>().resetStatus();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => BottomNav(tabIndex: 1)),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFFBFAF8),
          appBar: buildProfileSubpageAppBar(
            title: translateText(widget.title ?? 'Add Salon'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
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
                          const SizedBox(height: 26),
                          if (widget.branchFormData != null &&
                              widget.sourceBranches.isNotEmpty) ...[
                            _buildCopyFromBranchCard(),
                            const SizedBox(height: 26),
                            _buildOrDivider(),
                            const SizedBox(height: 18),
                          ],
                          Text(
                            translateText(
                              '"Excellence is in every detail of the service\nyou provide."',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Color(0xFF6C625A),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            translateText('Choose Your Specialties'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF191817),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            translateText(
                              "Select the categories that define your salon's professional catalog.",
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Color(0xFF5E554E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 34),
                          AbsorbPointer(
                            absorbing: copyServicesSelected,
                            child: Opacity(
                              opacity: copyServicesSelected ? 0.45 : 1,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.86,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 22,
                                ),
                                itemCount: _services.length,
                                itemBuilder: (context, index) {
                                  final service =
                                      _services[index] as Map<String, dynamic>;
                                  final name =
                                      (service['name'] ?? '') as String;
                                  final imageUrl =
                                      (service['image_url'] ?? '') as String;
                                  final code =
                                      (service['code'] ?? '') as String;
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
                                    child: _buildSpecialtyCard(
                                      name: name,
                                      imageUrl: imageUrl,
                                      isSelected: isSelected,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          _buildLaunchQuote(),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitSelection(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B6500),
                                foregroundColor: Colors.white,
                                elevation: 9,
                                shadowColor: const Color(0x338B6500),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
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
                                        translateText(
                                            widget.branchFormData != null
                                                ? widget.submitLabel
                                                : 'Finish & Launch Salon'),
                                        key: const ValueKey('text'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
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
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCopyFromBranchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6D9CC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.content_copy_rounded,
              color: Color(0xFF8B6500),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Copy from Branch'),
                  style: const TextStyle(
                    color: Color(0xFF2B241E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  translateText(
                    'Replicate services from an existing branch to save time.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF7A7168),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: ValueKey(_selectedSourceBranchId),
                  initialValue: _selectedSourceBranchId,
                  isExpanded: true,
                  icon: _selectedSourceBranchId == null
                      ? const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF8B6500),
                          size: 18,
                        )
                      : const SizedBox.shrink(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F1ED),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: _selectedSourceBranchId == null
                        ? null
                        : IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: translateText('Clear selection'),
                            onPressed: () {
                              setState(() {
                                _selectedSourceBranchId = null;
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF8B6500),
                              size: 20,
                            ),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE0D6CD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE0D6CD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFFD0A244),
                        width: 1.2,
                      ),
                    ),
                  ),
                  hint: Text(
                    translateText('Select Branch'),
                    style: const TextStyle(
                      color: Color(0xFF6F665E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        translateText('Select Branch'),
                        style: const TextStyle(
                          color: Color(0xFF6F665E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ...widget.sourceBranches.map((branch) {
                      final branchId = (branch['id'] as num?)?.toInt();
                      return DropdownMenuItem<int?>(
                        value: branchId,
                        child: Text(
                          _branchDisplayName(branch),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2B241E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (branchId) {
                    setState(() {
                      _selectedSourceBranchId = branchId;
                      if (branchId != null) {
                        _selectedCodes.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE8DED6))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            translateText('OR'),
            style: const TextStyle(
              color: Color(0xFF8B6500),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE8DED6))),
      ],
    );
  }

  String _branchDisplayName(Map<String, dynamic> branch) {
    final name = [
      branch['name'],
      branch['branchName'],
      branch['displayName'],
      branch['title'],
    ].map((value) => (value ?? '').toString().trim()).firstWhere(
          (value) => value.isNotEmpty && value.toLowerCase() != 'null',
          orElse: () => '',
        );
    return name.isEmpty ? translateText('Unnamed Branch') : name;
  }

  Widget _buildSpecialtyCard({
    required String name,
    required String imageUrl,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected ? const Color(0xFFD0A244) : const Color(0xFFE2D6CC),
          width: isSelected ? 1.2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B6500)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFBDB5AE),
                        )
                      : Image(
                          image: _imageProviders.putIfAbsent(
                            imageUrl,
                            () => CachedNetworkImageProvider(imageUrl),
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFFBDB5AE),
                          ),
                        ),
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  bottom: -8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEF8),
                      border: Border.all(
                        color: const Color(0xFF8B6500),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF8B6500),
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24211E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchQuote() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 198,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/salonImage.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(color: const Color(0xCC3A240B)),
            Image.asset(
              'assets/images/salonImage.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
            Container(color: const Color(0x773A240B)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  translateText(
                    '"Your artistry defines the experience. Choose the specialties that will become your salon\'s signature."',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD0A244),
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final salonCubit = context.read<AddSalonCubit>();
    salonCubit.updateSelectedServiceCodes(List<String>.from(_selectedCodes));

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(
          List<String>.from(_selectedCodes),
          _selectedSourceBranchId,
        );
        if (!mounted) return;
        navigator.pop(true);
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
          imageUrls: branch.imageUrls,
          selectedCategoryCodes: _selectedCodes, // ✅ FIXED
          sourceBranchId: _selectedSourceBranchId,
        );

        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(translateText('Branch added successfully!'))),
        );

        navigator.pushAndRemoveUntil(
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
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(translateText('Failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
