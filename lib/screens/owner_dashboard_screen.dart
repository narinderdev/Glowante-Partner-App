import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _dashboard = const {};
  StylistBranchSelection _selection = const StylistBranchSelection();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await _apiService.getReportsDashboard();
      if (!mounted) return;
      setState(() {
        _selection = selection;
        _dashboard = response['data'] is Map<String, dynamic>
            ? response['data']
            : const {};
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _formatMinorCurrency(dynamic value) {
    final minor = _asInt(value);
    return '₹${(minor / 100).toStringAsFixed(2)}';
  }

  String _selectedSalonLabel() {
    final label = _selection.salonName.trim();
    return label.isEmpty ? translateText('All Salons') : label;
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_dashboard['summary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final bookingStatusCounts =
        ((_dashboard['bookingStatusCounts'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final topSalonsByRevenue =
        ((_dashboard['topSalonsByRevenue'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final topServicesByBookings =
        ((_dashboard['topServicesByBookings'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final topRatedSalons = ((_dashboard['topRatedSalons'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final totalBookingsByStatus = bookingStatusCounts
        .map(
          (item) => _MetricBarItem(
            label: (item['status'] ?? '').toString(),
            value: _asInt(item['count']).toDouble(),
            valueLabel: '${_asInt(item['count'])}',
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Dashboard')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _DashboardHeaderCard(
              title: context.t('Showing Reports For'),
              value: _selectedSalonLabel(),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 420;
                  return GridView.count(
                    crossAxisCount: isNarrow ? 1 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isNarrow ? 2.35 : 1.1,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      _SummaryCard(
                        title: context.t('Total Salons'),
                        value: '${_asInt(summary['salons'])}',
                        icon: Icons.store_mall_directory_outlined,
                      ),
                      _SummaryCard(
                        title: context.t('Total Branches'),
                        value: '${_asInt(summary['branches'])}',
                        icon: Icons.storefront_outlined,
                      ),
                      _SummaryCard(
                        title: context.t('Team Members'),
                        value: '${_asInt(summary['teamMembers'])}',
                        icon: Icons.groups_2_outlined,
                      ),
                      _SummaryCard(
                        title: context.t('Total Active Services'),
                        value: '${_asInt(summary['services'])}',
                        icon: Icons.content_cut_outlined,
                      ),
                      _SummaryCard(
                        title: context.t('Total Bookings'),
                        value: '${_asInt(summary['bookings'])}',
                        icon: Icons.calendar_today_outlined,
                      ),
                      _RevenueCard(
                        title: context.t('Completed Revenue'),
                        value: _formatMinorCurrency(summary['revenueMinor']),
                        statusCounts: bookingStatusCounts,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: context.t('Revenue By Top Salons'),
                child: _SimpleBarList(
                  items: topSalonsByRevenue
                      .take(5)
                      .map(
                        (item) => _MetricBarItem(
                          label: (item['salonName'] ?? '').toString(),
                          value: _asInt(item['revenueMinor']).toDouble(),
                          valueLabel:
                              _formatMinorCurrency(item['revenueMinor']),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: context.t('Most Booked Services'),
                child: _SimpleBarList(
                  items: topServicesByBookings
                      .take(5)
                      .map(
                        (item) => _MetricBarItem(
                          label: (item['serviceName'] ?? '').toString(),
                          value: _asInt(item['bookings']).toDouble(),
                          valueLabel: '${_asInt(item['bookings'])}',
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: context.t('Booking Status Distribution'),
                child: _StatusDistribution(
                  items: bookingStatusCounts
                      .map(
                        (item) => _StatusCountItem(
                          label: (item['status'] ?? '').toString(),
                          count: _asInt(item['count']),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: context.t('Total Bookings by Status'),
                child: _SimpleBarList(items: totalBookingsByStatus),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: context.t('Top Rated Salons'),
                child: _SimpleBarList(
                  items: topRatedSalons
                      .take(5)
                      .map(
                        (item) => _MetricBarItem(
                          label: (item['salonName'] ?? '').toString(),
                          value: _asDouble(item['rating']),
                          valueLabel:
                              '${_asDouble(item['rating']).toStringAsFixed(1)} (${_asInt(item['reviewCount'])})',
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardHeaderCard extends StatelessWidget {
  const _DashboardHeaderCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D6B5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F1EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.starColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.starColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.title,
    required this.value,
    required this.statusCounts,
  });

  final String title;
  final String value;
  final List<Map<String, dynamic>> statusCounts;

  @override
  Widget build(BuildContext context) {
    final allItems = statusCounts
        .map(
          (entry) => _StatusCountItem(
            label: (entry['status'] ?? '').toString(),
            count: entry['count'] is num ? (entry['count'] as num).toInt() : 0,
          ),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight > 0 && constraints.maxHeight < 145;
        final items = allItems.take(isCompact ? 2 : 3).toList();
        final titleStyle = TextStyle(
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: const Color(0xFFB45309),
        );
        final valueStyle = TextStyle(
          fontSize: isCompact ? 20 : 24,
          fontWeight: FontWeight.w700,
          color: AppColors.starColor,
        );
        final legendStyle = TextStyle(
          fontSize: isCompact ? 10 : 11,
          color: const Color(0xFF78716C),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1D6B5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    SizedBox(height: isCompact ? 4 : 8),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                    SizedBox(height: isCompact ? 6 : 10),
                    ...items.map(
                      (item) => Padding(
                        padding: EdgeInsets.only(bottom: isCompact ? 2 : 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _statusColor(item.label),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${item.label.toUpperCase()} (${item.count})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: legendStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              SizedBox(
                width: isCompact ? 72 : 88,
                height: isCompact ? 72 : 88,
                child: CustomPaint(
                  painter: _DonutPainter(items: items),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D6B5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricBarItem {
  const _MetricBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
  });

  final String label;
  final double value;
  final String valueLabel;
}

class _SimpleBarList extends StatelessWidget {
  const _SimpleBarList({
    required this.items,
  });

  final List<_MetricBarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        context.t('No data available'),
        style: const TextStyle(color: Color(0xFF78716C)),
      );
    }

    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return Column(
      children: items.map((item) {
        final factor = maxValue <= 0 ? 0.0 : (item.value / maxValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.valueLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.starColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: factor.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF5EDE3),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.starColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusCountItem {
  const _StatusCountItem({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class _StatusDistribution extends StatelessWidget {
  const _StatusDistribution({
    required this.items,
  });

  final List<_StatusCountItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        context.t('No data available'),
        style: const TextStyle(color: Color(0xFF78716C)),
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      children: items.map((item) {
        final ratio = total == 0 ? 0.0 : item.count / total;
        final color = _statusColor(item.label);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  item.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: const Color(0xFFF5EDE3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: Text(
                  '${item.count}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.items,
  });

  final List<_StatusCountItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<int>(0, (sum, item) => sum + item.count);
    final strokeWidth = size.width * 0.18;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    var startAngle = -math.pi / 2;
    for (final item in items) {
      final sweepAngle = total == 0 ? 0.0 : (item.count / total) * 2 * math.pi;
      paint.color = _statusColor(item.label);
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return const Color(0xFFEAA36F);
    case 'confirmed':
      return const Color(0xFFD58C5C);
    case 'in_progress':
    case 'in progress':
      return const Color(0xFFF3C27E);
    case 'cancelled':
      return const Color(0xFFDCB08E);
    case 'payment_pending':
      return const Color(0xFFF0B59D);
    default:
      return AppColors.starColor;
  }
}
