import 'package:flutter/material.dart';

import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import 'SalonDeal.dart';
import 'SalonPackage.dart';
import 'SalonTeams.dart';
import 'gallery.dart';

class OwnerMoreScreen extends StatefulWidget {
  const OwnerMoreScreen({super.key});

  @override
  State<OwnerMoreScreen> createState() => _OwnerMoreScreenState();
}

class _OwnerMoreScreenState extends State<OwnerMoreScreen> {
  bool _permissionsLoaded = false;
  bool _hasPermissionPayload = false;
  Set<String> _branchPermissions = const <String>{};
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final selection = await StylistBranchSelectionStore.load();
    final hasPermissionPayload =
        await UserRoleSession.instance.hasPersistedPermissions();
    final branchPermissions = await UserRoleSession.instance.loadPermissions(
      branchId: selection.branchId,
    );
    if (!mounted) return;
    setState(() {
      _selectedBranchId = selection.branchId;
      _permissionsLoaded = true;
      _hasPermissionPayload = hasPermissionPayload;
      _branchPermissions = branchPermissions;
    });
  }

  bool _canAccess(List<String> permissions) {
    if (!_permissionsLoaded || !_hasPermissionPayload) return true;
    return permissions.any(_branchPermissions.contains);
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_QuickLinkData>[
      _QuickLinkData(
        icon: Icons.groups_rounded,
        title: context.t('Team members'),
        subtitle: context.t('Manage stylists & staff'),
        permissions: const ['team.view'],
        onTap: () => _open(TeamScreen()),
      ),
      _QuickLinkData(
        icon: Icons.local_offer_outlined,
        title: context.t('Deals'),
        subtitle: context.t('Create offers'),
        permissions: const ['deals.view'],
        onTap: () => _open(DealScreen()),
      ),
      _QuickLinkData(
        icon: Icons.card_giftcard_outlined,
        title: context.t('Packages'),
        subtitle: context.t('Bundle services'),
        permissions: const ['packages.view'],
        onTap: () => _open(PackageScreen()),
      ),
      _QuickLinkData(
        icon: Icons.image_outlined,
        title: context.t('Gallery'),
        subtitle: context.t('Salon images'),
        permissions: const ['gallery.view'],
        onTap: () => _open(GalleryScreen(initialBranchId: _selectedBranchId)),
      ),
    ].where((item) => _canAccess(item.permissions)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: kToolbarHeight,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          context.t('More'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Inter', 'sans-serif'],
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B6500),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1EBE6),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _loadPermissions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _QuickLinksCard(items: items),
          ],
        ),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({required this.items});

  final List<_QuickLinkData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _quickLinkCardDecoration(),
        child: Text(
          context.t('No quick links available.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF756A61),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: _quickLinkCardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _QuickLinkRow(item: items[index]),
            if (index != items.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: Color(0xFFE8DED6),
              ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _quickLinkCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE8DED6)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({required this.item});

  final _QuickLinkData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF3E8D1),
              child: Icon(
                item.icon,
                color: AppColors.starColor,
                size: 23,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Color(0xFF1C1917),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB8AEA5),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkData {
  const _QuickLinkData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.permissions,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> permissions;
  final VoidCallback onTap;
}
