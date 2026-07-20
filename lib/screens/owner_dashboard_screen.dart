import 'dart:math' as math;
import '../../../utils/price_formatter.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/profile/compensation/profile_compensation_screen.dart';
import '../features/profile/operations/owner_profile_operations_screen.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';
import 'bottom_nav.dart';
import 'owner_ai_insights_screen.dart';
import 'owner_branch_clients_screen.dart';
import 'owner_roles_permissions_screen.dart';
import 'owner_sales_reports_screen.dart';
import 'profile_screen.dart';
import 'SalonReviews.dart';
import 'ad.dart';

const Color _dashboardPrimaryText = Color(0xFF1C1917);
const Color _dashboardSecondaryText = Color(0xFF78716C);

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key, this.onOpenMoreTab});

  final VoidCallback? onOpenMoreTab;

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ApiService _apiService = ApiService();
  late final VoidCallback _salonCatalogListener;
  late final VoidCallback _branchSelectionListener;
  int _notificationPage = 0;
  static const int _notificationPageSize = 4;
  List<OwnerBranchOption> _branchOptions = const [];
  int? _selectedBranchId;
  int _dashboardLoadSerial = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dashboard = const {};
  String _profileImageUrl = '';
  bool _isLoadingDashboard = false;
  bool _staffLiveStatusExpanded = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _salonCatalogListener = () {
      if (!mounted) return;
      _loadData();
    };
    _branchSelectionListener = _handleSharedBranchSelectionChanged;
    StylistBranchSelectionStore.salonCatalogRevision
        .addListener(_salonCatalogListener);
    StylistBranchSelectionStore.selectionNotifier
        .addListener(_branchSelectionListener);
    _loadData();
  }

  @override
  void dispose() {
    StylistBranchSelectionStore.salonCatalogRevision
        .removeListener(_salonCatalogListener);
    StylistBranchSelectionStore.selectionNotifier
        .removeListener(_branchSelectionListener);
    super.dispose();
  }

  void _handleSharedBranchSelectionChanged() {
    if (!mounted) return;

    final selection = StylistBranchSelectionStore.selectionNotifier.value;
    final branchId = selection.branchId;
    if (branchId == null || branchId == _selectedBranchId) return;

    if (_branchOptions.isEmpty) {
      _loadData();
      return;
    }

    final hasBranch =
        _branchOptions.any((option) => option.branchId == branchId);
    if (!hasBranch) {
      _loadData();
      return;
    }

    _loadDashboard(
      branchId,
      saveSelection: false,
    );
  }

  Future<void> _loadData() async {
    final requestSerial = ++_dashboardLoadSerial;
    setState(() {
      _isLoadingDashboard = true;
      _errorMessage = null;
      _staffLiveStatusExpanded = true;
    });

    try {
      final selectionFuture = StylistBranchSelectionStore.load();
      final prefsFuture = SharedPreferences.getInstance();
      final salonFuture = _apiService.getSalonListApi();

      final selection = await selectionFuture;
      final prefs = await prefsFuture;
      _profileImageUrl = _readProfileImageUrl(prefs);

      final response = await salonFuture;
      if (!mounted || requestSerial != _dashboardLoadSerial) return;
      final rawSalons = (response['data'] as List?) ?? const [];
      final options = OwnerBranchOption.listFromSalonList(rawSalons);
      final selectedBranchId = options.any(
        (option) => option.branchId == selection.branchId,
      )
          ? selection.branchId
          : (options.isNotEmpty ? options.first.branchId : null);

      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranchId = selectedBranchId;
      });

      if (selectedBranchId == null) {
        await StylistBranchSelectionStore.clear();
        if (!mounted) return;
        setState(() {
          _dashboard = const {};
          _isLoadingDashboard = false;
        });
        return;
      }

      await _loadDashboard(
        selectedBranchId,
        saveSelection: selectedBranchId != selection.branchId,
        showLoading: false,
      );
    } catch (error) {
      if (requestSerial != _dashboardLoadSerial) return;
      if (!mounted) return;
      setState(() {
        _errorMessage = extractErrorMessage(error);
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
    bool showLoading = true,
  }) async {
    final requestSerial = ++_dashboardLoadSerial;
    if (!mounted) return;
    setState(() {
      _selectedBranchId = branchId;
      if (showLoading) {
        _isLoadingDashboard = true;
        _errorMessage = null;
      }
      _staffLiveStatusExpanded = true;
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

      if (!mounted ||
          requestSerial != _dashboardLoadSerial ||
          _selectedBranchId != branchId) {
        return;
      }
      setState(() {
        _dashboard = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : const {};
        _notificationPage = 0;
        _isLoadingDashboard = false;
      });
    } catch (error) {
      if (requestSerial != _dashboardLoadSerial ||
          _selectedBranchId != branchId) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = extractErrorMessage(error);
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

  OwnerBranchOption? get _selectedBranchOption {
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
    final hasSalon = _branchOptions.isNotEmpty && _selectedBranchId != null;
    final targetTabIndex = hasSalon ? 1 : 2;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => BottomNav(tabIndex: targetTabIndex)),
      (route) => false,
    );
  }

  void _openDrawerRoute(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openMoreTab() {
    final onOpenMoreTab = widget.onOpenMoreTab;
    if (onOpenMoreTab != null) {
      onOpenMoreTab();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openDashboardDrawer(BuildContext scaffoldContext) {
    if (_selectedBranchId == null || _branchOptions.isEmpty) {
      Fluttertoast.showToast(msg: context.t('Please add a salon first'));
      return;
    }

    Scaffold.of(scaffoldContext).openDrawer();
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
    final hasSalon = _selectedBranchId != null && _branchOptions.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      drawer: _DashboardDrawer(
        onOpen: _openDrawerRoute,
        selectedBranchId: _selectedBranchId,
      ),
      appBar: buildProfileSubpageAppBar(
        title: context.t('Dashboard'),
        automaticallyImplyLeading: false,
        toolbarHeight: 58,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: hasSalon ? AppColors.starColor : const Color(0xFFBDB5AE),
            ),
            onPressed: () => _openDashboardDrawer(context),
            tooltip: context.t('Menu'),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _openMoreTab,
              child: _DashboardProfileAvatar(imageUrl: _profileImageUrl),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.starColor,
            onRefresh: () => RefreshFeedback.playAndRun(_loadData),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
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
                else if (_selectedBranchId == null && !_isLoadingDashboard)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Text(
                      context.t('No Salons available'),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_selectedBranchId != null) ...[
                  if (_branchOptions.length > 1) _buildBranchSelector(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _branchOptions.length > 1 ? 28 : 16,
                      16,
                      0,
                    ),
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
                ] else
                  const SizedBox(height: 420),
              ],
            ),
          ),
          if (_isLoadingDashboard)
            const Positioned.fill(child: _DashboardLoadingOverlay()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'owner_dashboard_add_fab',
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
    final canChangeBranch = _branchOptions.length > 1 && !_isLoadingDashboard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: OwnerBranchHeaderSelector<OwnerBranchOption>(
        label: selected?.label ?? context.t('Select Branch'),
        options: _branchOptions
            .map(
              (item) => OwnerBranchHeaderSelectorOption<OwnerBranchOption>(
                value: item,
                label: item.label,
                subtitle: item.subtitle,
              ),
            )
            .toList(),
        selectedValue: selected,
        placeholder: context.t('Select Branch'),
        isInteractive: canChangeBranch,
        onSelected: (option) => _loadDashboard(option.branchId),
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
          selectedDate: _selectedDate,
          branchId: _selectedBranchId,
          apiService: _apiService,
          onOpenBookings: _openBookingsTab,
        );
        final staffCard = _StaffLiveStatusCard(
          data: _mapValue('staff_live_status'),
          appointmentsData: _mapValue('todays_appointments'),
          cleanText: _cleanText,
          isExpanded: _staffLiveStatusExpanded,
          onToggleExpanded: () {
            setState(() {
              _staffLiveStatusExpanded = !_staffLiveStatusExpanded;
            });
          },
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

    final totalPages =
        items.isEmpty ? 1 : (items.length / _notificationPageSize).ceil();

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

class _DashboardDrawer extends StatefulWidget {
  const _DashboardDrawer({
    required this.onOpen,
    required this.selectedBranchId,
  });

  final ValueChanged<Widget> onOpen;
  final int? selectedBranchId;

  @override
  State<_DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<_DashboardDrawer> {
  final Set<String> _expandedGroups = <String>{};
  String? _selectedDrawerItem;

  @override
  void initState() {
    super.initState();
    _loadDrawerPermissions();
  }

  @override
  void didUpdateWidget(covariant _DashboardDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBranchId != widget.selectedBranchId) {
      _loadDrawerPermissions();
    }
  }

  Future<void> _loadDrawerPermissions() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<_DashboardDrawerChildItem> allowedChildren(
      List<_DashboardDrawerChildItem> children,
    ) {
      return children;
    }

    Widget? drawerTile({
      required String id,
      required _DashboardDrawerItem item,
      required VoidCallback onTap,
    }) {
      return _DashboardDrawerTile(
        item: item,
        selected: _selectedDrawerItem == id,
        onTap: onTap,
      );
    }

    Widget? drawerGroup({
      required String id,
      required IconData icon,
      required String label,
      required List<_DashboardDrawerChildItem> children,
    }) {
      final visibleChildren = allowedChildren(children);
      if (visibleChildren.isEmpty) return null;
      return _DashboardDrawerGroupTile(
        id: id,
        icon: icon,
        label: label,
        isExpanded: _expandedGroups.contains(id),
        isSelected: _isGroupSelected(id),
        onToggle: () => _toggleGroup(id),
        children: visibleChildren,
        selectedId: _selectedDrawerItem,
        onOpen: _openDrawerChild,
      );
    }

    final entries = <Widget>[
      if (drawerGroup(
        id: 'sales',
        icon: Icons.insert_chart_outlined_rounded,
        label: context.t('Sales & Reports'),
        children: [
          _DashboardDrawerChildItem(
            id: 'sales.revenue',
            label: context.t('Revenue & Sales'),
            permissions: const ['revenue_sales.view'],
            screen: const OwnerSalesReportsScreen(
              initialModule: OwnerSalesReportModule.revenueSales,
              showModuleTabs: false,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'sales.staffPerformance',
            label: context.t('Staff Performance'),
            permissions: const ['staff_performance.view'],
            screen: const OwnerSalesReportsScreen(
              initialModule: OwnerSalesReportModule.staffPerformance,
              showModuleTabs: false,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'sales.operations',
            label: context.t('Operations'),
            permissions: const ['operations.view'],
            screen: const OwnerSalesReportsScreen(
              initialModule: OwnerSalesReportModule.operations,
              showModuleTabs: false,
            ),
          ),
        ],
      )
          case final group?)
        group,
      if (drawerTile(
        id: 'aiInsights',
        item: _DashboardDrawerItem(
          icon: Icons.auto_awesome_outlined,
          label: context.t('AI Insights'),
          permissions: const ['insights_dashboard.view'],
          screen: const OwnerAiInsightsScreen(),
        ),
        onTap: () => _openDrawerItem(
          'aiInsights',
          const OwnerAiInsightsScreen(),
        ),
      )
          case final tile?)
        tile,
      // if (drawerTile(
      //   id: 'membership',
      //   item: _DashboardDrawerItem(
      //     icon: Icons.workspace_premium_outlined,
      //     label: context.t('Membership'),
      //     permissions: const ['membership.view'],
      //     screen: const OwnerMembershipScreen(),
      //   ),
      //   onTap: () =>
      //       _openDrawerItem('membership', const OwnerMembershipScreen()),
      // )
      //     case final tile?)
      //   tile,
      if (drawerTile(
        id: 'roles',
        item: _DashboardDrawerItem(
          icon: Icons.admin_panel_settings_outlined,
          label: context.t('Roles'),
          permissions: const ['roles.view'],
          screen: const OwnerRolesPermissionsScreen(),
        ),
        onTap: () =>
            _openDrawerItem('roles', const OwnerRolesPermissionsScreen()),
      )
          case final tile?)
        tile,
      if (drawerGroup(
        id: 'inventory',
        icon: Icons.inventory_2_outlined,
        label: context.t('Inventory'),
        children: [
          _DashboardDrawerChildItem(
            id: 'inventory.store',
            label: context.t('Store'),
            permissions: const ['store.view'],
            screen: const OwnerProfileOperationsScreen(
              initialModule: OwnerOperationsModule.inventory,
              initialInventorySection: OwnerInventorySection.store,
              showInventoryTabs: false,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'inventory.vendor',
            label: context.t('Vendor'),
            permissions: const ['vendor.view'],
            screen: const OwnerProfileOperationsScreen(
              initialModule: OwnerOperationsModule.vendor,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'inventory.item',
            label: context.t('Inventory Item'),
            permissions: const ['inventory_item.view'],
            screen: const OwnerProfileOperationsScreen(
              initialModule: OwnerOperationsModule.inventory,
              initialInventorySection: OwnerInventorySection.inventoryItem,
              showInventoryTabs: false,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'inventory.purchaseOrder',
            label: context.t('Purchase Order'),
            permissions: const ['purchase_order.view'],
            screen: const OwnerProfileOperationsScreen(
              initialModule: OwnerOperationsModule.inventory,
              initialInventorySection: OwnerInventorySection.purchaseOrder,
              showInventoryTabs: false,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'inventory.goodsReceiptNote',
            label: context.t('Goods Receipt Note'),
            permissions: const ['goods_receipt_note.view'],
            screen: const OwnerProfileOperationsScreen(
              initialModule: OwnerOperationsModule.inventory,
              initialInventorySection: OwnerInventorySection.goodsReceiptNote,
              showInventoryTabs: false,
            ),
          ),
        ],
      )
          case final group?)
        group,
      if (drawerTile(
        id: 'clients',
        item: _DashboardDrawerItem(
          icon: Icons.groups_outlined,
          label: context.t('Clients'),
          permissions: const ['clients.view'],
          screen: const OwnerBranchClientsScreen(),
        ),
        onTap: () =>
            _openDrawerItem('clients', const OwnerBranchClientsScreen()),
      )
          case final tile?)
        tile,
      if (drawerTile(
        id: 'reviews',
        item: _DashboardDrawerItem(
          icon: Icons.rate_review_outlined,
          label: context.t('Reviews'),
          permissions: const ['reviews.view'],
          screen: const SalonReviews(),
        ),
        onTap: () => _openDrawerItem('reviews', const SalonReviews()),
      )
          case final tile?)
        tile,
      if (drawerGroup(
        id: 'payroll',
        icon: Icons.payments_outlined,
        label: context.t('Payroll'),
        children: [
          _DashboardDrawerChildItem(
            id: 'payroll.payroll',
            label: context.t('Payroll'),
            permissions: const ['payroll.view'],
            screen: const ProfileCompensationScreen(
              initialModule: CompensationModule.payroll,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'payroll.commission',
            label: context.t('Commission Setup'),
            permissions: const ['commission_setup.view'],
            screen: const ProfileCompensationScreen(
              initialModule: CompensationModule.commission,
            ),
          ),
          _DashboardDrawerChildItem(
            id: 'payroll.advance',
            label: context.t('Advance'),
            permissions: const ['advances.view'],
            screen: const ProfileCompensationScreen(
              initialModule: CompensationModule.advance,
            ),
          ),
        ],
      )
          case final group?)
        group,
      if (drawerTile(
        id: 'advertisement',
        item: _DashboardDrawerItem(
          icon: Icons.campaign_outlined,
          label: context.t('Advertisement'),
          permissions: const ['advertisement.view'],
          screen: const AdScreen(),
        ),
        onTap: () => _openDrawerItem(
          'advertisement',
          const AdScreen(),
        ),
      )
          case final tile?)
        tile,
      if (drawerTile(
        id: 'attendance',
        item: _DashboardDrawerItem(
          icon: Icons.event_available_outlined,
          label: context.t('Attendance'),
          permissions: const ['attendance.view'],
          screen: const ProfileCompensationScreen(
            initialModule: CompensationModule.attendance,
          ),
        ),
        onTap: () => _openDrawerItem(
          'attendance',
          const ProfileCompensationScreen(
            initialModule: CompensationModule.attendance,
          ),
        ),
      )
          case final tile?)
        tile,
      if (drawerTile(
        id: 'leaves',
        item: _DashboardDrawerItem(
          icon: Icons.beach_access_outlined,
          label: context.t('Leaves'),
          permissions: const ['leaves.view'],
          screen: const ProfileCompensationScreen(
            initialModule: CompensationModule.leaves,
          ),
        ),
        onTap: () => _openDrawerItem(
          'leaves',
          const ProfileCompensationScreen(
            initialModule: CompensationModule.leaves,
          ),
        ),
      )
          case final tile?)
        tile,
      if (drawerTile(
        id: 'holidays',
        item: _DashboardDrawerItem(
          icon: Icons.calendar_month_outlined,
          label: context.t('Holidays Calendar'),
          permissions: const ['holidays_calendar.view'],
          screen: const ProfileCompensationScreen(
            initialModule: CompensationModule.holidays,
          ),
        ),
        onTap: () => _openDrawerItem(
          'holidays',
          const ProfileCompensationScreen(
            initialModule: CompensationModule.holidays,
          ),
        ),
      )
          case final tile?)
        tile,
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
              SizedBox(
                width: double.infinity,
                height: 34,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/finallogo.png',
                    height: 28,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png',
                      height: 28,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE8DED6),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8DED6),
                  ),
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 8),
                        child: _DrawerProfileQuoteCard(),
                      );
                    }

                    return entries[index];
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleGroup(String id) {
    setState(() {
      if (_expandedGroups.contains(id)) {
        _expandedGroups.remove(id);
      } else {
        _expandedGroups.add(id);
      }
    });
  }

  void _openDrawerChild(_DashboardDrawerChildItem item) {
    setState(() {
      _selectedDrawerItem = item.id;
      _expandedGroups
        ..clear()
        ..add(item.groupId);
    });
    widget.onOpen(item.screen);
  }

  void _openDrawerItem(String id, Widget screen) {
    setState(() {
      _selectedDrawerItem = id;
      _expandedGroups.clear();
    });
    widget.onOpen(screen);
  }

  bool _isGroupSelected(String id) =>
      _selectedDrawerItem?.startsWith('$id.') ?? false;
}

class _DashboardDrawerTile extends StatelessWidget {
  const _DashboardDrawerTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _DashboardDrawerItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF5EFE6) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        overlayColor: _drawerOverlayColor(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: const Color(0xFF5F574F),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2926),
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

class _DashboardDrawerGroupTile extends StatelessWidget {
  const _DashboardDrawerGroupTile({
    required this.id,
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.isSelected,
    required this.onToggle,
    required this.children,
    required this.selectedId,
    required this.onOpen,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onToggle;
  final List<_DashboardDrawerChildItem> children;
  final String? selectedId;
  final ValueChanged<_DashboardDrawerChildItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: isSelected ? AppColors.starColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            overlayColor: _drawerOverlayColor(),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF5F574F),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF2D2926),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF5F574F),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 2, bottom: 8),
            child: Column(
              children: children
                  .map(
                    (child) => _DashboardDrawerChildTile(
                      item: child,
                      selected: selectedId == child.id,
                      onTap: () => onOpen(child),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _DashboardDrawerChildTile extends StatelessWidget {
  const _DashboardDrawerChildTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _DashboardDrawerChildItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: selected ? const Color(0xFFF5EFE6) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          overlayColor: _drawerOverlayColor(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? AppColors.starColor : const Color(0xFF756A61),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

WidgetStateProperty<Color?> _drawerOverlayColor() {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return const Color(0x1FC19A6B);
    }
    return null;
  });
}

class _DashboardDrawerItem {
  const _DashboardDrawerItem({
    required this.icon,
    required this.label,
    required this.screen,
    this.permissions = const <String>[],
  });

  final IconData icon;
  final String label;
  final Widget screen;
  final List<String> permissions;
}

class _DashboardDrawerChildItem {
  const _DashboardDrawerChildItem({
    required this.id,
    required this.label,
    required this.screen,
    this.permissions = const <String>[],
  });

  final String id;
  final String label;
  final Widget screen;
  final List<String> permissions;

  String get groupId => id.split('.').first;
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

class _DashboardLoadingOverlay extends StatefulWidget {
  const _DashboardLoadingOverlay();

  @override
  State<_DashboardLoadingOverlay> createState() =>
      _DashboardLoadingOverlayState();
}

class _DashboardLoadingOverlayState extends State<_DashboardLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: const Color(0x99FBF9F8),
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final pulse = 0.94 + (0.06 * math.sin(t * math.pi * 2).abs());
            final lift = 6 * math.sin(t * math.pi * 2);
            return Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(scale: pulse, child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF0E4D4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 98,
                  height: 98,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final progress = _controller.value;
                      return CustomPaint(
                        painter: _DashboardLoaderPainter(progress),
                        child: Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFF8EC),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.dashboard_customize_rounded,
                              color: AppColors.starColor,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading dashboard',
                  style: TextStyle(
                    color: _dashboardPrimaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fetching live data',
                  style: TextStyle(
                    color: _dashboardSecondaryText,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLoaderPainter extends CustomPainter {
  _DashboardLoaderPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1F8B6500);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.starColor;

    canvas.drawCircle(center, radius, basePaint);

    final sweep = math.pi * 1.45;
    final start = -math.pi / 2 + progress * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arcPaint,
    );

    final dotAngle = start + sweep;
    final dotCenter = Offset(
      center.dx + math.cos(dotAngle) * radius,
      center.dy + math.sin(dotAngle) * radius,
    );
    final dotRadius = 5.5 + 1.2 * math.sin(progress * math.pi * 2).abs();
    final dotPaint = Paint()..color = AppColors.starColor;
    canvas.drawCircle(dotCenter, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DashboardLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
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

// class _KpiCard extends StatelessWidget {
//   const _KpiCard({
//     required this.data,
//     required this.percentBuilder,
//     required this.cleanText,
//   });

//   final Map<String, dynamic> data;
//   final String Function(dynamic value) percentBuilder;
//   final String Function(dynamic value) cleanText;

//   @override
//   Widget build(BuildContext context) {
//     final label = cleanText(data['label']);
//     final value = cleanText(data['formatted_value']).isEmpty
//         ? cleanText(data['value'])
//         : cleanText(data['formatted_value']);
//     final changeLabel = cleanText(data['change_label']);
//     final hasChange = data.containsKey('change_percent');
//     final direction = cleanText(data['change_direction']).toLowerCase();
//     final changeColor = direction == 'up'
//         ? const Color(0xFF047857)
//         : direction == 'down'
//             ? const Color(0xFFBE123C)
//             : const Color(0xFF6B5B4D);
//     final changeIcon = direction == 'up'
//         ? '↑'
//         : direction == 'down'
//             ? '↓'
//             : '•';

//     return _DashboardSection(
//       padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.start,
//         children: [
//           Text(
//             label.toUpperCase(),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//               fontSize: 9,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.7,
//               color: Color(0xFF6D6259),
//             ),
//           ),
//           const SizedBox(height: 9),
//           Text(
//             value.isEmpty ? '0' : value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//               fontSize: 21,
//               fontWeight: FontWeight.w500,
//               color: Colors.black,
//             ),
//           ),
//           if (hasChange) ...[
//             const SizedBox(height: 4),
//             Text(
//               '$changeIcon ${percentBuilder(data['change_percent'])} $changeLabel',
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w700,
//                 color: changeColor,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.data,
    required this.percentBuilder,
    required this.cleanText,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) percentBuilder;
  final String Function(dynamic value) cleanText;

  bool _isMoneyKpi(String label) {
    final normalized = label.toLowerCase();

    return normalized.contains('revenue') ||
        normalized.contains('payment') ||
        normalized.contains('payments') ||
        normalized.contains('earning') ||
        normalized.contains('earnings') ||
        normalized.contains('sales') ||
        normalized.contains('amount') ||
        normalized.contains('collection') ||
        normalized.contains('collections');
  }

  @override
  Widget build(BuildContext context) {
    final label = cleanText(data['label']);

    final formattedValue = cleanText(data['formatted_value']);
    final rawValue = data['value'];

    final value = formattedValue.isNotEmpty
        ? formattedValue
        : _isMoneyKpi(label)
            ? formatMinorAmount(rawValue)
            : cleanText(rawValue);

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
    final total = formattedTotal.isEmpty
        ? formatMinorAmount(data['total'])
        : formattedTotal;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    required this.selectedDate,
    required this.branchId,
    required this.apiService,
    required this.onOpenBookings,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value) cleanText;
  final int Function(dynamic value) asInt;
  final DateTime selectedDate;
  final int? branchId;
  final ApiService apiService;
  final VoidCallback onOpenBookings;

  @override
  State<_TodayAppointmentsCard> createState() => _TodayAppointmentsCardState();
}

class _TodayAppointmentsCardState extends State<_TodayAppointmentsCard> {
  String _selectedFilterKey = 'all';

  int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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

  String _formatAppointmentDate(dynamic value) {
    final text = widget.cleanText(value);
    if (text.isEmpty || text == '{}') return '';

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return DateFormat('EEEE, MMM d').format(parsed.toLocal());
    }

    return text;
  }

  String _normalizeLookupKey(dynamic key) {
    return key.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  dynamic _findNestedAppointmentValue(
    dynamic node,
    Set<String> normalizedKeys,
  ) {
    if (node is Map) {
      final map = Map<dynamic, dynamic>.from(node);

      for (final entry in map.entries) {
        if (normalizedKeys.contains(_normalizeLookupKey(entry.key))) {
          return entry.value;
        }
      }

      for (final entry in map.entries) {
        final nested = _findNestedAppointmentValue(
          entry.value,
          normalizedKeys,
        );
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _findNestedAppointmentValue(item, normalizedKeys);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  dynamic _firstAppointmentValue(
    Map<String, dynamic> appointment,
    List<String> keys,
  ) {
    final normalizedKeys = keys.map(_normalizeLookupKey).toSet();
    return _findNestedAppointmentValue(appointment, normalizedKeys);
  }

  String _appointmentDateLabel(Map<String, dynamic> appointment) {
    final candidate = _firstAppointmentValue(appointment, [
      'date',
      'appointmentDate',
      'bookingDate',
      'scheduledDate',
      'startAt',
      'start_at',
      'createdAt',
      'created_at',
      'bookedAt',
      'booked_at',
    ]);

    final formatted = _formatAppointmentDate(candidate);
    if (formatted.isNotEmpty) return formatted;

    return DateFormat('EEEE, MMM d').format(widget.selectedDate);
  }

  String _appointmentPaymentLabel(Map<String, dynamic> appointment) {
    final candidate = _firstAppointmentValue(appointment, [
      'totalPriceMinor',
      'totalAmountMinor',
      'amountMinor',
      'paymentAmountMinor',
      'paidAmountMinor',
      'payableAmountMinor',
      'finalAmountMinor',
      'subtotalMinor',
      'total_price_minor',
      'total_amount_minor',
      'amount_minor',
      'payment_amount_minor',
      'paid_amount_minor',
      'payable_amount_minor',
      'final_amount_minor',
      'subtotal_minor',
      'totalPrice',
      'totalAmount',
      'amount',
      'paymentAmount',
      'paidAmount',
      'payableAmount',
      'finalAmount',
      'subtotal',
      'total_price',
      'total_amount',
      'payment_amount',
      'paid_amount',
      'payable_amount',
      'final_amount',
      'subtotal_amount',
    ]);

    if (candidate == null) return '';

    final text = widget.cleanText(candidate);
    if (text.isNotEmpty) {
      final value = num.tryParse(text.replaceAll(RegExp(r'[^0-9.-]'), ''));
      if (value != null) return formatMinorAmount(value);
    }

    if (candidate is num) {
      return formatMinorAmount(candidate);
    }

    return text;
  }

  List<Map<String, dynamic>> _extractAppointmentRecords(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in const ['appointments', 'items', 'data']) {
        final nested = map[key];
        final records = _extractAppointmentRecords(nested);
        if (records.isNotEmpty) return records;
      }
      return [map];
    }

    return const [];
  }

  Map<String, dynamic> _mergeAppointmentRecords(
    Map<String, dynamic> summary,
    Map<String, dynamic> detail,
  ) {
    final merged = Map<String, dynamic>.from(summary);
    detail.forEach((key, value) {
      if (value != null) {
        merged[key] = value;
      }
    });
    return merged;
  }

  Future<Map<String, dynamic>> _enrichAppointmentDetails(
    Map<String, dynamic> appointment,
  ) async {
    final appointmentId = _asIntOrNull(
      appointment['appointment_id'] ??
          appointment['appointmentId'] ??
          appointment['id'],
    );
    final branchId = widget.branchId;
    if (appointmentId == null || branchId == null) {
      return appointment;
    }

    try {
      final response = await widget.apiService.fetchAppointments(
        branchId,
        DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      );
      final records = _extractAppointmentRecords(response['data']);

      for (final record in records) {
        final recordId = _asIntOrNull(
          record['appointment_id'] ?? record['appointmentId'] ?? record['id'],
        );
        if (recordId == appointmentId) {
          return _mergeAppointmentRecords(appointment, record);
        }
      }
    } catch (_) {}

    return appointment;
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) async {
    final enriched = await _enrichAppointmentDetails(appointment);

    if (!context.mounted) return;

    final details = <String, String>{
      'Date': _appointmentDateLabel(enriched),
      'Time': widget.cleanText(enriched['time_label']),
      'Customer': widget.cleanText(enriched['customer_name']),
      'Service': widget.cleanText(enriched['service_name']),
      'Professional': widget.cleanText(enriched['professional_name']),
      'Payment': _appointmentPaymentLabel(enriched),
      'Status': widget.cleanText(enriched['status_label']).isEmpty
          ? widget.cleanText(enriched['status'])
          : widget.cleanText(enriched['status_label']),
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
    required this.appointmentsData,
    required this.cleanText,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> appointmentsData;
  final String Function(dynamic value) cleanText;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final staff = data['staff'] is List
        ? (data['staff'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final appointments = appointmentsData['appointments'] is List
        ? (appointmentsData['appointments'] as List)
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
                onTap: staff.isEmpty ? null : onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded
                            ? context.t('Hide live status')
                            : context.t('View live status'),
                        style: TextStyle(
                          color: AppColors.starColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.starColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
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
                  appointments: appointments,
                  cleanText: cleanText,
                ),
              ),
          ],
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
    required this.appointments,
    required this.cleanText,
  });

  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> appointments;
  final String Function(dynamic value) cleanText;

  @override
  Widget build(BuildContext context) {
    final name = cleanText(member['name']);
    final status = _cleanStaffStatus(member);
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final completedCount = _completedBookingCount();

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
            mainAxisSize: MainAxisSize.min,
            children: [
              _DashboardStatusPill(label: status),
              const SizedBox(height: 4),
              Text(
                '$completedCount ${context.t('completed')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A8D81),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _completedBookingCount() {
    final direct = _directCompletedCount();
    if (direct != null) return direct;

    return appointments.where((appointment) {
      if (!_isCompletedAppointment(appointment)) return false;
      return _appointmentBelongsToMember(appointment);
    }).length;
  }

  int? _directCompletedCount() {
    const keys = [
      'completed',
      'completed_items',
      'completedItems',
      'completed_count',
      'completedCount',
      'completed_bookings',
      'completedBookings',
      'completed_appointments',
      'completedAppointments',
      'completed_appointments_count',
      'completedAppointmentsCount',
      'appointments_completed',
      'appointmentsCompleted',
      'today_completed',
      'todayCompleted',
    ];

    for (final key in keys) {
      final value = member[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse('${value ?? ''}');
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _isCompletedAppointment(Map<String, dynamic> appointment) {
    final status = '${appointment['status'] ?? ''}'.toLowerCase();
    final label = '${appointment['status_label'] ?? ''}'.toLowerCase();
    return status.contains('complete') || label.contains('complete');
  }

  bool _appointmentBelongsToMember(Map<String, dynamic> appointment) {
    final memberIds = <String>{
      _normalizeLookupKey(member['id']),
      _normalizeLookupKey(member['user_id']),
      _normalizeLookupKey(member['userId']),
      _normalizeLookupKey(member['team_member_id']),
      _normalizeLookupKey(member['teamMemberId']),
      _normalizeLookupKey(member['professional_id']),
      _normalizeLookupKey(member['professionalId']),
    }..remove('');

    final appointmentIds = <String>{
      _normalizeLookupKey(appointment['professional_id']),
      _normalizeLookupKey(appointment['professionalId']),
      _normalizeLookupKey(appointment['professional_user_id']),
      _normalizeLookupKey(appointment['professionalUserId']),
      _normalizeLookupKey(appointment['team_member_id']),
      _normalizeLookupKey(appointment['teamMemberId']),
      _normalizeLookupKey(appointment['staff_id']),
      _normalizeLookupKey(appointment['staffId']),
      _normalizeLookupKey(appointment['assigned_to_id']),
      _normalizeLookupKey(appointment['assignedToId']),
    }..remove('');

    if (memberIds.isNotEmpty &&
        appointmentIds.any((id) => memberIds.contains(id))) {
      return true;
    }

    final memberNames = <String>{
      _normalizeLookupKey(member['name']),
      _normalizeLookupKey(member['full_name']),
      _normalizeLookupKey(member['fullName']),
      _normalizeLookupKey(
        '${cleanText(member['firstName'])} ${cleanText(member['lastName'])}',
      ),
    }..remove('');

    final appointmentNames = <String>{
      _normalizeLookupKey(appointment['professional_name']),
      _normalizeLookupKey(appointment['professionalName']),
      _normalizeLookupKey(appointment['staff_name']),
      _normalizeLookupKey(appointment['staffName']),
      _normalizeLookupKey(appointment['assigned_to']),
      _normalizeLookupKey(appointment['assignedTo']),
    }..remove('');

    return memberNames.isNotEmpty &&
        appointmentNames.any((name) => memberNames.contains(name));
  }

  String _normalizeLookupKey(dynamic value) {
    return cleanText(value).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _cleanStaffStatus(Map<String, dynamic> member) {
    final keys = [
      'professional_status',
      'professionalStatus',
      'status',
      'availability_status',
      'availabilityStatus',
      'live_status',
      'liveStatus',
      'current_status',
      'currentStatus',
      'memberStatus',
    ];
    for (final key in keys) {
      final value = cleanText(member[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
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
    final normalized = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final isAvailable = normalized.contains('available') ||
        normalized.contains('active') ||
        normalized == 'online';
    final isBusy = normalized.contains('busy') ||
        normalized.contains('occupied') ||
        normalized.contains('in progress') ||
        normalized.contains('working');
    final isBreak = normalized.contains('break') ||
        normalized.contains('pause') ||
        normalized.contains('away');
    final isUnavailable = normalized.contains('unavailable') ||
        normalized.contains('offline') ||
        normalized.contains('inactive') ||
        normalized.contains('cancelled') ||
        normalized.contains('no show');
    final background = isAvailable
        ? const Color(0xFFE8FFF5)
        : isBusy
            ? const Color(0xFFFFF3E0)
            : isBreak
                ? const Color(0xFFF1F5F9)
                : isUnavailable
                    ? const Color(0xFFFDEDEF)
                    : const Color(0xFFFFF7E6);
    final foreground = isAvailable
        ? const Color(0xFF059669)
        : isBusy
            ? const Color(0xFFD97706)
            : isBreak
                ? const Color(0xFF64748B)
                : isUnavailable
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
        label.isEmpty ? 'Unknown' : _titleCase(normalized),
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
    final values =
        chartData.map((item) => asDouble(item['value']) / 100).toList();
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
      final value = asDouble(item['value']) / 100;
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

class _DrawerProfileQuoteCard extends StatelessWidget {
  const _DrawerProfileQuoteCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEDDD2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '"Investing in your hair is the\ncrown you never take off."',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              height: 1.25,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.72),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEDDD2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/profile_placeholder.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: AppColors.starColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jandrotia Amitabh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'APP USER',
                      style: TextStyle(
                        fontSize: 7.5,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.black.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
