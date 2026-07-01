import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../utils/price_formatter.dart';
import 'bottom_nav.dart';
import 'package:fluttertoast/fluttertoast.dart';


enum OwnerSalesReportModule {
  revenueSales,
  staffPerformance,
  operations,
}

extension OwnerSalesReportModuleLabel on OwnerSalesReportModule {
  String title(BuildContext context) {
    switch (this) {
      case OwnerSalesReportModule.revenueSales:
        return context.t('Revenue & Sales');
      case OwnerSalesReportModule.staffPerformance:
        return context.t('Staff Performance');
      case OwnerSalesReportModule.operations:
        return context.t('Operations');
    }
  }
}

class OwnerSalesReportsScreen extends StatefulWidget {
  const OwnerSalesReportsScreen({
    super.key,
    required this.initialModule,
    this.showModuleTabs = true,
  });

  final OwnerSalesReportModule initialModule;
  final bool showModuleTabs;

  @override
  State<OwnerSalesReportsScreen> createState() =>
      _OwnerSalesReportsScreenState();
}

class _OwnerSalesReportsScreenState extends State<OwnerSalesReportsScreen> {
  final ApiService _apiService = ApiService();
  final List<_ReportPeriod> _periods = const [
    _ReportPeriod('today', 'Today'),
    _ReportPeriod('this_week', 'This Week'),
    _ReportPeriod('this_month', 'This Month'),
    _ReportPeriod('this_year', 'This Year'),
  ];

  late OwnerSalesReportModule _module;
  String _selectedRange = 'today';
  List<_ReportBranchOption> _branchOptions = const [];
  int? _selectedBranchId;
  Map<String, dynamic> _data = const {};
  bool _loadingBranches = true;
  bool _loadingReport = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _module = widget.initialModule;
    _loadBranchesAndReport();
  }

  Future<void> _loadBranchesAndReport() async {
    setState(() {
      _loadingBranches = true;
      _loadingReport = true;
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
        setState(() => _loadingReport = false);
        return;
      }

      await _loadReport(selectedBranchId, saveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadingBranches = false;
        _loadingReport = false;
      });
    }
  }

  Future<void> _loadReport(
    int branchId, {
    bool saveSelection = true,
  }) async {
    setState(() {
      _selectedBranchId = branchId;
      _loadingReport = true;
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

      final response = switch (_module) {
        OwnerSalesReportModule.staffPerformance =>
          await _apiService.getStaffPerformanceReport(
            branchId: branchId,
            dateRange: _selectedRange,
          ),
        OwnerSalesReportModule.operations =>
          await _apiService.getOperationsDashboard(
            branchId: branchId,
            dateRange: _selectedRange,
          ),
        OwnerSalesReportModule.revenueSales =>
          await _apiService.getRevenueSalesDashboard(
            branchId: branchId,
            dateRange: _selectedRange,
          ),
      };

      if (!mounted) return;
      setState(() {
        _data = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : const {};
        _loadingReport = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadingReport = false;
      });
    }
  }

  Future<void> _changeRange(String range) async {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
    final branchId = _selectedBranchId;
    if (branchId != null) {
      await _loadReport(branchId, saveSelection: false);
    }
  }

  List<_ReportBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_ReportBranchOption>[];
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
          _ReportBranchOption(
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

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
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
      appBar: buildProfileSubpageAppBar(title: _module.title(context)),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.starColor,
            onRefresh: _loadBranchesAndReport,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (_loadingBranches || _branchOptions.length > 1) ...[
                  _buildBranchSelector(),
                  const SizedBox(height: 18),
                ],
                if (widget.showModuleTabs) ...[
                  _buildModuleTabs(),
                  const SizedBox(height: 18),
                ],
                if (_errorMessage != null)
                  _ReportEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: context.t('Unable to load report'),
                    message: _errorMessage!,
                  )
                else if (_selectedBranchId == null)
                  _ReportEmptyState(
                    icon: Icons.storefront_outlined,
                    title: context.t('No branches available'),
                    message: context.t('Please add a branch to view reports.'),
                  )
                else if (_module == OwnerSalesReportModule.operations)
                  _buildOperations()
                else if (_module == OwnerSalesReportModule.staffPerformance)
                  _buildStaffPerformance()
                else
                  _buildRevenueSales(),
              ],
            ),
          ),
          if (_loadingReport)
            const Positioned.fill(child: _ReportLoadingOverlay()),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return _ReportBranchSelector(
      isLoading: _loadingBranches,
      branches: _branchOptions,
      selectedBranchId: _selectedBranchId,
      onBranchSelected: (branch) => _loadReport(branch.branchId),
    );
  }

  Widget _buildModuleTabs() {
    return _ReportSection(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: OwnerSalesReportModule.values.asMap().entries.map((entry) {
          final index = entry.key;
          final module = entry.value;
          final selected = module == _module;
          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: const Color(0xFFE4DDD6),
                  ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      if (_module == module) return;
                      setState(() {
                        _module = module;
                        _data = const {};
                      });
                      final branchId = _selectedBranchId;
                      if (branchId != null) {
                        await _loadReport(branchId, saveSelection: false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.starColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        module.title(context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : const Color(0xFF6B5B4D),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.starColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'Playfair Display',
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B5B4D),
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildPeriodSelector()),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {
                Fluttertoast.showToast(msg: context.t('Export is coming soon'));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1C1917),
                side: const BorderSide(color: Color(0xFFE6D6C6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(context.t('Export')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6D6C6)),
      ),
      child: Row(
        children: _periods.map((period) {
          final selected = period.key == _selectedRange;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _changeRange(period.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.starColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t(period.label),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFF6B5B4D),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _periodLabel(String key) {
    for (final period in _periods) {
      if (period.key == key) return context.t(period.label);
    }
    return context.t('This Month');
  }

  Widget _buildRevenueSales() {
    final page = _mapValue(_data['page']);
    final revenueTrend = _mapValue(_data['revenueTrend']);
    final paymentMethod = _mapValue(_data['revenueByPaymentMethod']);
    final serviceCategory = _mapValue(_data['revenueByServiceCategory']);
    final topServices = _mapValue(_data['topServicesByRevenue']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(
          title: _cleanText(page['title']).isEmpty
              ? context.t('Revenue & Sales')
              : _cleanText(page['title']),
          subtitle: _cleanText(page['subtitle']).isEmpty
              ? context.t('Track your revenue, sales performance and growth.')
              : _cleanText(page['subtitle']),
        ),
        const SizedBox(height: 16),
        _buildSummaryCards(_mapList(_data['summaryCards'])),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final trendCard = _RevenueTrendCard(
              data: revenueTrend,
              cleanText: _cleanText,
              asDouble: _asDouble,
              periodLabel: _periodLabel(_selectedRange),
            );
            final paymentCard = _PaymentMethodCard(
              data: paymentMethod,
              cleanText: _cleanText,
              asDouble: _asDouble,
            );
            final categoryCard = _CategoryRevenueCard(
              data: serviceCategory,
              cleanText: _cleanText,
              asDouble: _asDouble,
            );
            final topServicesCard = _TopServicesCard(
              data: topServices,
              cleanText: _cleanText,
              onViewAllServices: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const BottomNav(tabIndex: 2)),
                  (route) => false,
                );
              },
            );

            if (constraints.maxWidth >= 760) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: trendCard),
                      const SizedBox(width: 16),
                      Expanded(child: paymentCard),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: categoryCard),
                      const SizedBox(width: 16),
                      Expanded(child: topServicesCard),
                    ],
                  ),
                ],
              );
            }

            return Column(
              children: [
                trendCard,
                const SizedBox(height: 16),
                paymentCard,
                const SizedBox(height: 16),
                categoryCard,
                const SizedBox(height: 16),
                topServicesCard,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStaffPerformance() {
    final summary = _mapValue(_data['summary']);
    final rows = _mapList(_data['staffPerformance']);
    final pagination = _mapValue(_data['pagination']);
    final from = _asInt(pagination['from']);
    final to = _asInt(pagination['to']);
    final total = _asInt(pagination['totalRecords']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(
          title: context.t('Staff Performance'),
          subtitle: '',
        ),
        const SizedBox(height: 16),
        _buildSummaryCards([
          {
            'title': context.t('Total Staff'),
            'displayValue': '${summary['totalStaff'] ?? 0}',
          },
          {
            'title': context.t('Total Revenue'),
            'displayValue': formatMinorAmount(summary['totalRevenue'],
                trimZeroDecimals: true),
          },
          {
            'title': context.t('Avg Revenue / Staff'),
            'displayValue': formatMinorAmount(
              summary['averageRevenuePerStaff'],
              trimZeroDecimals: true,
            ),
          },
          {
            'title': context.t('Avg Rating'),
            'displayValue': '${summary['averageRating'] ?? 0}',
          },
        ]),
        const SizedBox(height: 16),
        _ReportSection(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useTable = constraints.maxWidth >= 680;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (useTable) const _StaffPerformanceTableHeader(),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: _ReportEmptyState(
                        icon: Icons.groups_outlined,
                        title: context.t('No staff performance data'),
                        message: context
                            .t('No staff activity found for this range.'),
                        compact: true,
                      ),
                    )
                  else
                    ...rows.map((row) {
                      return useTable
                          ? _StaffPerformanceRow(
                              row: row,
                              cleanText: _cleanText,
                            )
                          : _StaffPerformanceMobileRow(
                              row: row,
                              cleanText: _cleanText,
                            );
                    }),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      total == 0
                          ? context.t('Showing 0 results')
                          : 'Showing $from to $to of $total results',
                      style: const TextStyle(
                        color: Color(0xFF78716C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 420
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
            mainAxisExtent: 118,
          ),
          itemBuilder: (context, index) => _ReportSummaryCard(
            data: cards[index],
            cleanText: _cleanText,
          ),
        );
      },
    );
  }

  Map<String, dynamic> _operationSummaryCard({
    required String title,
    required Map<String, dynamic> metric,
    String? suffix,
  }) {
    final value =
        _cleanText(metric['value']).isEmpty ? '0' : _cleanText(metric['value']);
    final changeType = _cleanText(metric['changeType']).toLowerCase();
    final percentageChange = metric.containsKey('percentageChange')
        ? '${metric['percentageChange'] ?? 0}%'
        : '${metric['changeValue'] ?? 0}${suffix == null ? '' : ' $suffix'}';
    return {
      'title': title,
      'displayValue': suffix == null ? value : '$value $suffix',
      'comparison': {
        'type': changeType.isEmpty ? 'flat' : changeType,
        'displayValue': changeType == 'increase'
            ? '+$percentageChange'
            : changeType == 'decrease'
                ? '-$percentageChange'
                : percentageChange,
        'label': context.t('vs last month'),
      },
    };
  }

  Widget _buildOperations() {
    final summary = _mapValue(_data['summary']);
    final page = _mapValue(_data['page']);
    final charts = _mapValue(_data['charts']);
    final appointmentsOverview =
        _mapValue(charts['appointmentsOverview']).isNotEmpty
            ? _mapValue(charts['appointmentsOverview'])
            : _mapValue(_data['appointmentsOverview']);
    final peakBookingHours = _mapValue(charts['peakBookingHours']).isNotEmpty
        ? _mapValue(charts['peakBookingHours'])
        : _mapValue(_data['peakBookingHours']);
    final bookingStatus = _mapValue(charts['bookingStatus']).isNotEmpty
        ? _mapValue(charts['bookingStatus'])
        : _mapValue(_data['bookingStatus']);
    final cancellationChart = _mapValue(charts['topCancellationReasons']);
    final cancellationReasons = _mapList(cancellationChart['data']).isNotEmpty
        ? _mapList(cancellationChart['data'])
        : _mapList(_data['topCancellationReasons']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(
          title: _cleanText(page['title']).isEmpty
              ? context.t('Operations')
              : _cleanText(page['title']),
          subtitle: _cleanText(page['subtitle']).isEmpty
              ? context.t('Monitor daily operations and business efficiency.')
              : _cleanText(page['subtitle']),
        ),
        const SizedBox(height: 16),
        _buildSummaryCards([
          _operationSummaryCard(
            title: context.t('Total Appointments'),
            metric: _mapValue(summary['totalAppointments']),
          ),
          _operationSummaryCard(
            title: context.t('Completed'),
            metric: _mapValue(summary['completedAppointments']),
          ),
          _operationSummaryCard(
            title: context.t('Cancelled'),
            metric: _mapValue(summary['cancelledAppointments']),
          ),
          _operationSummaryCard(
            title: context.t('No Shows'),
            metric: _mapValue(summary['noShowAppointments']),
          ),
          _operationSummaryCard(
            title: context.t('Avg. Service Time'),
            metric: _mapValue(summary['averageServiceTime']),
            suffix: context.t('minutes'),
          ),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final overviewCard = _OperationsOverviewCard(
              data: appointmentsOverview,
              cleanText: _cleanText,
              asDouble: _asDouble,
            );
            final peakCard = _PeakBookingHoursCard(
              data: peakBookingHours,
              cleanText: _cleanText,
              asDouble: _asDouble,
            );
            final statusCard = _BookingStatusCard(
              data: bookingStatus,
              cleanText: _cleanText,
              asDouble: _asDouble,
            );
            final cancellationCard = _CancellationReasonsCard(
              title: _cleanText(cancellationChart['title']),
              emptyMessage: _cleanText(cancellationChart['emptyMessage']),
              rows: cancellationReasons,
              cleanText: _cleanText,
            );

            if (constraints.maxWidth >= 760) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: overviewCard),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: peakCard),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: statusCard),
                      const SizedBox(width: 16),
                      Expanded(child: cancellationCard),
                    ],
                  ),
                ],
              );
            }

            return Column(
              children: [
                overviewCard,
                const SizedBox(height: 16),
                peakCard,
                const SizedBox(height: 16),
                statusCard,
                const SizedBox(height: 16),
                cancellationCard,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OperationsOverviewCard extends StatelessWidget {
  const _OperationsOverviewCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  Widget build(BuildContext context) {
    final rows = data['data'] is List
        ? (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Appointments Overview'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PeriodBadge(
                label: cleanText(data['periodLabel']).isEmpty
                    ? context.t('This Month')
                    : cleanText(data['periodLabel']),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _ChartLegendDot(label: 'Completed', color: Color(0xFF7A5A10)),
              _ChartLegendDot(label: 'Cancelled', color: Color(0xFFB48A45)),
              _ChartLegendDot(label: 'No Shows', color: Color(0xFFE75A70)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: rows.isEmpty
                ? _ReportEmptyState(
                    icon: Icons.event_note_outlined,
                    title: context.t('No appointments overview data'),
                    message:
                        context.t('No appointments overview data available.'),
                    compact: true,
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _OperationsOverviewPainter(
                      rows: rows,
                      cleanText: cleanText,
                      asDouble: asDouble,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeakBookingHoursCard extends StatelessWidget {
  const _PeakBookingHoursCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  Widget build(BuildContext context) {
    final rows = data['data'] is List
        ? (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final maxBookings = rows
        .map((row) => asDouble(row['bookingCount'] ?? row['bookings']))
        .fold<double>(0, math.max);

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Peak Booking Hours'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty || maxBookings <= 0)
            _ReportEmptyState(
              icon: Icons.alarm_rounded,
              title: context.t('No peak booking hour data'),
              message: context.t('No peak booking hour data available.'),
              compact: true,
            )
          else
            SizedBox(
              height: 210,
              child: CustomPaint(
                size: Size.infinite,
                painter: _PeakBookingHoursPainter(
                  rows: rows,
                  cleanText: cleanText,
                  asDouble: asDouble,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingStatusCard extends StatelessWidget {
  const _BookingStatusCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  Widget build(BuildContext context) {
    final statusData = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : const <String, dynamic>{};
    final rows = [
      _statusRow(context.t('Pending'), statusData['pending']),
      _statusRow(context.t('Confirmed'), statusData['confirmed']),
      _statusRow(context.t('Approved'), statusData['approved']),
      _statusRow(context.t('Completed'), statusData['completed']),
      _statusRow(context.t('In Progress'), statusData['inProgress']),
      _statusRow(context.t('Cancelled'), statusData['cancelled']),
      _statusRow(context.t('No Show'), statusData['noShow']),
      _statusRow(context.t('Hold'), statusData['hold']),
      _statusRow(context.t('Expired'), statusData['expired']),
      _statusRow(context.t('Other'), statusData['other']),
    ];
    const colors = [
      Color(0xFF7A5A10),
      Color(0xFFB48A45),
      Color(0xFFE75A70),
      Color(0xFF4CAF50),
      Color(0xFF2F80ED),
      Color(0xFFF59E0B),
      Color(0xFF9C27B0),
      Color(0xFF795548),
      Color(0xFF607D8B),
      Color(0xFF26A69A),
    ];
    final hasData = rows.any((row) => asDouble(row['count']) > 0);

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Booking Status'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          if (!hasData)
            _ReportEmptyState(
              icon: Icons.show_chart_rounded,
              title: context.t('No booking status data'),
              message: context.t('No booking status data available.'),
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final donut = SizedBox(
                  width: compact ? 96 : 128,
                  height: compact ? 96 : 128,
                  child: CustomPaint(
                    painter: _PaymentDonutPainter(
                      rows: rows,
                      colors: colors,
                      asDouble: asDouble,
                    ),
                  ),
                );
                final legend = Column(
                  children: rows.asMap().entries.map((entry) {
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: colors[entry.key % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cleanText(row['paymentMethod']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${_formatPercent(asDouble(row['percentage']))}% (${cleanText(row['count'])})',
                            style: const TextStyle(
                              color: Color(0xFF78716C),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
                if (compact) {
                  return Column(
                    children: [
                      Center(child: donut),
                      const SizedBox(height: 16),
                      legend,
                    ],
                  );
                }
                return Row(
                  children: [
                    donut,
                    const SizedBox(width: 20),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Map<String, dynamic> _statusRow(String label, dynamic value) {
    final map = value is Map ? Map<String, dynamic>.from(value) : const {};
    return {
      'paymentMethod': label,
      'percentage': map['percentage'] ?? 0,
      'count': map['count'] ?? 0,
    };
  }
}

class _CancellationReasonsCard extends StatelessWidget {
  const _CancellationReasonsCard({
    required this.title,
    required this.emptyMessage,
    required this.rows,
    required this.cleanText,
  });

  final String title;
  final String emptyMessage;
  final List<Map<String, dynamic>> rows;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? context.t('Top Cancellation Reasons') : title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEAD7BF)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFE11D48),
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage.isEmpty
                        ? context.t('No cancellation reasons available.')
                        : emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            ...rows.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cleanText(row['reason']).isEmpty
                            ? context.t('Unknown reason')
                            : cleanText(row['reason']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      cleanText(row['count']).isEmpty
                          ? '0'
                          : cleanText(row['count']),
                      style: TextStyle(
                        color: AppColors.starColor,
                        fontWeight: FontWeight.w900,
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

class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6D6C6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.starColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          context.t(label),
          style: const TextStyle(
            color: Color(0xFF6B5B4D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReportPeriod {
  const _ReportPeriod(this.key, this.label);

  final String key;
  final String label;
}

class _ReportBranchOption {
  const _ReportBranchOption({
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

class _ReportBranchSelector extends StatelessWidget {
  const _ReportBranchSelector({
    required this.isLoading,
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  final bool isLoading;
  final List<_ReportBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<_ReportBranchOption> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    _ReportBranchOption? selected;
    for (final branch in branches) {
      if (branch.branchId == selectedBranchId) {
        selected = branch;
        break;
      }
    }

    if (isLoading) {
      return const _SharedBranchSelectorShell(
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
      return _SharedBranchSelectorShell(
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

class _SharedBranchSelectorShell extends StatelessWidget {
  const _SharedBranchSelectorShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9CBBB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
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
        borderRadius: BorderRadius.circular(10),
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

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.data,
    required this.cleanText,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final title = cleanText(data['title']).isEmpty
        ? cleanText(data['label'])
        : cleanText(data['title']);
    final value = cleanText(data['displayValue']).isEmpty
        ? cleanText(data['formatted_value']).isEmpty
            ? _formatSummaryValue(data)
            : cleanText(data['formatted_value'])
        : cleanText(data['displayValue']);
    final comparison = data['comparison'] is Map
        ? Map<String, dynamic>.from(data['comparison'] as Map)
        : const <String, dynamic>{};
    final comparisonType = cleanText(comparison['type']).toLowerCase();
    final comparisonColor = comparisonType == 'increase'
        ? const Color(0xFF047857)
        : comparisonType == 'decrease'
            ? const Color(0xFFBE123C)
            : const Color(0xFF78716C);
    final comparisonIcon = comparisonType == 'increase'
        ? '↑'
        : comparisonType == 'decrease'
            ? '↓'
            : '•';
    final comparisonText = cleanText(comparison['displayValue']);
    final comparisonLabel = cleanText(comparison['label']);

    return _ReportSection(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFFA08F7F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? '0' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          if (comparisonText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '$comparisonIcon $comparisonText $comparisonLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: comparisonColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSummaryValue(Map<String, dynamic> data) {
    final moneyValue = data['majorValue'] ?? data['minorValue'];
    if (moneyValue != null) {
      return formatMinorAmount(moneyValue, trimZeroDecimals: true);
    }
    return cleanText(data['value']).isEmpty
        ? cleanText(data['count'])
        : cleanText(data['value']);
  }
}

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
    required this.periodLabel,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final rows = data['data'] is List
        ? (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cleanText(data['title']).isEmpty
                      ? context.t('Revenue Trend')
                      : cleanText(data['title']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PeriodBadge(label: periodLabel),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: rows.isEmpty
                ? _ReportEmptyState(
                    icon: Icons.insert_chart_outlined_rounded,
                    title: context.t('No revenue trend data'),
                    message:
                        context.t('No trend data available for this range.'),
                    compact: true,
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _RevenueBarPainter(
                      rows: rows,
                      cleanText: cleanText,
                      asDouble: asDouble,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  Widget build(BuildContext context) {
    final rows = data['data'] is List
        ? (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    const colors = [
      Color(0xFF7A5A10),
      Color(0xFFB48A45),
      Color(0xFFD8AE64),
      Color(0xFFE7C98B),
    ];
    final totalRevenue = cleanText(data['displayTotalRevenue']).isEmpty
        ? cleanText(data['formattedTotalRevenue']).isEmpty
            ? formatMinorAmount(
                data['majorTotalRevenue'] ?? data['totalRevenue'],
                trimZeroDecimals: true,
              )
            : cleanText(data['formattedTotalRevenue'])
        : cleanText(data['displayTotalRevenue']);

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanText(data['title']).isEmpty
                ? context.t('Revenue by Payment Method')
                : cleanText(data['title']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty ||
              rows.every((row) => asDouble(row['percentage']) <= 0))
            _ReportEmptyState(
              icon: Icons.credit_card_rounded,
              title: context.t('No payment method data'),
              message: context.t('No payment method data available.'),
              compact: true,
            )
          else ...[
            Center(
              child: SizedBox(
                width: 142,
                height: 142,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _PaymentDonutPainter(
                        rows: rows,
                        colors: colors,
                        asDouble: asDouble,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.t('Total'),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          totalRevenue.isEmpty
                              ? formatMinorAmount(0, trimZeroDecimals: true)
                              : totalRevenue,
                          style: const TextStyle(
                            color: Color(0xFF231F20),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...rows.asMap().entries.map((entry) {
              final row = entry.value;
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cleanText(row['paymentMethod']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${cleanText(row['percentage'])}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      cleanText(row['displayAmount']).isNotEmpty
                          ? cleanText(row['displayAmount'])
                          : formatMinorAmount(
                              row['majorAmount'] ??
                                  row['amount'] ??
                                  row['totalAmount'] ??
                                  row['revenue'],
                              trimZeroDecimals: true,
                            ),
                      style: TextStyle(
                        color: AppColors.starColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _CategoryRevenueCard extends StatelessWidget {
  const _CategoryRevenueCard({
    required this.data,
    required this.cleanText,
    required this.asDouble,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  Widget build(BuildContext context) {
    final rows = data['data'] is List
        ? (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanText(data['title']).isEmpty
                ? context.t('Revenue by Service Category')
                : cleanText(data['title']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            _ReportEmptyState(
              icon: Icons.category_outlined,
              title: context.t('No service category data'),
              message: context.t('No service category data available.'),
              compact: true,
            )
          else
            ...rows.map((row) {
              final percent = asDouble(row['percentage']).clamp(0, 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cleanText(row['categoryName']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          cleanText(row['displayRevenue']).isNotEmpty
                              ? cleanText(row['displayRevenue'])
                              : formatMinorAmount(
                                  row['majorRevenue'] ??
                                      row['revenueMinor'] ??
                                      row['revenue'],
                                  trimZeroDecimals: true,
                                ),
                          style: TextStyle(
                            color: AppColors.starColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${percent.toStringAsFixed(percent == percent.roundToDouble() ? 0 : 1)}%',
                          style: const TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1EBE6),
                        color: AppColors.starColor,
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

class _TopServicesCard extends StatelessWidget {
  const _TopServicesCard({
    required this.data,
    required this.cleanText,
    required this.onViewAllServices,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final VoidCallback onViewAllServices;

  @override
  Widget build(BuildContext context) {
    final rows = data['rows'] is List
        ? (data['rows'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final viewAllEnabled = data['viewAllEnabled'] == true || rows.isNotEmpty;
    final viewAllLabel = cleanText(data['viewAllLabel']).isEmpty
        ? context.t('View all services')
        : cleanText(data['viewAllLabel']);

    return _ReportSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanText(data['title']).isEmpty
                ? context.t('Top Services by Revenue')
                : cleanText(data['title']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            _ReportEmptyState(
              icon: Icons.star_border_rounded,
              title: context.t('No top service data'),
              message: context.t('No top service data available.'),
              compact: true,
            )
          else
            ...rows.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    _RankBadge(rank: row['rank']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanText(row['serviceName']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${row['totalBookings'] ?? 0} bookings',
                            style: const TextStyle(
                              color: Color(0xFF78716C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      cleanText(row['displayRevenue']).isNotEmpty
                          ? cleanText(row['displayRevenue'])
                          : formatMinorAmount(
                              row['majorRevenue'] ??
                                  row['revenueMinor'] ??
                                  row['revenue'],
                              trimZeroDecimals: true,
                            ),
                      style: TextStyle(
                        color: AppColors.starColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (viewAllEnabled) ...[
            const Divider(height: 20, color: Color(0xFFF1EBE6)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAllServices,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.starColor,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text('$viewAllLabel →'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffPerformanceTableHeader extends StatelessWidget {
  const _StaffPerformanceTableHeader();

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: Color(0xFF8B7B6C),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF8),
        border: Border(bottom: BorderSide(color: Color(0xFFE8D8C8))),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 54,
              child: Text(context.t('Rank').toUpperCase(), style: headerStyle)),
          Expanded(
              flex: 3,
              child:
                  Text(context.t('Staff').toUpperCase(), style: headerStyle)),
          Expanded(
              child:
                  Text(context.t('Revenue').toUpperCase(), style: headerStyle)),
          Expanded(
              child: Text(context.t('Services').toUpperCase(),
                  style: headerStyle)),
          Expanded(
              child:
                  Text(context.t('Clients').toUpperCase(), style: headerStyle)),
          Expanded(
              child: Text(context.t('Avg. Rating').toUpperCase(),
                  style: headerStyle)),
          Expanded(
              child: Text(context.t('Rebook Rate').toUpperCase(),
                  style: headerStyle)),
        ],
      ),
    );
  }
}

class _StaffPerformanceRow extends StatelessWidget {
  const _StaffPerformanceRow({
    required this.row,
    required this.cleanText,
  });

  final Map<String, dynamic> row;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final name = cleanText(row['name']);
    final initial = name.isEmpty ? 'S' : name.characters.first.toUpperCase();
    final rowStyle = const TextStyle(
      color: Color(0xFF1C1917),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8D8C8))),
      ),
      child: Row(
        children: [
          SizedBox(width: 54, child: _RankBadge(rank: row['rank'])),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFF1EBE6),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.starColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isEmpty ? context.t('Staff') : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rowStyle.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              formatMinorAmount(row['revenue'], trimZeroDecimals: true),
              style: rowStyle.copyWith(color: AppColors.starColor),
            ),
          ),
          Expanded(
              child: Text('${row['totalServices'] ?? 0}', style: rowStyle)),
          Expanded(child: Text('${row['totalClients'] ?? 0}', style: rowStyle)),
          Expanded(
              child: Text('${row['averageRating'] ?? 0}', style: rowStyle)),
          Expanded(child: Text('${row['rebookRate'] ?? 0}', style: rowStyle)),
        ],
      ),
    );
  }
}

class _StaffPerformanceMobileRow extends StatelessWidget {
  const _StaffPerformanceMobileRow({
    required this.row,
    required this.cleanText,
  });

  final Map<String, dynamic> row;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final name = cleanText(row['name']);
    final initial = name.isEmpty ? 'S' : name.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8D8C8))),
      ),
      child: Row(
        children: [
          _RankBadge(rank: row['rank']),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF1EBE6),
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.starColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.t('Staff') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _MiniMetric(
                      label: context.t('Services'),
                      value: '${row['totalServices'] ?? 0}',
                    ),
                    _MiniMetric(
                      label: context.t('Clients'),
                      value: '${row['totalClients'] ?? 0}',
                    ),
                    _MiniMetric(
                      label: context.t('Rating'),
                      value: '${row['averageRating'] ?? 0}',
                    ),
                    _MiniMetric(
                      label: context.t('Rebook'),
                      value: '${row['rebookRate'] ?? 0}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMinorAmount(row['revenue'], trimZeroDecimals: true),
            style: TextStyle(
              color: AppColors.starColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: Color(0xFF78716C),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final dynamic rank;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse('${rank ?? ''}') ?? 0;
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return SizedBox(
      width: 28,
      child: Text(
        medals[value] ?? '$value',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: compact ? 22 : 42,
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 28 : 42, color: AppColors.starColor),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF78716C), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReportLoadingOverlay extends StatelessWidget {
  const _ReportLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: const Color(0x66FBF9F8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const CircularProgressIndicator(color: AppColors.starColor),
        ),
      ),
    );
  }
}

class _PeakBookingHoursPainter extends CustomPainter {
  const _PeakBookingHoursPainter({
    required this.rows,
    required this.cleanText,
    required this.asDouble,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF1E7DC)
      ..strokeWidth = 1;
    final barPaint = Paint()..color = AppColors.starColor;
    final chartTop = 8.0;
    final chartLeft = 30.0;
    final chartRight = size.width - 4;
    final chartBottom = size.height - 32;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxBookings = rows
        .map((row) => asDouble(row['bookingCount'] ?? row['bookings']))
        .fold<double>(0, math.max);
    final yAxisMax = math.max(4, maxBookings.ceil()).toDouble();

    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      final label = (yAxisMax * (4 - i) / 4).round().toString();
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      _drawText(
        canvas,
        label,
        Offset(0, y - 7),
        const Color(0xFFB6A89B),
        10,
        maxWidth: 24,
      );
    }

    final slotWidth = chartWidth / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final bookings = asDouble(row['bookingCount'] ?? row['bookings']);
      final barHeight = bookings <= 0 ? 0.0 : chartHeight * bookings / yAxisMax;
      final barWidth = math.min(34.0, slotWidth * 0.38);
      final left = chartLeft + slotWidth * i + (slotWidth - barWidth) / 2;
      final rect = Rect.fromLTWH(
        left,
        chartBottom - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        barPaint,
      );
      _drawText(
        canvas,
        _formatHourLabel(row),
        Offset(
            chartLeft + slotWidth * i + slotWidth / 2 - 28, chartBottom + 12),
        const Color(0xFF9CA3AF),
        10,
        maxWidth: 56,
        align: TextAlign.center,
      );
    }
  }

  String _formatHourLabel(Map<String, dynamic> row) {
    final label = cleanText(row['label']);
    if (label.isNotEmpty) return label;
    return _formatHour(cleanText(row['hour']));
  }

  String _formatHour(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    double maxWidth = 72,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PeakBookingHoursPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _OperationsOverviewPainter extends CustomPainter {
  const _OperationsOverviewPainter({
    required this.rows,
    required this.cleanText,
    required this.asDouble,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF1E7DC)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFE8D8C8)
      ..strokeWidth = 1;
    final chartTop = 8.0;
    final chartLeft = 28.0;
    final chartRight = size.width - 8;
    final chartBottom = size.height - 32;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = rows
        .expand((row) => [
              asDouble(row['completed']),
              asDouble(row['cancelled']),
              asDouble(row['noShow']),
            ])
        .fold<double>(0, math.max);
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      _drawText(
        canvas,
        '${(scaleMax * (4 - i) / 4).round()}',
        Offset(0, y - 7),
        const Color(0xFFB6A89B),
        10,
        maxWidth: 24,
      );
    }
    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );

    _drawSeries(
      canvas,
      chartLeft,
      chartTop,
      chartWidth,
      chartHeight,
      chartBottom,
      scaleMax,
      'completed',
      const Color(0xFF7A5A10),
    );
    _drawSeries(
      canvas,
      chartLeft,
      chartTop,
      chartWidth,
      chartHeight,
      chartBottom,
      scaleMax,
      'cancelled',
      const Color(0xFFB48A45),
    );
    _drawSeries(
      canvas,
      chartLeft,
      chartTop,
      chartWidth,
      chartHeight,
      chartBottom,
      scaleMax,
      'noShow',
      const Color(0xFFE75A70),
    );

    for (var i = 0; i < rows.length; i++) {
      final x = rows.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * i / (rows.length - 1);
      _drawText(
        canvas,
        cleanText(rows[i]['label']),
        Offset(x - 28, chartBottom + 12),
        const Color(0xFF9CA3AF),
        10,
        maxWidth: 56,
        align: TextAlign.center,
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double chartBottom,
    double scaleMax,
    String key,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();

    for (var i = 0; i < rows.length; i++) {
      final value = asDouble(rows[i][key]);
      final x = rows.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * i / (rows.length - 1);
      final y = chartBottom - chartHeight * (value / scaleMax);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
    for (var i = 0; i < rows.length; i++) {
      final value = asDouble(rows[i][key]);
      final x = rows.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * i / (rows.length - 1);
      final y = chartBottom - chartHeight * (value / scaleMax);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 4, pointBorderPaint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    double maxWidth = 72,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _OperationsOverviewPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _RevenueBarPainter extends CustomPainter {
  const _RevenueBarPainter({
    required this.rows,
    required this.cleanText,
    required this.asDouble,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(dynamic value) cleanText;
  final double Function(dynamic value) asDouble;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xFFE8D8C8)
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = const Color(0xFFF1E7DC)
      ..strokeWidth = 1;
    final barPaint = Paint()..color = AppColors.starColor;
    final maxRevenue = rows
        .map((row) => asDouble(row['majorRevenue'] ?? row['revenue']))
        .fold<double>(0, math.max);
    final maxValue = maxRevenue <= 0 ? 1 : maxRevenue;
    final chartTop = 10.0;
    final chartBottom = size.height - 34;
    final chartHeight = chartBottom - chartTop;

    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
        Offset(0, chartBottom), Offset(size.width, chartBottom), axisPaint);

    final slotWidth = size.width / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final value = asDouble(row['majorRevenue'] ?? row['revenue']);
      final barHeight = value <= 0 ? 0.0 : chartHeight * (value / maxValue);
      final barWidth = math.min(42.0, slotWidth * 0.48);
      final left = slotWidth * i + (slotWidth - barWidth) / 2;
      final rect = Rect.fromLTWH(
        left,
        chartBottom - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        barPaint,
      );
      _drawText(
        canvas,
        cleanText(row['label']),
        Offset(slotWidth * i + slotWidth / 2, chartBottom + 12),
        const Color(0xFF9CA3AF),
        10,
        align: TextAlign.center,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: FontWeight.w600),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: 72);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _RevenueBarPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _PaymentDonutPainter extends CustomPainter {
  const _PaymentDonutPainter({
    required this.rows,
    required this.colors,
    required this.asDouble,
  });

  final List<Map<String, dynamic>> rows;
  final List<Color> colors;
  final double Function(dynamic value) asDouble;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    var startAngle = -math.pi / 2;
    for (var i = 0; i < rows.length; i++) {
      final percent = asDouble(rows[i]['percentage']).clamp(0, 100);
      if (percent <= 0) continue;
      final sweep = 2 * math.pi * (percent / 100);
      paint.color = colors[i % colors.length];
      canvas.drawArc(
          rect.deflate(strokeWidth / 2), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}
