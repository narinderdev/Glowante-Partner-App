import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../widgets/app_loader.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistServicesScreen extends StatefulWidget {
  const StylistServicesScreen({
    super.key,
    this.refreshSignal = 0,
  });

  final int refreshSignal;

  @override
  State<StylistServicesScreen> createState() => _StylistServicesScreenState();
}

class _StylistServicesScreenState extends State<StylistServicesScreen> {
  final ApiService _apiService = ApiService();

  StylistBranchSelection _selection = const StylistBranchSelection();
  List<Map<String, dynamic>> _services = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StylistServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  String _readText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  int get _activeServiceCount => _services
      .where((service) =>
          service['isActive'] != false &&
          service['branchServiceActive'] != false)
      .length;

  ({
    bool foundBranch,
    bool hasAssignedPayload,
    List<Map<String, dynamic>> items
  }) _extractAssignedServices(
    List<Map<String, dynamic>> userBranches,
    int branchId,
  ) {
    for (final rawEntry in userBranches) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final rawBranch = entry['branch'];
      if (rawBranch is! Map) {
        continue;
      }

      final branch = Map<String, dynamic>.from(rawBranch);
      if (_asInt(branch['id']) != branchId) {
        continue;
      }

      final rawAssigned = entry['userBranchServices'];
      if (rawAssigned is! List) {
        return (
          foundBranch: true,
          hasAssignedPayload: false,
          items: const <Map<String, dynamic>>[],
        );
      }

      final items = rawAssigned
          .whereType<Map>()
          .map((rawItem) {
            final item = Map<String, dynamic>.from(rawItem);
            final rawBranchService = item['branchService'];
            final service = rawBranchService is Map
                ? Map<String, dynamic>.from(rawBranchService)
                : <String, dynamic>{};

            if (item['id'] != null) {
              service['userBranchServiceId'] = item['id'];
            }
            return service;
          })
          .where((service) => service.isNotEmpty)
          .toList();

      return (
        foundBranch: true,
        hasAssignedPayload: true,
        items: items,
      );
    }

    return (
      foundBranch: false,
      hasAssignedPayload: false,
      items: const <Map<String, dynamic>>[],
    );
  }

  // Flat-shape services (from UserRoleSession.fetchFreshUserBranches — the
  // live getTeamMemberDetailV2 endpoint) for the given branchId, if that
  // branch is present in the fresh fetch and has a non-empty services list.
  // Same flat/nested branch-id matching as stylist_schedule_screen.dart.
  List<Map<String, dynamic>>? _freshServicesForBranch(
    List<Map<String, dynamic>> freshBranches,
    int branchId,
  ) {
    for (final entry in freshBranches) {
      final rawBranch = entry['branch'];
      final entryBranchId = rawBranch is Map
          ? _asInt(rawBranch['id'])
          : _asInt(entry['branchId']);
      if (entryBranchId != branchId) continue;

      final services = entry['services'];
      if (services is List && services.isNotEmpty) {
        return services
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return null;
    }
    return null;
  }

  Future<void> _loadData() async {
    final selection = await StylistBranchSelectionStore.load();
    debugPrint(
      '[StylistServices] opening services for branchId=${selection.branchId}, salonId=${selection.salonId}, label=${selection.label}',
    );

    if (!mounted) return;
    setState(() {
      _selection = selection;
      _isLoading = true;
      _errorMessage = null;
    });

    if (selection.branchId == null) {
      debugPrint('[StylistServices] no branch selected, skipping API call');
      setState(() {
        _services = const [];
        _isLoading = false;
      });
      return;
    }

    final freshBranches =
        await UserRoleSession.instance.fetchFreshUserBranches();
    final freshServices =
        _freshServicesForBranch(freshBranches, selection.branchId!);
    if (freshServices != null) {
      if (!mounted) return;
      setState(() {
        _services = freshServices;
        _errorMessage = null;
        _isLoading = false;
      });
      debugPrint(
        '[StylistServices] using live services for branchId=${selection.branchId}, count=${_services.length}',
      );
      return;
    }

    final assignedServicesResult = _extractAssignedServices(
      await UserRoleSession.instance.loadUserBranches(),
      selection.branchId!,
    );

    if (assignedServicesResult.foundBranch &&
        assignedServicesResult.hasAssignedPayload) {
      if (!mounted) return;
      setState(() {
        _services = assignedServicesResult.items;
        _errorMessage = null;
        _isLoading = false;
      });
      debugPrint(
        '[StylistServices] using assigned services from OTP for branchId=${selection.branchId}, count=${_services.length}',
      );
      return;
    }

    final response =
        await _apiService.fetchBranchServicesFlat(selection.branchId!);
    final rawData = response['data'];
    final items = rawData is List ? rawData : const [];

    if (!mounted) return;
    setState(() {
      _services = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _errorMessage =
          response['success'] == true ? null : response['message']?.toString();
      _isLoading = false;
    });
    debugPrint(
      '[StylistServices] parsed ${_services.length} services, error=$_errorMessage',
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('Services')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => RefreshFeedback.playAndDetach(_loadData),
            color: AppColors.starColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (_selection.branchId == null)
                  _EmptyState(
                    message: context.t('Select a salon in Bookings first'),
                  )
                else if (_isLoading)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                  )
                else if (_errorMessage != null && _services.isEmpty)
                  _EmptyState(message: _errorMessage!)
                else if (_services.isEmpty)
                  _EmptyState(
                    message: context.t('No services found for this branch'),
                  )
                else ...[
                  _ServicesSummaryCard(
                    branchName: _selection.label,
                    totalCount: _services.length,
                    activeCount: _activeServiceCount,
                  ),
                  const SizedBox(height: 14),
                  ..._services.map((service) {
                    final name = _readText(
                      service,
                      const ['displayName', 'name', 'title'],
                    );
                    final isActive = service['isActive'] != false &&
                        service['branchServiceActive'] != false;

                    return _ServiceStrip(
                      name: name.isEmpty ? context.t('Service') : name,
                      isActive: isActive,
                    );
                  }),
                ],
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: AppLoader.page(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServicesSummaryCard extends StatelessWidget {
  const _ServicesSummaryCard({
    required this.branchName,
    required this.totalCount,
    required this.activeCount,
  });

  final String branchName;
  final int totalCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branchName.trim().isEmpty
                ? context.t('Services')
                : branchName.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ServiceSummaryPill(
                label: context.t('Active'),
                value: activeCount.toString(),
                color: const Color(0xFF166534),
                background: const Color(0xFFECFDF3),
              ),
              const SizedBox(width: 8),
              _ServiceSummaryPill(
                label: context.t('Services'),
                value: totalCount.toString(),
                color: const Color(0xFF9A3412),
                background: const Color(0xFFFFF7ED),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceSummaryPill extends StatelessWidget {
  const _ServiceSummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ServiceStrip extends StatelessWidget {
  const _ServiceStrip({
    required this.name,
    required this.isActive,
  });

  final String name;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isActive ? const Color(0xFF166534) : const Color(0xFF78716C);
    final statusBackground =
        isActive ? const Color(0xFFECFDF3) : const Color(0xFFF5F5F4);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.25,
                color: Color(0xFF1C1917),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              context.t(isActive ? 'Active' : 'Inactive'),
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.spa_outlined,
            size: 42,
            color: AppColors.starColor,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF57534E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
