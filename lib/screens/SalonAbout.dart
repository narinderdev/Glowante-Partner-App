import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class SalonAbout extends StatefulWidget {
  const SalonAbout({super.key, this.branchId});

  final int? branchId;

  @override
  State<SalonAbout> createState() => _SalonAboutState();
}

class _SalonAboutState extends State<SalonAbout> {
  List<Map<String, dynamic>> _salons = [];
  bool _loading = true;
  bool _loadingSalons = true;
  bool _showPhotos = false;
  int? _branchId;
  Map<String, dynamic>? _details;
  String? _error;
  String? _salonError;

  @override
  void initState() {
    super.initState();
    _loadSalons();
    _resolveBranchId();
  }

  List<Map<String, dynamic>> _normalizeSalonsList(Iterable<dynamic> raw) {
    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final rawBranches = (map['branches'] as List?) ?? const [];
        final branches = <Map<String, dynamic>>[];
        for (final branch in rawBranches) {
          if (branch is Map) {
            branches.add(Map<String, dynamic>.from(branch));
          }
        }
        map['branches'] = branches;
        result.add(map);
      }
    }
    return result;
  }

  String _branchAddressSummary(Map<String, dynamic> branch) {
    final address = branch['address'];
    if (address is Map) {
      final map = Map<String, dynamic>.from(address);
      final line1 = map['line1']?.toString().trim();
      if (line1 != null && line1.isNotEmpty) {
        return line1;
      }
    }
    return '';
  }

  List<_BranchOption> _computeBranchOptions() {
    final options = <_BranchOption>[];
    final seenBranchIds = <int>{};
    for (final salon in _salons) {
      final salonId = salon['id'];
      if (salonId is! int) continue;
      final salonName = (salon['name'] ?? '').toString();
      final branches = salon['branches'];
      if (branches is! List || branches.isEmpty) {
        continue;
      }
      for (final branchEntry in branches) {
        if (branchEntry is! Map || branchEntry.isEmpty) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = branch['id'];
        if (branchId is! int || !seenBranchIds.add(branchId)) continue;
        final branchName = (branch['name'] ?? '').toString();
        options.add(
          _BranchOption(
            salonId: salonId,
            salonName: salonName.isEmpty ? 'Salon #$salonId' : salonName,
            branchId: branchId,
            branchName: branchName.isEmpty ? 'Branch #$branchId' : branchName,
            addressSummary: _branchAddressSummary(branch),
            branch: branch,
          ),
        );
      }
    }
    return options;
  }

  Future<void> _loadSalons() async {
    if (mounted) {
      setState(() {
        _loadingSalons = true;
        _salonError = null;
      });
    }
    try {
      final response = await ApiService().getSalonListApi();
      if (response['success'] == true) {
        final data = (response['data'] as List?)?.toList() ?? const [];
        final normalized = _normalizeSalonsList(data);
        if (!mounted) return;
        setState(() {
          _salons = normalized;
          _loadingSalons = false;
          _salonError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _salons = [];
          _loadingSalons = false;
          _salonError =
              (response['message'] ?? translateText('Failed to reach server'))
                  .toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salons = [];
        _loadingSalons = false;
        _salonError = e.toString();
      });
    }
  }

  Future<void> _resolveBranchId() async {
    int? id = widget.branchId;
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getInt('selected_branch_id');
    }

    if (!mounted) return;

    if (id == null) {
      setState(() {
        _branchId = null;
        _details = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _branchId = id;
      _details = null;
      _error = null;
      _loading = true;
    });

    await _fetchBranchDetails(id);
  }

  Future<void> _onBranchSelected(_BranchOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_branch_id', option.branchId);
    await prefs.setInt('selected_salon_id', option.salonId);

    if (!mounted) return;
    setState(() {
      _branchId = option.branchId;
      _details = null;
      _error = null;
      _loading = true;
    });
    await _fetchBranchDetails(option.branchId);
  }

  Future<void> _fetchBranchDetails(int branchId) async {
    try {
      final response = await ApiService().getBranchDetail(branchId);
      Map<String, dynamic>? data;
      if (response['data'] is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(response['data'] as Map);
      } else {
        data = Map<String, dynamic>.from(response);
      }

      if (!mounted) return;

      setState(() {
        _details = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _details = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> _extractPhotoUrls(Map<String, dynamic> details) {
    final urls = <String>[];
    final seen = <String>{};
    final single = details['imageUrl'];
    if (single is String && single.trim().isNotEmpty) {
      final value = single.trim();
      if (seen.add(value)) urls.add(value);
    }
    final list = details['imageUrls'];
    if (list is List) {
      for (final entry in list) {
        if (entry is String && entry.trim().isNotEmpty) {
          final value = entry.trim();
          if (seen.add(value)) urls.add(value);
        }
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    context.t(''); // register for language changes
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: translateText('About Salon')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final branchOptions = _computeBranchOptions();
    _BranchOption? selectedOption;
    for (final option in branchOptions) {
      if (option.branchId == _branchId) {
        selectedOption = option;
        break;
      }
    }
    final List<_BranchOption> menuOptions = selectedOption == null
        ? List<_BranchOption>.from(branchOptions)
        : [
            selectedOption,
            ...branchOptions.where(
              (option) => option.branchId != selectedOption!.branchId,
            ),
          ];

    final branchHint = _loadingSalons
        ? context.t('Loading...')
        : (branchOptions.isEmpty
            ? context.t('No branches available')
            : context.t('Select Branch'));
    final List<DropdownMenuItem<int>> branchItems = menuOptions
        .map(
          (option) => DropdownMenuItem<int>(
            value: option.branchId,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              color: option.branchId == selectedOption?.branchId
                  ? const Color(0xFFE0E0E0)
                  : Colors.transparent,
              child: _BranchDropdownOption(option: option),
            ),
          ),
        )
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        translateText('Choose Branch'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (_loadingSalons)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedOption?.branchId,
                        isExpanded: true,
                        itemHeight: 60,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.starColor,
                        ),
                        dropdownColor: Colors.white,
                        items: branchItems,
                        selectedItemBuilder: branchItems.isNotEmpty
                            ? (context) => menuOptions
                                .map(
                                  (option) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BranchDropdownOption(
                                      option: option,
                                      compact: true,
                                    ),
                                  ),
                                )
                                .toList()
                            : null,
                        onChanged: _loadingSalons || branchOptions.isEmpty
                            ? null
                            : (newValue) {
                                if (newValue == null) return;
                                final option = branchOptions.firstWhere(
                                  (element) => element.branchId == newValue,
                                );
                                _onBranchSelected(option);
                              },
                        hint: Text(
                          branchOptions.isEmpty
                              ? translateText('No branches available')
                              : branchHint,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_salonError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _salonError!,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(child: _buildDetailsContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_branchId == null) {
      return _CenteredMessage(
        text: context.t('Select a branch to view details'),
      );
    }

    if (_error != null) {
      return _CenteredMessage(
        text: context.t('Unable to load branch details.'),
        secondary: _error,
      );
    }

    final details = _details ?? const {};
    final description = (details['description'] as String?)?.trim();
    final phone = (details['phone'] ?? '').toString().trim();
    final address = details['address'] as Map<String, dynamic>?;
    final line1 = (address?['line1'] ?? '').toString().trim();
    final city = (address?['city'] ?? '').toString().trim();
    final state = (address?['state'] ?? '').toString().trim();
    final pincode = (address?['pincode'] ?? '').toString().trim();
    final photoUrls = _extractPhotoUrls(details);

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (description != null && description.isNotEmpty)
                ? description
                : context.t('No description available'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _PhotoGallerySection(
            urls: photoUrls,
            expanded: _showPhotos,
            onToggle: () => setState(() => _showPhotos = !_showPhotos),
          ),
          const SizedBox(height: 24),
          if (phone.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.phone,
              label: context.t('Phone Number'),
              value: phone,
            ),
            const SizedBox(height: 16),
          ],
          if (line1.isNotEmpty ||
              city.isNotEmpty ||
              state.isNotEmpty ||
              pincode.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.location_on,
              label: context.t('Address'),
              value: _composeAddress(
                line1: line1,
                city: city,
                state: state,
                pincode: pincode,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  String _composeAddress({
    required String line1,
    required String city,
    required String state,
    required String pincode,
  }) {
    final parts = [line1, city, state, pincode]
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.starColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.secondary});

  final String text;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              Text(
                secondary!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchOption {
  const _BranchOption({
    required this.salonId,
    required this.salonName,
    required this.branchId,
    required this.branchName,
    required this.addressSummary,
    required this.branch,
  });

  final int salonId;
  final String salonName;
  final int branchId;
  final String branchName;
  final String addressSummary;
  final Map<String, dynamic> branch;
}

class _BranchDropdownOption extends StatelessWidget {
  const _BranchDropdownOption({required this.option, this.compact = false});

  final _BranchOption option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchLabel = option.branchName.trim();
    final address = option.addressSummary.trim();
    final displayTitle =
        branchLabel.isEmpty ? 'Branch #${option.branchId}' : branchLabel;

    if (compact) {
      return Text(
        displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront,
            color: AppColors.starColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (address.isNotEmpty)
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blueGrey.shade500,
                      ) ??
                      const TextStyle(color: Colors.blueGrey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoGallerySection extends StatelessWidget {
  const _PhotoGallerySection({
    required this.urls,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> urls;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              translateText('Photos'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.visibility_off : Icons.photo),
              label: Text(
                expanded
                    ? translateText('Hide Photos')
                    : translateText('View Photos'),
              ),
            ),
          ],
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: urls.isEmpty
                ? Text(translateText('No photos uploaded yet'))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: urls.length,
                    itemBuilder: (context, index) {
                      final url = urls[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
