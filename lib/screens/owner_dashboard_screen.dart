import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/profile/compensation/profile_compensation_screen.dart';
import '../features/profile/operations/owner_profile_operations_screen.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import 'bottom_nav.dart';
import 'owner_branch_clients_screen.dart';
import 'owner_sales_reports_screen.dart';
import 'SalonReviews.dart';
const String _dashboardFontFamily = 'Manrope';
const Color _dashboardAccent = Color(0xFFC19A6B);
const Color _dashboardGold = Color(0xFF8B6500);
const Color _dashboardPrimaryText = Color(0xFF1C1917);
const Color _dashboardSecondaryText = Color(0xFF78716C);
const Color _dashboardBorder = Color(0xFFE7E5E4);

TextStyle _dashboardTextStyle({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _dashboardPrimaryText,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _dashboardFontFamily,
    fontFamilyFallback: const ['Inter'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final GlobalKey _branchSelectorKey = GlobalKey();
  final ApiService _apiService = ApiService();
int _notificationPage = 0;
static const int _notificationPageSize = 4;
  List<_DashboardBranchOption> _branchOptions = const [];
  int? _selectedBranchId;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dashboard = const {};
  String _profileImageUrl = '';
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
      final prefs = await SharedPreferences.getInstance();
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
        _profileImageUrl = _readProfileImageUrl(prefs);
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

  String _readProfileImageUrl(SharedPreferences prefs) {
    const keys = [
      'profilePictureUrl',
      'profile_picture_url',
      'profileImage',
      'profile_image',
      'imageUrl',
    ];
    for (final key in keys) {
      final value = prefs.getString(key)?.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
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
              _notificationPage = 0;
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
            address: _addressSummary(branch['address']),
          ),
        );
      }
    }
    return options;
  }

  String _addressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];
    for (final key in ['line1', 'line2', 'city', 'state']) {
      final value = _cleanText(address[key]);
      if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
    }
    return parts.take(2).join(', ');
  }

  _DashboardBranchOption? get _selectedBranchOption {
    final branchId = _selectedBranchId;
    if (branchId == null) return null;
    for (final option in _branchOptions) {
      if (option.branchId == branchId) return option;
    }
    return _branchOptions.isEmpty ? null : _branchOptions.first;
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

  String _dayPartGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.t('Good morning');
    if (hour < 17) return context.t('Good afternoon');
    return context.t('Good evening');
  }

  String _headerGreeting() {
    final header = _dashboard['header'];

    if (header is Map) {
      var greeting = _cleanText(header['greeting']);

      if (greeting.isNotEmpty) {
        greeting = greeting
            .replaceAll(':wave:', '')
            .replaceAll('👋', '')
            .replaceAll(
              RegExp(
                r'\bGood\s+(morning|afternoon|evening|night)\b',
                caseSensitive: false,
              ),
              '',
            )
            .replaceFirst(RegExp(r'^[\s,:\-]+'), '')
            .trim();

        return greeting.endsWith('!') ? greeting : '$greeting!';
      }
    }

    final selected = _selectedBranchOption;

    if (selected != null && selected.salonName.trim().isNotEmpty) {
      return '${selected.salonName.trim()}!';
    }

    return '';
  }

  String _headerSubtext() {
    final header = _dashboard['header'];
    if (header is Map) {
      final subtext = _cleanText(header['subtext']);
      if (subtext.isNotEmpty) return subtext;
    }
    return context.t("Here's what's happening at your salon today.");
  }

  void _openBookingsTab() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BottomNav(tabIndex: 1)),
      (route) => false,
    );
  }

  void _openDrawerRoute(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
  Future<void> _showBranchPicker() async {
  if (_branchOptions.length <= 1) return;

  final selectorContext = _branchSelectorKey.currentContext;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final selectorBox = selectorContext?.findRenderObject() as RenderBox?;

  if (overlay == null || selectorBox == null) return;

  final selectorOffset = selectorBox.localToGlobal(
    Offset.zero,
    ancestor: overlay,
  );

  final selectorRect = selectorOffset & selectorBox.size;
  final menuWidth = overlay.size.width - 32;

  final selected = await showMenu<_DashboardBranchOption>(
    context: context,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 10,
    position: RelativeRect.fromLTRB(
      16,
      selectorRect.bottom + 8,
      16,
      0,
    ),
    constraints: BoxConstraints(
      minWidth: menuWidth,
      maxWidth: menuWidth,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: _dashboardBorder),
    ),
    items: _branchOptions.map((option) {
      final isSelected = option.branchId == _selectedBranchId;

      return PopupMenuItem<_DashboardBranchOption>(
        value: option,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: _DashboardBranchDropdownItem(
          option: option,
          isSelected: isSelected,
        ),
      );
    }).toList(),
  );

  if (!mounted || selected == null) return;

  await _loadDashboard(selected.branchId);
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
      backgroundColor: const Color(0xFFFBFAF8),
      drawer: _DashboardDrawer(onOpen: _openDrawerRoute),
      appBar: buildProfileSubpageAppBar(
        title: context.t('Dashboard'),
        automaticallyImplyLeading: false,
        toolbarHeight: 58,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: context.t('Menu'),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _DashboardProfileAvatar(imageUrl: _profileImageUrl),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.starColor,
            onRefresh: _loadData,
            child: ListView(
             padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_errorMessage != null)
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
                      context.t('No Salons available'),
                      textAlign: TextAlign.center,
                    ),
                  )
         else ...[
  _buildBranchSelector(),
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildKpiCards(),
        const SizedBox(height: 18),
        _buildRevenueSection(),
        const SizedBox(height: 18),
        _buildTodayAndStaffSection(),
        const SizedBox(height: 18),
        _buildNotificationsSection(),
      ],
    ),
  ),
],
              ],
            ),
          ),
          if (_isLoadingDashboard)
            const Positioned.fill(child: _DashboardLoadingOverlay()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openBookingsTab,
        backgroundColor: AppColors.starColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

Widget _buildBranchSelector() {
  final selected = _selectedBranchOption;

  final selectedLabel = selected == null
      ? context.t('Select Branch')
      : selected.displayLabel;

  final selectedAddressSummary = selected?.address ?? '';
  final canChangeBranch = _branchOptions.length > 1;

  return Padding(
   padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: _DashboardHeaderBranchSelector(
      key: _branchSelectorKey,
      label: selectedLabel,
      addressSummary: selectedAddressSummary,
      isInteractive: canChangeBranch,
      onTap: canChangeBranch ? _showBranchPicker : null,
    ),
  );
}
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final name = _headerGreeting();
       final titleText = name.isEmpty
    ? '${_dayPartGreeting()}! 👋'
    : '${_dayPartGreeting()}, $name 👋';

final title = Text(
  titleText,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontSize: 21,
    height: 1.18,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  ),
);

        final subtitle = Text(
          _headerSubtext(),
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
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
              subtitle,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: dateButton,
              ),
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
                  const SizedBox(height: 4),
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
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 112,
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
          onOpenBookings: _openBookingsTab,
        );
        final staffCard = _StaffLiveStatusCard(
          data: _mapValue('staff_live_status'),
          cleanText: _cleanText,
          onOpenBookings: _openBookingsTab,
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
  final unreadCount = _asInt(notifications['unread_count']);

  final items = notifications['items'] is List
      ? (notifications['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  final totalPages = items.isEmpty
      ? 1
      : (items.length / _notificationPageSize).ceil();

  final safePage = _notificationPage.clamp(0, totalPages - 1);

  final pagedItems = items
      .skip(safePage * _notificationPageSize)
      .take(_notificationPageSize)
      .toList();

  return _DashboardSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('Notifications'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.starColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _EmptyDashedBox(
            icon: Icons.notifications_none_outlined,
            message: 'No notifications right now.',
          )
        else ...[
          ...pagedItems.map(
            (item) => _NotificationDashboardRow(
              item: item,
              cleanText: _cleanText,
            ),
          ),
          const SizedBox(height: 8),
          _NotificationPaginationBar(
            currentPage: safePage,
            totalPages: totalPages,
            onPrevious: safePage == 0
                ? null
                : () {
                    setState(() {
                      _notificationPage = safePage - 1;
                    });
                  },
            onNext: safePage >= totalPages - 1
                ? null
                : () {
                    setState(() {
                      _notificationPage = safePage + 1;
                    });
                  },
            onPageSelected: (page) {
              setState(() {
                _notificationPage = page;
              });
            },
          ),
        ],
      ],
    ),
  );
}
}

class _DashboardLoadingOverlay extends StatelessWidget {
  const _DashboardLoadingOverlay();

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
          child: const CircularProgressIndicator(
            color: AppColors.starColor,
          ),
        ),
      ),
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <_DashboardDrawerItem>[
      _DashboardDrawerItem(
        icon: Icons.inventory_2_outlined,
        label: context.t('Inventory'),
        screen: const OwnerProfileOperationsScreen(
          initialModule: OwnerOperationsModule.inventory,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.insert_chart_outlined_rounded,
        label: context.t('Reports'),
        screen: const OwnerSalesReportsScreen(
          initialModule: OwnerSalesReportModule.operations,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.payments_outlined,
        label: context.t('Payroll'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.payroll,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.event_available_outlined,
        label: context.t('Attendance'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.attendance,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.groups_outlined,
        label: context.t('Clients'),
        screen: const OwnerBranchClientsScreen(),
      ),
      _DashboardDrawerItem(
        icon: Icons.tune_rounded,
        label: context.t('Commission'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.commission,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.account_balance_wallet_outlined,
        label: context.t('Advance'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.advance,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.beach_access_outlined,
        label: context.t('Leaves'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.leaves,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.calendar_month_outlined,
        label: context.t('Holidays Calendar'),
        screen: const ProfileCompensationScreen(
          initialModule: CompensationModule.holidays,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.badge_outlined,
        label: context.t('Vendor'),
        screen: const OwnerProfileOperationsScreen(
          initialModule: OwnerOperationsModule.vendor,
        ),
      ),
      _DashboardDrawerItem(
        icon: Icons.rate_review_outlined,
        label: context.t('Reviews'),
        screen: const SalonReviews(),
      ),
    ];

  return SafeArea(
  top: true,
  bottom: false,
  child: Drawer(
    backgroundColor: const Color(0xFFFBF9F8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6E8C8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      color: AppColors.starColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('Glowante'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.starColor,
                          ),
                        ),
                        Text(
                          context.t('Salon Operations'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF756A61),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final highlighted = index == 0;
                    return Material(
                      color: highlighted
                          ? const Color(0xFFD0A244)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onOpen(item.screen),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: highlighted
                                    ? Colors.white
                                    : const Color(0xFF5F574F),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: highlighted
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: highlighted
                                      ? Colors.white
                                      : const Color(0xFF2D2926),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardDrawerItem {
  const _DashboardDrawerItem({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Widget screen;
}

class _DashboardProfileAvatar extends StatelessWidget {
  const _DashboardProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.starColor, width: 1.4),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _DashboardAvatarFallback(),
              )
            : const _DashboardAvatarFallback(),
      ),
    );
  }
}

class _DashboardAvatarFallback extends StatelessWidget {
  const _DashboardAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF6E8C8),
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.starColor,
        size: 20,
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
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

   String get displayLabel {
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (salonName.trim().isNotEmpty) return salonName.trim();
    return 'Salon #$salonId';
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6D6C6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('Date'),
              style: TextStyle(
                color: AppColors.starColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.calendar_today_outlined, size: 14),
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
    final direction = cleanText(data['change_direction']).toLowerCase();
    final changeColor = direction == 'up'
        ? const Color(0xFF047857)
        : direction == 'down'
            ? const Color(0xFFBE123C)
            : const Color(0xFF6B5B4D);
    final changeIcon = direction == 'up'
        ? '↑'
        : direction == 'down'
            ? '↓'
            : '•';

    return _DashboardSection(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Color(0xFF6D6259),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            value.isEmpty ? '0' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          if (hasChange) ...[
            const SizedBox(height: 4),
            Text(
              '$changeIcon ${percentBuilder(data['change_percent'])} $changeLabel',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: changeColor,
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
    final formattedTotal = cleanText(data['formatted_total']).isEmpty
        ? cleanText(data['formatted_value'])
        : cleanText(data['formatted_total']);
    final total = formattedTotal.isEmpty ? _plainNumber(data['total']) : formattedTotal;
    final direction = cleanText(data['change_direction']).toLowerCase();
    final changeColor =
        direction == 'down' ? const Color(0xFFBE123C) : const Color(0xFF047857);
    final changeIcon = direction == 'down' ? '↓' : '↑';

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
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.starColor),
                ),
                child: Text(
                  periodLabel.isEmpty ? context.t('This Month') : periodLabel,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    color: AppColors.starColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$changeIcon ${percentBuilder(data['change_percent'])} ${cleanText(data['change_label'])}',
                style: TextStyle(
                  color: changeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 132,
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

  String _plainNumber(dynamic value) {
    final text = cleanText(value);
    if (text.isEmpty) return '0';
    final parsed = asDouble(value);
    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }
    return parsed.toStringAsFixed(2);
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          if (sources.isEmpty)
            Text(
              context.t('No data available'),
              style: const TextStyle(color: Color(0xFF78716C)),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: _RevenueSourceDonutPainter(
                        sources: sources,
                        colors: colors,
                      ),
                      child: Center(
                        child: Text(
                          cleanText(data['center_label']).isEmpty
                              ? '100%'
                              : cleanText(data['center_label']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D2926),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: sources.asMap().entries.map((entry) {
                      final source = entry.value;
                      final color = colors[entry.key % colors.length];
                      final percent = cleanText(source['percent']).isEmpty
                          ? '0'
                          : cleanText(source['percent']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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
                                cleanText(source['label']),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4F463F),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayAppointmentsCard extends StatefulWidget {
  const _TodayAppointmentsCard({
    required this.data,
    required this.cleanText,
    required this.asInt,
    required this.onOpenBookings,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final int Function(dynamic value) asInt;
  final VoidCallback onOpenBookings;

  @override
  State<_TodayAppointmentsCard> createState() => _TodayAppointmentsCardState();
}

class _TodayAppointmentsCardState extends State<_TodayAppointmentsCard> {
  String _selectedFilterKey = 'all';
@override
Widget build(BuildContext context) {
  final filters = widget.data['filters'] is List
      ? (widget.data['filters'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  final appointments = widget.data['appointments'] is List
      ? (widget.data['appointments'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

 if (filters.isNotEmpty &&
    !filters.any(
      (filter) => widget.cleanText(filter['key']) == _selectedFilterKey,
    )) {
  _selectedFilterKey = widget.cleanText(filters.first['key']).isEmpty
      ? 'all'
      : widget.cleanText(filters.first['key']);
}

final visibleAppointments = _selectedFilterKey == 'all'
    ? appointments
    : appointments.where((appointment) {
        return _appointmentFilterKey(appointment) == _selectedFilterKey;
      }).toList();

  return _DashboardSection(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                context.t("Today's Appointments"),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onOpenBookings,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('View All'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B6500),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Color(0xFF8B6500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row(
        //   children: [
        //     Expanded(
        //       child: _AppointmentSummaryTile(
        //         label: widget.cleanText(allFilter['label']).isEmpty
        //             ? 'All'
        //             : widget.cleanText(allFilter['label']),
        //         count: widget.asInt(allFilter['count']),
        //         selected: true,
        //       ),
        //     ),
        //     const SizedBox(width: 10),
        //     Expanded(
        //       child: _AppointmentSummaryTile(
        //         label: widget.cleanText(upcomingFilter['label']).isEmpty
        //             ? 'Upcoming'
        //             : widget.cleanText(upcomingFilter['label']),
        //         count: widget.asInt(upcomingFilter['count']),
        //         selected: false,
        //       ),
        //     ),
        //   ],
        // ),
        SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: filters.map((filter) {
      final key = widget.cleanText(filter['key']).isEmpty
          ? 'all'
          : widget.cleanText(filter['key']);

      final selected = key == _selectedFilterKey;

      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedFilterKey = key;
            });
          },
          child: SizedBox(
            width: 118,
            child: _AppointmentSummaryTile(
              label: widget.cleanText(filter['label']).isEmpty
                  ? key
                  : widget.cleanText(filter['label']),
              count: widget.asInt(filter['count']),
              selected: selected,
            ),
          ),
        ),
      );
    }).toList(),
  ),
),
        const SizedBox(height: 16),
      if (visibleAppointments.isEmpty)
  _AppointmentEmptyBookNow(onTap: widget.onOpenBookings)
else
  ...visibleAppointments.take(3).map(
                (appointment) => _AppointmentDashboardRow(
                  appointment: appointment,
                  cleanText: widget.cleanText,
                  onTap: () => _showAppointmentDetails(context, appointment),
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

  String _appointmentFilterKey(Map<String, dynamic> appointment) {
    final status = widget.cleanText(appointment['status']).toLowerCase();
    final label = widget.cleanText(appointment['status_label']).toLowerCase();
    if (status.contains('cancel') || label.contains('cancel')) {
      return 'cancelled';
    }
    if (status.contains('complete') || label.contains('complete')) {
      return 'completed';
    }
    if (status.contains('progress') || label.contains('progress')) {
      return 'in_progress';
    }
    return 'upcoming';
  }

  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final details = <String, String>{
      'Time': widget.cleanText(appointment['time_label']),
      'Customer': widget.cleanText(appointment['customer_name']),
      'Service': widget.cleanText(appointment['service_name']),
      'Professional': widget.cleanText(appointment['professional_name']),
      'Status': widget.cleanText(appointment['status_label']).isEmpty
          ? widget.cleanText(appointment['status'])
          : widget.cleanText(appointment['status_label']),
    };
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('Appointment Details'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 22),
              ...details.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: Color(0xFF9A8A7A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value.isEmpty ? '-' : entry.value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _AppointmentSummaryTile extends StatelessWidget {
  const _AppointmentSummaryTile({
    required this.label,
    required this.count,
    required this.selected,
  });

  final String label;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // return Container(
    //   height: 52,
    //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    //   decoration: BoxDecoration(
    //     color: selected ? const Color(0xFFFAF7F3) : const Color(0xFFF1F0EF),
    //     borderRadius: BorderRadius.circular(8),
    //     border: Border.all(
    //       color: selected ? const Color(0xFF8B6500) : Colors.transparent,
    //       width: 1,
    //     ),
    //   ),
    //   child: Column(
    //     mainAxisAlignment: MainAxisAlignment.center,
    //     children: [
    //       Text(
    //         label.toUpperCase(),
    //         maxLines: 1,
    //         overflow: TextOverflow.ellipsis,
    //         style: const TextStyle(
    //           fontSize: 8,
    //           letterSpacing: 0.7,
    //           fontWeight: FontWeight.w800,
    //           color: Color(0xFF9A8A7A),
    //         ),
    //       ),
    //       const SizedBox(height: 6),
    //       Text(
    //         '$count',
    //         style: const TextStyle(
    //           fontSize: 13,
    //           fontWeight: FontWeight.w800,
    //           color: Color(0xFF44403C),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
    return Container(
  height: 58,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: selected ? const Color(0xFFFAF7F3) : const Color(0xFFF1F0EF),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: selected ? const Color(0xFF8B6500) : Colors.transparent,
      width: 1,
    ),
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 8,
          height: 1.0,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9A8A7A),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '$count',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: Color(0xFF44403C),
        ),
      ),
    ],
  ),
);
  }
}

class _AppointmentEmptyBookNow extends StatelessWidget {
  const _AppointmentEmptyBookNow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 142,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1DB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 22,
            color: Color(0xFFC19A6B),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('No appointments found for\nthe selected day.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B6500),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                context.t('Book Now'),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _StaffLiveStatusCard extends StatelessWidget {
  const _StaffLiveStatusCard({
    required this.data,
    required this.cleanText,
    required this.onOpenBookings,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final VoidCallback onOpenBookings;

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
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onOpenBookings,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Text(
                    context.t('View live status →'),
                    style: TextStyle(
                      color: AppColors.starColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
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
              (member) => _StaffDashboardRow(
                member: member,
                cleanText: cleanText,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentDashboardRow extends StatelessWidget {
  const _AppointmentDashboardRow({
    required this.appointment,
    required this.cleanText,
    required this.onTap,
  });

  final Map<String, dynamic> appointment;
  final String Function(dynamic value) cleanText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeLabel = cleanText(appointment['time_label']);
    final customerName = cleanText(appointment['customer_name']);
    final serviceName = cleanText(appointment['service_name']);
    final professionalName = cleanText(appointment['professional_name']);
    final statusLabel = cleanText(appointment['status_label']).isEmpty
        ? cleanText(appointment['status'])
        : cleanText(appointment['status_label']);

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE8D8C8)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel.split(' - ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8A7A6C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.isEmpty ? 'Customer' : customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B5B4D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                professionalName.isEmpty ? '' : 'with $professionalName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8A7A6C),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DashboardStatusPill(label: statusLabel),
          ],
        ),
      ),
    );
  }
}

class _StaffDashboardRow extends StatelessWidget {
  const _StaffDashboardRow({
    required this.member,
    required this.cleanText,
  });

  final Map<String, dynamic> member;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final name = cleanText(member['name']);
    final status = cleanText(member['professional_status']);
    final completed = cleanText(member['completed_items']).isEmpty
        ? '0'
        : cleanText(member['completed_items']);
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF1E6D7),
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.starColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isEmpty ? 'Team Member' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _DashboardStatusPill(label: status),
              const SizedBox(height: 4),
              Text(
                '$completed completed',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9A8A7A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationDashboardRow extends StatelessWidget {
  const _NotificationDashboardRow({
    required this.item,
    required this.cleanText,
  });

  final Map<String, dynamic> item;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6C987)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF8E7CC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanText(item['title']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cleanText(item['message']),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B5B4D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.starColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatusPill extends StatelessWidget {
  const _DashboardStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase().replaceAll('_', ' ');
    final isAvailable = normalized.contains('available');
    final isCompleted = normalized.contains('completed');
    final isCancelled = normalized.contains('cancelled');
    final background = isAvailable || isCompleted
        ? const Color(0xFFE8FFF5)
        : isCancelled
            ? const Color(0xFFFDEDEF)
            : const Color(0xFFFFF7E6);
    final foreground = isAvailable || isCompleted
        ? const Color(0xFF059669)
        : isCancelled
            ? const Color(0xFFE11D48)
            : AppColors.starColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Text(
        label.isEmpty ? 'Upcoming' : _titleCase(normalized),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

class _RevenueSourceDonutPainter extends CustomPainter {
  const _RevenueSourceDonutPainter({
    required this.sources,
    required this.colors,
  });

  final List<Map<String, dynamic>> sources;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = sources.fold<double>(0, (sum, source) {
      final value = source['percent'];
      if (value is num) return sum + value.toDouble();
      return sum + (double.tryParse('${value ?? ''}') ?? 0);
    });
    final strokeWidth = math.max(14.0, radius * 0.28);
    var startAngle = -math.pi / 2;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1E6D7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi * 2, false, backgroundPaint);

    if (total <= 0) return;

    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      final rawPercent = source['percent'];
      final percent = rawPercent is num
          ? rawPercent.toDouble()
          : double.tryParse('${rawPercent ?? ''}') ?? 0;
      if (percent <= 0) continue;
      final sweep = (percent / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep - 0.045, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueSourceDonutPainter oldDelegate) {
    return oldDelegate.sources != sources;
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
    final maxValue = _niceMaxValue(
      values.fold<double>(0, (max, value) => math.max(max, value)),
    );

    for (var i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight - (chartHeight * i / 4);
      final tick = maxValue * i / 4;
      _drawDashedLine(
        canvas,
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
      axisTextPainter.text = TextSpan(
        text: _formatTick(tick),
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
    final barPaint = Paint()..color = const Color(0xFF7A5A10);

    for (var index = 0; index < chartData.length; index++) {
      final item = chartData[index];
      final value = asDouble(item['value']);
      final x = leftPadding + slotWidth * index + slotWidth / 2;
      final y = topPadding + chartHeight - (value / maxValue) * chartHeight;

      _drawDashedLine(
        canvas,
        Offset(x + slotWidth / 2, topPadding),
        Offset(x + slotWidth / 2, topPadding + chartHeight),
        gridPaint,
      );

      if (value > 0) {
        final barWidth = math.min(170.0, slotWidth * 0.72);
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

  double _niceMaxValue(double value) {
    if (value <= 0) return 4;
    if (value <= 100) return (value / 10).ceil() * 10;
    return (value / 100).ceil() * 100;
  }

  String _formatTick(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData;
  }
}
class _NotificationPaginationBar extends StatelessWidget {
  const _NotificationPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSelected,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Text(
            'Page ${currentPage + 1} of $totalPages',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9A8A7A),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
        ),
        ...List.generate(totalPages, (index) {
          final selected = index == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPageSelected(index),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.starColor : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppColors.starColor
                        : const Color(0xFFE6D6C6),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFF5F574F),
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
        ),
      ],
    );
  }
}

class _DashboardHeaderBranchSelector extends StatelessWidget {
  const _DashboardHeaderBranchSelector({
    super.key,
    required this.label,
    this.addressSummary = '',
    required this.isInteractive,
    this.onTap,
  });

  final String label;
  final String addressSummary;
  final bool isInteractive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isInteractive ? onTap : null,
        child: Ink(
          height: 68,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE8E1DB),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5D46A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF8B6500),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13.5,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44403C),
                      ),
                    ),
                    if (addressSummary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addressSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 9.5,
                          height: 1.05,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF78716C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isInteractive)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF8B6500),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
class _DashboardBranchDropdownItem extends StatelessWidget {
  const _DashboardBranchDropdownItem({
    required this.option,
    required this.isSelected,
  });

  final _DashboardBranchOption option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? _dashboardAccent.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _dashboardAccent : _dashboardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _dashboardAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: _dashboardAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _dashboardTextStyle(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _dashboardPrimaryText,
                    letterSpacing: 0.2,
                  ),
                ),
                if (option.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _dashboardTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _dashboardSecondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isSelected ? _dashboardAccent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _dashboardAccent : _dashboardBorder,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}