import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../widgets/app_loader.dart';

const Color _tcInk = Color(0xFF1C1917);
const Color _tcMuted = Color(0xFF78716C);
const Color _tcBorder = Color(0xFFE7E5E4);
const Color _tcSurface = Color(0xFFFAF8F5);
const Color _tcAccent = Color(0xFFC19A6B);
const Color _tcAccentLight = Color(0xFFF3E8D1);

const List<String> _employmentTypes = [
  'FULL_TIME',
  'PART_TIME',
  'CONTRACT',
  'FREELANCER',
];

String _employmentTypeLabel(String value) {
  switch (value) {
    case 'FULL_TIME':
      return translateText('Full-time');
    case 'PART_TIME':
      return translateText('Part-time');
    case 'CONTRACT':
      return translateText('Contract');
    case 'FREELANCER':
      return translateText('Freelancer');
    default:
      return value;
  }
}

String _compensationTypeLabel(String value) {
  return value == 'SALARY_PLUS_COMMISSION'
      ? translateText('Salary + Commission')
      : translateText('Salary');
}

String _formatMoney(dynamic minor, String currency) {
  final amount = (minor is num ? minor : num.tryParse('$minor') ?? 0) / 100;
  final formatted = NumberFormat.decimalPattern('en_IN').format(amount);
  return '$currency $formatted';
}

/// salon_user_compensation.md — employment type + dated salary history.
/// Deliberately its own screen and its own five endpoints, separate from
/// the profile PATCH/GET routes — the spec explicitly forbids surfacing
/// compensation on Team list/detail responses.
class TeamMemberCompensationScreen extends StatefulWidget {
  const TeamMemberCompensationScreen({
    super.key,
    required this.salonId,
    required this.userId,
    required this.memberName,
    this.canUpdate = true,
  });

  final int salonId;
  final int userId;
  final String memberName;

  /// team.update — same gate the rest of the Team edit surface uses.
  /// GET only needs team.view (already implied by reaching this screen).
  final bool canUpdate;

  @override
  State<TeamMemberCompensationScreen> createState() =>
      _TeamMemberCompensationScreenState();
}

class _TeamMemberCompensationScreenState
    extends State<TeamMemberCompensationScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Map<String, dynamic>? get _current =>
      _data['current'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _upcoming =>
      _data['upcoming'] as Map<String, dynamic>?;
  List<Map<String, dynamic>> get _history {
    final raw = _data['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await ApiService()
          .getTeamMemberCompensation(widget.salonId, widget.userId);
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(response['data'] as Map);
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError = extractMessage(
            response,
            fallback: 'Unable to load compensation',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = extractErrorMessage(
          e,
          fallback: 'Unable to load compensation',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _pickEmploymentType() async {
    if (!widget.canUpdate || _isBusy) return;
    final current = (_data['employmentType'] ?? '').toString();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translateText('Employment type'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 12),
              ..._employmentTypes.map((type) {
                final isSelected = type == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(ctx, type),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _tcAccentLight : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected ? _tcAccent : const Color(0xFFE7E5E4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _employmentTypeLabel(type),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: const Color(0xFF1C1917),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded,
                                color: _tcAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(translateText('Cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == current) return;

    setState(() => _isBusy = true);
    try {
      final response = await ApiService().patchTeamMemberEmploymentType(
        widget.salonId,
        widget.userId,
        selected,
      );
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        setState(
            () => _data = Map<String, dynamic>.from(response['data'] as Map));
        Fluttertoast.showToast(msg: translateText('Employment type updated'));
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(
            response,
            fallback: 'Unable to update employment type',
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(e,
            fallback: 'Unable to update employment type'),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openCompensationForm({Map<String, dynamic>? editing}) async {
    if (!widget.canUpdate || _isBusy) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CompensationFormScreen(
          salonId: widget.salonId,
          userId: widget.userId,
          existing: editing,
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _cancelUpcoming() async {
    final upcoming = _upcoming;
    if (!widget.canUpdate || upcoming == null || _isBusy) return;
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

    setState(() => _isBusy = true);
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
        await _load();
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(response, fallback: 'Unable to cancel'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: extractErrorMessage(e, fallback: 'Unable to cancel'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tcSurface,
      appBar: buildProfileSubpageAppBar(title: 'Employment & Compensation'),
      body: _isLoading
          ? AppLoader.page()
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final employmentType = (_data['employmentType'] ?? '').toString();
    final upcoming = _upcoming;
    final current = _current;
    final history = _history;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.starColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            widget.memberName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: translateText('Employment Type')),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickEmploymentType,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _tcBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.work_outline_rounded,
                      size: 18, color: _tcAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      employmentType.isEmpty
                          ? translateText('Not set')
                          : _employmentTypeLabel(employmentType),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _tcInk,
                      ),
                    ),
                  ),
                  if (widget.canUpdate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _tcAccentLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _tcAccent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: _tcAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            translateText('Edit'),
                            style: const TextStyle(
                              color: _tcAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(text: translateText('Compensation')),
          const SizedBox(height: 8),
          if (current != null)
            _CompensationCard(
                record: current, statusLabel: translateText('Current'))
          else
            _EmptyCompensationCard(
                text: translateText('No compensation on file')),
          if (upcoming != null) ...[
            const SizedBox(height: 10),
            _CompensationCard(
              record: upcoming,
              statusLabel: translateText('Upcoming'),
              actions: widget.canUpdate
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () =>
                                    _openCompensationForm(editing: upcoming),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFFF3E8FF),
                              foregroundColor: const Color(0xFF6D28D9),
                              disabledBackgroundColor: const Color(0xFFF5F5F4),
                              disabledForegroundColor: _tcMuted,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: Text(
                              translateText('Edit'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBusy ? null : _cancelUpcoming,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFFFFF1F2),
                              foregroundColor: AppColors.red,
                              disabledBackgroundColor: const Color(0xFFF5F5F4),
                              disabledForegroundColor: _tcMuted,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 15),
                            label: Text(
                              translateText('Cancel'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
          if (widget.canUpdate && upcoming == null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : () => _openCompensationForm(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _tcAccent),
                  foregroundColor: _tcAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  current == null
                      ? translateText('Add Compensation')
                      : translateText('Record a Change'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionLabel(text: translateText('History')),
            const SizedBox(height: 8),
            ...history.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CompensationCard(
                  record: record,
                  statusLabel: translateText('Past'),
                  muted: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: _tcMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _EmptyCompensationCard extends StatelessWidget {
  const _EmptyCompensationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tcBorder),
      ),
      child: Text(text, style: const TextStyle(color: _tcMuted, fontSize: 13)),
    );
  }
}

class _CompensationCard extends StatelessWidget {
  const _CompensationCard({
    required this.record,
    required this.statusLabel,
    this.actions,
    this.muted = false,
  });

  final Map<String, dynamic> record;
  final String statusLabel;
  final Widget? actions;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final currency = (record['currency'] ?? 'INR').toString();
    final amount = _formatMoney(record['salaryAmountMinor'], currency);
    final type =
        _compensationTypeLabel((record['compensationType'] ?? '').toString());
    final from = (record['effectiveFrom'] ?? '').toString();
    final to = (record['effectiveTo'] ?? '').toString();
    final pillColor = muted
        ? _tcMuted
        : statusLabel == translateText('Current')
            ? const Color(0xFF18864B)
            : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: muted ? _tcSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tcBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  amount,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: muted ? _tcMuted : _tcInk,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: pillColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$type · ${translateText('Monthly')}',
            style: const TextStyle(color: _tcMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Text(
            to.isEmpty
                ? translateText('From {from}', params: {'from': from})
                : translateText('{from} to {to}',
                    params: {'from': from, 'to': to}),
            style: const TextStyle(color: _tcMuted, fontSize: 11.5),
          ),
          if (actions != null) ...[
            const SizedBox(height: 10),
            actions!,
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.red, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: onRetry, child: Text(translateText('Retry'))),
          ],
        ),
      ),
    );
  }
}

// ---- Add / Edit compensation form ----

class _CompensationFormScreen extends StatefulWidget {
  const _CompensationFormScreen({
    required this.salonId,
    required this.userId,
    this.existing,
  });

  final int salonId;
  final int userId;

  /// Non-null when editing the sole upcoming row (PATCH); null for a new
  /// arrangement (POST), which replaces the current one when backdated
  /// per salon_user_compensation.md §5.2.
  final Map<String, dynamic>? existing;

  @override
  State<_CompensationFormScreen> createState() =>
      _CompensationFormScreenState();
}

class _CompensationFormScreenState extends State<_CompensationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _compensationType =
      (widget.existing?['compensationType'] ?? 'SALARY').toString();
  late final _amountCtrl = TextEditingController(
    text: widget.existing == null
        ? ''
        : ((((widget.existing!['salaryAmountMinor'] as num?) ?? 0) / 100)
                .round())
            .toString(),
  );
  late final _currencyCtrl = TextEditingController(
    text: (widget.existing?['currency'] ?? 'INR').toString(),
  );
  DateTime? _effectiveFrom;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final raw = widget.existing?['effectiveFrom']?.toString();
    if (raw != null && raw.isNotEmpty) {
      _effectiveFrom = DateTime.tryParse(raw);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _tcAccent,
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

  Future<void> _submit() async {
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
      final Map<String, dynamic> response;
      if (_isEditing) {
        final compensationId = widget.existing!['compensationId'];
        response = await ApiService().patchTeamMemberCompensation(
          widget.salonId,
          widget.userId,
          compensationId is int ? compensationId : int.parse('$compensationId'),
          {
            'compensationType': _compensationType,
            'salaryAmountMinor': salaryAmountMinor,
            'currency': currency,
            'effectiveFrom': effectiveFrom,
          },
        );
      } else {
        response = await ApiService().createTeamMemberCompensation(
          widget.salonId,
          widget.userId,
          {
            'compensationType': _compensationType,
            'salaryAmountMinor': salaryAmountMinor,
            'currency': currency,
            'effectiveFrom': effectiveFrom,
          },
        );
      }
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Compensation saved'));
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
          msg:
              extractMessage(response, fallback: 'Unable to save compensation'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(e, fallback: 'Unable to save compensation'),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _tcBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _tcBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _tcAccent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tcSurface,
      appBar: buildProfileSubpageAppBar(
        title: _isEditing ? 'Edit Compensation' : 'Add Compensation',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionLabel(text: translateText('Type')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: translateText('Salary'),
                    selected: _compensationType == 'SALARY',
                    onTap: () => setState(() => _compensationType = 'SALARY'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    label: translateText('Salary + Commission'),
                    selected: _compensationType == 'SALARY_PLUS_COMMISSION',
                    onTap: () => setState(
                        () => _compensationType = 'SALARY_PLUS_COMMISSION'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: translateText('Monthly Base Amount')),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _currencyCtrl,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoration('INR').copyWith(
                      counterText: ' ',
                      counterStyle: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: _decoration(translateText('Amount')).copyWith(
                      counterStyle: const TextStyle(
                        color: _tcMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      final parsed = int.tryParse(text);
                      return (text.isEmpty || parsed == null || parsed < 0)
                          ? translateText('Enter a valid amount')
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: translateText('Effective From')),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _decoration(translateText('Select date')).copyWith(
                  suffixIcon: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: _tcMuted),
                ),
                child: Text(
                  _effectiveFrom == null
                      ? translateText('Select date')
                      : '${_effectiveFrom!.year}-${_effectiveFrom!.month.toString().padLeft(2, '0')}-${_effectiveFrom!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: _effectiveFrom == null ? _tcMuted : _tcInk),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translateText(
                'A future date schedules this as an upcoming change. A past or today\'s date replaces the current arrangement.',
              ),
              style: const TextStyle(color: _tcMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    translateText('Save'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _tcAccentLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _tcAccent : _tcBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? _tcAccent : _tcMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
