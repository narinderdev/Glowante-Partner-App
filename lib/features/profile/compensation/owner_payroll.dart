part of 'profile_compensation_screen.dart';

extension _OwnerPayrollUi on _ProfileCompensationScreenState {
  Widget _buildPayrollDashboard() {
    final readyPayrollPeriod = _readyPayrollPeriod();
    final readyPayrollPeriodKey = DateFormat('yyyy-MM').format(
      readyPayrollPeriod,
    );
    final hasReadyPayrollRun = _payrollRuns.any(
      (run) => run.periodKey == readyPayrollPeriodKey,
    );
    final shouldShowStartSetup = _payrollRuns.isEmpty && _payrollSetups.isEmpty;
    final isOpeningPayrollReview = _openingPayrollReviewRunId != null;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.starColor,
          backgroundColor: const Color(0xFFFFFCF8),
          onRefresh: () => RefreshFeedback.playAndRun(
            () => _reloadContent(showLoader: false),
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (shouldShowStartSetup)
                _PayrollNotGeneratedEmptyState(
                  isLoading: _isOpeningPayrollSetup,
                  onStartSetup: (_isActionInProgress || _isOpeningPayrollSetup)
                      ? null
                      : _openPayrollSetupScreen,
                )
              else
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
                            onTap:
                                (_isActionInProgress || _isOpeningPayrollSetup)
                                    ? null
                                    : _openPayrollSetupScreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!hasReadyPayrollRun) ...[
                        _ReadyPayrollPeriodCard(
                          periodLabel: DateFormat('MMMM yyyy').format(
                            readyPayrollPeriod,
                          ),
                          isLoading: _isActionInProgress,
                          onGenerate: _isActionInProgress
                              ? null
                              : () => _generatePayroll(readyPayrollPeriod),
                        ),
                        if (_payrollRuns.isNotEmpty) const SizedBox(height: 12),
                      ],
                      if (_payrollRuns.isNotEmpty)
                        ..._payrollRuns.map(
                          (run) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PayrollRunTile(
                              run: run,
                              statusColor: _statusColor(run.statusLabel),
                              onOpen: isOpeningPayrollReview
                                  ? null
                                  : () {
                                      _openPayrollReview(run);
                                    },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (isOpeningPayrollReview)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: const Color(0x66FFFCF8),
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  color: AppColors.starColor,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  DateTime _readyPayrollPeriod() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }
}

class _PayrollNotGeneratedEmptyState extends StatelessWidget {
  const _PayrollNotGeneratedEmptyState({
    required this.isLoading,
    required this.onStartSetup,
  });

  final bool isLoading;
  final VoidCallback? onStartSetup;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PayrollEmptyIllustration(),
            const SizedBox(height: 26),
            Text(
              context.t('You havent generated any payroll yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 300,
              child: Text(
                context.t(
                  'Track and pay your team based on their work, tips, and commissions.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onStartSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isLoading
                        ? context.t('Opening...')
                        : context.t('Start Setup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollEmptyIllustration extends StatelessWidget {
  const _PayrollEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 10,
            child: Container(
              width: 138,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2CC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFECC767)),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: Container(
              width: 98,
              height: 76,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEADFD6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.starColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 30,
                    color: Color(0xFFB45309),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 26,
            child: _PayrollCoin(size: 34),
          ),
          Positioned(
            right: 26,
            bottom: 22,
            child: _PayrollCoin(size: 42),
          ),
          Positioned(
            right: 18,
            top: 38,
            child: Icon(
              Icons.payments_rounded,
              color: AppColors.starColor,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollCoin extends StatelessWidget {
  const _PayrollCoin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD36B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0A72E)),
      ),
      alignment: Alignment.center,
      child: const Text(
        '₹',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF9A6A00),
        ),
      ),
    );
  }
}

class _ReadyPayrollPeriodCard extends StatelessWidget {
  const _ReadyPayrollPeriodCard({
    required this.periodLabel,
    required this.isLoading,
    required this.onGenerate,
  });

  final String periodLabel;
  final bool isLoading;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2D29A)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                periodLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('You can now calculate salary & commission.'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          );
          final actions = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                context.t('Ready to Generate'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB26A00),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isLoading
                          ? context.t('Generating...')
                          : context.t('Generate Payroll'),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
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
    this.onRefresh,
  });

  final List<ProfileTeamMember> teamMembers;
  final Map<int, PayrollSetupRecord> existingSetups;
  final Future<void> Function(PayrollSetupRecord setup) onSave;
  final VoidCallback onContinue;
  final Future<_PayrollSetupRefreshData> Function()? onRefresh;

  @override
  State<_PayrollSetupView> createState() => _PayrollSetupViewState();
}

class _PayrollSetupRefreshData {
  const _PayrollSetupRefreshData({
    required this.teamMembers,
    required this.existingSetups,
  });

  final List<ProfileTeamMember> teamMembers;
  final Map<int, PayrollSetupRecord> existingSetups;
}

class _PayrollSetupViewState extends State<_PayrollSetupView> {
  final Set<int> _savingIds = <int>{};
  final ScrollController _tableScrollController = ScrollController();
  late List<ProfileTeamMember> _visibleTeamMembers;
  late Map<int, PayrollSetupRecord> _visibleSetups;

  @override
  void initState() {
    super.initState();
    _visibleTeamMembers = List<ProfileTeamMember>.from(widget.teamMembers);
    _visibleSetups = Map<int, PayrollSetupRecord>.from(widget.existingSetups);
  }

  @override
  void didUpdateWidget(covariant _PayrollSetupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visibleTeamMembers = List<ProfileTeamMember>.from(widget.teamMembers);
    _visibleSetups
      ..clear()
      ..addAll(widget.existingSetups);
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  int get _configuredCount => _visibleTeamMembers
      .where((member) => _visibleSetups.containsKey(member.id))
      .length;

  int get _pendingCount => _visibleTeamMembers.length - _configuredCount;

  Future<void> _refreshSetupData() async {
    final refresh = widget.onRefresh;
    if (refresh == null) return;

    final data = await refresh();
    if (!mounted) return;
    setState(() {
      _visibleTeamMembers = List<ProfileTeamMember>.from(data.teamMembers);
      _visibleSetups = Map<int, PayrollSetupRecord>.from(data.existingSetups);
    });
  }

  Future<void> _openEditDialog(ProfileTeamMember member) async {
    final initial = _visibleSetups[member.id];
    debugPrint(
      '[OwnerCompensation:payroll] open_payroll_setup_member_dialog | '
      'userId=${member.id}, configured=${initial != null}',
    );
    bool isDialogSaving = false;
    await showDialog<void>(
      context: context,
      builder: (routeContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final dialogWidth = MediaQuery.sizeOf(dialogContext).width;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              backgroundColor: const Color(0xFFFFFCF8),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE8DED6)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(dialogWidth - 28, 560),
                  maxHeight: math.min(
                    MediaQuery.sizeOf(dialogContext).height * 0.78,
                    600,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              initial == null
                                  ? context.t('Add Payroll Setup')
                                  : context.t('Edit Payroll Setup'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1C1917),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isDialogSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        fit: FlexFit.loose,
                        child: _PayrollSetupMemberCard(
                          member: member,
                          initialSetup: initial,
                          isSaving: isDialogSaving,
                          onSave: (setup) async {
                            debugPrint(
                              '[OwnerCompensation:payroll] payroll_setup_member_save_started | '
                              'userId=${member.id}, payrollType=${setup.payrollType}',
                            );
                            setDialogState(() => isDialogSaving = true);
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
                              final message = error
                                  .toString()
                                  .replaceFirst('Exception: ', '')
                                  .trim();
                              Fluttertoast.showToast(
                                msg: message.isEmpty
                                    ? 'Something went wrong. Please try again.'
                                    : message,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _savingIds.remove(member.id));
                              }
                              if (dialogContext.mounted) {
                                setDialogState(() => isDialogSaving = false);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.starColor,
            backgroundColor: const Color(0xFFFFFCF8),
            onRefresh: () => RefreshFeedback.playAndRun(_refreshSetupData),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                          'Team Members (${_visibleTeamMembers.length})',
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
                            final tableWidth = constraints.maxWidth < 900
                                ? 900.0
                                : constraints.maxWidth;
                            return RawScrollbar(
                              controller: _tableScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              thickness: 4,
                              radius: const Radius.circular(10),
                              thumbColor:
                                  AppColors.starColor.withValues(alpha: 0.72),
                              trackColor: const Color(0xFFFFF3D5),
                              trackBorderColor: const Color(0xFFE8C774),
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              child: SingleChildScrollView(
                                controller: _tableScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 12),
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
                                            Expanded(
                                              child: Text(
                                                'Effective From',
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
                                      if (_visibleTeamMembers.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 34,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'No team members found for payroll setup.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ..._visibleTeamMembers
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final member = entry.value;
                                          final setup =
                                              _visibleSetups[member.id];
                                          final payType = setup == null
                                              ? 'Not configured'
                                              : PayrollTypes.label(
                                                  setup.payrollType);
                                          final salaryText = setup == null ||
                                                  setup.salaryMinor == 0
                                              ? '-'
                                              : _formatSalaryRupees(
                                                  setup.salaryMinor,
                                                );
                                          final commissionText = setup ==
                                                      null ||
                                                  setup.commissionPercent == 0
                                              ? '-'
                                              : '${_formatCommissionPercentText(setup.commissionPercent)}%';
                                          final joiningDateText =
                                              member.joiningDate == null
                                                  ? '-'
                                                  : DateFormat('dd MMM yyyy')
                                                      .format(
                                                      member.joiningDate!,
                                                    );
                                          final effectiveDateText =
                                              setup == null
                                                  ? '-'
                                                  : DateFormat('dd MMM yyyy')
                                                      .format(
                                                      setup.effectiveDate,
                                                    );
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          member.name,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          member.role.isEmpty
                                                              ? context.t(
                                                                  'Team member')
                                                              : member.role,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFF6B7280,
                                                            ),
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      salaryText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      commissionText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      joiningDateText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      effectiveDateText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 96,
                                                    child: Center(
                                                      child: OutlinedButton(
                                                        onPressed: _savingIds
                                                                .contains(
                                                                    member.id)
                                                            ? null
                                                            : () =>
                                                                _openEditDialog(
                                                                  member,
                                                                ),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              AppColors
                                                                  .starColor,
                                                          side: BorderSide(
                                                            color: AppColors
                                                                .starColor,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
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
                                                              : setup == null
                                                                  ? context
                                                                      .t('Add')
                                                                  : context.t(
                                                                      'Edit'),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (index !=
                                                  _visibleTeamMembers.length -
                                                      1)
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
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.starColor,
                                side: BorderSide(color: AppColors.starColor),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(context.t('Back to Dashboard')),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: widget.onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.starColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Review'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
        return translateText('Commission cannot exceed 100%.');
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
    return joiningDate;
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
      _formKey.currentState?.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
    return Stack(
      children: [
        Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(10),
                  thumbColor: AppColors.starColor.withValues(alpha: 0.72),
                  trackColor: const Color(0xFFFFF3D5),
                  trackBorderColor: const Color(0xFFE8C774),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 12),
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
                                      if (_autoValidateMode !=
                                          AutovalidateMode.disabled) {
                                        _formKey.currentState?.validate();
                                      }
                                    }
                                  },
                          ),
                          const SizedBox(height: 12),
                          _LabeledTextField(
                            label: context.t('Salary'),
                            controller: _salaryController,
                            enabled: _requiresSalary && !widget.isSaving,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                          const SizedBox(height: 12),
                          _LabeledTextField(
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
                            validator: (value) {
                              if (!_requiresCommission) return null;
                              final commission =
                                  double.tryParse((value ?? '').trim()) ?? 0;
                              if (commission <= 0 || commission > 100) {
                                return translateText(
                                  'Commission cannot exceed 100%',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5F2),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE9DFD1)),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            final minimum =
                                                _minimumEffectiveDate();
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _effectiveDate
                                                      .isBefore(minimum)
                                                  ? minimum
                                                  : _effectiveDate,
                                              firstDate: minimum,
                                              lastDate: DateTime(2100),
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context)
                                                      .copyWith(
                                                    colorScheme:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .copyWith(
                                                              primary: AppColors
                                                                  .starColor,
                                                            ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (picked != null) {
                                              final clamped =
                                                  _clampEffectiveDate(picked);
                                              setState(() =>
                                                  _effectiveDate = clamped);
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
                                        fontWeight: FontWeight.w600,
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
              ),
              const SizedBox(height: 12),
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
                      child: Text(context.t('Save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.isSaving)
          Positioned.fill(
            child: Container(
              color: const Color(0x66FFFCF8),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                color: AppColors.starColor,
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}
