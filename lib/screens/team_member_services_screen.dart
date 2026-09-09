import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';

const Color _svcBackground = Color(0xFFFBFAF8);
const Color _svcBorder = Color(0xFFE8DED6);
const Color _svcText = Color(0xFF2B241D);
const Color _svcMuted = Color(0xFF8C7A66);
const Color _svcGoldLight = Color(0xFFFFF5DE);

/// Narinder's guidance (2026-09-02 Slack): don't show services inline on
/// View Member — a "View Services" button opens this screen instead, with
/// a branch filter at the top since each branch can have different
/// services assigned.
class TeamMemberServicesScreen extends StatefulWidget {
  const TeamMemberServicesScreen({
    super.key,
    required this.memberName,
    required this.services,
    required this.branches,
    this.initialBranchId,
  });

  final String memberName;

  /// Raw TeamAssignedServiceSummary entries (each carries its own
  /// branchId) — not the deduped display-name list View Member uses for
  /// its summary count, so branch filtering here stays accurate.
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> branches;

  /// Pre-selects the branch filter when opened from that branch's own row
  /// on View Member, instead of always starting on "all branches" — the
  /// filter itself stays, so switching to another branch still works.
  final int? initialBranchId;

  @override
  State<TeamMemberServicesScreen> createState() =>
      _TeamMemberServicesScreenState();
}

class _TeamMemberServicesScreenState extends State<TeamMemberServicesScreen> {
  late int? _selectedBranchId = widget.initialBranchId;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _serviceLabel(Map<String, dynamic> item) {
    for (final key in const ['displayName', 'serviceName', 'name', 'label']) {
      final value = (item[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    final id = _toInt(item['branchServiceId'] ?? item['id']);
    return id == null ? '' : '${translateText('Service')} #$id';
  }

  List<Map<String, dynamic>> get _filteredServices {
    final branchId = _selectedBranchId;
    if (branchId == null) return widget.services;
    return widget.services
        .where((item) => _toInt(item['branchId']) == branchId)
        .toList();
  }

  String _branchNameForId(int? branchId) {
    if (branchId == null) return translateText('All Branches');
    for (final branch in widget.branches) {
      final id = _toInt(branch['branchId'] ?? branch['id']);
      if (id == branchId) {
        final name = (branch['name'] ?? branch['branchName'] ?? '').toString();
        if (name.trim().isNotEmpty) return name.trim();
      }
    }
    return '${translateText('Branch')} #$branchId';
  }

  String get _selectedBranchName => _branchNameForId(_selectedBranchId);

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TM';
    final first = parts.first.characters.first.toUpperCase();
    final second =
        parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return '$first$second';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;
    final selectedBranchName = _selectedBranchName;
    return Scaffold(
      backgroundColor: _svcBackground,
      appBar: buildProfileSubpageAppBar(title: translateText('Services')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _MemberServicesHeader(
            memberName: widget.memberName,
            initials: _initials(widget.memberName),
            serviceCount: filtered.length,
            branchName: selectedBranchName,
          ),
          if (widget.branches.length > 1) ...[
            const SizedBox(height: 14),
            _SectionShell(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BranchFilterChip(
                    label: translateText('All Branches'),
                    selected: _selectedBranchId == null,
                    onTap: () => setState(() => _selectedBranchId = null),
                  ),
                  for (final branch in widget.branches) ...[
                    _BranchFilterChip(
                      label: (branch['name'] ?? branch['branchName'] ?? '')
                          .toString(),
                      selected: _selectedBranchId ==
                          _toInt(branch['branchId'] ?? branch['id']),
                      onTap: () => setState(
                        () => _selectedBranchId =
                            _toInt(branch['branchId'] ?? branch['id']),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _EmptyServicesCard(
              message: translateText('No services assigned'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // 3 per row is the target on a normal phone width — cards
                // are just short text now (no icon), so they stay legible
                // that narrow. Only steps down on genuinely cramped widths.
                final columns = constraints.maxWidth >= 300
                    ? 3
                    : constraints.maxWidth >= 200
                        ? 2
                        : 1;
                final itemWidth =
                    (constraints.maxWidth - 10 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final service in filtered)
                      SizedBox(
                        width: itemWidth,
                        child: _ServiceCard(
                          name: _serviceLabel(service),
                          branchName: _selectedBranchId == null
                              ? _branchNameForId(_toInt(service['branchId']))
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MemberServicesHeader extends StatelessWidget {
  const _MemberServicesHeader({
    required this.memberName,
    required this.initials,
    required this.serviceCount,
    required this.branchName,
  });

  final String memberName;
  final String initials;
  final int serviceCount;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceCount == 1
        ? translateText('Service')
        : translateText('Services');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _svcBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _svcGoldLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.starColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _svcText,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniStatPill(
                      icon: Icons.design_services_outlined,
                      label: '$serviceCount $serviceLabel',
                    ),
                    _MiniStatPill(
                      icon: Icons.storefront_outlined,
                      label: branchName,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _svcBorder),
      ),
      child: child,
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _svcBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.starColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _svcText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.name,
    this.branchName,
  });

  final String name;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final branch = branchName?.trim() ?? '';
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _svcBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: _svcText,
            ),
          ),
          if (branch.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              branch,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _svcMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyServicesCard extends StatelessWidget {
  const _EmptyServicesCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _svcBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _svcGoldLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.design_services_outlined,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _svcMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchFilterChip extends StatelessWidget {
  const _BranchFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.starColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.starColor : _svcBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _svcText,
          ),
        ),
      ),
    );
  }
}
