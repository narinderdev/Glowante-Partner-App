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
const String _monthlyBlockedMessage =
    'Monthly billing is available for all salons.';

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

  bool get _monthlyPlansBlocked => false;

  void _logMembership(String event, {Object? details}) {
    debugPrint(
      '[OwnerMembership] $event${details == null ? '' : ' | $details'}',
    );
  }

  String _responseSummary(Map<String, dynamic> response) {
    final data = response['data'];
    final dataSummary = data is Map
        ? <String>[
            if (data['id'] != null) 'id=${data['id']}',
            if (data['paymentTransactionId'] != null)
              'paymentTransactionId=${data['paymentTransactionId']}',
            if (data['razorpayOrderId'] != null)
              'razorpayOrderId=${data['razorpayOrderId']}',
            if (data['currentPlanId'] != null)
              'currentPlanId=${data['currentPlanId']}',
            if (data['currentPlan'] != null)
              'currentPlan=${data['currentPlan']}',
            if (data['membershipStatus'] != null)
              'membershipStatus=${data['membershipStatus']}',
          ].join(', ')
        : data?.toString() ?? 'null';

    return <String>[
      'success=${response['success']}',
      if (response['statusCode'] != null)
        'statusCode=${response['statusCode']}',
      if (_cleanText(response['message']).isNotEmpty)
        'message=${_cleanText(response['message'])}',
      'data={$dataSummary}',
    ].join(' | ');
  }

  Map<String, dynamic> _responseDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final root = Map<String, dynamic>.from(data);
      for (final key in const [
        'paymentOrder',
        'payment_order',
        'order',
        'subscription',
        'membership',
      ]) {
        final nested = root[key];
        if (nested is Map) {
          return Map<String, dynamic>.from(nested);
        }
      }
      return root;
    }
    return response;
  }

  String _purchaseSelectionSummary(_PurchaseSelection selection) {
    return 'planId=${selection.plan.id}, plan=${selection.plan.name}, '
        'billingCycle=${selection.billingCycle}, amountMinor=${selection.amountMinor}, '
        'renew=${selection.renew}, replaceCurrentPlan=${selection.replaceCurrentPlan}, '
        'startDate=${_apiDateString(selection.startDate)}';
  }

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
    _logMembership('load_start');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logMembership('load_salon_options_start');
      final salonOptions = await _loadSalonOptions();
      final salonId = salonOptions.selected?.salonId;
      _logMembership(
        'load_plans_start',
        details: 'selectedSalonId=${salonId ?? 'none'}',
      );
      final plansResponse = await _apiService.getMembershipPlans();
      _logMembership(
        'load_plans_success',
        details: _responseSummary(plansResponse),
      );
      final subscriptionResponse = salonId == null
          ? <String, dynamic>{'success': false}
          : await _apiService.getSalonSubscription(salonId);
      _logMembership(
        'load_subscription_response',
        details: salonId == null
            ? 'skipped_no_salon'
            : _responseSummary(subscriptionResponse),
      );

      if (!mounted) return;
      setState(() {
        _salonId = salonId;
        _salonOptions = salonOptions.options;
        _selectedSalon = salonOptions.selected;
        _plans = _parsePlans(plansResponse);
        _subscription = _parseSubscription(subscriptionResponse);
        _isLoading = false;
      });
      _logMembership(
        'load_success',
        details: 'salonId=${_salonId ?? 'none'}, '
            'salonOptions=${_salonOptions.length}, '
            'plans=${_plans.length}, '
            'subscription=${_subscription == null ? 'none' : 'loaded'}',
      );
    } catch (error) {
      _logMembership('load_failure', details: error);
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
    _logMembership('load_salon_options_prefs',
        details: 'storedSalonId=${stored ?? 'none'}');

    final response = await _apiService.getSalonListApi();
    _logMembership('load_salon_options_response',
        details: _responseSummary(response));
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
          branchCount: branches.length,
        ),
      );
      _logMembership(
        'load_salon_option_item',
        details: 'salonId=$salonId, name=${_cleanText(salon['name'])}, '
            'branches=${branches.length}, address=${options.last.address}',
      );
    }

    final selected = options.cast<_MembershipSalonOption?>().firstWhere(
          (option) => option?.salonId == stored,
          orElse: () => options.isEmpty ? null : options.first,
        );

    if (selected != null) {
      await _saveSelectedSalon(selected);
    }

    _logMembership(
      'load_salon_options_selected',
      details: selected == null
          ? 'none'
          : 'salonId=${selected.salonId}, name=${selected.name}',
    );

    return _MembershipSalonSelection(
      options: options,
      selected: selected,
    );
  }

  Future<void> _saveSelectedSalon(_MembershipSalonOption salon) async {
    _logMembership(
      'save_selected_salon',
      details: 'salonId=${salon.salonId}, name=${salon.name}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_salon_id', salon.salonId);
    await prefs.setString('stylist_selected_salon_name', salon.name);
  }

  // String _addressSummary(dynamic rawAddress) {
  //   if (rawAddress is! Map) return '';
  //   final address = Map<String, dynamic>.from(rawAddress);
  //   final parts = <String>[];
  //   for (final key in ['line1', 'line2', 'city', 'state']) {
  //     final value = _cleanText(address[key]);
  //     if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
  //   }
  //   return parts.take(2).join(', ');
  // }
  String _addressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';

    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];

    for (final key in [
      'line1',
      'line2',
      'village',
      'district',
      'city',
      'state',
      'postalCode',
      'country',
    ]) {
      final value = _cleanText(address[key]);
      if (value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
    }

    return parts.join(', ');
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
    final root = Map<String, dynamic>.from(data);
    final current = root['currentMembership'] ??
        root['currentSubscription'] ??
        root['subscription'] ??
        root['membership'];
    if (current is Map) {
      return _SalonSubscription.fromJson({
        ...root,
        ...Map<String, dynamic>.from(current),
      });
    }
    return _SalonSubscription.fromJson(root);
  }

  Future<void> _choosePlan(_MembershipPlan plan) async {
    _logMembership(
      'choose_plan_start',
      details: 'planId=${plan.id}, name=${plan.name}, '
          'yearlyBilling=$_yearlyBilling, salonId=${_salonId ?? 'none'}',
    );
    final salonId = _salonId;
    if (salonId == null) {
      _logMembership('choose_plan_blocked', details: 'missing_salon');
      _showSnack('Please create or select a salon first.');
      return;
    }
    final subscription = _subscription;
    final isActiveMonthly = subscription != null &&
        !_isYearlyCycle(subscription.billingCycle) &&
        subscription.upcomingMembership == null;
    if (subscription != null &&
        subscription.currentPlanId != plan.id &&
        !_isUpgradePlan(plan, subscription, _plans)) {
      _logMembership(
        'choose_plan_blocked',
        details:
            'reason=lower_tier_plan, subscriptionPlanId=${subscription.currentPlanId}',
      );
      _showSnack(
        'Lower-tier plans cannot be purchased while an active membership exists. Select a higher-tier plan or renew the current plan.',
      );
      return;
    }
    if (subscription != null && !subscription.canUpgrade && !isActiveMonthly) {
      _logMembership(
        'choose_plan_blocked',
        details:
            'reason=subscriptions_blocked, message=${subscription.membershipMessage}',
      );
      _showSnack(subscription.membershipMessage);
      return;
    }

    final selection = await showDialog<_PurchaseSelection>(
      context: context,
      barrierDismissible: !_isPaying,
      builder: (context) => _PurchaseDialog(
        plan: plan,
        initialYearlyBilling: _yearlyBilling,
        subscription: _subscription,
        allowMonthly: !_monthlyPlansBlocked,
      ),
    );
    if (selection == null || !mounted) return;

    _logMembership(
      'choose_plan_selected',
      details: _purchaseSelectionSummary(selection),
    );

    await _startPayment(salonId: salonId, selection: selection);
  }

  Future<void> _showPaymentHistory() async {
    final subscription = _subscription;
    if (subscription == null) return;
    _logMembership(
      'payment_history_open',
      details: 'items=${subscription.history.length}',
    );

    await showDialog<void>(
      context: context,
      builder: (context) =>
          _PaymentHistoryDialog(history: subscription.history),
    );
  }

  Future<void> _showAvailablePlans() async {
    if (_plans.isEmpty) {
      _logMembership('show_plans_blocked', details: 'no_plans_loaded');
      _showSnack('Plans are not available right now.');
      return;
    }

    _logMembership(
      'show_plans_open',
      details: 'plans=${_plans.length}, yearlyBilling=$_yearlyBilling',
    );

    final selectedPlan = await showDialog<_MembershipPlan>(
      context: context,
      builder: (context) => _AvailablePlansDialog(
        plans: _plans,
        yearlyBilling: _yearlyBilling,
        currentPlanId: _subscription?.currentPlanId,
        subscription: _subscription,
        allowMonthly: !_monthlyPlansBlocked,
        onBillingChanged: (value) => setState(() {
          _yearlyBilling = _monthlyPlansBlocked ? true : value;
        }),
      ),
    );
    if (selectedPlan == null || !mounted) return;

    await _choosePlan(selectedPlan);
  }

  Future<void> _activateUpcomingMembership() async {
    final salonId = _salonId;
    final subscription = _subscription;
    final upcoming = subscription?.upcomingMembership;
    if (salonId == null || subscription == null || upcoming == null) return;

    _logMembership(
      'activate_upcoming_start',
      details: 'salonId=$salonId, upcomingPlan=${upcoming.planName}, '
          'upcomingPlanId=${upcoming.planId ?? 'none'}, subscriptionDays=${subscription.daysRemaining}',
    );

    final planId = upcoming.planId ?? _planIdForUpcoming(upcoming);
    if (planId == null) {
      _logMembership('activate_upcoming_blocked', details: 'plan_not_found');
      _showSnack('Unable to find upcoming membership plan.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ImmediateReplaceDialog(
        planName: upcoming.planName,
        billingCycle: _cycleLabel(upcoming.billingCycle),
        remainingDays:
            subscription.daysRemaining < 0 ? 0 : subscription.daysRemaining,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isPaying = true);
    try {
      final response = await _apiService.activateSalonSubscriptionNow(
        salonId: salonId,
        planId: planId,
        billingCycle: upcoming.billingCycle,
        upcomingMembershipId: upcoming.id,
      );
      _logMembership(
        'activate_upcoming_response',
        details: _responseSummary(response),
      );
      if (!mounted) return;

      if (response['success'] == true) {
        final forfeitedDays = _readForfeitedDays(response);
        _showSnack(
          forfeitedDays != null
              ? 'Membership updated successfully. $forfeitedDays remaining days were forfeited.'
              : 'Membership updated successfully.',
        );
        await _loadMembership();
        return;
      }

      _showSnack(
          response['message']?.toString() ?? 'Unable to activate membership.');
    } catch (error) {
      _logMembership('activate_upcoming_failure', details: error);
      if (mounted) {
        _showSnack('Unable to activate membership.');
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  int? _planIdForUpcoming(_UpcomingMembership upcoming) {
    final targetName = upcoming.planName.trim().toLowerCase();
    final targetCycle = _isYearlyCycle(upcoming.billingCycle);
    for (final plan in _plans) {
      if (plan.name.trim().toLowerCase() != targetName) continue;
      if (plan.amountFor(targetCycle) == upcoming.amountMinor) {
        return plan.id;
      }
    }
    for (final plan in _plans) {
      if (plan.name.trim().toLowerCase() == targetName) return plan.id;
    }
    return null;
  }

  Future<void> _startPayment({
    required int salonId,
    required _PurchaseSelection selection,
  }) async {
    if (selection.amountMinor <= 0) {
      _logMembership(
        'start_payment_blocked',
        details:
            'reason=invalid_amount, ${_purchaseSelectionSummary(selection)}',
      );
      _showSnack('Selected plan amount is invalid.');
      return;
    }

    if (selection.replaceCurrentPlan) {
      _logMembership(
        'start_payment_replace_confirmation',
        details: _purchaseSelectionSummary(selection),
      );
      final confirmed = await _confirmImmediateReplace(selection);
      if (!confirmed) return;
    }

    _logMembership(
      'start_payment_begin',
      details: 'salonId=$salonId, ${_purchaseSelectionSummary(selection)}',
    );
    setState(() => _isPaying = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _logMembership('payment_order_request',
          details: _purchaseSelectionSummary(selection));
      final orderResponse =
          await _apiService.createSalonSubscriptionPaymentOrder(
        salonId: salonId,
        planId: selection.plan.id!,
        billingCycle: selection.billingCycle,
        startDate: selection.startDate,
        replaceCurrentPlan: selection.replaceCurrentPlan,
      );
      _logMembership(
        'payment_order_response',
        details: _responseSummary(orderResponse),
      );

      if (!mounted) return;

      if (orderResponse['success'] != true) {
        _showSnack(
          orderResponse['message']?.toString() ??
              'Unable to create membership payment order.',
        );
        return;
      }

      final orderData = _responseDataMap(orderResponse);
      final paymentTransactionId = orderData['paymentTransactionId'] ??
          orderData['payment_transaction_id'] ??
          orderData['paymentTransaction'] ??
          orderData['payment_transaction'] ??
          orderData['transactionId'] ??
          orderData['transaction_id'] ??
          orderData['id'];
      final orderId = _cleanText(orderData['razorpayOrderId'] ??
          orderData['razorpay_order_id'] ??
          orderData['orderId'] ??
          orderData['order_id']);
      final amountMinor = _readInt(orderData['amountMinor'] ??
              orderData['amount_minor'] ??
              orderData['amount']) ??
          selection.amountMinor;
      final currency = _cleanText(orderData['currency']).isEmpty
          ? selection.plan.currency
          : _cleanText(orderData['currency']);

      if (paymentTransactionId == null) {
        _logMembership(
          'payment_order_blocked',
          details:
              'reason=missing_payment_transaction_id, response=${_responseSummary(orderResponse)}',
        );
        _showSnack('Unable to start membership payment.');
        return;
      }
      if (orderId.isEmpty) {
        _logMembership(
          'payment_order_blocked',
          details:
              'reason=missing_razorpay_order_id, response=${_responseSummary(orderResponse)}',
        );
        _showSnack('Unable to start membership payment.');
        return;
      }

      final checkout = _checkout ??= GlowanteRazorpayCheckout();
      _logMembership(
        'razorpay_checkout_open',
        details: 'paymentTransactionId=$paymentTransactionId, '
            'orderId=$orderId, '
            'amountMinor=$amountMinor, currency=$currency, '
            'contact=${prefs.getString('phone_number') ?? 'none'}, '
            'email=${prefs.getString('email') ?? 'none'}',
      );
      final result = await checkout.open(
        RazorpayCheckoutRequest(
          key: _razorpayKeyId,
          amountMinor: amountMinor,
          currency: currency,
          name: 'Glowante',
          description: '${selection.plan.name} membership',
          orderId: orderId,
          contact: prefs.getString('phone_number'),
          email: prefs.getString('email'),
        ),
      );
      _logMembership(
        'razorpay_checkout_result',
        details:
            'status=${result.status.name}, paymentId=${result.paymentId ?? 'none'}, '
            'orderId=${result.orderId ?? 'none'}, signature=${result.signature == null ? 'none' : 'present'}, '
            'message=${result.message ?? 'none'}',
      );

      if (!mounted) return;

      if (result.status == RazorpayCheckoutStatus.cancelled) {
        _showSnack(
            _checkoutMessage(result.message, fallback: 'Payment cancelled.'));
        return;
      }

      if (result.status != RazorpayCheckoutStatus.success ||
          result.paymentId == null) {
        _showSnack(
            _checkoutMessage(result.message, fallback: 'Payment failed.'));
        return;
      }

      final razorpayOrderId = _cleanText(result.orderId).isNotEmpty
          ? _cleanText(result.orderId)
          : orderId;
      final razorpaySignature = _cleanText(result.signature);
      if (razorpayOrderId.isEmpty || razorpaySignature.isEmpty) {
        _logMembership(
          'payment_verify_blocked',
          details: 'missing_order_or_signature, '
              'razorpayOrderId=${razorpayOrderId.isEmpty ? 'none' : razorpayOrderId}, '
              'signature=${razorpaySignature.isEmpty ? 'none' : 'present'}',
        );
        _showSnack('Payment completed, but verification data is incomplete.');
        return;
      }

      _logMembership(
        'payment_verify_request',
        details: 'paymentTransactionId=$paymentTransactionId, '
            'razorpayPaymentId=${result.paymentId}, '
            'razorpayOrderId=$razorpayOrderId',
      );
      final verifyResponse = await _apiService.verifySalonSubscriptionPayment(
        salonId: salonId,
        paymentTransactionId: paymentTransactionId,
        razorpayPaymentId: result.paymentId!,
        razorpayOrderId: razorpayOrderId,
        razorpaySignature: razorpaySignature,
      );
      _logMembership(
        'payment_verify_response',
        details: _responseSummary(verifyResponse),
      );

      if (!mounted) return;

      if (verifyResponse['success'] == true) {
        final forfeitedDays = _readForfeitedDays(verifyResponse);
        _showSnack(
          forfeitedDays != null
              ? 'Membership updated successfully. $forfeitedDays remaining days were forfeited.'
              : 'Membership updated successfully.',
        );
        await _loadMembership();
        return;
      }

      _showSnack(
        verifyResponse['message']?.toString() ??
            'Unable to verify membership payment.',
      );
    } catch (error) {
      _logMembership('start_payment_failure', details: error);
      if (mounted) {
        _showSnack('Unable to update membership.');
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  String _checkoutMessage(String? message, {required String fallback}) {
    final text = message?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'undefined') {
      return fallback;
    }
    return text;
  }

  Future<bool> _confirmImmediateReplace(_PurchaseSelection selection) async {
    final subscription = _subscription;
    final remainingDays = subscription?.daysRemaining ?? 0;
    final positiveDays = remainingDays < 0 ? 0 : remainingDays;
    _logMembership(
      'confirm_replace_open',
      details: _purchaseSelectionSummary(selection),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ImmediateReplaceDialog(
        planName: selection.plan.name,
        billingCycle: _cycleLabel(selection.billingCycle),
        remainingDays: positiveDays,
      ),
    );
    _logMembership(
      'confirm_replace_result',
      details: 'confirmed=${confirmed == true}',
    );
    return confirmed == true;
  }

  void _showSnack(String message) {
    _logMembership('toast', details: message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateText(message))),
    );
  }

  Future<void> _switchSalon(_MembershipSalonOption salon) async {
    _logMembership(
      'switch_salon_start',
      details: 'salonId=${salon.salonId}, name=${salon.name}',
    );
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
      _logMembership(
        'switch_salon_subscription_response',
        details: _responseSummary(subscriptionResponse),
      );
      if (!mounted) return;
      setState(() {
        _subscription = _parseSubscription(subscriptionResponse);
        _isLoading = false;
      });
    } catch (error) {
      _logMembership('switch_salon_failure', details: error);
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
              subtitle: _salonSelectorSubtitle(salon),
            ),
          )
          .toList(),
      selectedValue: _selectedSalon,
      placeholder: context.t('Select Salon'),
      isInteractive: _salonOptions.length > 1,
      onSelected: _switchSalon,
    );
  }

  String _salonSelectorSubtitle(_MembershipSalonOption salon) {
    final branchLabel =
        salon.branchCount == 1 ? '1 branch' : '${salon.branchCount} branches';
    if (salon.address.isEmpty) return branchLabel;
    return '$branchLabel • ${salon.address}';
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
        if (_salonOptions.length > 1) ...[
          _buildSalonSelector(),
          const SizedBox(height: 18),
        ],
        if (_subscription != null) ...[
          _ExpiryBanner(
            subscription: _subscription!,
            onRenew: null,
          ),
          const SizedBox(height: 18),
          _MembershipSummaryRow(
            subscription: _subscription!,
            actions: _MembershipActions(
              subscription: _subscription!,
              onPlans: _showAvailablePlans,
              onPaymentHistory: _showPaymentHistory,
              onActivateUpcoming: _activateUpcomingMembership,
            ),
            onActivateUpcoming: _activateUpcomingMembership,
          ),
          const SizedBox(height: 14),
          _UsageGrid(subscription: _subscription!),
          const SizedBox(height: 24),
        ],
        if (_subscription == null) ...[
          _PlansHeader(
            yearlyBilling: _yearlyBilling,
            allowMonthly: !_monthlyPlansBlocked,
            onBillingChanged: (value) {
              setState(() {
                _yearlyBilling = _monthlyPlansBlocked ? true : value;
              });
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
              subscription: _subscription,
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
    required this.allowMonthly,
    required this.onBillingChanged,
  });

  final bool yearlyBilling;
  final bool allowMonthly;
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
              onChanged: (value) {
                if (!value && !allowMonthly) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t(_monthlyBlockedMessage))),
                  );
                  return;
                }
                onBillingChanged(value);
              },
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
        if (!allowMonthly) ...[
          const SizedBox(height: 8),
          Text(
            context.t(_monthlyBlockedMessage),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              height: 1.35,
              color: _membershipMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    required this.branchCount,
  });

  final int salonId;
  final String name;
  final String address;
  final int branchCount;
}

class _PlansGrid extends StatelessWidget {
  const _PlansGrid({
    required this.plans,
    required this.yearlyBilling,
    required this.currentPlanId,
    required this.subscription,
    required this.onChoose,
  });

  final List<_MembershipPlan> plans;
  final bool yearlyBilling;
  final int? currentPlanId;
  final _SalonSubscription? subscription;
  final ValueChanged<_MembershipPlan> onChoose;

  @override
  Widget build(BuildContext context) {
    final current = subscription;
    final currentBillingCycle = current == null
        ? null
        : _billingCycleApiValue(_isYearlyCycle(current.billingCycle));
    final viewedBillingCycle = _billingCycleApiValue(yearlyBilling);

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
                  isCurrent: currentPlanId == plan.id &&
                      currentBillingCycle == viewedBillingCycle,
                  canChoose: _canChoosePlan(
                    plan,
                    viewedBillingCycle: viewedBillingCycle,
                  ),
                  disabledMessage: currentPlanId == plan.id &&
                          currentBillingCycle == viewedBillingCycle
                      ? 'This plan is already active. Please choose a different upgrade plan.'
                      : subscription?.membershipMessage,
                  onChoose: () => onChoose(plan),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _canChoosePlan(
    _MembershipPlan plan, {
    required String viewedBillingCycle,
  }) {
    final current = subscription;
    if (current == null) return true;
    if (current.upcomingMembership != null) return false;
    final currentBillingCycle =
        _billingCycleApiValue(_isYearlyCycle(current.billingCycle));
    if (current.currentPlanId == plan.id) {
      return currentBillingCycle != viewedBillingCycle;
    }
    if (current.eligibleUpgradePlanIds.isNotEmpty) {
      return current.eligibleUpgradePlanIds.contains(plan.id);
    }
    if (_isHigherTierPlan(plan, current, plans)) return true;
    if (!_isYearlyCycle(current.billingCycle)) return true;
    return current.canUpgrade;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearlyBilling,
    required this.isCurrent,
    required this.canChoose,
    required this.disabledMessage,
    required this.onChoose,
  });

  final _MembershipPlan plan;
  final bool yearlyBilling;
  final bool isCurrent;
  final bool canChoose;
  final String? disabledMessage;
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
              onPressed: canChoose
                  ? onChoose
                  : () {
                      final message = disabledMessage?.trim();
                      if (message == null || message.isEmpty) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t(message))),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canChoose ? AppColors.starColor : const Color(0xFFD8CEC5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isCurrent
                    ? context.t('Current Plan')
                    : !canChoose
                        ? context.t('Not Eligible')
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

bool _isUpgradePlan(
  _MembershipPlan plan,
  _SalonSubscription current,
  List<_MembershipPlan> plans,
) {
  if (current.eligibleUpgradePlanIds.isNotEmpty) {
    return current.eligibleUpgradePlanIds.contains(plan.id);
  }
  return _isHigherTierPlan(plan, current, plans);
}

bool _isHigherTierPlan(
  _MembershipPlan plan,
  _SalonSubscription current,
  List<_MembershipPlan> plans,
) {
  final currentPlan = _resolvedCurrentPlan(current, plans);
  final planHasHigherMonetaryValue =
      plan.monthlyPriceMinor > currentPlan.monthlyPriceMinor ||
          plan.annualPriceMinor > currentPlan.annualPriceMinor;
  final planHasHigherCapacity = plan.branchLimit > currentPlan.branchLimit ||
      plan.staffLimit > currentPlan.staffLimit ||
      plan.storageLimit > currentPlan.storageLimit;
  return planHasHigherMonetaryValue || planHasHigherCapacity;
}

_MembershipPlan _resolvedCurrentPlan(
  _SalonSubscription current,
  List<_MembershipPlan> plans,
) {
  for (final plan in plans) {
    if (plan.id == current.currentPlanId) return plan;
  }
  return _MembershipPlan(
    id: current.currentPlanId,
    name: current.currentPlan,
    description: '',
    monthlyPriceMinor: current.amountMinor,
    annualPriceMinor: current.amountMinor * 12,
    branchLimit: current.branchUsage.limit,
    staffLimit: current.staffUsage.limit,
    storageLimit: current.storageUsage.limit,
    includedFeatures: const [],
    currency: current.currency,
    isRecommended: false,
  );
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
  const _CurrentMembershipCard({
    required this.subscription,
    required this.onActivateUpcoming,
  });

  final _SalonSubscription subscription;
  final VoidCallback onActivateUpcoming;

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
          if (subscription.upcomingMembership != null) ...[
            const SizedBox(height: 14),
            _UpcomingMembershipPanel(
              upcomingMembership: subscription.upcomingMembership!,
              onActivate: onActivateUpcoming,
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingMembershipPanel extends StatelessWidget {
  const _UpcomingMembershipPanel({
    required this.upcomingMembership,
    required this.onActivate,
  });

  final _UpcomingMembership upcomingMembership;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB8DEC0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 18,
                color: Color(0xFF2F8A4C),
              ),
              const SizedBox(width: 8),
              Text(
                context.t('Upcoming Membership'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2F8A4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Fact(label: 'Plan', value: upcomingMembership.planName),
              _Fact(
                label: 'Billing',
                value: _cycleLabel(upcomingMembership.billingCycle),
              ),
              _Fact(
                label: 'Starts',
                value: _formatDate(upcomingMembership.startDate),
              ),
              _Fact(
                label: 'Expires',
                value: _formatDate(upcomingMembership.expiryDate),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onActivate,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(context.t('Activate Upgrade')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F8A4C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
    required this.onActivateUpcoming,
  });

  final _SalonSubscription subscription;
  final Widget actions;
  final VoidCallback onActivateUpcoming;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              _CurrentMembershipCard(
                subscription: subscription,
                onActivateUpcoming: onActivateUpcoming,
              ),
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
              child: _CurrentMembershipCard(
                subscription: subscription,
                onActivateUpcoming: onActivateUpcoming,
              ),
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
    required this.subscription,
    required this.onPlans,
    required this.onPaymentHistory,
    required this.onActivateUpcoming,
  });

  final _SalonSubscription subscription;
  final VoidCallback onPlans;
  final VoidCallback onPaymentHistory;
  final VoidCallback onActivateUpcoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.refresh_rounded,
            label: 'Renew Plan',
            onTap: null,
            disabledMessage:
                'This plan is already active. Please choose a different upgrade plan.',
          ),
          const Divider(height: 1, color: _membershipBorder),
          _ActionRow(
            icon: Icons.trending_up_rounded,
            label: 'Upgrade Plan',
            onTap: subscription.canUpgrade ? onPlans : null,
            disabledMessage: subscription.membershipMessage,
          ),
          const Divider(height: 1, color: _membershipBorder),
          if (subscription.upcomingMembership != null) ...[
            _ActionRow(
              icon: Icons.play_arrow_rounded,
              label: 'Activate Upgrade',
              onTap: onActivateUpcoming,
            ),
            const Divider(height: 1, color: _membershipBorder),
          ],
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
    this.disabledMessage,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final message = _cleanText(disabledMessage);
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
              child: Icon(
                icon,
                size: 16,
                color: enabled ? AppColors.starColor : _membershipMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(label),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enabled ? _membershipText : _membershipMuted,
                    ),
                  ),
                  if (!enabled && message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      context.t(message),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _membershipMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              enabled ? Icons.chevron_right_rounded : Icons.lock_outline,
              color: _membershipMuted,
              size: enabled ? 24 : 16,
            ),
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
  final VoidCallback? onRenew;

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
    final used = data.usage.used;
    final limit = data.usage.limit;
    final overLimit = data.usage.overLimit;
    final progressBase = limit <= 0 ? 1 : limit;
    final percent = (used / progressBase).clamp(0, 1).toDouble();
    final statusColor =
        overLimit ? const Color(0xFFB42318) : AppColors.starColor;
    final statusText = overLimit
        ? '${context.t('Over limit by')} ${used - limit}${data.suffix}'
        : '${(limit - used).clamp(0, 999999)}${data.suffix} ${context.t('remaining')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overLimit ? const Color(0xFFFFF4F2) : _membershipSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: overLimit ? const Color(0xFFFDA29B) : _membershipBorder,
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(data.title).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: statusColor,
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
                  text: '$used${data.suffix}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
                TextSpan(
                  text: ' / $limit${data.suffix}',
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
            color: statusColor,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (overLimit) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFB42318),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: overLimit ? FontWeight.w800 : FontWeight.w600,
                    color: overLimit ? statusColor : _membershipMuted,
                  ),
                ),
              ),
            ],
          ),
          if (overLimit) ...[
            const SizedBox(height: 6),
            Text(
              context
                  .t('Backend limit reached. New additions may be rejected.'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                height: 1.3,
                color: _membershipMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: maxHeight,
        ),
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
              Expanded(
                child: history.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(22),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            context.t('No payment history available.'),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              color: _membershipMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(22),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _PaymentHistoryItem(
                            item: history[index],
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
    required this.subscription,
    required this.allowMonthly,
    required this.onBillingChanged,
  });

  final List<_MembershipPlan> plans;
  final bool yearlyBilling;
  final int? currentPlanId;
  final _SalonSubscription? subscription;
  final bool allowMonthly;
  final ValueChanged<bool> onBillingChanged;

  @override
  State<_AvailablePlansDialog> createState() => _AvailablePlansDialogState();
}

class _AvailablePlansDialogState extends State<_AvailablePlansDialog> {
  late bool _yearlyBilling = widget.allowMonthly ? widget.yearlyBilling : true;

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
                      allowMonthly: widget.allowMonthly,
                      onBillingChanged: (value) {
                        final nextValue = widget.allowMonthly ? value : true;
                        setState(() => _yearlyBilling = nextValue);
                        widget.onBillingChanged(nextValue);
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
                subscription: widget.subscription,
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
    required this.allowMonthly,
  });

  final _MembershipPlan plan;
  final _SalonSubscription subscription;
  final bool allowMonthly;

  @override
  State<_RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends State<_RenewMembershipDialog> {
  late bool _yearlyBilling;
  String _paymentMethod = 'Saved Credit Card (**** 4242)';

  @override
  void initState() {
    super.initState();
    _yearlyBilling = !widget.allowMonthly;
  }

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
                            value: false,
                            label: Text('Monthly'),
                          ),
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
                          final nextValue = values.first;
                          if (!nextValue && !widget.allowMonthly) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t(_monthlyBlockedMessage),
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _yearlyBilling = nextValue);
                        },
                      ),
                    ),
                    if (!widget.allowMonthly) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.t(_monthlyBlockedMessage),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          height: 1.35,
                          color: _membershipMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                                  renew: true,
                                  replaceCurrentPlan: false,
                                  startDate: DateTime.now(),
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
    required this.allowMonthly,
  });

  final _MembershipPlan plan;
  final bool initialYearlyBilling;
  final _SalonSubscription? subscription;
  final bool allowMonthly;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late bool _yearlyBilling;

  @override
  void initState() {
    super.initState();
    _yearlyBilling = _isMonthlyBlocked ? true : widget.initialYearlyBilling;
  }

  bool get _isMonthlyBlocked => !widget.allowMonthly;

  bool get _isRenewalSelection {
    final subscription = widget.subscription;
    if (subscription == null) return false;
    if (subscription.currentPlanId != widget.plan.id) return false;
    return _billingCycleApiValue(_yearlyBilling) ==
        _billingCycleApiValue(_isYearlyCycle(subscription.billingCycle));
  }

  bool get _isUpgradeSelection {
    final subscription = widget.subscription;
    if (subscription == null) return false;
    return subscription.currentPlanId != widget.plan.id;
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.plan.amountFor(_yearlyBilling);
    final startDate = DateTime.now();
    final isRenewalSelection = _isRenewalSelection;
    final isUpgradeSelection = _isUpgradeSelection;
    final baseDate = isRenewalSelection && widget.subscription != null
        ? _renewalBaseDate(widget.subscription!.expiryDate)
        : startDate;
    final validUntil = DateTime(
      baseDate.year + (_yearlyBilling ? 1 : 0),
      baseDate.month + (_yearlyBilling ? 0 : 1),
      baseDate.day,
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
                  final nextValue = values.first;
                  if (!nextValue && _isMonthlyBlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.t(_monthlyBlockedMessage),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _yearlyBilling = nextValue);
                },
              ),
              if (!widget.allowMonthly) ...[
                const SizedBox(height: 8),
                Text(
                  context.t(_monthlyBlockedMessage),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    height: 1.35,
                    color: _membershipMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                            renew: isRenewalSelection,
                            replaceCurrentPlan: isUpgradeSelection,
                            startDate: startDate,
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

class _ImmediateReplaceDialog extends StatelessWidget {
  const _ImmediateReplaceDialog({
    required this.planName,
    required this.billingCycle,
    required this.remainingDays,
  });

  final String planName;
  final String billingCycle;
  final int remainingDays;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        context.t('Replace current plan now?'),
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.starColor,
        ),
      ),
      content: Text(
        context.t(
          'This will activate $planName ($billingCycle) immediately and discard $remainingDays remaining days from your current plan.',
        ),
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          height: 1.4,
          color: _membershipText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t('Cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(context.t('Replace Now')),
        ),
      ],
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
    required this.remainingDays,
    required this.canRenew,
    required this.canUpgrade,
    required this.renewalEligibleAfterDays,
    required this.membershipMessage,
    required this.upcomingMembership,
    required this.eligibleUpgradePlanIds,
  });

  factory _SalonSubscription.fromJson(Map<String, dynamic> json) {
    json = _subscriptionJsonWithDeferredUpcoming(json);
    final expiryDate = _parseDate(json['expiryDate']);
    final computedRemainingDays = _remainingDaysFromExpiry(expiryDate);
    final remainingDays = _readInt(json['remainingDays']) ??
        _readInt(json['daysLeft']) ??
        computedRemainingDays;
    final billingCycle = _subscriptionBillingCycleFromJson(
      json,
      remainingDays: remainingDays,
    );
    final ruleEligible =
        _canRenewOrUpgradeFallback(billingCycle, remainingDays);
    final backendRenew =
        _readBool(json['renew']) ?? _readBool(json['canRenew']);
    final backendCanUpgrade = _readBool(json['canUpgrade']);
    var canRenew = ruleEligible && (backendRenew ?? true);
    var canUpgrade =
        ruleEligible && (backendCanUpgrade ?? backendRenew ?? true);
    final upcomingRaw = json['upcomingMembership'];
    final hasUpcomingMembership = upcomingRaw is Map;
    if (hasUpcomingMembership) {
      canRenew = false;
      canUpgrade = false;
    } else if (!_isYearlyCycle(billingCycle) && remainingDays > 0) {
      canRenew = true;
      canUpgrade = true;
    }
    final renewalEligibleAfterDays =
        _readInt(json['renewalEligibleAfterDays']) ??
            _renewalEligibleAfterDaysFallback(billingCycle, remainingDays);
    final eligibleUpgradePlanIds = _readEligibleUpgradePlanIds(
        json['eligibleUpgradePlans'] ?? json['eligibleUpgradePlanIds']);
    final message = _cleanText(json['membershipMessage']).isNotEmpty
        ? _cleanText(json['membershipMessage'])
        : _membershipEligibilityMessage(
            billingCycle: billingCycle,
            remainingDays: remainingDays,
            canRenew: canRenew,
            canUpgrade: canUpgrade,
            renewalEligibleAfterDays: renewalEligibleAfterDays,
          );

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
      expiryDate: expiryDate,
      billingCycle: billingCycle,
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
      remainingDays: remainingDays,
      canRenew: canRenew,
      canUpgrade: canUpgrade,
      renewalEligibleAfterDays: renewalEligibleAfterDays,
      membershipMessage: message,
      upcomingMembership: upcomingRaw is Map
          ? _UpcomingMembership.fromJson(Map<String, dynamic>.from(upcomingRaw))
          : null,
      eligibleUpgradePlanIds: eligibleUpgradePlanIds,
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
  final int remainingDays;
  final bool canRenew;
  final bool canUpgrade;
  final int? renewalEligibleAfterDays;
  final String membershipMessage;
  final _UpcomingMembership? upcomingMembership;
  final List<int> eligibleUpgradePlanIds;

  int get daysRemaining => remainingDays;
}

class _UpcomingMembership {
  const _UpcomingMembership({
    required this.id,
    required this.planId,
    required this.planName,
    required this.billingCycle,
    required this.startDate,
    required this.expiryDate,
    required this.amountMinor,
    required this.currency,
    required this.membershipStatus,
  });

  factory _UpcomingMembership.fromJson(Map<String, dynamic> json) {
    return _UpcomingMembership(
      id: _readInt(json['id']),
      planId: _readInt(
        json['planId'] ??
            json['currentPlanId'] ??
            json['membershipPlanId'] ??
            json['id'],
      ),
      planName: _cleanText(json['planName'] ?? json['currentPlan']).isEmpty
          ? 'Plan'
          : _cleanText(json['planName'] ?? json['currentPlan']),
      billingCycle: _cleanText(json['billingCycle']).isEmpty
          ? 'MONTHLY'
          : _cleanText(json['billingCycle']),
      startDate: _parseDate(json['startDate']),
      expiryDate: _parseDate(json['expiryDate']),
      amountMinor: _readInt(json['amountMinor']) ?? 0,
      currency: _cleanText(json['currency']).isEmpty
          ? 'INR'
          : _cleanText(json['currency']),
      membershipStatus: _cleanText(json['membershipStatus']).isEmpty
          ? 'UPCOMING'
          : _cleanText(json['membershipStatus']),
    );
  }

  final int? id;
  final int? planId;
  final String planName;
  final String billingCycle;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final int amountMinor;
  final String currency;
  final String membershipStatus;
}

class _SubscriptionHistory {
  const _SubscriptionHistory({
    required this.planId,
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
      planId: _readInt(json['planId']),
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

  final int? planId;
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
  const _Usage({
    required this.used,
    required this.limit,
    required this.overLimit,
  });

  factory _Usage.fromJson(dynamic json) {
    if (json is! Map) {
      return const _Usage(used: 0, limit: 0, overLimit: false);
    }
    return _Usage(
      used: _readInt(json['used']) ?? 0,
      limit: _readInt(json['limit']) ?? 0,
      overLimit: _readBool(json['overLimit']) ?? false,
    );
  }

  final int used;
  final int limit;
  final bool overLimit;
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
    required this.renew,
    required this.replaceCurrentPlan,
    required this.startDate,
  });

  final _MembershipPlan plan;
  final String billingCycle;
  final int amountMinor;
  final bool renew;
  final bool replaceCurrentPlan;
  final DateTime startDate;
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

int? _readForfeitedDays(Map<String, dynamic> response) {
  final direct = _readInt(response['forfeitedDays']);
  if (direct != null) return direct;
  final data = response['data'];
  if (data is Map) {
    return _readInt(data['forfeitedDays']);
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  final raw = _cleanText(value);
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  final text = _cleanText(value).toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

List<int> _readEligibleUpgradePlanIds(dynamic value) {
  final ids = <int>[];
  if (value is List) {
    for (final item in value) {
      if (item is Map) {
        final planId = _readInt(item['id'] ?? item['planId']);
        if (planId != null) ids.add(planId);
        continue;
      }
      final planId = _readInt(item);
      if (planId != null) ids.add(planId);
    }
  } else if (value is Map) {
    final nested = value['data'] ?? value['plans'] ?? value['items'];
    ids.addAll(_readEligibleUpgradePlanIds(nested));
  }
  return ids.toSet().toList();
}

Map<String, dynamic> _subscriptionJsonWithDeferredUpcoming(
  Map<String, dynamic> json,
) {
  if (json['upcomingMembership'] is Map) return json;
  final rawHistory = json['history'];
  if (rawHistory is! List) return json;
  final hasExplicitCurrentMembership =
      _readInt(json['currentPlanId']) != null ||
          _cleanText(json['currentPlan']).isNotEmpty ||
          _cleanText(json['membershipStatus']).isNotEmpty;

  final topExpiryDate = _parseDate(json['expiryDate']);
  final topRemainingDays = _readInt(json['remainingDays']) ??
      _readInt(json['daysLeft']) ??
      _remainingDaysFromExpiry(topExpiryDate);
  final topBillingCycle = _subscriptionBillingCycleFromJson(
    json,
    remainingDays: topRemainingDays,
  );
  final history = rawHistory
      .whereType<Map>()
      .map((item) =>
          _SubscriptionHistory.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  if (!_isYearlyCycle(topBillingCycle)) {
    final upcomingYearlyHistory = history.where((item) {
      if (!_isYearlyCycle(item.billingCycle)) return false;
      final startDate = item.startDate;
      final expiryDate = item.expiryDate;
      if (startDate == null || expiryDate == null) return false;
      return !_dateOnly(startDate).isBefore(_todayDateOnly());
    }).toList()
      ..sort((a, b) {
        final startCompare =
            (a.startDate ?? DateTime(0)).compareTo(b.startDate ?? DateTime(0));
        if (startCompare != 0) return startCompare;
        return (b.expiryDate ?? DateTime(0))
            .compareTo(a.expiryDate ?? DateTime(0));
      });

    if (upcomingYearlyHistory.isEmpty) return json;
    final upcoming = upcomingYearlyHistory.first;
    return <String, dynamic>{
      ...json,
      'renew': false,
      'canRenew': false,
      'canUpgrade': false,
      'membershipMessage':
          'You already have an upcoming yearly membership. Renewal or upgrade will be available after the current monthly membership ends.',
      'upcomingMembership': <String, dynamic>{
        'planId': upcoming.planId,
        'planName': upcoming.planName,
        'billingCycle':
            upcoming.billingCycle.isEmpty ? 'ANNUAL' : upcoming.billingCycle,
        'startDate': _apiDateString(upcoming.startDate),
        'expiryDate': _apiDateString(upcoming.expiryDate),
        'amountMinor': upcoming.amountMinor,
        'currency': upcoming.currency,
        'membershipStatus': 'UPCOMING',
      },
    };
  }

  if (hasExplicitCurrentMembership) return json;

  final activeMonthlyHistory = history.where((item) {
    if (_isYearlyCycle(item.billingCycle)) return false;
    final startDate = item.startDate;
    final expiryDate = item.expiryDate;
    if (startDate == null || expiryDate == null) return false;
    final today = _todayDateOnly();
    final startOnly = _dateOnly(startDate);
    final expiryOnly = _dateOnly(expiryDate);
    return !startOnly.isAfter(today) && expiryOnly.isAfter(today);
  }).toList()
    ..sort((a, b) {
      final expiryCompare =
          (b.expiryDate ?? DateTime(0)).compareTo(a.expiryDate ?? DateTime(0));
      if (expiryCompare != 0) return expiryCompare;
      return (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0));
    });

  if (activeMonthlyHistory.isEmpty) return json;

  final currentMonthly = activeMonthlyHistory.first;
  final currentExpiry = currentMonthly.expiryDate;
  if (currentExpiry == null) return json;

  final topStartDate = _parseDate(json['startDate']);
  final topDurationDays = topStartDate == null || topExpiryDate == null
      ? 365
      : topExpiryDate.difference(topStartDate).inDays;
  final upcomingStart = _dateOnly(currentExpiry);
  final upcomingExpiry = upcomingStart.add(
    Duration(days: topDurationDays > 0 ? topDurationDays : 365),
  );
  final currentRemainingDays = _remainingDaysFromExpiry(currentExpiry);

  return <String, dynamic>{
    ...json,
    'currentPlanId': currentMonthly.planId ?? json['currentPlanId'],
    'currentPlan': currentMonthly.planName,
    'paymentStatus': currentMonthly.paymentStatus,
    'membershipStatus': 'ACTIVE',
    'startDate': _apiDateString(currentMonthly.startDate),
    'expiryDate': _apiDateString(currentMonthly.expiryDate),
    'billingCycle': currentMonthly.billingCycle.isEmpty
        ? 'MONTHLY'
        : currentMonthly.billingCycle,
    'amountMinor': currentMonthly.amountMinor,
    'currency': currentMonthly.currency,
    'remainingDays': currentRemainingDays,
    'daysLeft': currentRemainingDays,
    'renew': false,
    'canRenew': false,
    'canUpgrade': false,
    'renewalEligibleAfterDays': currentRemainingDays,
    'membershipMessage':
        'You already have an upcoming yearly membership. Renewal or upgrade will be available after the current monthly membership ends.',
    'upcomingMembership': <String, dynamic>{
      'planId': _readInt(json['currentPlanId']),
      'planName': _cleanText(json['currentPlan']).isEmpty
          ? currentMonthly.planName
          : _cleanText(json['currentPlan']),
      'billingCycle': topBillingCycle,
      'startDate': _apiDateString(upcomingStart),
      'expiryDate': _apiDateString(upcomingExpiry),
      'amountMinor': _readInt(json['amountMinor']) ?? 0,
      'currency': _cleanText(json['currency']).isEmpty
          ? 'INR'
          : _cleanText(json['currency']),
      'membershipStatus': 'UPCOMING',
    },
  };
}

DateTime _todayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String? _apiDateString(DateTime? date) {
  if (date == null) return null;
  return DateFormat('yyyy-MM-dd').format(date);
}

int _remainingDaysFromExpiry(DateTime? expiryDate) {
  if (expiryDate == null) return 0;
  return _dateOnly(expiryDate).difference(_todayDateOnly()).inDays;
}

bool _isYearlyCycle(String billingCycle) {
  final normalized = billingCycle.trim().toUpperCase();
  return normalized == 'YEARLY' || normalized == 'ANNUAL';
}

String _subscriptionBillingCycleFromJson(
  Map<String, dynamic> json, {
  required int remainingDays,
}) {
  final cycle = _subscriptionBillingCycleValueFromJson(json);
  if (cycle != null) return cycle;
  return remainingDays > 330 ? 'ANNUAL' : 'MONTHLY';
}

String? _subscriptionBillingCycleValueFromJson(Map<String, dynamic> json) {
  for (final key in const [
    'billingCycle',
    'billing_cycle',
    'billingInterval',
    'billing_interval',
    'cycle',
    'interval',
  ]) {
    final cycle = _normalizeBillingCycle(json[key]);
    if (cycle != null) return cycle;
  }

  for (final key in const [
    'plan',
    'membershipPlan',
    'currentPlan',
    'subscriptionPlan',
  ]) {
    final value = json[key];
    if (value is Map) {
      final cycle = _subscriptionBillingCycleValueFromJson(
          Map<String, dynamic>.from(value));
      if (cycle != null) return cycle;
    }
  }

  for (final key in const [
    'currentPlan',
    'planName',
    'name',
    'displayName',
  ]) {
    final cycle = _normalizeBillingCycle(json[key]);
    if (cycle != null) return cycle;
  }

  return null;
}

String? _normalizeBillingCycle(dynamic value) {
  final text = _cleanText(value).toUpperCase();
  if (text.isEmpty) return null;
  if (text.contains('ANNUAL') ||
      text.contains('YEARLY') ||
      text.contains('YEAR')) {
    return 'ANNUAL';
  }
  if (text.contains('MONTHLY') || text.contains('MONTH')) {
    return 'MONTHLY';
  }
  return null;
}

bool _canRenewOrUpgradeFallback(String billingCycle, int remainingDays) {
  if (!_isYearlyCycle(billingCycle)) return true;
  return remainingDays <= 330;
}

int? _renewalEligibleAfterDaysFallback(String billingCycle, int remainingDays) {
  if (!_isYearlyCycle(billingCycle) || remainingDays <= 330) return null;
  return remainingDays - 330;
}

String _membershipEligibilityMessage({
  required String billingCycle,
  required int remainingDays,
  required bool canRenew,
  required bool canUpgrade,
  int? renewalEligibleAfterDays,
}) {
  if (canRenew && canUpgrade) {
    if (_isYearlyCycle(billingCycle)) {
      return 'Yearly membership is eligible for renewal or upgrade.';
    }
    return 'Monthly membership can be renewed or upgraded at any time.';
  }

  if (_isYearlyCycle(billingCycle)) {
    final waitDays = renewalEligibleAfterDays ??
        _renewalEligibleAfterDaysFallback(billingCycle, remainingDays);
    if (waitDays != null && waitDays > 0) {
      return 'Yearly membership can be renewed or upgraded when 330 days or fewer remain. Try again in $waitDays days.';
    }
    return 'Yearly membership is not eligible for renewal or upgrade yet.';
  }

  if (!canRenew && canUpgrade) {
    return 'Monthly membership can be renewed or upgraded at any time.';
  }

  return 'Membership is not eligible for renewal or upgrade yet.';
}
