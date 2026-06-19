import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../utils/price_formatter.dart';

enum _AiInsightRange { week, month }

class OwnerAiInsightsScreen extends StatefulWidget {
  const OwnerAiInsightsScreen({super.key});

  @override
  State<OwnerAiInsightsScreen> createState() => _OwnerAiInsightsScreenState();
}

class _OwnerAiInsightsScreenState extends State<OwnerAiInsightsScreen> {
  final ApiService _apiService = ApiService();

  List<_AiBranchOption> _branchOptions = const [];
  int? _selectedBranchId;
  _AiInsightRange _range = _AiInsightRange.month;
  String _selectedCategory = 'all';
  Map<String, dynamic> _data = const {};
  bool _loadingBranches = true;
  bool _loadingInsights = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBranchesAndInsights();
  }

  Future<void> _loadBranchesAndInsights() async {
    setState(() {
      _loadingBranches = true;
      _loadingInsights = true;
      _errorMessage = null;
    });

    try {
      final saved = await StylistBranchSelectionStore.load();
      final response = await _apiService.getSalonListApi();
      final options = _extractBranchOptions(
        (response['data'] as List?) ?? const [],
      );
      final selectedBranchId = options.any(
        (option) => option.branchId == saved.branchId,
      )
          ? saved.branchId
          : (options.isNotEmpty ? options.first.branchId : null);

      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranchId = selectedBranchId;
        _loadingBranches = false;
      });

      if (selectedBranchId == null) {
        if (!mounted) return;
        setState(() => _loadingInsights = false);
        return;
      }

      await _loadInsights(selectedBranchId, saveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadingBranches = false;
        _loadingInsights = false;
      });
    }
  }

  Future<void> _loadInsights(
    int branchId, {
    bool saveSelection = true,
  }) async {
    setState(() {
      _selectedBranchId = branchId;
      _loadingInsights = true;
      _errorMessage = null;
    });

    try {
      if (saveSelection) {
        final selected = _branchOptions.firstWhere(
          (option) => option.branchId == branchId,
        );
        await StylistBranchSelectionStore.save(
          salonId: selected.salonId,
          branchId: selected.branchId,
          salonName: selected.salonName,
          branchName: selected.branchName,
        );
      }

      final period = _periodForRange(_range);
      final response = await _apiService.getAiInsightsDashboardSummary(
        branchId: branchId,
        fromDate: period.$1,
        toDate: period.$2,
      );

      if (!mounted) return;
      setState(() {
        _data = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : const {};
        _selectedCategory =
            _hasCategory(_selectedCategory) ? _selectedCategory : 'all';
        _loadingInsights = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadingInsights = false;
      });
    }
  }

  Future<void> _changeRange(_AiInsightRange range) async {
    if (_range == range) return;
    setState(() => _range = range);
    final branchId = _selectedBranchId;
    if (branchId != null) {
      await _loadInsights(branchId, saveSelection: false);
    }
  }

  (DateTime, DateTime) _periodForRange(_AiInsightRange range) {
    final now = DateTime.now();
    if (range == _AiInsightRange.month) {
      return (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1, 0),
      );
    }
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return (start, start.add(const Duration(days: 6)));
  }

  bool _hasCategory(String key) {
    return _categories.any((category) => _cleanText(category['key']) == key);
  }

  List<Map<String, dynamic>> get _categories => _mapList(_data['categories']);

  List<Map<String, dynamic>> get _filteredInsights {
    final insights = _mapList(_data['insights']);
    if (_selectedCategory == 'all') return insights;
    return insights
        .where(
            (insight) => _cleanText(insight['category']) == _selectedCategory)
        .toList();
  }

  List<_AiBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_AiBranchOption>[];
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
          _AiBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _branchAddressSummary(branch['address']),
          ),
        );
      }
    }
    return options;
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _branchAddressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    void push(dynamic value) {
      final text = _cleanText(value);
      if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
    }

    push(address['line1']);
    push(address['line2']);
    push(address['village']);
    push(address['district']);
    push(address['city']);
    push(address['state']);
    push(address['postalCode']);
    push(address['country']);
    return parts.join(', ');
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('AI Insights')),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.starColor,
            onRefresh: _loadBranchesAndInsights,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildBranchSelector(),
                const SizedBox(height: 18),
                _buildHeader(),
                const SizedBox(height: 18),
                if (_errorMessage != null)
                  _AiEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: context.t('Unable to load insights'),
                    message: _errorMessage!,
                  )
                else if (_selectedBranchId == null)
                  _AiEmptyState(
                    icon: Icons.storefront_outlined,
                    title: context.t('No branches available'),
                    message: context.t('Please add a branch to view insights.'),
                  )
                else
                  _buildInsightsContent(),
              ],
            ),
          ),
          if (_loadingInsights)
            const Positioned.fill(child: _AiLoadingOverlay()),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return _AiBranchSelector(
      isLoading: _loadingBranches,
      branches: _branchOptions,
      selectedBranchId: _selectedBranchId,
      onBranchSelected: (branch) => _loadInsights(branch.branchId),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('AI Insights ✨'),
                    style: const TextStyle(
                      color: AppColors.starColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'Smart insights and recommendations to help you grow your salon business.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF6B5B4D),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildRangeToggle(),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6D6C6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeButton(
            label: context.t('This Week'),
            icon: Icons.calendar_today_outlined,
            selected: _range == _AiInsightRange.week,
            onTap: () => _changeRange(_AiInsightRange.week),
          ),
          _RangeButton(
            label: context.t('This Month'),
            icon: Icons.calendar_month_outlined,
            selected: _range == _AiInsightRange.month,
            onTap: () => _changeRange(_AiInsightRange.month),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    final summary = _mapValue(_data['summary']);
    final breakdown = _mapList(_data['summaryBreakdown']);
    final topOpportunities = _mapList(_data['topOpportunities']);
    final recentActions = _mapList(_data['recentActions']);
    final insights = _filteredInsights;

    return Column(
      children: [
        _buildSummaryCards(summary),
        const SizedBox(height: 16),
        _buildCategoryFilters(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildInsightGrid(insights, twoColumns: true),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 300,
                    child: _buildSideRail(
                      breakdown,
                      topOpportunities,
                      recentActions,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _buildInsightGrid(insights, twoColumns: false),
                const SizedBox(height: 16),
                _buildSideRail(
                  breakdown,
                  topOpportunities,
                  recentActions,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final cards = [
      _SummaryCardData(
        icon: Icons.auto_awesome_outlined,
        title: context.t('Total Insights'),
        value: _asInt(summary['totalInsights']).toString(),
        background: const Color(0xFFFFFBF5),
        iconColor: AppColors.starColor,
      ),
      _SummaryCardData(
        icon: Icons.check_circle_outline_rounded,
        title: context.t('Action Taken'),
        value: _asInt(summary['actionTaken']).toString(),
        background: const Color(0xFFEFFCF4),
        iconColor: const Color(0xFF16A34A),
      ),
      _SummaryCardData(
        icon: Icons.lightbulb_outline_rounded,
        title: context.t('High Impact'),
        value: _asInt(summary['highImpact']).toString(),
        subtitle: context.t('Requires your attention'),
        background: const Color(0xFFFFF8DB),
        iconColor: const Color(0xFFF59E0B),
      ),
      _SummaryCardData(
        icon: Icons.visibility_outlined,
        title: context.t('Potential Impact'),
        value: formatMinorAmount(
          summary['potentialImpactAmount'],
          trimZeroDecimals: true,
        ),
        subtitle: context.t('Additional revenue'),
        background: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _AiSummaryCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    final categories = _categories
        .where((category) => _cleanText(category['key']).isNotEmpty)
        .toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final key = _cleanText(category['key']);
          final selected = key == _selectedCategory;
          final label = _cleanText(category['label']);
          final count = _asInt(category['count']);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              label: Text('$label ($count)'),
              onSelected: (_) => setState(() => _selectedCategory = key),
              selectedColor: AppColors.starColor,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.starColor : const Color(0xFFE4D5C7),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF5B5674),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightGrid(
    List<Map<String, dynamic>> insights, {
    required bool twoColumns,
  }) {
    if (insights.isEmpty) {
      return _AiEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: context.t('No insights yet'),
        message: context.t('Insights will appear here once data is available.'),
      );
    }

    if (!twoColumns) {
      return Column(
        children: insights
            .map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AiInsightCard(
                  insight: insight,
                  cleanText: _cleanText,
                  asInt: _asInt,
                ),
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: insights
              .map(
                (insight) => SizedBox(
                  width: width,
                  child: _AiInsightCard(
                    insight: insight,
                    cleanText: _cleanText,
                    asInt: _asInt,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSideRail(
    List<Map<String, dynamic>> breakdown,
    List<Map<String, dynamic>> topOpportunities,
    List<Map<String, dynamic>> recentActions,
  ) {
    return Column(
      children: [
        _InsightsSummaryPanel(
          breakdown: breakdown,
          categories: _categories,
          cleanText: _cleanText,
          asInt: _asInt,
        ),
        const SizedBox(height: 12),
        _CompactListPanel(
          title: context.t('Top Opportunities'),
          icon: Icons.trending_up_rounded,
          items: topOpportunities,
          emptyTitle: context.t('No opportunities yet'),
          emptyMessage: context.t(
            'Opportunity recommendations will show here when the API returns them.',
          ),
          cleanText: _cleanText,
        ),
        const SizedBox(height: 12),
        _CompactListPanel(
          title: context.t('Recent Actions Taken'),
          icon: Icons.sync_rounded,
          items: recentActions,
          emptyTitle: context.t('No recent actions'),
          emptyMessage: context.t(
            'Completed and in-progress actions will appear here once available.',
          ),
          cleanText: _cleanText,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(context.t('AI report generation is coming soon')),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(context.t('Generate AI Report')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4E4C8),
              foregroundColor: AppColors.starColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFDCC7AA)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiBranchOption {
  const _AiBranchOption({
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

  String get displayLabel => branchName.isEmpty ? salonName : branchName;
}

class _AiBranchSelector extends StatelessWidget {
  const _AiBranchSelector({
    required this.isLoading,
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  final bool isLoading;
  final List<_AiBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<_AiBranchOption> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final selected = branches.cast<_AiBranchOption?>().firstWhere(
          (branch) => branch?.branchId == selectedBranchId,
          orElse: () => null,
        );

    if (isLoading) {
      return const _AiBranchSelectorShell(
        child: Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF8B6500),
          ),
        ),
      );
    }

    if (branches.isEmpty) {
      return _AiBranchSelectorShell(
        child: Text(
          context.t('No branches available'),
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedBranch = selected ?? branches.first;
    final child = _AiBranchSelectorContent(
      branch: selectedBranch,
      showDropdown: branches.length > 1,
    );

    if (branches.length <= 1) return child;

    return PopupMenuButton<_AiBranchOption>(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      constraints: const BoxConstraints(minWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8DED6)),
      ),
      onSelected: onBranchSelected,
      itemBuilder: (context) {
        return branches.map((branch) {
          return PopupMenuItem<_AiBranchOption>(
            value: branch,
            child: _AiBranchMenuItem(
              branch: branch,
              isSelected: branch.branchId == selectedBranch.branchId,
            ),
          );
        }).toList();
      },
      child: child,
    );
  }
}

class _AiBranchSelectorShell extends StatelessWidget {
  const _AiBranchSelectorShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: child,
    );
  }
}

class _AiBranchSelectorContent extends StatelessWidget {
  const _AiBranchSelectorContent({
    required this.branch,
    required this.showDropdown,
  });

  final _AiBranchOption branch;
  final bool showDropdown;

  @override
  Widget build(BuildContext context) {
    return _AiBranchSelectorShell(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFF3E8D1),
            child: Icon(
              Icons.storefront_outlined,
              color: Color(0xFF8B6500),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  branch.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2D2926),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (branch.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    branch.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF756A61),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showDropdown)
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8B6500),
            ),
        ],
      ),
    );
  }
}

class _AiBranchMenuItem extends StatelessWidget {
  const _AiBranchMenuItem({
    required this.branch,
    required this.isSelected,
  });

  final _AiBranchOption branch;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isSelected
              ? Icons.check_circle_outline_rounded
              : Icons.storefront_outlined,
          size: 18,
          color: const Color(0xFF8B6500),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AiBranchSelectorContent(
            branch: branch,
            showDropdown: false,
          ),
        ),
      ],
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.background,
    required this.iconColor,
    this.subtitle = '',
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color background;
  final Color iconColor;
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D5C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 19),
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            style: const TextStyle(
              color: Color(0xFF5B5674),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              color: Color(0xFF161329),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (data.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              style: const TextStyle(
                color: Color(0xFF7A7391),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.starColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.starColor.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF5B5674),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF5B5674),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.insight,
    required this.cleanText,
    required this.asInt,
  });

  final Map<String, dynamic> insight;
  final String Function(dynamic value) cleanText;
  final int Function(dynamic value) asInt;

  @override
  Widget build(BuildContext context) {
    final title = cleanText(insight['title']);
    final description = cleanText(insight['description']);
    final category = cleanText(insight['categoryLabel']);
    final impactKind = cleanText(insight['impactKind']);
    final impact = _impactText(context, insight, impactKind);
    final icon = _iconForCategory(cleanText(insight['category']));

    return _AiSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.starColor, size: 19),
          ),
          const SizedBox(height: 16),
          Text(
            title.isEmpty ? context.t('Insight') : title,
            style: const TextStyle(
              color: Color(0xFF161329),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty
                ? context.t('No description available.')
                : description,
            style: const TextStyle(
              color: Color(0xFF7A7391),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE8D8C8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InsightMeta(
                  title: context.t('Potential Impact'),
                  value: impact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InsightMeta(
                  title: context.t('Category'),
                  value: category.isEmpty ? context.t('General') : category,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _impactText(
    BuildContext context,
    Map<String, dynamic> insight,
    String impactKind,
  ) {
    final metric = insight['impactMetric'];
    if (metric is Map) {
      final value = metric['value'];
      final unit = cleanText(metric['unit']);
      if (value != null && unit.isNotEmpty) return '$value $unit';
      if (value != null) return value.toString();
    }
    if (impactKind == 'monetary') {
      return formatMinorAmount(
        insight['potentialImpactAmount'],
        trimZeroDecimals: true,
      );
    }
    final level = cleanText(insight['impactLevel']);
    if (level.isNotEmpty) return level;
    final amount = asInt(insight['potentialImpactAmount']);
    if (amount != 0) {
      return formatMinorAmount(amount, trimZeroDecimals: true);
    }
    return context.t('Informational');
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'customers':
        return Icons.groups_outlined;
      case 'staff':
        return Icons.badge_outlined;
      case 'operations':
        return Icons.calendar_month_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'revenue_sales':
        return Icons.trending_up_rounded;
      default:
        return Icons.auto_awesome_outlined;
    }
  }
}

class _InsightMeta extends StatelessWidget {
  const _InsightMeta({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFA79DB8),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4B3A12),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InsightsSummaryPanel extends StatelessWidget {
  const _InsightsSummaryPanel({
    required this.breakdown,
    required this.categories,
    required this.cleanText,
    required this.asInt,
  });

  final List<Map<String, dynamic>> breakdown;
  final List<Map<String, dynamic>> categories;
  final String Function(dynamic value) cleanText;
  final int Function(dynamic value) asInt;

  @override
  Widget build(BuildContext context) {
    final visibleBreakdown = breakdown
        .where((item) => cleanText(item['category']).isNotEmpty)
        .toList();
    final total = visibleBreakdown.fold<int>(
      0,
      (sum, item) => sum + asInt(item['count']),
    );

    return _AiSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Insights Summary'),
            style: const TextStyle(
              color: Color(0xFF161329),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 128,
              height: 128,
              child: CustomPaint(
                painter: _InsightDonutPainter(
                  values: visibleBreakdown
                      .map((item) => asInt(item['count']))
                      .toList(),
                  colors: visibleBreakdown
                      .map((item) =>
                          _colorForCategory(cleanText(item['category'])))
                      .toList(),
                ),
                child: Center(
                  child: Text(
                    total == 0 ? '0%' : '100%',
                    style: const TextStyle(
                      color: Color(0xFF3C332B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...visibleBreakdown.map((item) {
            final key = cleanText(item['category']);
            final label = _categoryLabel(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colorForCategory(key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF5B5674),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    asInt(item['count']).toString(),
                    style: const TextStyle(
                      color: Color(0xFF161329),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                context.t('View Summary Report'),
                style: const TextStyle(
                  color: AppColors.starColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.starColor,
                size: 15,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String key) {
    for (final category in categories) {
      if (cleanText(category['key']) == key) {
        final label = cleanText(category['label']);
        if (label.isNotEmpty) return label;
      }
    }
    return key.replaceAll('_', ' ');
  }
}

class _CompactListPanel extends StatelessWidget {
  const _CompactListPanel({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.cleanText,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String emptyTitle;
  final String emptyMessage;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    return _AiSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF161329),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(icon, color: AppColors.starColor, size: 17),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE7CFAE),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.starColor,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF161329),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8B8398),
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.take(4).map((item) {
              final title = cleanText(item['title']).isEmpty
                  ? cleanText(item['name'])
                  : cleanText(item['title']);
              final subtitle = cleanText(item['description']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.starColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? context.t('Insight') : title,
                            style: const TextStyle(
                              color: Color(0xFF161329),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF7A7391),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D5C7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _AiSection(
      child: Column(
        children: [
          Icon(icon, color: AppColors.starColor, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF161329),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A7391),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingOverlay extends StatelessWidget {
  const _AiLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        color: Colors.white.withValues(alpha: 0.38),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.starColor),
      ),
    );
  }
}

class _InsightDonutPainter extends CustomPainter {
  const _InsightDonutPainter({
    required this.values,
    required this.colors,
  });

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1ECE6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi * 2, false, backgroundPaint);

    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value <= 0) continue;
      final sweep = (value / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _InsightDonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

Color _colorForCategory(String category) {
  switch (category) {
    case 'revenue_sales':
      return AppColors.starColor;
    case 'customers':
      return const Color(0xFFD0A244);
    case 'staff':
      return const Color(0xFF4DB6A6);
    case 'operations':
      return const Color(0xFF4CAF7A);
    case 'marketing':
      return const Color(0xFF7C3AED);
    default:
      return const Color(0xFF8B8378);
  }
}
