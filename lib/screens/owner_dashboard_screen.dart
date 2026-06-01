import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ApiService _apiService = ApiService();

  List<_DashboardBranchOption> _branchOptions = const [];
  int? _selectedBranchId;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dashboard = const {};
  bool _isLoadingBranches = true;
  bool _isLoadingDashboard = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingBranches = true;
      _isLoadingDashboard = true;
      _errorMessage = null;
    });

    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await _apiService.getSalonListApi();
      final rawSalons = (response['data'] as List?) ?? const [];
      final options = _extractBranchOptions(rawSalons);
      final selectedBranchId = options.any(
        (option) => option.branchId == selection.branchId,
      )
          ? selection.branchId
          : (options.isNotEmpty ? options.first.branchId : null);

      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranchId = selectedBranchId;
        _isLoadingBranches = false;
      });

      if (selectedBranchId == null) {
        if (!mounted) return;
        setState(() => _isLoadingDashboard = false);
        return;
      }

      await _loadDashboard(selectedBranchId, saveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoadingBranches = false;
        _isLoadingDashboard = false;
      });
    }
  }

  Future<void> _loadDashboard(
    int branchId, {
    bool saveSelection = true,
  }) async {
    setState(() {
      _selectedBranchId = branchId;
      _isLoadingDashboard = true;
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

      final response = await _apiService.getReportsDashboard(
        branchId: branchId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );

      if (!mounted) return;
      setState(() {
        _dashboard = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : const {};
        _isLoadingDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoadingDashboard = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.starColor,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    final branchId = _selectedBranchId;
    if (branchId != null) {
      await _loadDashboard(branchId, saveSelection: false);
    }
  }

  List<_DashboardBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_DashboardBranchOption>[];
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
          _DashboardBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
          ),
        );
      }
    }
    return options;
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

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _percentText(dynamic value) {
    final percent = _asDouble(value);
    final formatted = percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '$formatted%';
  }

  String _headerGreeting() {
    final header = _dashboard['header'];
    if (header is Map) {
      final greeting = _cleanText(header['greeting']);
      if (greeting.isNotEmpty) {
        return greeting.replaceAll(':wave:', '👋');
      }
    }
    return context.t('Good evening');
  }

  String _headerSubtext() {
    final header = _dashboard['header'];
    if (header is Map) {
      final subtext = _cleanText(header['subtext']);
      if (subtext.isNotEmpty) return subtext;
    }
    return context.t("Here's what's happening at your salon today.");
  }

  List<Map<String, dynamic>> _mapList(String key) {
    final value = _dashboard[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _mapValue(String key) {
    final value = _dashboard[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Dashboard')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildBranchSelector(),
            const SizedBox(height: 18),
            if (_isLoadingDashboard && _dashboard.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
              )
            else if (_selectedBranchId == null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  context.t('No branches available'),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              _buildHeader(),
              const SizedBox(height: 16),
              _buildKpiCards(),
              const SizedBox(height: 16),
              _buildRevenueSection(),
              const SizedBox(height: 16),
              _buildTodayAndStaffSection(),
              const SizedBox(height: 16),
              _buildNotificationsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    return _DashboardSection(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Select Branch').toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingBranches)
            const Center(child: CircularProgressIndicator())
          else if (_branchOptions.isEmpty)
            Text(context.t('No branches available'))
          else
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: _branchOptions.map((option) {
                final isSelected = option.branchId == _selectedBranchId;
                return InkWell(
                  onTap: () => _loadDashboard(option.branchId),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? AppColors.starColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppColors.starColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          option.branchName.isEmpty
                              ? option.salonName
                              : option.branchName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.starColor
                                : const Color(0xFF6B5B4D),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final title = Text(
          _headerGreeting(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        );
        final subtitle = Text(
          _headerSubtext(),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B5B4D),
          ),
        );
        final dateButton = _DateButton(
          label: DateFormat('MM/dd/yyyy').format(_selectedDate),
          onTap: _pickDate,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 6),
              subtitle,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: dateButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 6),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 16),
            dateButton,
          ],
        );
      },
    );
  }

  Widget _buildKpiCards() {
    final cards = _mapList('kpi_cards');
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: crossAxisCount == 1 ? 132 : 124,
          ),
          itemBuilder: (context, index) => _KpiCard(
            data: cards[index],
            percentBuilder: _percentText,
            cleanText: _cleanText,
          ),
        );
      },
    );
  }

  Widget _buildRevenueSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final revenueCard = _RevenueOverviewCard(
          data: _mapValue('revenue_overview'),
          cleanText: _cleanText,
          asDouble: _asDouble,
          percentBuilder: _percentText,
        );
        final sourceCard = _RevenueSourceCard(
          data: _mapValue('revenue_by_source'),
          cleanText: _cleanText,
        );

        if (!isWide) {
          return Column(
            children: [
              revenueCard,
              const SizedBox(height: 16),
              sourceCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: revenueCard),
            const SizedBox(width: 16),
            Expanded(child: sourceCard),
          ],
        );
      },
    );
  }

  Widget _buildTodayAndStaffSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final appointmentsCard = _TodayAppointmentsCard(
          data: _mapValue('todays_appointments'),
          cleanText: _cleanText,
          asInt: _asInt,
        );
        final staffCard = _StaffLiveStatusCard(
          data: _mapValue('staff_live_status'),
          cleanText: _cleanText,
        );

        if (!isWide) {
          return Column(
            children: [
              appointmentsCard,
              const SizedBox(height: 16),
              staffCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: appointmentsCard),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: staffCard),
          ],
        );
      },
    );
  }

  Widget _buildNotificationsSection() {
    final notifications = _mapValue('notifications');
    final items = notifications['items'] is List
        ? (notifications['items'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _DashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Notifications'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _EmptyDashedBox(
              icon: Icons.notifications_none_outlined,
              message: 'No notifications right now.',
            )
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.notifications_none_outlined,
                  color: AppColors.starColor,
                ),
                title: Text(_cleanText(item['title'])),
                subtitle: Text(_cleanText(item['message'])),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardBranchOption {
  const _DashboardBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D6C6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('Date'),
              style: TextStyle(
                color: AppColors.starColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Text(label),
            const SizedBox(width: 12),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.data,
    required this.percentBuilder,
    required this.cleanText,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) percentBuilder;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final label = cleanText(data['label']);
    final value = cleanText(data['formatted_value']).isEmpty
        ? cleanText(data['value'])
        : cleanText(data['formatted_value']);
    final changeLabel = cleanText(data['change_label']);
    final hasChange = data.containsKey('change_percent');

    return _DashboardSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Color(0xFF8A6F58),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value.isEmpty ? '0' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          if (hasChange) ...[
            const SizedBox(height: 8),
            Text(
              '— ${percentBuilder(data['change_percent'])} $changeLabel',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B5B4D),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevenueOverviewCard extends StatelessWidget {
  const _RevenueOverviewCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
    required this.percentBuilder,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;
  final String Function(dynamic value) percentBuilder;

  @override
  Widget build(BuildContext context) {
    final chartData = data['chart_data'] is List
        ? (data['chart_data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final periodLabel = cleanText(data['period_label']);
    final total = cleanText(data['formatted_total']).isEmpty
        ? '₹0'
        : cleanText(data['formatted_total']);

    return _DashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Revenue Overview'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE6D6C6)),
                ),
                child: Text(
                  periodLabel.isEmpty ? context.t('This Month') : periodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.starColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                total,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '— ${percentBuilder(data['change_percent'])} ${cleanText(data['change_label'])}',
                style: const TextStyle(color: Color(0xFF6B5B4D)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RevenueChartPainter(
                chartData: chartData,
                asDouble: asDouble,
                cleanText: cleanText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueSourceCard extends StatelessWidget {
  const _RevenueSourceCard({
    required this.data,
    required this.cleanText,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final sources = data['sources'] is List
        ? (data['sources'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    const colors = [
      Color(0xFF7A5A10),
      Color(0xFFB48A45),
      Color(0xFFD8AE64),
    ];

    return _DashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Revenue by Source'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 42),
          if (sources.isEmpty)
            Text(
              context.t('No data available'),
              style: const TextStyle(color: Color(0xFF78716C)),
            )
          else
            ...sources.asMap().entries.map((entry) {
              final source = entry.value;
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanText(source['label']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${cleanText(source['percent']).isEmpty ? '0' : cleanText(source['percent'])}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A6F58),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      cleanText(source['formatted_value']).isEmpty
                          ? '₹0'
                          : cleanText(source['formatted_value']),
                      style: TextStyle(
                        color: AppColors.starColor,
                        fontWeight: FontWeight.w700,
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

class _TodayAppointmentsCard extends StatelessWidget {
  const _TodayAppointmentsCard({
    required this.data,
    required this.cleanText,
    required this.asInt,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final int Function(dynamic value) asInt;

  @override
  Widget build(BuildContext context) {
    final filters = data['filters'] is List
        ? (data['filters'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final appointments = data['appointments'] is List
        ? (data['appointments'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _DashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t("Today's Appointments"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                cleanText(data['cta_label']).isEmpty
                    ? context.t('View all appointments →')
                    : cleanText(data['cta_label']),
                style: TextStyle(
                  color: AppColors.starColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filters.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.asMap().entries.map((entry) {
                  final filter = entry.value;
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _appointmentFilterColor(cleanText(filter['key'])),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: entry.key == 0
                            ? AppColors.starColor
                            : Colors.transparent,
                        width: entry.key == 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          cleanText(filter['label']).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9A8A7A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${asInt(filter['count'])}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            const _EmptyDashedBox(
              icon: Icons.calendar_month_outlined,
              message: 'No appointments found for the selected day.',
            )
          else
            ...appointments.map(
              (appointment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(cleanText(appointment['client_name'])),
                subtitle: Text(cleanText(appointment['status'])),
              ),
            ),
        ],
      ),
    );
  }

  Color _appointmentFilterColor(String key) {
    switch (key) {
      case 'completed':
        return const Color(0xFFEAF9F1);
      case 'cancelled':
        return const Color(0xFFFDEDEF);
      case 'in_progress':
        return const Color(0xFFFFFBEC);
      case 'upcoming':
        return const Color(0xFFFFF6EB);
      default:
        return const Color(0xFFFAF6F0);
    }
  }
}

class _StaffLiveStatusCard extends StatelessWidget {
  const _StaffLiveStatusCard({
    required this.data,
    required this.cleanText,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final staff = data['staff'] is List
        ? (data['staff'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _DashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Staff Live Status'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                context.t('View live status →'),
                style: TextStyle(
                  color: AppColors.starColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (staff.isEmpty)
            const _EmptyDashedBox(
              icon: Icons.person_outline,
              message: 'No live staff activity is available.',
            )
          else
            ...staff.map(
              (member) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(cleanText(member['name'])),
                subtitle: Text(cleanText(member['status'])),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDashedBox extends StatelessWidget {
  const _EmptyDashedBox({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBD8BF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFC8B7D8), size: 28),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8A6F58)),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({
    required this.chartData,
    required this.asDouble,
    required this.cleanText,
  });

  final List<Map<String, dynamic>> chartData;
  final double Function(dynamic value) asDouble;
  final String Function(dynamic value) cleanText;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEEDFCC)
      ..strokeWidth = 1;
    final axisTextPainter = TextPainter(textDirection: TextDirection.ltr);
    const leftPadding = 34.0;
    const bottomPadding = 26.0;
    const topPadding = 8.0;
    const rightPadding = 8.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final values = chartData.map((item) => asDouble(item['value'])).toList();
    final maxValue = math.max(
      4,
      values.fold<double>(0, (max, value) => math.max(max, value)).ceil(),
    );

    for (var i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight - (chartHeight * i / 4);
      _drawDashedLine(
        canvas,
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
      axisTextPainter.text = TextSpan(
        text: '${(maxValue * i / 4).round()}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF8A6F58)),
      );
      axisTextPainter.layout();
      axisTextPainter.paint(
        canvas,
        Offset(leftPadding - axisTextPainter.width - 8, y - 6),
      );
    }

    if (chartData.isEmpty) return;

    final slotWidth = chartWidth / chartData.length;
    final barPaint = Paint()..color = const Color(0xFFC9C9C9);
    final linePaint = Paint()
      ..color = AppColors.starColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final points = <Offset>[];

    for (var index = 0; index < chartData.length; index++) {
      final item = chartData[index];
      final value = asDouble(item['value']);
      final x = leftPadding + slotWidth * index + slotWidth / 2;
      final y = topPadding + chartHeight - (value / maxValue) * chartHeight;
      points.add(Offset(x, y));

      if (value > 0) {
        final barWidth = math.min(42.0, slotWidth * 0.55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              x - barWidth / 2,
              y,
              x + barWidth / 2,
              topPadding + chartHeight,
            ),
            const Radius.circular(4),
          ),
          barPaint,
        );
      }

      axisTextPainter.text = TextSpan(
        text: cleanText(item['label']),
        style: const TextStyle(fontSize: 10, color: Color(0xFF8A6F58)),
      );
      axisTextPainter.layout(maxWidth: slotWidth);
      axisTextPainter.paint(
        canvas,
        Offset(
          x - axisTextPainter.width / 2,
          topPadding + chartHeight + 10,
        ),
      );
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = AppColors.starColor;
    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var currentX = start.dx;
    while (currentX < end.dx) {
      canvas.drawLine(
        Offset(currentX, start.dy),
        Offset(math.min(currentX + dashWidth, end.dx), end.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData;
  }
}
