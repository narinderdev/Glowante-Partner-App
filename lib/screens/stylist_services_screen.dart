import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../services/user_role_session.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:bloc_onboarding/utils/price_formatter.dart';

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

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
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

  String _commissionTypeLabel(Map<String, dynamic> service) {
    if (service['commissionEnabled'] != true) {
      return context.t('Commission off');
    }

    final type = _readText(service, const ['commissionType']).toLowerCase();
    if (type == 'fixed') return context.t('Fixed commission');
    if (type == 'percentage') return context.t('Percentage commission');
    return context.t('Commission enabled');
  }

  String _commissionValueLabel(Map<String, dynamic> service) {
    if (service['commissionEnabled'] != true) return context.t('No commission');

    final type = _readText(service, const ['commissionType']).toLowerCase();
    if (type == 'fixed') {
      final amount = _asInt(service['commissionFixedAmountMinor']);
      return amount != null ? formatMinorAmount(amount) : context.t('Fixed');
    }

    if (type == 'percentage') {
      final percent = _asDouble(service['commissionPercentage']);
      final maxAmount = _asInt(service['commissionMaxAmountMinor']);
      final percentLabel = percent == null
          ? context.t('Percentage')
          : '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}%';
      return maxAmount != null
          ? '$percentLabel • max ${formatMinorAmount(maxAmount)}'
          : percentLabel;
    }

    return context.t('Enabled');
  }

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
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.t('Services'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SelectionHeader(
              title: context.t('Current Salon'),
              value: _selection.label.isEmpty
                  ? context.t('Select a salon in Bookings first')
                  : _selection.label,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selection.branchId == null)
              _EmptyState(
                message: context.t('Select a salon in Bookings first'),
              )
            else if (_errorMessage != null && _services.isEmpty)
              _EmptyState(message: _errorMessage!)
            else if (_services.isEmpty)
              _EmptyState(
                message: context.t('No services found for this branch'),
              )
            else
              ..._services.map((service) {
                final name =
                    _readText(service, const ['displayName', 'name', 'title']);
                final category = _readText(service, const ['categoryName']);
                final subcategory =
                    _readText(service, const ['subCategoryName']);
                final duration = _asInt(
                  service['durationMin'] ?? service['defaultDurationMin'],
                );
                final price = _asInt(
                  service['priceMinor'] ?? service['defaultPriceMinor'],
                );
                final priceType =
                    _readText(service, const ['priceType']).toLowerCase();
                final bool isActive = service['isActive'] != false;
                final commissionType = _commissionTypeLabel(service);
                final commissionValue = _commissionValueLabel(service);

                final details = <String>[
                  if (category.isNotEmpty) category,
                  if (subcategory.isNotEmpty) subcategory,
                  if (duration != null && duration > 0) '$duration min',
                ].join(' • ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      name.isEmpty ? context.t('Services') : name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (details.isNotEmpty) Text(details),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _InfoPill(
                              text: commissionType,
                              backgroundColor: const Color(0xFFF6EFE3),
                              textColor: AppColors.starColor,
                            ),
                            _InfoPill(
                              text: commissionValue,
                              backgroundColor: const Color(0xFFF3F4F6),
                              textColor: Colors.black54,
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (price != null)
                          Text(
                            priceType.isNotEmpty
                                ? '${formatMinorAmount(price)} ($priceType)'
                                : formatMinorAmount(price),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.12)
                                : Colors.grey.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.t(isActive ? 'Active' : 'Inactive'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive ? Colors.green : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.black54),
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
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
