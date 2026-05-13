part of 'profile_compensation_screen.dart';

extension _OwnerPayrollUi on _ProfileCompensationScreenState {
  Widget _buildPayrollDashboard() {
    final currentRun = _payrollRuns.isEmpty ? null : _payrollRuns.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: context.t('Active team'),
                value: '${_activeTeamMembers.length}',
                subtitle: context.t('members'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: context.t('Configured'),
                value: '${_payrollSetups.length}',
                subtitle: context.t('payroll setups'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: context.t('Runs'),
                value: '${_payrollRuns.length}',
                subtitle: context.t('generated'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (currentRun != null)
          _HighlightCard(
            title: context.t('Current run'),
            subtitle: currentRun.periodLabel,
            amount: _formatCurrency(currentRun.totalAmountMinor),
            status: currentRun.statusLabel,
            onTap: () {
              _openPayrollReview(currentRun);
            },
          )
        else
          _EmptyStateCard(
            title: context.t('No payroll generated yet'),
            subtitle: context.t(
              'Finish payroll setup, then generate the first payroll period for this branch.',
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!_isPayrollConfiguredForAllTeam)
              _ActionChipButton(
                label: context.t('Setup Payroll'),
                filled: true,
                onTap: _isActionInProgress
                    ? null
                    : () {
                        _showPayrollSetupStage();
                      },
              ),
            if (_isPayrollConfiguredForAllTeam)
              _ActionChipButton(
                label: _isActionInProgress
                    ? context.t('Generating...')
                    : context.t('Generate Payroll'),
                filled: true,
                onTap: _isActionInProgress
                    ? null
                    : () {
                        _openGeneratePayrollDialog();
                      },
              ),
            if (_payrollRuns.isNotEmpty)
              _ActionChipButton(
                label: context.t('Review & Pay'),
                onTap: _isActionInProgress
                    ? null
                    : () {
                        _openPayrollReview(_payrollRuns.first);
                      },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.t('Generated Payroll Periods'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const SizedBox(height: 12),
        if (_activeTeamMembers.isEmpty)
          _EmptyStateCard(
            title: context.t('No staff found for this branch'),
            subtitle: context.t(
              'Add or activate team members before setting up payroll.',
            ),
          )
        else if (_payrollRuns.isEmpty)
          _EmptyStateCard(
            title: context.t('No payroll history available'),
            subtitle: context.t(
              'Once you generate payroll, each period will appear here for review and payment.',
            ),
          )
        else
          ..._payrollRuns.map(
            (run) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
    required this.onBack,
    required this.onContinue,
  });

  final List<ProfileTeamMember> teamMembers;
  final Map<int, PayrollSetupRecord> existingSetups;
  final Future<void> Function(PayrollSetupRecord setup) onSave;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<_PayrollSetupView> createState() => _PayrollSetupViewState();
}

class _PayrollSetupViewState extends State<_PayrollSetupView> {
  final Set<int> _savingIds = <int>{};

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(context.t('Back to Dashboard')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(context.t('Continue / Review')),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.teamMembers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = widget.teamMembers[index];
              final initial = widget.existingSetups[member.id];
              return _PayrollSetupMemberCard(
                member: member,
                initialSetup: initial,
                isSaving: _savingIds.contains(member.id),
                onSave: (setup) async {
                  setState(() => _savingIds.add(member.id));
                  try {
                    await widget.onSave(setup);
                  } finally {
                    if (mounted) {
                      setState(() => _savingIds.remove(member.id));
                    }
                  }
                },
              );
            },
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
              child: Text(
                  widget.isSaving ? context.t('Saving...') : context.t('Save')),
            ),
          ),
        ],
      ),
    );
  }
}
