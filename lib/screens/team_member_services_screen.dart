import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';

const Color _svcBackground = Color(0xFFFBFAF8);
const Color _svcBorder = Color(0xFFE8DED6);
const Color _svcText = Color(0xFF2B241D);
const Color _svcMuted = Color(0xFF8C7A66);

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
  });

  final String memberName;

  /// Raw TeamAssignedServiceSummary entries (each carries its own
  /// branchId) — not the deduped display-name list View Member uses for
  /// its summary count, so branch filtering here stays accurate.
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> branches;

  @override
  State<TeamMemberServicesScreen> createState() =>
      _TeamMemberServicesScreenState();
}

class _TeamMemberServicesScreenState extends State<TeamMemberServicesScreen> {
  int? _selectedBranchId;

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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;
    return Scaffold(
      backgroundColor: _svcBackground,
      appBar: buildProfileSubpageAppBar(title: translateText('Services')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            widget.memberName,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _svcText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            translateText('Services assigned across branches.'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              color: _svcMuted,
            ),
          ),
          if (widget.branches.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BranchFilterChip(
                    label: translateText('All Branches'),
                    selected: _selectedBranchId == null,
                    onTap: () => setState(() => _selectedBranchId = null),
                  ),
                  for (final branch in widget.branches) ...[
                    const SizedBox(width: 8),
                    _BranchFilterChip(
                      label: (branch['name'] ?? branch['branchName'] ?? '')
                          .toString(),
                      selected: _selectedBranchId == _toInt(branch['branchId']),
                      onTap: () => setState(
                        () => _selectedBranchId = _toInt(branch['branchId']),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            Text(
              translateText('No services assigned'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _svcMuted,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in filtered)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8C774)),
                    ),
                    child: Text(
                      _serviceLabel(service),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _svcText,
                      ),
                    ),
                  ),
              ],
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
