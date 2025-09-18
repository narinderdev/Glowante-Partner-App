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
      backgroundColor: Colors.white,
     appBar: AppBar(
      backgroundColor: Colors.orange, // main orange background
      centerTitle: true, // center the title
      title: const Text(
        'My Salons',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: _goToAddSalon,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white, // dark orange circle
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.deepOrange,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    ),
      body: BlocBuilder<SalonListCubit, SalonListState>(
        builder: (context, state) {
          if (state.isLoading && state.salons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError && state.salons.isEmpty) {
            return _ErrorView(
              message: state.errorMessage ?? 'Failed to load salons',
              onRetry: _refreshSalons,
            );
          }

          if (state.salons.isEmpty) {
            return Center(
              child: ElevatedButton.icon(
                onPressed: _goToAddSalon,
                icon: const Icon(Icons.add),
                label: const Text('Add Salon'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshSalons,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.salons.length,
              itemBuilder: (context, index) {
                final salon = state.salons[index];
                final salonId = salon['id'] as int;
                final isExpanded = state.expandedSalonId == salonId;
                return _SalonCard(
                  salon: salon,
                  isExpanded: isExpanded,
                  onToggle: () =>
                      context.read<SalonListCubit>().toggleExpanded(salonId),
                  onAddBranch: () => _goToAddBranch(salonId),
                  onOpenBranch: (branchId) =>
                      _openBranchDetail(salonId: salonId, branchId: branchId),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fabExpanded)
            Container(
              width: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _FabMenuItem(
                    icon: Icons.group,
                    label: 'Team',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TeamScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _FabMenuItem(
                    icon: Icons.local_offer,
                    label: 'Deals',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DealScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _FabMenuItem(
                    icon: Icons.card_giftcard,
                    label: 'Packages',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PackageScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            child: Icon(fabExpanded ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                fabExpanded = !fabExpanded;
              });
            },
          ),
        ],
      ),
    );
  }
}
class _SalonCard extends StatelessWidget {
  _SalonCard({  // remove 'const' here
    required this.salon,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddBranch,
    required this.onOpenBranch,
  });

  final Map<String, dynamic> salon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddBranch;
  final Future<void> Function(int branchId) onOpenBranch; // fixed typo

  @override
  Widget build(BuildContext context) {
    final imageUrl = salon['imageUrl'] as String?;
    final branches =
        (salon['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                 else
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            "assets/images/salonImage.png",
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          (salon['name'] ?? 'Salon') as String,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Icon(
        isExpanded
            ? Icons.keyboard_arrow_up
            : Icons.keyboard_arrow_down,
        color: Colors.grey,
      ),
    ],
  ),
),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              if (branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No branches yet. Start by adding one!'),
                )
              else
                ...branches.map(
                  (branch) => _BranchTile(
                    branch: branch,
                    onOpen: () async => await onOpenBranch(branch['id'] as int),
                  ),
                ),
              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: onAddBranch,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      '+ Add Branch',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchTile extends StatefulWidget {
  const _BranchTile({required this.branch, required this.onOpen, Key? key}) : super(key: key);

  final Map<String, dynamic> branch;
    final Future<void> Function() onOpen;

  @override
  State<_BranchTile> createState() => _BranchTileState();
}

class _BranchTileState extends State<_BranchTile> {
  bool isLoading = false;

  void _handleTap() async {
    setState(() => isLoading = true);
    try {
      await widget.onOpen(); // This calls _openBranchDetail
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.branch['address'] as Map<String, dynamic>?;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.branch['name'] ?? 'Branch') as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (address?['line1'] ?? '') as String,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: isLoading ? null : _handleTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA500), Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'View Branch',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey,
        ),
      ],
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          mini: true,
          backgroundColor: Colors.orange,
          onPressed: onTap,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
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
