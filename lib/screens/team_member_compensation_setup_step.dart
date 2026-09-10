import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'complete_profile_shared.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../utils/price_formatter.dart';
import '../widgets/app_loader.dart';

const List<String> _employmentTypes = [
  'FULL_TIME',
  'PART_TIME',
  'CONTRACT',
  'FREELANCER',
];

String _employmentTypeLabel(String value) {
  switch (value) {
    case 'FULL_TIME':
      return translateText('Full Time');
    case 'PART_TIME':
      return translateText('Part Time');
    case 'CONTRACT':
      return translateText('Contract');
    case 'FREELANCER':
      return translateText('Freelancer');
    default:
      return value;
  }
}

const List<String> _payTypes = ['SALARY', 'SALARY_PLUS_COMMISSION'];

String _payTypeLabel(String value) {
  return value == 'SALARY_PLUS_COMMISSION'
      ? translateText('Salary + Commission')
      : translateText('Monthly Salary');
}

/// "Employment Details" — used two ways:
/// - As the final step of the Setup Required onboarding chain (pushed from
///   team_online_availability_screen.dart after Assign succeeds), where
///   [isStandalone] is false and there's a "Skip for now" option, since
///   compensation shouldn't block finishing onboarding for a brand-new
///   member.
/// - As the standalone "Edit Compensation" action for an already-active
///   member (SalonTeams.dart's Actions menu), where [isStandalone] is
///   true — it prefills the member's current employment type and latest
///   compensation record, and has no skip option since it's a deliberate,
///   direct action.
///
/// Either way this always records a *new* compensation arrangement (POST),
/// matching salon_user_compensation.md §5.2's backdating-replaces-current
/// semantics — same as _CompensationFormScreen's create path in
/// team_member_compensation_screen.dart.
class TeamMemberCompensationSetupStep extends StatefulWidget {
  const TeamMemberCompensationSetupStep({
    super.key,
    required this.salonId,
    required this.userId,
    required this.memberName,
    this.isStandalone = false,
  });

  final int salonId;
  final int userId;
  final String memberName;
  final bool isStandalone;

  @override
  State<TeamMemberCompensationSetupStep> createState() =>
      _TeamMemberCompensationSetupStepState();
}

class _TeamMemberCompensationSetupStepState
    extends State<TeamMemberCompensationSetupStep> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _loadError;
  String _employmentType = 'FULL_TIME';
  String _payType = 'SALARY';
  final _amountCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'INR');
  DateTime? _effectiveFrom;
  bool _isSaving = false;
  // The member's existing CURRENT record specifically — kept separate from
  // whatever prefills the form (which falls back through upcoming/current)
  // so it can still be shown as a read-only reference card even when an
  // upcoming record is what actually prefilled the fields below it.
  Map<String, dynamic>? _currentCompensation;
  Map<String, dynamic>? _upcomingCompensation;
  // Non-null while editing the upcoming record shown above the form — Save
  // then PATCHes that record instead of POSTing a new one.
  int? _editingCompensationId;

  @override
  void initState() {
    super.initState();
    if (widget.isStandalone) {
      unawaited(_loadExisting());
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await ApiService()
          .getTeamMemberCompensation(widget.salonId, widget.userId);
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final employmentType = (data['employmentType'] ?? '').toString();
        if (_employmentTypes.contains(employmentType)) {
          _employmentType = employmentType;
        }

        // Reset before repopulating — this method also runs after a
        // cancel/edit-save reload, and without this a stale upcoming
        // record's values (e.g. a cancelled amount) would keep showing in
        // the form even though the fresh response no longer has one.
        _currentCompensation = null;
        _upcomingCompensation = null;
        _editingCompensationId = null;
        _payType = 'SALARY';
        _amountCtrl.clear();
        _currencyCtrl.text = 'INR';
        _effectiveFrom = null;

        final current = data['current'];
        if (current is Map) {
          _currentCompensation = Map<String, dynamic>.from(current);
        }
        final upcoming = data['upcoming'];
        if (upcoming is Map) {
          _upcomingCompensation = Map<String, dynamic>.from(upcoming);
        }

        // The form below is left blank here (a new-record form), even when
        // an upcoming record exists — that record already has its own card
        // with an Edit action, and prefilling both would show the same data
        // twice. _editUpcoming() prefills the form only when that Edit is
        // actually tapped.
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = extractErrorMessage(
          e,
          fallback: 'Unable to load current compensation',
        );
        _isLoading = false;
      });
    }
  }

  void _editUpcoming() {
    final upcoming = _upcomingCompensation;
    if (upcoming == null) return;
    final compensationId = upcoming['compensationId'];
    if (compensationId is! int) return;

    setState(() {
      _editingCompensationId = compensationId;

      final compensationType = (upcoming['compensationType'] ?? '').toString();
      if (_payTypes.contains(compensationType)) _payType = compensationType;

      final amountMinor = upcoming['salaryAmountMinor'];
      if (amountMinor is num) {
        _amountCtrl.text = (amountMinor / 100).round().toString();
      }

      final currency = (upcoming['currency'] ?? '').toString().trim();
      if (currency.isNotEmpty) _currencyCtrl.text = currency;

      final effectiveFromRaw = (upcoming['effectiveFrom'] ?? '').toString();
      final parsed = DateTime.tryParse(effectiveFromRaw.trim());
      if (parsed != null) _effectiveFrom = parsed;
    });
  }

  Future<void> _cancelUpcoming() async {
    final upcoming = _upcomingCompensation;
    if (upcoming == null || _isSaving) return;
    final compensationId = upcoming['compensationId'];
    if (compensationId is! int) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translateText('Cancel scheduled change?')),
        content: Text(
          translateText(
            'This removes the upcoming compensation change. The current arrangement stays in effect.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(translateText('No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              translateText('Yes, cancel'),
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final response = await ApiService().deleteTeamMemberCompensation(
        widget.salonId,
        widget.userId,
        compensationId,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(
            msg: translateText('Scheduled change cancelled'));
        if (_editingCompensationId == compensationId) {
          _editingCompensationId = null;
        }
        await _loadExisting();
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(response, fallback: 'Unable to cancel'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: extractErrorMessage(e, fallback: 'Unable to cancel'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: cpAccent,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _effectiveFrom = picked);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_effectiveFrom == null) {
      Fluttertoast.showToast(msg: translateText('Effective date is required'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    final amountMajor = double.tryParse(_amountCtrl.text.trim());
    if (amountMajor == null || amountMajor < 0) {
      Fluttertoast.showToast(msg: translateText('Enter a valid amount'));
      return;
    }
    final salaryAmountMinor = (amountMajor * 100).round();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    final d = _effectiveFrom!;
    final effectiveFrom =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    setState(() => _isSaving = true);
    try {
      final employmentResponse =
          await ApiService().patchTeamMemberEmploymentType(
        widget.salonId,
        widget.userId,
        _employmentType,
      );
      if (!mounted) return;
      if (employmentResponse['success'] != true) {
        Fluttertoast.showToast(
          msg: extractMessage(
            employmentResponse,
            fallback: 'Unable to save employment type',
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final payload = {
        'compensationType': _payType,
        'salaryAmountMinor': salaryAmountMinor,
        'currency': currency,
        'effectiveFrom': effectiveFrom,
      };
      final editingId = _editingCompensationId;
      final response = editingId != null
          ? await ApiService().patchTeamMemberCompensation(
              widget.salonId,
              widget.userId,
              editingId,
              payload,
            )
          : await ApiService().createTeamMemberCompensation(
              widget.salonId,
              widget.userId,
              payload,
            );
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Employment details saved'));
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
          msg:
              extractMessage(response, fallback: 'Unable to save compensation'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(e, fallback: 'Unable to save'),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.memberName.trim();
    return Scaffold(
      backgroundColor: cpSurface,
      appBar: buildProfileSubpageAppBar(
        title: widget.isStandalone
            ? (_editingCompensationId != null
                ? translateText('Update Compensation')
                : translateText('Add Compensation'))
            : translateText('Employment Details'),
      ),
      body: _isLoading
          ? AppLoader.page()
          : _loadError != null
              ? CpErrorState(message: _loadError!, onRetry: _loadExisting)
              : _buildForm(memberName),
      bottomNavigationBar: (_isLoading || _loadError != null)
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CpBottomButton(
                    label: translateText('Save & Continue'),
                    isBusy: _isSaving,
                    onPressed: _save,
                  ),
                  if (!widget.isStandalone)
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        translateText('Skip for now'),
                        style: const TextStyle(
                          color: cpMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildForm(String memberName) {
    final current = _currentCompensation;
    final upcoming = _upcomingCompensation;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (current != null) ...[
            _CurrentCompensationCard(record: current),
            const SizedBox(height: 12),
          ],
          if (upcoming != null) ...[
            _UpcomingCompensationCard(
              record: upcoming,
              isBusy: _isSaving,
              onEdit: _editUpcoming,
              onCancel: _cancelUpcoming,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            widget.isStandalone
                ? (memberName.isEmpty
                    ? translateText(
                        'Record a new compensation arrangement below.')
                    : translateText(
                        'Record a new compensation arrangement for {name}.',
                        params: {'name': memberName},
                      ))
                : translateText('Finalize employment and compensation.'),
            style: const TextStyle(color: cpMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          CpSectionCard(
            title: translateText('Employment Type'),
            icon: Icons.work_outline_rounded,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _employmentType,
                decoration: cpInputDecoration(translateText('Employment Type')),
                items: _employmentTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_employmentTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _employmentType = value);
                },
              ),
            ],
          ),
          const CpSectionDivider(),
          CpSectionCard(
            title: translateText('Pay Type'),
            icon: Icons.payments_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _payType,
                decoration: cpInputDecoration(translateText('Pay Type')),
                items: _payTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_payTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _payType = value);
                },
              ),
            ],
          ),
          const CpSectionDivider(),
          CpSectionCard(
            title: translateText('Base Salary'),
            icon: Icons.account_balance_wallet_outlined,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _currencyCtrl,
                      maxLength: 3,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          cpInputDecoration('INR').copyWith(counterText: ''),
                      validator: (value) {
                        final v = (value ?? '').trim().toUpperCase();
                        return RegExp(r'^[A-Z]{3}$').hasMatch(v)
                            ? null
                            : translateText('3 letters');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: 6,
                      decoration: cpInputDecoration('35000'),
                      validator: (value) {
                        final v = double.tryParse((value ?? '').trim());
                        return v == null || v < 0
                            ? translateText('Enter a valid amount')
                            : null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const CpSectionDivider(),
          CpSectionCard(
            title: translateText('Effective From'),
            icon: Icons.event_outlined,
            children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration:
                      cpInputDecoration(translateText('Select date')).copyWith(
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        size: 16, color: cpMuted),
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: cpMuted),
                  ),
                  child: Text(
                    _effectiveFrom == null
                        ? translateText('Select date')
                        : '${_effectiveFrom!.year}-${_effectiveFrom!.month.toString().padLeft(2, '0')}-${_effectiveFrom!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _effectiveFrom == null ? cpMuted : cpInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentCompensationCard extends StatelessWidget {
  const _CurrentCompensationCard({required this.record});

  final Map<String, dynamic> record;

  Widget _column(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: cpMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cpInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payType =
        _payTypeLabel((record['compensationType'] ?? '').toString());
    final salary =
        formatMinorAmount(record['salaryAmountMinor'], trimZeroDecimals: true);
    final effectiveFrom = (record['effectiveFrom'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cpAccentLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText('Current compensation'),
            style: const TextStyle(
              color: Color(0xFF8B6500),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _column(translateText('Pay Type'), payType),
              _column(translateText('Salary'), salary),
              _column(translateText('Effective From'), effectiveFrom),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCompensationCard extends StatelessWidget {
  const _UpcomingCompensationCard({
    required this.record,
    required this.isBusy,
    required this.onEdit,
    required this.onCancel,
  });

  final Map<String, dynamic> record;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  Widget _column(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: cpMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cpInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payType =
        _payTypeLabel((record['compensationType'] ?? '').toString());
    final salary =
        formatMinorAmount(record['salaryAmountMinor'], trimZeroDecimals: true);
    final effectiveFrom = (record['effectiveFrom'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cpBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  translateText('Upcoming compensation'),
                  style: const TextStyle(
                    color: cpInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: isBusy ? null : onEdit,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: cpAccent),
                  foregroundColor: cpAccent,
                ),
                child: Text(
                  translateText('Edit'),
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: isBusy ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppColors.red),
                  foregroundColor: AppColors.red,
                ),
                child: Text(
                  translateText('Cancel'),
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _column(translateText('Pay Type'), payType),
              _column(translateText('Salary'), salary),
              _column(translateText('Effective From'), effectiveFrom),
            ],
          ),
        ],
      ),
    );
  }
}
