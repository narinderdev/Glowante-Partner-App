import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../services/razorpay_checkout/razorpay_checkout.dart';
import '../services/razorpay_checkout/razorpay_checkout_models.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

const String _razorpayKeyId = 'rzp_test_KtuXq3FhhX7j5e';
const Color _membershipBackground = Color(0xFFFBFAF8);
const Color _membershipBorder = Color(0xFFE8DED6);
const Color _membershipText = Color(0xFF2B241D);
const Color _membershipMuted = Color(0xFF8C7A66);
const Color _membershipSurface = Colors.white;

class OwnerMembershipScreen extends StatefulWidget {
  const OwnerMembershipScreen({super.key});

  @override
  State<OwnerMembershipScreen> createState() => _OwnerMembershipScreenState();
}

class _OwnerMembershipScreenState extends State<OwnerMembershipScreen> {
  final ApiService _apiService = ApiService();
  GlowanteRazorpayCheckout? _checkout;

  List<_MembershipPlan> _plans = const [];
  List<_MembershipSalonOption> _salonOptions = const [];
  _MembershipSalonOption? _selectedSalon;
  _SalonSubscription? _subscription;
  int? _salonId;
  bool _isLoading = true;
  bool _isPaying = false;
  bool _yearlyBilling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  @override
  void dispose() {
    _checkout?.dispose();
    super.dispose();
  }

  Future<void> _loadMembership() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final salonOptions = await _loadSalonOptions();
      final salonId = salonOptions.selected?.salonId;
      final plansResponse = await _apiService.getMembershipPlans();
      final subscriptionResponse = salonId == null
          ? <String, dynamic>{'success': false}
          : await _apiService.getSalonSubscription(salonId);

      if (!mounted) return;
      setState(() {
        _salonId = salonId;
        _salonOptions = salonOptions.options;
        _selectedSalon = salonOptions.selected;
        _plans = _parsePlans(plansResponse);
        _subscription = _parseSubscription(subscriptionResponse);
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

  Future<_MembershipSalonSelection> _loadSalonOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _readInt(prefs.get('selected_salon_id'));

    final response = await _apiService.getSalonListApi();
    final salons =
        response['data'] is List ? response['data'] as List : const [];
    final options = <_MembershipSalonOption>[];
    for (final entry in salons) {
      if (entry is! Map) continue;
      final salon = Map<String, dynamic>.from(entry);
      final salonId = _readInt(salon['id']);
      if (salonId == null) continue;
      final salonAddress = _addressSummary(salon['address']);
      final branches = (salon['branches'] as List?) ?? const [];
      var fallbackBranchAddress = '';
      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;
        fallbackBranchAddress = _addressSummary(branchEntry['address']);
        if (fallbackBranchAddress.isNotEmpty) break;
      }
      options.add(
        _MembershipSalonOption(
          salonId: salonId,
          name: _cleanText(salon['name']).isEmpty
              ? 'Salon #$salonId'
              : _cleanText(salon['name']),
          address:
              salonAddress.isNotEmpty ? salonAddress : fallbackBranchAddress,
        ),
      );
    }

    final selected = options.cast<_MembershipSalonOption?>().firstWhere(
          (option) => option?.salonId == stored,
          orElse: () => options.isEmpty ? null : options.first,
        );

    if (selected != null) {
      await _saveSelectedSalon(selected);
    }

    return _MembershipSalonSelection(
      options: options,
      selected: selected,
    );
  }

  Future<void> _saveSelectedSalon(_MembershipSalonOption salon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_salon_id', salon.salonId);
    await prefs.setString('stylist_selected_salon_name', salon.name);
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

  List<_MembershipPlan> _parsePlans(Map<String, dynamic> response) {
    final data = response['data'];
    final rawPlans = data is List
        ? data
        : data is Map && data['plans'] is List
            ? data['plans'] as List
            : const [];
    return rawPlans
        .whereType<Map>()
        .map(
            (plan) => _MembershipPlan.fromJson(Map<String, dynamic>.from(plan)))
        .where((plan) => plan.id != null)
        .toList();
  }

  _SalonSubscription? _parseSubscription(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map) return null;
    return _SalonSubscription.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> _choosePlan(_MembershipPlan plan) async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnack('Please create or select a salon first.');
      return;
    }

    final selection = await showDialog<_PurchaseSelection>(
      context: context,
      barrierDismissible: !_isPaying,
      builder: (context) => _PurchaseDialog(
        plan: plan,
        initialYearlyBilling: _yearlyBilling,
        subscription: _subscription,
      ),
    );
    if (selection == null || !mounted) return;

    await _startPayment(salonId: salonId, selection: selection);
  }

  Future<void> _renewCurrentPlan() async {
    final subscription = _subscription;
    final salonId = _salonId;
    if (subscription == null || salonId == null) return;

    final plan = _planForSubscription(subscription);
    if (plan.id == null) {
      _showSnack('Unable to find current membership plan.');
      return;
    }

    final selection = await showDialog<_PurchaseSelection>(
      context: context,
      barrierDismissible: !_isPaying,
      builder: (context) => _RenewMembershipDialog(
        plan: plan,
        subscription: subscription,
      ),
    );
    if (selection == null || !mounted) return;

    await _startPayment(salonId: salonId, selection: selection);
  }

  Future<void> _showPaymentHistory() async {
    final subscription = _subscription;
    if (subscription == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) =>
          _PaymentHistoryDialog(history: subscription.history),
    );
  }

  Future<void> _showAvailablePlans() async {
    if (_plans.isEmpty) {
      _showSnack('Plans are not available right now.');
      return;
    }

    final selectedPlan = await showDialog<_MembershipPlan>(
      context: context,
      builder: (context) => _AvailablePlansDialog(
        plans: _plans,
        yearlyBilling: _yearlyBilling,
        currentPlanId: _subscription?.currentPlanId,
        onBillingChanged: (value) => setState(() => _yearlyBilling = value),
      ),
    );
    if (selectedPlan == null || !mounted) return;

    await _choosePlan(selectedPlan);
  }

  _MembershipPlan _planForSubscription(_SalonSubscription subscription) {
    for (final plan in _plans) {
      if (plan.id == subscription.currentPlanId) return plan;
    }
    return _MembershipPlan(
      id: subscription.currentPlanId,
      name: subscription.currentPlan,
      description: '',
      monthlyPriceMinor: subscription.amountMinor,
      annualPriceMinor: subscription.amountMinor * 12,
      branchLimit: subscription.branchUsage.limit,
      staffLimit: subscription.staffUsage.limit,
      storageLimit: subscription.storageUsage.limit,
      includedFeatures: const [],
      currency: subscription.currency,
      isRecommended: false,
    );
  }

  Future<void> _startPayment({
    required int salonId,
    required _PurchaseSelection selection,
  }) async {
    if (selection.amountMinor <= 0) {
      _showSnack('Selected plan amount is invalid.');
      return;
    }

    setState(() => _isPaying = true);

    final prefs = await SharedPreferences.getInstance();
    final checkout = _checkout ??= GlowanteRazorpayCheckout();
    final result = await checkout.open(
      RazorpayCheckoutRequest(
        key: _razorpayKeyId,
        amountMinor: selection.amountMinor,
        currency: selection.plan.currency,
        name: 'Glowante',
        description: '${selection.plan.name} membership',
        contact: prefs.getString('phone_number'),
        email: prefs.getString('email'),
      ),
    );

    if (!mounted) return;

    if (result.status == RazorpayCheckoutStatus.cancelled) {
      setState(() => _isPaying = false);
      _showSnack(result.message ?? 'Payment cancelled.');
      return;
    }

    if (result.status != RazorpayCheckoutStatus.success ||
        result.paymentId == null) {
      setState(() => _isPaying = false);
      _showSnack(result.message ?? 'Payment failed.');
      return;
    }

    final response = await _apiService.createSalonSubscription(
      salonId: salonId,
      planId: selection.plan.id!,
      billingCycle: selection.billingCycle,
      paymentReference: result.paymentId!,
      razorpayOrderId: result.orderId,
      razorpaySignature: result.signature,
      amountMinor: selection.amountMinor,
      currency: selection.plan.currency,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() => _isPaying = false);
      _showSnack('Membership updated successfully.');
      await _loadMembership();
      return;
    }

    setState(() => _isPaying = false);
    _showSnack(
        response['message']?.toString() ?? 'Unable to update membership.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateText(message))),
    );
  }

  Future<void> _switchSalon(_MembershipSalonOption salon) async {
    await _saveSelectedSalon(salon);
    if (!mounted) return;
    setState(() {
      _selectedSalon = salon;
      _salonId = salon.salonId;
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final subscriptionResponse =
          await _apiService.getSalonSubscription(salon.salonId);
      if (!mounted) return;
      setState(() {
        _subscription = _parseSubscription(subscriptionResponse);
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

  Widget _buildSalonSelector() {
    if (_selectedSalon == null) return const SizedBox.shrink();
    return OwnerBranchHeaderSelector<_MembershipSalonOption>(
      label: _selectedSalon!.name,
      options: _salonOptions
          .map(
            (salon) => OwnerBranchHeaderSelectorOption<_MembershipSalonOption>(
              value: salon,
              label: salon.name,
              subtitle: salon.address,
            ),
          )
          .toList(),
      selectedValue: _selectedSalon,
      placeholder: context.t('Select Salon'),
      isInteractive: _salonOptions.length > 1,
      onSelected: _switchSalon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _membershipBackground,
      appBar: buildProfileSubpageAppBar(title: context.t('Membership')),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.starColor,
            onRefresh: _loadMembership,
            child: _buildBody(),
          ),
          if (_isPaying)
            Container(
              color: Colors.black.withValues(alpha: 0.24),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.starColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.starColor),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _EmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load membership',
            message: _errorMessage!,
            actionLabel: 'Try Again',
            onAction: _loadMembership,
          ),
        ],
      );
    }

    if (_salonId == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _EmptyStateCard(
            icon: Icons.storefront_outlined,
            title: 'No salon found',
            message: 'Create a salon before choosing a membership plan.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Text(
          context.t('My Membership'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.starColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t('View your current plan, payment status, and expiry.'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: _membershipMuted,
          ),
        ),
        const SizedBox(height: 18),
        _buildSalonSelector(),
        const SizedBox(height: 18),
        if (_subscription != null) ...[
          _ExpiryBanner(
            subscription: _subscription!,
            onRenew: _renewCurrentPlan,
          ),
          const SizedBox(height: 18),
          _MembershipSummaryRow(
            subscription: _subscription!,
            actions: _MembershipActions(
              onRenew: _renewCurrentPlan,
              onPlans: _showAvailablePlans,
              onPaymentHistory: _showPaymentHistory,
            ),
          ),
          const SizedBox(height: 14),
          _UsageGrid(subscription: _subscription!),
          const SizedBox(height: 24),
        ],
        if (_subscription == null) ...[
          _PlansHeader(
            yearlyBilling: _yearlyBilling,
            onBillingChanged: (value) {
              setState(() => _yearlyBilling = value);
            },
          ),
          const SizedBox(height: 16),
          if (_plans.isEmpty)
            const _EmptyStateCard(
              icon: Icons.workspace_premium_outlined,
              title: 'No membership plans',
              message: 'Plans are not available right now.',
            )
          else
            _PlansGrid(
              plans: _plans,
              yearlyBilling: _yearlyBilling,
              currentPlanId: _subscription?.currentPlanId,
              onChoose: _choosePlan,
            ),
        ],
      ],
    );
  }
}

class _PlansHeader extends StatelessWidget {
  const _PlansHeader({
    required this.yearlyBilling,
    required this.onBillingChanged,
  });

  final bool yearlyBilling;
  final ValueChanged<bool> onBillingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Choose Your Membership Plan'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _membershipText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t('Select a plan that fits your salon and branches.'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: _membershipMuted,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BillingLabel(label: 'Monthly', active: !yearlyBilling),
            Switch(
              value: yearlyBilling,
              activeThumbColor: AppColors.starColor,
              activeTrackColor: const Color(0xFFE7D6A8),
              inactiveThumbColor: AppColors.starColor,
              inactiveTrackColor: const Color(0xFFE9E1D7),
              onChanged: onBillingChanged,
            ),
            _BillingLabel(label: 'Yearly', active: yearlyBilling),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE8C774)),
              ),
              child: const Text(
                'Save 20%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.starColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillingLabel extends StatelessWidget {
  const _BillingLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: active ? AppColors.starColor : _membershipMuted,
      ),
    );
  }
}

class _MembershipSalonSelection {
  const _MembershipSalonSelection({
    required this.options,
    required this.selected,
  });

  final List<_MembershipSalonOption> options;
  final _MembershipSalonOption? selected;
}

class _MembershipSalonOption {
  const _MembershipSalonOption({
    required this.salonId,
    required this.name,
    required this.address,
  });

  final int salonId;
  final String name;
  final String address;
}

class _PlansGrid extends StatelessWidget {
  const _PlansGrid({
    required this.plans,
    required this.yearlyBilling,
    required this.currentPlanId,
    required this.onChoose,
  });

  final List<_MembershipPlan> plans;
  final bool yearlyBilling;
  final int? currentPlanId;
  final ValueChanged<_MembershipPlan> onChoose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 780
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final plan in plans)
              SizedBox(
                width: cardWidth,
                child: _PlanCard(
                  plan: plan,
                  yearlyBilling: yearlyBilling,
                  isCurrent: currentPlanId == plan.id,
                  onChoose: () => onChoose(plan),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearlyBilling,
    required this.isCurrent,
    required this.onChoose,
  });

  final _MembershipPlan plan;
  final bool yearlyBilling;
  final bool isCurrent;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final amount = plan.amountFor(yearlyBilling);
    final suffix = yearlyBilling ? '/yr' : '/mo';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _membershipSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: plan.isRecommended ? AppColors.starColor : _membershipBorder,
          width: plan.isRecommended ? 1.3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _membershipText,
                  ),
                ),
              ),
              if (plan.isRecommended)
                const _StatusPill(label: 'Popular', color: AppColors.starColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description.isEmpty ? 'Membership plan' : plan.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              height: 1.35,
              color: _membershipMuted,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(amount, plan.currency),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _membershipText,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  suffix,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _membershipMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FeatureLine(text: '${plan.branchLimit} Branch'),
          _FeatureLine(text: '${plan.staffLimit} Staff members'),
          _FeatureLine(text: '${plan.storageLimit}GB Cloud Storage'),
          for (final feature in plan.includedFeatures.take(5))
            _FeatureLine(text: feature),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onChoose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isCurrent
                    ? context.t('Renew Plan')
                    : context.t('Choose ${plan.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
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

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17,
            height: 17,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF3D5),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 13,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                height: 1.35,
                color: _membershipText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentMembershipCard extends StatelessWidget {
  const _CurrentMembershipCard({required this.subscription});

  final _SalonSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                alignment: Alignment.center,
                child: Text(
                  subscription.salonName.isEmpty
                      ? 'S'
                      : subscription.salonName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: AppColors.starColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.salonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _membershipText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subscription.currentPlan} · ${_cycleLabel(subscription.billingCycle)} Billing',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: _membershipMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: subscription.paymentStatus,
                color: subscription.paymentStatus.toUpperCase() == 'PAID'
                    ? const Color(0xFF2F8A4C)
                    : AppColors.starColor,
              ),
              const SizedBox(width: 6),
              _StatusPill(
                label: subscription.membershipStatus,
                color: AppColors.starColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 22,
            runSpacing: 14,
            children: [
              _Fact(label: 'Current Plan', value: subscription.currentPlan),
              _Fact(
                  label: 'Billing Cycle',
                  value: _cycleLabel(subscription.billingCycle)),
              _Fact(
                  label: 'Start Date',
                  value: _formatDate(subscription.startDate)),
              _Fact(
                  label: 'Expiry Date',
                  value: _formatDate(subscription.expiryDate)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('Time Remaining'),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: _membershipMuted,
                    ),
                  ),
                ),
                Text(
                  '${subscription.daysRemaining.clamp(0, 9999)}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.starColor,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  context.t('days left'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: _membershipMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipSummaryRow extends StatelessWidget {
  const _MembershipSummaryRow({
    required this.subscription,
    required this.actions,
  });

  final _SalonSubscription subscription;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              _CurrentMembershipCard(subscription: subscription),
              const SizedBox(height: 14),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _CurrentMembershipCard(subscription: subscription),
            ),
            const SizedBox(width: 14),
            SizedBox(width: 260, child: actions),
          ],
        );
      },
    );
  }
}

class _MembershipActions extends StatelessWidget {
  const _MembershipActions({
    required this.onRenew,
    required this.onPlans,
    required this.onPaymentHistory,
  });

  final VoidCallback onRenew;
  final VoidCallback onPlans;
  final VoidCallback onPaymentHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _ActionRow(
              icon: Icons.refresh_rounded, label: 'Renew Plan', onTap: onRenew),
          const Divider(height: 1, color: _membershipBorder),
          _ActionRow(
              icon: Icons.trending_up_rounded,
              label: 'Upgrade Plan',
              onTap: onPlans),
          const Divider(height: 1, color: _membershipBorder),
          _ActionRow(
            icon: Icons.workspace_premium_outlined,
            label: 'View Available Plans',
            onTap: onPlans,
          ),
          const Divider(height: 1, color: _membershipBorder),
          _ActionRow(
            icon: Icons.flash_on_rounded,
            label: 'Payment History',
            onTap: onPaymentHistory,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.starColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t(label),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _membershipText,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _membershipMuted),
          ],
        ),
      ),
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  const _ExpiryBanner({
    required this.subscription,
    required this.onRenew,
  });

  final _SalonSubscription subscription;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysRemaining;
    if (days > 30) return const SizedBox.shrink();
    final expired = days < 0;
    final message = expired
        ? context.t('Your membership has expired. Renew to continue service.')
        : context.t(
            'Your membership will expire in $days days. Renew early to avoid service interruption.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final icon = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            size: 16,
            color: AppColors.starColor,
          ),
        );
        final text = Text(
          message,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.starColor,
          ),
        );
        final button = ElevatedButton(
          onPressed: onRenew,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 42),
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(context.t('Renew Now')),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8C774)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: text),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: text),
                    const SizedBox(width: 10),
                    SizedBox(width: 124, child: button),
                  ],
                ),
        );
      },
    );
  }
}

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.subscription});

  final _SalonSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _UsageCardData('BR', 'Branches Used', subscription.branchUsage),
      _UsageCardData('ST', 'Staff Used', subscription.staffUsage),
      _UsageCardData('GB', 'Storage Used', subscription.storageUsage,
          suffix: 'GB'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 780
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _UsageCard(data: card)),
          ],
        );
      },
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.data});

  final _UsageCardData data;

  @override
  Widget build(BuildContext context) {
    final limit = data.usage.limit <= 0 ? 1 : data.usage.limit;
    final percent = (data.usage.used / limit).clamp(0, 1).toDouble();
    final remaining = (data.usage.limit - data.usage.used).clamp(0, 999999);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  data.prefix,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.starColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(data.title).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.starColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: _membershipText,
              ),
              children: [
                TextSpan(
                  text: '${data.usage.used}${data.suffix}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' / ${data.usage.limit}${data.suffix}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _membershipMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            minHeight: 3,
            backgroundColor: const Color(0xFFE9E1D7),
            color: AppColors.starColor,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 10),
          Text(
            '$remaining ${context.t('slots remaining')}',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              color: _membershipMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryDialog extends StatelessWidget {
  const _PaymentHistoryDialog({required this.history});

  final List<_SubscriptionHistory> history;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Payment History'),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppColors.starColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t(
                              'Subscription payments from your membership history.',
                            ),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: _membershipMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.starColor,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _membershipBorder),
              Padding(
                padding: const EdgeInsets.all(22),
                child: history.isEmpty
                    ? Text(
                        context.t('No payment history available.'),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: _membershipMuted,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in history.take(5)) ...[
                            _PaymentHistoryItem(item: item),
                            if (item != history.take(5).last)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  const _PaymentHistoryItem({required this.item});

  final _SubscriptionHistory item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.planName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _membershipText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isCurrent)
                          const _StatusPill(
                            label: 'Current',
                            color: Color(0xFF2F8A4C),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_cycleLabel(item.billingCycle)} billing',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: _membershipMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMoney(item.amountMinor, item.currency),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.starColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusPill(
                    label: item.paymentStatus,
                    color: item.paymentStatus.toUpperCase() == 'PAID'
                        ? const Color(0xFF2F8A4C)
                        : AppColors.starColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final facts = [
                _Fact(label: 'Start Date', value: _formatDate(item.startDate)),
                _Fact(
                    label: 'Expiry Date', value: _formatDate(item.expiryDate)),
                _Fact(
                    label: 'Membership',
                    value: _titleCase(item.membershipStatus)),
                _Fact(label: 'Reference', value: item.paymentReference),
              ];
              if (compact) {
                return Wrap(spacing: 12, runSpacing: 14, children: facts);
              }
              return Row(
                children: [
                  for (final fact in facts) Expanded(child: fact),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AvailablePlansDialog extends StatefulWidget {
  const _AvailablePlansDialog({
    required this.plans,
    required this.yearlyBilling,
    required this.currentPlanId,
    required this.onBillingChanged,
  });

  final List<_MembershipPlan> plans;
  final bool yearlyBilling;
  final int? currentPlanId;
  final ValueChanged<bool> onBillingChanged;

  @override
  State<_AvailablePlansDialog> createState() => _AvailablePlansDialogState();
}

class _AvailablePlansDialogState extends State<_AvailablePlansDialog> {
  late bool _yearlyBilling = widget.yearlyBilling;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlansHeader(
                      yearlyBilling: _yearlyBilling,
                      onBillingChanged: (value) {
                        setState(() => _yearlyBilling = value);
                        widget.onBillingChanged(value);
                      },
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.starColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PlansGrid(
                plans: widget.plans,
                yearlyBilling: _yearlyBilling,
                currentPlanId: widget.currentPlanId,
                onChoose: (plan) => Navigator.pop(context, plan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenewMembershipDialog extends StatefulWidget {
  const _RenewMembershipDialog({
    required this.plan,
    required this.subscription,
  });

  final _MembershipPlan plan;
  final _SalonSubscription subscription;

  @override
  State<_RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends State<_RenewMembershipDialog> {
  bool _yearlyBilling = false;
  String _paymentMethod = 'Saved Credit Card (**** 4242)';

  @override
  Widget build(BuildContext context) {
    final baseDate = _renewalBaseDate(widget.subscription.expiryDate);
    final newExpiryDate = DateTime(
      baseDate.year + (_yearlyBilling ? 1 : 0),
      baseDate.month + (_yearlyBilling ? 0 : 1),
      baseDate.day,
    );
    final amount = widget.plan.amountFor(_yearlyBilling);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('Renew Membership'),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.starColor,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.starColor,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _membershipBorder),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAF1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8C774)),
                      ),
                      child: Column(
                        children: [
                          _DialogFact(
                            label: 'Salon Name',
                            value: widget.subscription.salonName,
                          ),
                          _DialogFact(
                            label: 'Current Plan',
                            value: widget.subscription.currentPlan,
                          ),
                          _DialogFact(
                            label: 'Current Expiry',
                            value: _formatDate(widget.subscription.expiryDate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('Renewal Duration').toUpperCase(),
                      style: _dialogLabelStyle(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                              value: false, label: Text('Monthly')),
                          ButtonSegment<bool>(
                              value: true, label: Text('Yearly (Save 15%)')),
                        ],
                        selected: {_yearlyBilling},
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? AppColors.starColor
                                : Colors.white;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? Colors.white
                                : _membershipText;
                          }),
                          side: const WidgetStatePropertyAll(
                            BorderSide(color: Color(0xFFE8C774)),
                          ),
                        ),
                        onSelectionChanged: (values) {
                          setState(() => _yearlyBilling = values.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogReadonlyBox(
                            label: 'New Expiry Date',
                            value: _formatDate(newExpiryDate),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DialogReadonlyBox(
                            label: 'Amount Payable',
                            value: _formatMoney(amount, widget.plan.currency),
                            emphasize: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('Payment Method').toUpperCase(),
                      style: _dialogLabelStyle(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFFAF1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE8C774)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.starColor),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'Saved Credit Card (**** 4242)',
                          child: Text('Saved Credit Card (**** 4242)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Razorpay',
                          child: Text('Razorpay'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _paymentMethod = value);
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _membershipText,
                              side: const BorderSide(color: Color(0xFFE8C774)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(context.t('Cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                _PurchaseSelection(
                                  plan: widget.plan,
                                  billingCycle:
                                      _billingCycleApiValue(_yearlyBilling),
                                  amountMinor: amount,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(context.t('Renew Now')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({
    required this.plan,
    required this.initialYearlyBilling,
    required this.subscription,
  });

  final _MembershipPlan plan;
  final bool initialYearlyBilling;
  final _SalonSubscription? subscription;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late bool _yearlyBilling = widget.initialYearlyBilling;

  @override
  Widget build(BuildContext context) {
    final amount = widget.plan.amountFor(_yearlyBilling);
    final startDate = DateTime.now();
    final validUntil = DateTime(
      startDate.year + (_yearlyBilling ? 1 : 0),
      startDate.month + (_yearlyBilling ? 0 : 1),
      startDate.day,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('Complete Purchase'),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.starColor,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: Column(
                  children: [
                    _DialogFact(
                        label: 'Plan Selected', value: widget.plan.name),
                    _DialogFact(
                      label: 'Salon',
                      value: widget.subscription?.salonName ?? 'Glowante Salon',
                    ),
                    _DialogFact(
                        label: 'Valid Until', value: _formatDate(validUntil)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('Billing Duration').toUpperCase(),
                style: _dialogLabelStyle(),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Monthly')),
                  ButtonSegment<bool>(
                      value: true, label: Text('Yearly (Save 20%)')),
                ],
                selected: {_yearlyBilling},
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? AppColors.starColor
                        : Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : _membershipText;
                  }),
                  side: const WidgetStatePropertyAll(
                    BorderSide(color: Color(0xFFE8C774)),
                  ),
                ),
                onSelectionChanged: (values) {
                  setState(() => _yearlyBilling = values.first);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogReadonlyBox(
                      label: 'Start Date',
                      value: _formatDate(startDate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogReadonlyBox(
                      label: 'Amount Payable',
                      value: _formatMoney(amount, widget.plan.currency),
                      emphasize: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _membershipText,
                        side: const BorderSide(color: Color(0xFFE8C774)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(context.t('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _PurchaseSelection(
                            plan: widget.plan,
                            billingCycle: _billingCycleApiValue(_yearlyBilling),
                            amountMinor: amount,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: FittedBox(
                          child: Text(context.t('Pay with Razorpay'))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogReadonlyBox extends StatelessWidget {
  const _DialogReadonlyBox({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(label).toUpperCase(), style: _dialogLabelStyle()),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: emphasize ? AppColors.starColor : const Color(0xFFE8C774),
            ),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              color: _membershipText,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogFact extends StatelessWidget {
  const _DialogFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t(label).toUpperCase(),
              style: _dialogLabelStyle(),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _membershipText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(label).toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _membershipText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        context.t(_titleCase(label)),
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppColors.starColor, size: 30),
          const SizedBox(height: 10),
          Text(
            context.t(title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _membershipText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: _membershipMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
              ),
              child: Text(context.t(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipPlan {
  const _MembershipPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPriceMinor,
    required this.annualPriceMinor,
    required this.branchLimit,
    required this.staffLimit,
    required this.storageLimit,
    required this.includedFeatures,
    required this.currency,
    required this.isRecommended,
  });

  factory _MembershipPlan.fromJson(Map<String, dynamic> json) {
    return _MembershipPlan(
      id: _readInt(json['id']),
      name:
          _cleanText(json['name']).isEmpty ? 'Plan' : _cleanText(json['name']),
      description: _cleanText(json['description']),
      monthlyPriceMinor: _readInt(json['monthlyPriceMinor']) ?? 0,
      annualPriceMinor: _readInt(json['annualPriceMinor']) ?? 0,
      branchLimit: _readInt(json['branchLimit']) ?? 0,
      staffLimit: _readInt(json['staffLimit']) ?? 0,
      storageLimit: _readInt(json['storageLimit']) ?? 0,
      includedFeatures: json['includedFeatures'] is List
          ? (json['includedFeatures'] as List)
              .map((item) => _cleanText(item))
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
      currency: _cleanText(json['currency']).isEmpty
          ? 'INR'
          : _cleanText(json['currency']),
      isRecommended: json['isRecommended'] == true,
    );
  }

  final int? id;
  final String name;
  final String description;
  final int monthlyPriceMinor;
  final int annualPriceMinor;
  final int branchLimit;
  final int staffLimit;
  final int storageLimit;
  final List<String> includedFeatures;
  final String currency;
  final bool isRecommended;

  int amountFor(bool yearlyBilling) {
    if (yearlyBilling && annualPriceMinor > 0) return annualPriceMinor;
    return monthlyPriceMinor;
  }
}

class _SalonSubscription {
  const _SalonSubscription({
    required this.salonName,
    required this.currentPlanId,
    required this.currentPlan,
    required this.paymentStatus,
    required this.membershipStatus,
    required this.startDate,
    required this.expiryDate,
    required this.billingCycle,
    required this.amountMinor,
    required this.currency,
    required this.branchUsage,
    required this.staffUsage,
    required this.storageUsage,
    required this.history,
  });

  factory _SalonSubscription.fromJson(Map<String, dynamic> json) {
    return _SalonSubscription(
      salonName: _cleanText(json['salonName']).isEmpty
          ? 'Salon'
          : _cleanText(json['salonName']),
      currentPlanId: _readInt(json['currentPlanId']),
      currentPlan: _cleanText(json['currentPlan']).isEmpty
          ? 'Plan'
          : _cleanText(json['currentPlan']),
      paymentStatus: _cleanText(json['paymentStatus']).isEmpty
          ? 'UNKNOWN'
          : _cleanText(json['paymentStatus']),
      membershipStatus: _cleanText(json['membershipStatus']).isEmpty
          ? 'UNKNOWN'
          : _cleanText(json['membershipStatus']),
      startDate: _parseDate(json['startDate']),
      expiryDate: _parseDate(json['expiryDate']),
      billingCycle: _cleanText(json['billingCycle']).isEmpty
          ? 'MONTHLY'
          : _cleanText(json['billingCycle']),
      amountMinor: _readInt(json['amountMinor']) ?? 0,
      currency: _cleanText(json['currency']).isEmpty
          ? 'INR'
          : _cleanText(json['currency']),
      branchUsage: _Usage.fromJson(json['branchUsage']),
      staffUsage: _Usage.fromJson(json['staffUsage']),
      storageUsage: _Usage.fromJson(json['storageUsage']),
      history: json['history'] is List
          ? (json['history'] as List)
              .whereType<Map>()
              .map((item) => _SubscriptionHistory.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  final String salonName;
  final int? currentPlanId;
  final String currentPlan;
  final String paymentStatus;
  final String membershipStatus;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final String billingCycle;
  final int amountMinor;
  final String currency;
  final _Usage branchUsage;
  final _Usage staffUsage;
  final _Usage storageUsage;
  final List<_SubscriptionHistory> history;

  int get daysRemaining {
    final expiry = expiryDate;
    if (expiry == null) return 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiryDateOnly = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDateOnly.difference(todayDate).inDays;
  }
}

class _SubscriptionHistory {
  const _SubscriptionHistory({
    required this.planName,
    required this.billingCycle,
    required this.paymentStatus,
    required this.membershipStatus,
    required this.startDate,
    required this.expiryDate,
    required this.amountMinor,
    required this.currency,
    required this.paymentReference,
    required this.isCurrent,
  });

  factory _SubscriptionHistory.fromJson(Map<String, dynamic> json) {
    return _SubscriptionHistory(
      planName: _cleanText(json['planName']).isEmpty
          ? 'Plan'
          : _cleanText(json['planName']),
      billingCycle: _cleanText(json['billingCycle']),
      paymentStatus: _cleanText(json['paymentStatus']),
      membershipStatus: _cleanText(json['membershipStatus']).isEmpty
          ? 'UNKNOWN'
          : _cleanText(json['membershipStatus']),
      startDate: _parseDate(json['startDate']),
      expiryDate: _parseDate(json['expiryDate']),
      amountMinor: _readInt(json['amountMinor']) ?? 0,
      currency: _cleanText(json['currency']).isEmpty
          ? 'INR'
          : _cleanText(json['currency']),
      paymentReference: _cleanText(json['paymentReference']),
      isCurrent: json['isCurrent'] == true,
    );
  }

  final String planName;
  final String billingCycle;
  final String paymentStatus;
  final String membershipStatus;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final int amountMinor;
  final String currency;
  final String paymentReference;
  final bool isCurrent;
}

class _Usage {
  const _Usage({required this.used, required this.limit});

  factory _Usage.fromJson(dynamic json) {
    if (json is! Map) return const _Usage(used: 0, limit: 0);
    return _Usage(
      used: _readInt(json['used']) ?? 0,
      limit: _readInt(json['limit']) ?? 0,
    );
  }

  final int used;
  final int limit;
}

class _UsageCardData {
  const _UsageCardData(
    this.prefix,
    this.title,
    this.usage, {
    this.suffix = '',
  });

  final String prefix;
  final String title;
  final _Usage usage;
  final String suffix;
}

class _PurchaseSelection {
  const _PurchaseSelection({
    required this.plan,
    required this.billingCycle,
    required this.amountMinor,
  });

  final _MembershipPlan plan;
  final String billingCycle;
  final int amountMinor;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: _membershipSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _membershipBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );
}

TextStyle _dialogLabelStyle() {
  return const TextStyle(
    fontFamily: 'Manrope',
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: AppColors.starColor,
  );
}

String _formatMoney(int amountMinor, String currency) {
  final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: symbol,
    decimalDigits: 0,
  ).format(amountMinor / 100);
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd MMM yyyy').format(date);
}

DateTime _renewalBaseDate(DateTime? expiryDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (expiryDate == null) return today;
  final expiryOnly =
      DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
  return expiryOnly.isAfter(today) ? expiryOnly : today;
}

String _cycleLabel(String cycle) {
  final normalized = cycle.toUpperCase();
  if (normalized == 'YEARLY' || normalized == 'ANNUAL') return 'Yearly';
  return 'Monthly';
}

String _billingCycleApiValue(bool yearlyBilling) {
  return yearlyBilling ? 'ANNUAL' : 'MONTHLY';
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _cleanText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

DateTime? _parseDate(dynamic value) {
  final raw = _cleanText(value);
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
