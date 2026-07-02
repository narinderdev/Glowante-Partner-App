part of 'profile_compensation_screen.dart';

extension _OwnerPayrollUi on _ProfileCompensationScreenState {
  Widget _buildPayrollDashboard() {
    final activeTeamCount = _activeTeamMembers.length;
    final configuredTeamCount = _activeTeamMembers
        .where((member) => _setupByUserId.containsKey(member.id))
        .length;
    final pendingTeamCount = activeTeamCount - configuredTeamCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFCF8),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DashboardStatChip(
                    icon: Icons.receipt_long_outlined,
                    label: context.t('Runs'),
                    value: '${_payrollRuns.length}',
                  ),
                  _DashboardStatChip(
                    icon: Icons.verified_outlined,
                    label: context.t('Configured'),
                    value: '$configuredTeamCount',
                  ),
                  _DashboardStatChip(
                    icon: Icons.schedule_outlined,
                    label: context.t('Pending'),
                    value: '$pendingTeamCount',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_payrollRuns.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFCFAF8),
                        Color(0xFFFFFBF5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE9DFD1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2D7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No payroll runs available',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Complete team setup first. Generated payroll periods will appear here for review.',
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
                      if (_isPayrollConfiguredForAllTeam) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ActionChipButton(
                            label: _isActionInProgress
                                ? context.t('Generating...')
                                : context.t('Generate Payroll'),
                            filled: true,
                            isLoading: _isActionInProgress,
                            onTap: _isActionInProgress
                                ? null
                                : _openGeneratePayrollDialog,
                          ),
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

class _DashboardStatChip extends StatelessWidget {
  const _DashboardStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DFD1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.starColor,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C6F60),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1917),
                ),
              ),
            ],
          ),
        ],
      ),
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

class _PayrollSetupStepHeader extends StatelessWidget {
  const _PayrollSetupStepHeader({
    required this.currentStep,
  });

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFB45309);
    const inactiveColor = Color(0xFFD7CEC5);
    final isStepOneActive = currentStep >= 1;
    final isStepTwoActive = currentStep >= 2;

    Widget stepCircle({
      required String label,
      required bool isActive,
      required bool isSelected,
    }) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget stepLabel({
      required String label,
      required bool isActive,
    }) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isActive ? const Color(0xFF1C1917) : const Color(0xFF6B7280),
        ),
      );
    }

    return Row(
      children: [
        stepCircle(
          label: '1',
          isActive: isStepOneActive,
          isSelected: true,
        ),
        const SizedBox(width: 10),
        stepLabel(
          label: 'Payroll Setup',
          isActive: isStepOneActive,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              color: isStepTwoActive ? activeColor : inactiveColor,
            ),
          ),
        ),
        stepCircle(
          label: '2',
          isActive: isStepTwoActive,
          isSelected: isStepTwoActive,
        ),
        const SizedBox(width: 10),
        stepLabel(
          label: 'Review',
          isActive: isStepTwoActive,
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
  late Map<int, PayrollSetupRecord> _visibleSetups;

  @override
  void initState() {
    super.initState();
    _visibleSetups = Map<int, PayrollSetupRecord>.from(widget.existingSetups);
  }

  @override
  void didUpdateWidget(covariant _PayrollSetupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visibleSetups
      ..clear()
      ..addAll(widget.existingSetups);
  }

  int get _configuredCount => widget.teamMembers
      .where((member) => _visibleSetups.containsKey(member.id))
      .length;

  int get _pendingCount => widget.teamMembers.length - _configuredCount;

  Future<void> _openEditDialog(ProfileTeamMember member) async {
    final initial = _visibleSetups[member.id];
    debugPrint(
      '[OwnerCompensation:payroll] open_payroll_setup_member_dialog | '
      'userId=${member.id}, configured=${initial != null}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width;
        final dialogHeight = math.min(
          MediaQuery.sizeOf(dialogContext).height * 0.62,
          540.0,
        );
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          contentPadding: const EdgeInsets.all(16),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: dialogWidth * 0.98,
              maxWidth: dialogWidth * 0.98,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              width: dialogWidth * 0.98,
              height: dialogHeight,
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
                    if (mounted) {
                      setState(() {
                        _visibleSetups[member.id] = setup;
                      });
                    }
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
                    final message =
                        error.toString().replaceFirst('Exception: ', '').trim();
                    Fluttertoast.showToast(
                      msg: message.isEmpty
                          ? 'Something went wrong. Please try again.'
                          : message,
                    );
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
              const _PayrollSetupStepHeader(currentStep: 1),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = constraints.maxWidth < 760
                              ? 760.0
                              : constraints.maxWidth;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Team Member',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Payroll Type',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Salary (₹)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Commission (%)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Joining Date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 96,
                                          child: Center(
                                            child: Text(
                                              'Action',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),
                                  ...widget.teamMembers
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final member = entry.value;
                                    final setup = _visibleSetups[member.id];
                                    final payType = setup == null
                                        ? 'Not configured'
                                        : PayrollTypes.label(setup.payrollType);
                                    final salaryText = setup == null ||
                                            setup.salaryMinor == 0
                                        ? '-'
                                        : _formatCurrency(setup.salaryMinor);
                                    final commissionText = setup == null ||
                                            setup.commissionPercent == 0
                                        ? '-'
                                        : '${_formatCommissionPercentText(setup.commissionPercent)}%';
                                    return Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    member.role.isEmpty
                                                        ? context
                                                            .t('Team member')
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
                                                        .format(setup
                                                            .effectiveDate),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 96,
                                              child: Center(
                                                child: OutlinedButton(
                                                  onPressed: _savingIds
                                                          .contains(member.id)
                                                      ? null
                                                      : () => _openEditDialog(
                                                            member,
                                                          ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.starColor,
                                                    side: BorderSide(
                                                      color:
                                                          AppColors.starColor,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _savingIds.contains(
                                                      member.id,
                                                    )
                                                        ? context.t(
                                                            'Saving...',
                                                          )
                                                        : context.t('Edit'),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (index !=
                                            widget.teamMembers.length - 1)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: Divider(height: 1),
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  String? _inlineErrorMessage;
  late final DateTime? _joiningDate;
  late String _payrollType;
  late TextEditingController _salaryController;
  late TextEditingController _commissionController;
  late DateTime _effectiveDate;

  @override
  void initState() {
    super.initState();
    _joiningDate = _dateOnly(widget.member.joiningDate);
    _payrollType = widget.initialSetup?.payrollType ?? PayrollTypes.salaryOnly;
    _salaryController = TextEditingController(
      text: widget.initialSetup == null || widget.initialSetup!.salaryMinor == 0
          ? ''
          : _paiseToRupeesText(widget.initialSetup!.salaryMinor),
    );
    _commissionController = TextEditingController(
      text: widget.initialSetup == null ||
              widget.initialSetup!.commissionPercent == 0
          ? ''
          : _formatCommissionPercent(widget.initialSetup!.commissionPercent),
    );
    _effectiveDate = _clampEffectiveDate(
      widget.initialSetup?.effectiveDate ?? DateTime.now(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          : _paiseToRupeesText(widget.initialSetup!.salaryMinor);
      _commissionController.text = widget.initialSetup!.commissionPercent == 0
          ? ''
          : _formatCommissionPercent(widget.initialSetup!.commissionPercent);
      _effectiveDate = _clampEffectiveDate(widget.initialSetup!.effectiveDate);
    }
  }

  bool get _requiresSalary =>
      _payrollType == PayrollTypes.salaryOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  bool get _requiresCommission =>
      _payrollType == PayrollTypes.commissionOnly ||
      _payrollType == PayrollTypes.salaryCommission;

  int _rupeesToPaise(int rupees) => rupees * 100;

  String _paiseToRupeesText(int paise) {
    if (paise <= 0) return '';
    return (paise ~/ 100).toString();
  }

  String _formatCommissionPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearInlineError() {
    if (_inlineErrorMessage == null) return;
    setState(() => _inlineErrorMessage = null);
  }

  String? _validatePayrollSetup() {
    if (_payrollType.trim().isEmpty) {
      return translateText('Payroll type is required');
    }

    if (_requiresSalary) {
      final salary = int.tryParse(_salaryController.text.trim()) ?? 0;
      if (salary <= 0) {
        return translateText('Salary is required');
      }
    }

    if (_requiresCommission) {
      final commission =
          double.tryParse(_commissionController.text.trim()) ?? 0;
      if (commission <= 0 || commission > 100) {
        return translateText('Commission must be between 0 and 100.');
      }
    }

    final minimum = _minimumEffectiveDate();
    if (_effectiveDate.isBefore(minimum)) {
      return translateText('Effective date cannot be before joining date.');
    }

    return null;
  }

  DateTime? _dateOnly(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _minimumEffectiveDate() {
    final today = DateTime.now();
    final joiningDate = _joiningDate;
    if (joiningDate == null) {
      return DateTime(today.year, today.month, today.day);
    }
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return joiningDate.isAfter(normalizedToday) ? joiningDate : normalizedToday;
  }

  DateTime _clampEffectiveDate(DateTime value) {
    final minimum = _minimumEffectiveDate();
    final selected = DateTime(value.year, value.month, value.day);
    return selected.isBefore(minimum) ? minimum : selected;
  }

  Future<void> _submit() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    final validationMessage = _validatePayrollSetup();
    if (validationMessage != null) {
      setState(() => _inlineErrorMessage = validationMessage);
      _formKey.currentState?.validate();
      _scrollToBottom();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollToBottom();
      return;
    }

    setState(() => _inlineErrorMessage = null);

    final salary = int.tryParse(_salaryController.text.trim()) ?? 0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0;

    final setup = PayrollSetupRecord(
      userId: widget.member.id,
      userName: widget.member.name,
      payrollType: _payrollType,
      salaryMinor: _requiresSalary ? _rupeesToPaise(salary) : 0,
      commissionPercent: _requiresCommission ? commission : 0,
      effectiveDate: _clampEffectiveDate(_effectiveDate),
    );
    await widget.onSave(setup);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
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
                            color: const Color(0xFF157347),
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
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? translateText('Payroll type is required')
                              : null,
                      onChanged: widget.isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _payrollType = value);
                                _clearInlineError();
                                if (_autoValidateMode !=
                                    AutovalidateMode.disabled) {
                                  _formKey.currentState?.validate();
                                }
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
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => _clearInlineError(),
                            validator: (value) {
                              if (!_requiresSalary) return null;
                              final salary =
                                  int.tryParse((value ?? '').trim()) ?? 0;
                              if (salary <= 0) {
                                return translateText('Salary is required');
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledTextField(
                            label: context.t('Commission %'),
                            controller: _commissionController,
                            enabled: _requiresCommission && !widget.isSaving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            maxLength: 3,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            onChanged: (_) => _clearInlineError(),
                            validator: (value) {
                              if (!_requiresCommission) return null;
                              final commission =
                                  double.tryParse((value ?? '').trim()) ?? 0;
                              if (commission <= 0 || commission > 100) {
                                return translateText(
                                  'Commission must be between 0 and 100.',
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE9DFD1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('Joining date'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  () {
                                    final joiningDate = _joiningDate;
                                    return joiningDate == null
                                        ? context.t('Not available')
                                        : DateFormat('dd MMM yyyy')
                                            .format(joiningDate);
                                  }(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormField<DateTime>(
                      initialValue: _effectiveDate,
                      autovalidateMode: _autoValidateMode,
                      validator: (value) {
                        final selected = value ?? _effectiveDate;
                        final minimum = _minimumEffectiveDate();
                        if (selected.isBefore(minimum)) {
                          return translateText(
                            'Effective date cannot be before joining date.',
                          );
                        }
                        return null;
                      },
                      builder: (field) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DateFieldButton(
                              label: context.t('Effective date'),
                              value: _effectiveDate,
                              onTap: widget.isSaving
                                  ? () {}
                                  : () async {
                                      final minimum = _minimumEffectiveDate();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _effectiveDate.isBefore(minimum)
                                                ? minimum
                                                : _effectiveDate,
                                        firstDate: minimum,
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        final clamped =
                                            _clampEffectiveDate(picked);
                                        setState(
                                            () => _effectiveDate = clamped);
                                        _clearInlineError();
                                        field.didChange(clamped);
                                      }
                                    },
                            ),
                            if (field.errorText != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                field.errorText!,
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _inlineErrorMessage == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_inlineErrorMessage),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _inlineErrorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.t('Cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isSaving ? null : _submit,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
        ],
      ),
    );
  }
}
