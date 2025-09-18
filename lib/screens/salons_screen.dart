import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/branch/add_branch_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/add_salon_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/repositories/branch_repository.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import 'add_branch_screen.dart';
import 'add_salon_screen.dart';
import 'branch_screen.dart';
import 'Deal.dart';
import 'Package.dart';
import 'Teams.dart';

class SalonsScreen extends StatefulWidget {
  const SalonsScreen({super.key});

  @override
  State<SalonsScreen> createState() => _SalonsScreenState();
}

class _SalonsScreenState extends State<SalonsScreen> {
  bool fabExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<SalonListCubit>();
      if (cubit.state.salons.isEmpty) {
        cubit.loadSalons();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }
    _searchController.clear();
    _handleSearchChanged('');
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> salons) {
    if (_searchQuery.isEmpty) {
      return salons;
    }
    final query = _searchQuery;
    return salons.where((salon) {
      final salonName = (salon['name'] ?? '').toString().toLowerCase();
      if (salonName.contains(query)) {
        return true;
      }
      final branches =
          (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final branch in branches) {
        final branchName = (branch['name'] ?? '').toString().toLowerCase();
        if (branchName.contains(query)) {
          return true;
        }
        final address = (branch['address'] as Map<String, dynamic>?) ?? {};
        final addressLine = (address['line1'] ?? '').toString().toLowerCase();
        if (addressLine.contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  int _resolveId(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  Future<void> _refreshSalons() async {
    await context.read<SalonListCubit>().loadSalons();
  }

  Future<void> _goToAddSalon() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => AddSalonCubit(context.read<SalonRepository>()),
          child: const AddSalonScreen(),
        ),
      ),
    );

    if (added == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _goToAddBranch(int salonId) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) =>
              AddBranchCubit(context.read<SalonRepository>(), salonId: salonId),
          child: AddBranchScreen(salonId: salonId),
        ),
      ),
    );

    if (added == true && mounted) {
      await _refreshSalons();
    }
  }

  Future<void> _openBranchDetail({
    required int salonId,
    required int branchId,
  }) async {
    final repository = context.read<BranchRepository>();

    try {
      final response = await repository.fetchBranchDetail(branchId);
      if (response['success'] == true && response['data'] != null) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BranchScreen(
              salonId: salonId,
              branchDetails: response['data'] as Map<String, dynamic>,
            ),
          ),
        );
      } else {
        final message = response['message'] ?? 'Unable to open branch details';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _SalonsAppBar(
        onAddSalon: _goToAddSalon,
        searchController: _searchController,
        onSearchChanged: _handleSearchChanged,
      ),
      body: BlocBuilder<SalonListCubit, SalonListState>(
        builder: (context, state) {
          final salons = _applySearch(state.salons);

          return RefreshIndicator(
            onRefresh: _refreshSalons,
            color: const Color(0xFFFF7A45),
            displacement: 32,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: _SalonsOverview(
                      totalSalons: state.salons.length,
                      visibleSalons: salons.length,
                      isLoading: state.isLoading,
                    ),
                  ),
                ),
                if (state.isLoading && state.salons.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.hasError && state.salons.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorView(
                      message: state.errorMessage ?? 'Failed to load salons',
                      onRetry: _refreshSalons,
                    ),
                  )
                else if (salons.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySalonsView(
                      hasSearchQuery: _searchQuery.isNotEmpty,
                      onAddSalon: _goToAddSalon,
                      onClearSearch: _clearSearch,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final salon = salons[index];
                        final dynamic rawId = salon['id'];
                        final salonId = _resolveId(rawId, index);
                        final isExpanded = state.expandedSalonId == salonId;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == salons.length - 1 ? 0 : 16,
                          ),
                          child: _SalonCard(
                            salon: salon,
                            salonId: salonId,
                            isExpanded: isExpanded,
                            onToggle: () => context
                                .read<SalonListCubit>()
                                .toggleExpanded(salonId),
                            onAddBranch: () => _goToAddBranch(salonId),
                            onOpenBranch: (branchId) => _openBranchDetail(
                              salonId: salonId,
                              branchId: branchId,
                            ),
                          ),
                        );
                      }, childCount: salons.length),
                    ),
                  ),
                if (state.isLoading && state.salons.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: _InlineLoadingBanner(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: fabExpanded
                  ? _FabActionPanel(
                      key: const ValueKey('fab-panel'),
                      onTeam: () {
                        setState(() => fabExpanded = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TeamScreen()),
                        );
                      },
                      onDeals: () {
                        setState(() => fabExpanded = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DealScreen()),
                        );
                      },
                      onPackages: () {
                        setState(() => fabExpanded = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PackageScreen()),
                        );
                      },
                    )
                  : const SizedBox.shrink(key: ValueKey('fab-empty')),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
              icon: Icon(fabExpanded ? Icons.close : Icons.menu_rounded),
              label: Text(fabExpanded ? 'Close' : 'Quick actions'),
              onPressed: () {
                setState(() => fabExpanded = !fabExpanded);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SalonsAppBar({
    required this.onAddSalon,
    required this.searchController,
    required this.onSearchChanged,
  });

  final VoidCallback onAddSalon;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Size get preferredSize => const Size.fromHeight(176);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x2AFF7043),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Salons',
                          style:
                              theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay on top of every branch and booking',
                          style:
                              theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ) ??
                              const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAddSalon,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Salon'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF7043),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _AppBarSearchField(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarSearchField extends StatelessWidget {
  const _AppBarSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14212121),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasQuery = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF37474F),
            ),
            decoration: InputDecoration(
              hintText: 'Search salons or branches',
              hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFF7043)),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close, color: Color(0xFF90A4AE)),
                    )
                  : const Icon(Icons.tune, color: Color(0xFFFF8A65)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SalonsOverview extends StatelessWidget {
  const _SalonsOverview({
    required this.totalSalons,
    required this.visibleSalons,
    required this.isLoading,
  });

  final int totalSalons;
  final int visibleSalons;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                icon: Icons.store_mall_directory_outlined,
                label: 'Total salons',
                value: totalSalons.toString(),
                highlight: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                icon: Icons.visibility_outlined,
                label: 'Showing now',
                value: visibleSalons.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? Row(
                  key: const ValueKey('loading-state'),
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Refreshing salons…',
                      style: TextStyle(
                        color: Color(0xFF607D8B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Preview branches and drill down into details.',
                  key: const ValueKey('overview-ready'),
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF607D8B),
                        fontWeight: FontWeight.w500,
                      ) ??
                      const TextStyle(
                        color: Color(0xFF607D8B),
                        fontWeight: FontWeight.w500,
                      ),
                ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(
                colors: [Color(0xFFFFA573), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: highlight ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0x33FFFFFF)
                  : const Color(0x1AFF7043),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: highlight ? Colors.white : const Color(0xFFFF7043),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: highlight ? Colors.white70 : const Color(0xFF90A4AE),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.white : const Color(0xFF37474F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadingBanner extends StatelessWidget {
  const _InlineLoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF7043),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Syncing latest data…',
              style: TextStyle(
                color: Color(0xFF546E7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySalonsView extends StatelessWidget {
  const _EmptySalonsView({
    required this.hasSearchQuery,
    required this.onAddSalon,
    this.onClearSearch,
  });

  final bool hasSearchQuery;
  final VoidCallback onAddSalon;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = hasSearchQuery
        ? 'No salons match your search'
        : 'Create your first salon experience';
    final subtitle = hasSearchQuery
        ? 'Try adjusting filters or check the spelling to discover more results.'
        : 'Add a salon to start managing branches, services, and teams together.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              hasSearchQuery ? Icons.search_off_rounded : Icons.spa,
              color: const Color(0xFFFF7043),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF37474F),
                ) ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF37474F),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607D8B),
                ) ??
                const TextStyle(color: Color(0xFF607D8B)),
          ),
          if (hasSearchQuery && onClearSearch != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF7043),
                side: const BorderSide(color: Color(0xFFFF7043)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAddSalon,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Add Salon',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = filled
        ? accentColor.withOpacity(0.12)
        : Colors.white;
    final Color borderColor = filled
        ? accentColor.withOpacity(0.25)
        : const Color(0xFFE0E0E0);
    final Color contentColor = filled ? accentColor : const Color(0xFF607D8B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: contentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonCard extends StatelessWidget {
  _SalonCard({
    required this.salon,
    required this.salonId,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddBranch,
    required this.onOpenBranch,
  });

  final Map<String, dynamic> salon;
  final int salonId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddBranch;
  final Future<void> Function(int branchId) onOpenBranch;

  int _parseId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _cleanText(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  Widget _buildAvatar(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(imageUrl, width: 66, height: 66, fit: BoxFit.cover)
          : Image.asset(
              'assets/images/salonImage.png',
              width: 66,
              height: 66,
              fit: BoxFit.cover,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = const Color(0xFFFF7043);
    final branches =
        (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final branchCount = branches.length;
    final effectiveSalonId = salonId != 0 ? salonId : _parseId(salon['id']);
    final rawName = _cleanText(salon['name']);
    final salonName = rawName.isEmpty ? 'Unnamed Salon' : rawName;
    final rawTagline = _cleanText(salon['tagline']);
    final rawDescription = _cleanText(salon['description']);
    final tagline = rawTagline.isNotEmpty ? rawTagline : rawDescription;
    final rawImage = _cleanText(salon['imageUrl']);
    final String? imageUrl = rawImage.isEmpty ? null : rawImage;
    final borderColor = accentColor.withOpacity(0.18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: isExpanded ? Border.all(color: borderColor, width: 1.1) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(26),
            splashColor: accentColor.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(imageUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salonName,
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF263238),
                              ) ??
                              const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF263238),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MetricChip(
                              icon: Icons.storefront_rounded,
                              label:
                                  "$branchCount ${branchCount == 1 ? 'branch' : 'branches'}",
                              accentColor: accentColor,
                              filled: true,
                            ),
                            if (effectiveSalonId != 0)
                              _MetricChip(
                                icon: Icons.confirmation_number_outlined,
                                label: 'Salon ID #$effectiveSalonId',
                                accentColor: accentColor,
                              ),
                          ],
                        ),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF607D8B),
                                ) ??
                                const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF607D8B),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      const Divider(height: 1, color: Color(0xFFECEFF1)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branches',
                              style:
                                  theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF37474F),
                                  ) ??
                                  const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF37474F),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            if (branches.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F8FA),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF90A4AE),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No branches yet. Start by adding one to unlock bookings.',
                                        style: TextStyle(
                                          color: Color(0xFF607D8B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...branches.map((branch) {
                                final branchId = _parseId(branch['id']);
                                if (branchId == 0) {
                                  return const SizedBox.shrink();
                                }
                                return _BranchTile(
                                  branch: branch,
                                  accentColor: accentColor,
                                  onOpen: () async => onOpenBranch(branchId),
                                );
                              }),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: onAddBranch,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Branch'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accentColor,
                                  side: BorderSide(
                                    color: accentColor.withOpacity(0.6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BranchTile extends StatefulWidget {
  const _BranchTile({
    required this.branch,
    required this.onOpen,
    required this.accentColor,
    Key? key,
  }) : super(key: key);

  final Map<String, dynamic> branch;
  final Future<void> Function() onOpen;
  final Color accentColor;

  @override
  State<_BranchTile> createState() => _BranchTileState();
}

class _BranchTileState extends State<_BranchTile> {
  bool isLoading = false;

  void _handleTap() async {
    if (isLoading) {
      return;
    }
    setState(() => isLoading = true);
    try {
      await widget.onOpen();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final accentColor = widget.accentColor;
    final address = branch['address'] as Map<String, dynamic>? ?? {};
    final line1 = (address['line1'] ?? address['addressLine1'] ?? '')
        .toString()
        .trim();
    final city = (address['city'] ?? address['state'] ?? '').toString().trim();
    final phone =
        (branch['phone'] ??
                branch['phoneNumber'] ??
                branch['contactNumber'] ??
                '')
            .toString()
            .trim();
    final borderTint = accentColor.withOpacity(isLoading ? 0.35 : 0.18);
    final shadowTint = accentColor.withOpacity(0.08);

    final chips = <Widget>[];
    if (city.isNotEmpty) {
      chips.add(
        _MetricChip(
          icon: Icons.location_on_outlined,
          label: city,
          accentColor: accentColor,
        ),
      );
    }
    if (phone.isNotEmpty) {
      chips.add(
        _MetricChip(
          icon: Icons.phone_outlined,
          label: phone,
          accentColor: accentColor,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderTint),
        boxShadow: [
          BoxShadow(
            color: shadowTint,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.storefront_rounded, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (branch['name'] ?? 'Branch').toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    if (line1.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        line1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: chips),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isLoading ? null : _handleTap,
              style: TextButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'View Branch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabActionPanel extends StatelessWidget {
  const _FabActionPanel({
    super.key,
    required this.onTeam,
    required this.onDeals,
    required this.onPackages,
  });

  final VoidCallback onTeam;
  final VoidCallback onDeals;
  final VoidCallback onPackages;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FabActionTile(
                icon: Icons.groups_2_rounded,
                label: 'Team members',
                subtitle: 'Manage stylists & staff',
                onTap: onTeam,
              ),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _FabActionTile(
                icon: Icons.local_offer_outlined,
                label: 'Deals',
                subtitle: 'Create irresistible offers',
                onTap: onDeals,
              ),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _FabActionTile(
                icon: Icons.card_giftcard_outlined,
                label: 'Packages',
                subtitle: 'Bundle services smartly',
                onTap: onPackages,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabActionTile extends StatelessWidget {
  const _FabActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0x1AFF7043),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFFF7043)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF37474F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFFB0BEC5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
