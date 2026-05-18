part of 'profile_compensation_screen.dart';

extension _OwnerPayrollUi on _ProfileCompensationScreenState {
  Widget _buildPayrollDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1EBE6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payroll Runs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                  ),
                  _ActionChipButton(
                    label: _isOpeningPayrollSetup
                        ? context.t('Opening...')
                        : 'Manage Team Setup',
                    icon: Icons.manage_accounts_outlined,
                    isLoading: _isOpeningPayrollSetup,
                    onTap: (_isActionInProgress || _isOpeningPayrollSetup)
                        ? null
                        : _openPayrollSetupScreen,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_payrollRuns.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DFD1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No payroll runs available',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Complete team setup first. Generated payroll periods will appear here for review.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (_isPayrollConfiguredForAllTeam) ...[
                        const SizedBox(height: 14),
                        _ActionChipButton(
                          label: _isActionInProgress
                              ? context.t('Generating...')
                              : context.t('Generate Payroll'),
                          filled: true,
                          isLoading: _isActionInProgress,
                          onTap: _isActionInProgress
                              ? null
                              : _openGeneratePayrollDialog,
                        ),
                      ],
                    ],
                  ),
                )
              else
                ..._payrollRuns.map(
                  (run) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PayrollRunTile(
                      run: run,
                      amountLabel: _formatCurrency(run.totalAmountMinor),
                      statusColor: _statusColor(run.statusLabel),
                      onOpen: () {
                        _openPayrollReview(run);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeneratePayrollDialog extends StatefulWidget {
  const _GeneratePayrollDialog();

  @override
  State<_GeneratePayrollDialog> createState() => _GeneratePayrollDialogState();
}

class _GeneratePayrollDialogState extends State<_GeneratePayrollDialog> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final years =
        List<int>.generate(5, (index) => DateTime.now().year - 1 + index);

    return AlertDialog(
      title: Text(context.t('Generate Payroll')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _selectedMonth,
            decoration: InputDecoration(labelText: context.t('Month')),
            items: List<DropdownMenuItem<int>>.generate(
              12,
              (index) => DropdownMenuItem<int>(
                value: index + 1,
                child:
                    Text(DateFormat('MMMM').format(DateTime(2026, index + 1))),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMonth = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: InputDecoration(labelText: context.t('Year')),
            items: years
                .map(
                  (year) => DropdownMenuItem<int>(
                    value: year,
                    child: Text('$year'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('Cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(_selectedYear, _selectedMonth, 1),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: Text(context.t('Generate Payroll')),
        ),
      ],
    );
  }
}

class _PayrollSetupView extends StatefulWidget {
  const _PayrollSetupView({
    required this.teamMembers,
    required this.existingSetups,
    required this.onSave,
    required this.onContinue,
  });

  final List<ProfileTeamMember> teamMembers;
  final Map<int, PayrollSetupRecord> existingSetups;
  final Future<void> Function(PayrollSetupRecord setup) onSave;
  final VoidCallback onContinue;

  @override
  State<_PayrollSetupView> createState() => _PayrollSetupViewState();
}

class _PayrollSetupViewState extends State<_PayrollSetupView> {
  final Set<int> _savingIds = <int>{};

  int get _configuredCount => widget.teamMembers
      .where((member) => widget.existingSetups.containsKey(member.id))
      .length;

  int get _pendingCount => widget.teamMembers.length - _configuredCount;

  Future<void> _openEditDialog(ProfileTeamMember member) async {
    final initial = widget.existingSetups[member.id];
    debugPrint(
      '[OwnerCompensation:payroll] open_payroll_setup_member_dialog | '
      'userId=${member.id}, configured=${initial != null}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          contentPadding: const EdgeInsets.all(16),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: _PayrollSetupMemberCard(
                member: member,
                initialSetup: initial,
                isSaving: _savingIds.contains(member.id),
                onSave: (setup) async {
                  debugPrint(
                    '[OwnerCompensation:payroll] payroll_setup_member_save_started | '
                    'userId=${member.id}, payrollType=${setup.payrollType}',
                  );
                  setState(() => _savingIds.add(member.id));
                  try {
                    await widget.onSave(setup);
                    debugPrint(
                      '[OwnerCompensation:payroll] payroll_setup_member_save_success | '
                      'userId=${member.id}',
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (error) {
                    debugPrint(
                      '[OwnerCompensation:payroll] payroll_setup_member_save_failed | '
                      'userId=${member.id}, error=$error',
                    );
                    rethrow;
                  } finally {
                    if (mounted) {
                      setState(() => _savingIds.remove(member.id));
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teamMembers.isEmpty) {
      return _EmptyStateCard(
        title: context.t('No staff found for this branch'),
        subtitle: context.t(
          'Add or activate team members before configuring payroll.',
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.t('Setup Payroll'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('Set up salary and commission for your team'),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB45309),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Payroll Setup',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(color: Color(0xFFD7CEC5)),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD7CEC5)),
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE7A45B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFB45309),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set salary and commission for your team',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'You can update salary or commission anytime. Changes will be used for payroll calculations.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Members (${widget.teamMembers.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add salary and commission details for each team member.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...widget.teamMembers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final member = entry.value;
                        final setup = widget.existingSetups[member.id];
                        final payType = setup == null
                            ? 'Not configured'
                            : PayrollTypes.label(setup.payrollType);
                        final salaryText =
                            setup == null || setup.salaryMinor == 0
                                ? '-'
                                : '₹${setup.salaryMinor}';
                        final commissionText = setup == null ||
                                setup.commissionPercent == 0
                            ? '-'
                            : '${setup.commissionPercent.toStringAsFixed(1)}%';
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        member.role.isEmpty
                                            ? context.t('Team member')
                                            : member.role,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    payType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    salaryText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    commissionText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    setup == null
                                        ? '-'
                                        : DateFormat('dd MMM yyyy')
                                            .format(setup.effectiveDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _savingIds.contains(member.id)
                                      ? null
                                      : () => _openEditDialog(member),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.starColor,
                                    side:
                                        BorderSide(color: AppColors.starColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _savingIds.contains(member.id)
                                        ? context.t('Saving...')
                                        : context.t('Edit'),
                                  ),
                                ),
                              ],
                            ),
                            if (index != widget.teamMembers.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1),
                              ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF2D29A)),
                        ),
                        child: Text(
                          '$_configuredCount members have payroll setup • $_pendingCount members need to be added\nTip: You can change payroll type, salary or commission for any team member.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB26A00),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.starColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Review'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayrollSetupMemberCard extends StatefulWidget {
  const _PayrollSetupMemberCard({
    required this.member,
    required this.initialSetup,
    required this.isSaving,
    required this.onSave,
  });

  final ProfileTeamMember member;
  final PayrollSetupRecord? initialSetup;
  final bool isSaving;
  final Future<void> Function(PayrollSetupRecord setup) onSave;

  @override
  State<_PayrollSetupMemberCard> createState() =>
      _PayrollSetupMemberCardState();
}

class _PayrollSetupMemberCardState extends State<_PayrollSetupMemberCard> {
  late String _payrollType;
  late TextEditingController _salaryController;
  late TextEditingController _commissionController;
  late DateTime _effectiveDate;

  @override
  void initState() {
    super.initState();
    _payrollType = widget.initialSetup?.payrollType ?? PayrollTypes.salaryOnly;
    _salaryController = TextEditingController(
      text: widget.initialSetup == null || widget.initialSetup!.salaryMinor == 0
          ? ''
          : '${widget.initialSetup!.salaryMinor}',
    );
    _commissionController = TextEditingController(
      text: widget.initialSetup == null ||
              widget.initialSetup!.commissionPercent == 0
          ? ''
          : widget.initialSetup!.commissionPercent.toStringAsFixed(1),
    );
    _effectiveDate = widget.initialSetup?.effectiveDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PayrollSetupMemberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSetup != widget.initialSetup &&
        widget.initialSetup != null) {
      _payrollType = widget.initialSetup!.payrollType;
      _salaryController.text = widget.initialSetup!.salaryMinor == 0
          ? ''
          : '${widget.initialSetup!.salaryMinor}';
      _commissionController.text = widget.initialSetup!.commissionPercent == 0
          ? ''
          : widget.initialSetup!.commissionPercent.toStringAsFixed(1);
      _effectiveDate = widget.initialSetup!.effectiveDate;
    }
  }

  bool get _requiresSalary =>
      _payrollType == PayrollTypes.salaryOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  bool get _requiresCommission =>
      _payrollType == PayrollTypes.commissionOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  Future<void> _submit() async {
    final salary = int.tryParse(_salaryController.text.trim()) ?? 0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0;
    final salaryRequired = translateText(
      'Salary is required for salary-based payroll types.',
    );
    final commissionRange = translateText(
      'Commission must be between 0 and 100.',
    );

    if (_requiresSalary && salary <= 0) {
      _showRowToast(salaryRequired);
      return;
    }
    if (_requiresCommission && (commission < 0 || commission > 100)) {
      _showRowToast(commissionRange);
      return;
    }

    final setup = PayrollSetupRecord(
      userId: widget.member.id,
      userName: widget.member.name,
      payrollType: _payrollType,
      salaryMinor: _requiresSalary ? salary : 0,
      commissionPercent: _requiresCommission ? commission : 0,
      effectiveDate: _effectiveDate,
    );
    await widget.onSave(setup);
  }

  void _showRowToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.member.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.member.role.isEmpty
                          ? context.t('Team member')
                          : widget.member.role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.initialSetup != null)
                _StatusPill(
                  label: context.t('Configured'),
                  color: Color(0xFF157347),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _payrollType,
            decoration: InputDecoration(
              labelText: context.t('Payroll type'),
              filled: true,
              fillColor: const Color(0xFFF8F5F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: PayrollTypes.values
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(PayrollTypes.label(value)),
                  ),
                )
                .toList(),
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _payrollType = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledTextField(
                  label: context.t('Salary'),
                  controller: _salaryController,
                  enabled: _requiresSalary && !widget.isSaving,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledTextField(
                  label: context.t('Commission %'),
                  controller: _commissionController,
                  enabled: _requiresCommission && !widget.isSaving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DateFieldButton(
            label: context.t('Effective date'),
            value: _effectiveDate,
            onTap: widget.isSaving
                ? () {}
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _effectiveDate,
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _effectiveDate = picked);
                    }
                  },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isSaving
                  ? null
                  : () {
                      _submit();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isSaving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  if (widget.isSaving) const SizedBox(width: 10),
                  Text(
                    widget.isSaving
                        ? context.t('Saving...')
                        : context.t('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
