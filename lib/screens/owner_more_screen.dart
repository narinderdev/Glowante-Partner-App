import 'package:flutter/material.dart';

import '../services/stylist_branch_selection.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import 'SalonDeal.dart';
import 'SalonPackage.dart';
import 'SalonTeams.dart';
import 'gallery.dart';

const Color _moreBg = Color(0xFFFBF9F8);
const Color _moreGold = Color(0xFF8B6500);
const Color _moreGoldLight = Color(0xFFF3E8D1);
const Color _moreText = Color(0xFF1C1917);
const Color _moreMuted = Color(0xFF78716C);
const Color _moreBorder = Color(0xFFE8DED6);
const Color _moreDivider = Color(0xFFF1EBE6);

class OwnerMoreScreen extends StatefulWidget {
  const OwnerMoreScreen({super.key});

  @override
  State<OwnerMoreScreen> createState() => _OwnerMoreScreenState();
}

class _OwnerMoreScreenState extends State<OwnerMoreScreen> {
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final selection = await StylistBranchSelectionStore.load();
    if (!mounted) return;

    setState(() {
      _selectedBranchId = selection.branchId;
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_QuickLinkData>[
      _QuickLinkData(
        icon: Icons.groups_2_rounded,
        title: context.t('Team members'),
        subtitle: context.t('Manage stylists, staff and roles'),
        permissions: const ['team.view'],
        onTap: () => _open(TeamScreen()),
      ),
      _QuickLinkData(
        icon: Icons.local_offer_rounded,
        title: context.t('Deals'),
        subtitle: context.t('Create discounts and offers'),
        permissions: const ['deals.view'],
        onTap: () => _open(DealScreen()),
      ),
      _QuickLinkData(
        icon: Icons.card_giftcard_rounded,
        title: context.t('Packages'),
        subtitle: context.t('Bundle services for customers'),
        permissions: const ['packages.view'],
        onTap: () => _open(PackageScreen()),
      ),
      _QuickLinkData(
        icon: Icons.photo_library_rounded,
        title: context.t('Gallery'),
        subtitle: context.t('Manage salon photos'),
        permissions: const ['gallery.view'],
        onTap: () => _open(GalleryScreen(initialBranchId: _selectedBranchId)),
      ),
    ];

    return Scaffold(
      backgroundColor: _moreBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _moreGold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: _moreDivider,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _loadPermissions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            _MoreHeaderCard(
              title: context.t('Salon tools'),
              subtitle: context.t(
                'Manage your team, offers, packages and gallery from one place.',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.t('Quick Actions').toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _moreGold,
              ),
            ),
            const SizedBox(height: 10),
            _QuickLinksCard(items: items),
          ],
        ),
      ),
    );
  }
}

class _MoreHeaderCard extends StatelessWidget {
  const _MoreHeaderCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFAF1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _moreBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: _moreGoldLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: _moreGold,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _moreText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: _moreMuted,
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

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({required this.items});

  final List<_QuickLinkData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _quickLinkCardDecoration(),
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _moreGoldLight,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: _moreGold,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.t('No quick links available.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: _moreText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('You do not have permission to access these tools.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: _moreMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: _quickLinkCardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _QuickLinkRow(
              item: items[index],
              isFirst: index == 0,
              isLast: index == items.length - 1,
            ),
            if (index != items.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 78,
                color: _moreBorder,
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
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _moreBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final _QuickLinkData item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(18) : Radius.zero,
          bottom: isLast ? const Radius.circular(18) : Radius.zero,
        ),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _moreGoldLight,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.starColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: _moreText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: _moreMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _moreBorder),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: _moreGold,
                  size: 22,
                ),
              ),
            ],
          ),
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
