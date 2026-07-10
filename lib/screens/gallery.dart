import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';

const Color _galleryBackground = Color(0xFFFBFAF8);
const Color _gallerySurface = Colors.white;
const Color _galleryBorder = Color(0xFFE7D8C8);
const Color _gallerySoftBorder = Color(0xFFFFE0C2);
const Color _galleryText = Color(0xFF1F1B18);
const Color _galleryMuted = Color(0xFF6F665E);
const Color _gallerySoftFill = Color(0xFFF7F1E8);
const Color _gallerySoftChip = Color(0xFFFDF4E6);
const Color _galleryShadow = Color(0x12000000);

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    this.initialBranchId,
  });

  final int? initialBranchId;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ApiService _apiService = ApiService();
  late final VoidCallback _branchSelectionListener;
  bool _suppressBranchSelectionRefresh = false;

  bool _isLoadingBranches = true;
  bool _isLoadingGallery = false;
  String? _errorMessage;

  List<_GalleryBranchOption> _branches = [];
  int? _selectedBranchId;

  String _branchName = '';
  String _address = '';
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    _branchSelectionListener = () {
      if (!mounted || _suppressBranchSelectionRefresh) return;
      _loadBranchesAndGallery();
    };
    StylistBranchSelectionStore.selectionNotifier
        .addListener(_branchSelectionListener);
    _loadBranchesAndGallery();
  }

  @override
  void dispose() {
    StylistBranchSelectionStore.selectionNotifier
        .removeListener(_branchSelectionListener);
    super.dispose();
  }

  Future<void> _loadBranchesAndGallery() async {
    setState(() {
      _isLoadingBranches = true;
      _isLoadingGallery = true;
      _errorMessage = null;
    });

    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await _apiService.getSalonListApi();
      final rawSalons = (response['data'] as List?) ?? const [];

      final branches = _extractBranchOptions(rawSalons);

      final initialBranchId = widget.initialBranchId ?? selection.branchId;

      final selectedBranchId = branches.any(
        (branch) => branch.branchId == initialBranchId,
      )
          ? initialBranchId
          : branches.isNotEmpty
              ? branches.first.branchId
              : null;

      if (!mounted) return;

      setState(() {
        _branches = branches;
        _selectedBranchId = selectedBranchId;
        _isLoadingBranches = false;
      });

      if (selectedBranchId == null) {
        setState(() {
          _isLoadingGallery = false;
          _branchName = '';
          _address = '';
          _imageUrls = [];
        });
        return;
      }

      await _loadGallery(selectedBranchId);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoadingBranches = false;
        _isLoadingGallery = false;
      });
    }
  }

  Future<void> _loadGallery(int branchId) async {
    setState(() {
      _selectedBranchId = branchId;
      _isLoadingGallery = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getBranchDetail(branchId);

      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      final branchName = _cleanText(data['name']);

      final seenUrls = <String>{};
      final imageUrls = <String>[];

      void addImageUrl(dynamic value) {
        final url = _cleanText(value);
        if (url.isEmpty) return;

        if (seenUrls.add(url)) {
          imageUrls.add(url);
        }
      }

      addImageUrl(data['imageUrl']);

      if (data['imageUrls'] is List) {
        for (final item in data['imageUrls'] as List) {
          addImageUrl(item);
        }
      }

      final address = _addressFromMap(data['address']);

      if (!mounted) return;

      setState(() {
        _branchName = branchName;
        _address = address;
        _imageUrls = imageUrls;
        _isLoadingGallery = false;
      });
    } catch (error) {
      if (!mounted) return;

      final fallback = _branches.firstWhere(
        (branch) => branch.branchId == branchId,
        orElse: () => _GalleryBranchOption(
          salonId: 0,
          branchId: branchId,
          salonName: '',
          branchName: '',
          address: '',
        ),
      );

      setState(() {
        _branchName = fallback.displayLabel;
        _address = fallback.address;
        _imageUrls = [];
        _errorMessage = error.toString();
        _isLoadingGallery = false;
      });
    }
  }

  Future<void> _onBranchSelected(_GalleryBranchOption branch) async {
    _suppressBranchSelectionRefresh = true;
    try {
      await StylistBranchSelectionStore.save(
        salonId: branch.salonId,
        branchId: branch.branchId,
        salonName: branch.salonName,
        branchName: branch.branchName,
      );

      await _loadGallery(branch.branchId);
    } finally {
      _suppressBranchSelectionRefresh = false;
    }
  }

  void _openImageModal(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(14),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.starColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: 260,
                          height: 220,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _gallerySurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                            color: AppColors.starColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_GalleryBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_GalleryBranchOption>[];

    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) continue;

      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _asIntOrNull(salon['id']);
      if (salonId == null) continue;

      final salonName = _cleanText(salon['name']);
      final branches = (salon['branches'] as List?) ?? const [];

      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;

        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asIntOrNull(branch['id']);
        if (branchId == null) continue;

        options.add(
          _GalleryBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _addressFromMap(branch['address']),
          ),
        );
      }
    }

    return options;
  }

  int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _addressFromMap(dynamic rawAddress) {
    if (rawAddress is! Map) return '';

    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    for (final key in [
      'line1',
      'line2',
      'village',
      'district',
      'city',
      'state',
      'country',
      'postalCode',
    ]) {
      final value = _cleanText(address[key]);
      if (value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
    }

    return parts.join(', ');
  }

  _GalleryBranchOption? get _selectedBranch {
    final branchId = _selectedBranchId;
    if (branchId == null) return null;

    for (final branch in _branches) {
      if (branch.branchId == branchId) return branch;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedBranch = _selectedBranch;

    final displayName = _branchName.isNotEmpty
        ? _branchName
        : selectedBranch?.displayLabel ?? context.t('Gallery');

    final displayAddress =
        _address.isNotEmpty ? _address : selectedBranch?.address ?? '';

    return Scaffold(
      backgroundColor: _galleryBackground,
      appBar: AppBar(
        backgroundColor: _gallerySurface,
        elevation: 0.5,
        surfaceTintColor: _gallerySurface,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.starColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t('Gallery'),
          style: const TextStyle(
            color: _galleryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.starColor,
          onRefresh: () => RefreshFeedback.playAndRun(() async {
            final branchId = _selectedBranchId;
            if (branchId != null) {
              await _loadGallery(branchId);
            }
          }),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (_isLoadingBranches || _branches.length > 1) ...[
                _BranchSelectorCard(
                  isLoading: _isLoadingBranches,
                  branches: _branches,
                  selectedBranchId: _selectedBranchId,
                  onBranchSelected: _onBranchSelected,
                ),
                const SizedBox(height: 18),
              ],
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                decoration: BoxDecoration(
                  color: _gallerySurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _galleryBorder,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: _galleryShadow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'S A L O N   G A L L E R Y',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 4,
                        color: AppColors.starColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 560;

                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: _galleryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _InfoChip(
                                  icon: Icons.storefront_outlined,
                                  text: displayName,
                                ),
                                if (displayAddress.isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.location_on_outlined,
                                    text: displayAddress,
                                  ),
                              ],
                            ),
                          ],
                        );

                        final actions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isLoadingGallery
                                  ? null
                                  : () {
                                      final branchId = _selectedBranchId;
                                      if (branchId != null) {
                                        _loadGallery(branchId);
                                      }
                                    },
                              icon: _isLoadingGallery
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                        color: AppColors.starColor,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: AppColors.starColor,
                                    ),
                              label: Text(context.t('Refresh')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.starColor,
                                side: const BorderSide(
                                  color: _galleryBorder,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: _gallerySoftFill,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_imageUrls.length} photos',
                                style: const TextStyle(
                                  color: AppColors.starColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleBlock,
                              const SizedBox(height: 14),
                              actions,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleBlock),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Divider(
                      height: 1,
                      color: _gallerySoftBorder,
                    ),
                    const SizedBox(height: 18),
                    if (_isLoadingGallery)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.starColor,
                          ),
                        ),
                      )
                    else if (_imageUrls.isEmpty)
                      _EmptyGalleryBox(
                        isLoading: _isLoadingGallery,
                        onRefresh: () => RefreshFeedback.playAndRun(() async {
                          final branchId = _selectedBranchId;
                          if (branchId != null) {
                            await _loadGallery(branchId);
                          }
                        }),
                      )
                    else
                      _GalleryGrid(
                        imageUrls: _imageUrls,
                        onImageTap: _openImageModal,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelectorCard extends StatelessWidget {
  const _BranchSelectorCard({
    required this.isLoading,
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  final bool isLoading;
  final List<_GalleryBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<_GalleryBranchOption> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    _GalleryBranchOption? selected;
    for (final branch in branches) {
      if (branch.branchId == selectedBranchId) {
        selected = branch;
        break;
      }
    }

    if (isLoading) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _gallerySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _galleryBorder),
          boxShadow: const [
            BoxShadow(
              color: _galleryShadow,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.starColor,
          ),
        ),
      );
    }

    if (branches.isEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _gallerySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _galleryBorder),
          boxShadow: const [
            BoxShadow(
              color: _galleryShadow,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          context.t('No branches available'),
          style: const TextStyle(
            fontSize: 13,
            color: _galleryMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedBranch = selected ?? branches.first;
    return OwnerBranchHeaderSelector<int>(
      label: selectedBranch.displayLabel,
      options: branches
          .map(
            (branch) => OwnerBranchHeaderSelectorOption<int>(
              value: branch.branchId,
              label: branch.displayLabel,
              subtitle: branch.address,
            ),
          )
          .toList(),
      selectedValue: selectedBranch.branchId,
      placeholder: context.t('Select Branch'),
      isInteractive: branches.length > 1,
      onSelected: (branchId) {
        final branch = branches.firstWhere(
          (item) => item.branchId == branchId,
          orElse: () => selectedBranch,
        );
        onBranchSelected(branch);
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _gallerySoftChip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.starColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: _galleryMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGalleryBox extends StatelessWidget {
  const _EmptyGalleryBox({
    required this.isLoading,
    required this.onRefresh,
  });

  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 38),
      decoration: BoxDecoration(
        color: _gallerySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _galleryBorder,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFF4E8D1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 32,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No image available',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _galleryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Salon images will appear here once they are available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _galleryMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onRefresh,
            icon: isLoading
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isLoading ? 'Checking...' : 'Check again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
              elevation: 10,
              shadowColor: AppColors.starColor.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({
    required this.imageUrls,
    required this.onImageTap,
  });

  final List<String> imageUrls;
  final ValueChanged<String> onImageTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;

        return GridView.builder(
          itemCount: imageUrls.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 170,
          ),
          itemBuilder: (context, index) {
            final imageUrl = imageUrls[index];

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onImageTap(imageUrl),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _gallerySoftFill,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.starColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GalleryBranchOption {
  const _GalleryBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get displayLabel {
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (salonName.trim().isNotEmpty) return salonName.trim();
    return 'Branch #$branchId';
  }
}
