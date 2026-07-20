part of 'profile_compensation_screen.dart';

extension _OwnerAdvanceUi on _ProfileCompensationScreenState {
  Widget _buildAdvanceScreen() {
    final filteredAdvances = _filteredAdvances;

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFCF8),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1EBE6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4E8),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'GLOWANTE PAYROLL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.t('Advance'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1C1917),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_advances.length}',
                            style: TextStyle(
                              color: AppColors.starColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track staff payroll advances for team members.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _advanceSearchController,
                      cursorColor: AppColors.starColor,
                      maxLength: 60,
                      decoration: InputDecoration(
                        hintText: 'Search by team member',
                        counterText: '',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE8DED6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.starColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isActionInProgress
                                ? null
                                : () async {
                                    final selected = await showDialog<DateTime>(
                                      context: context,
                                      builder: (context) =>
                                          _AdvanceMonthPickerDialog(
                                        initialValue: _advanceMonth,
                                      ),
                                    );
                                    if (selected == null || !mounted) {
                                      return;
                                    }
                                    _advanceMonth =
                                        DateTime(selected.year, selected.month);
                                    final branchId = _selectedBranch?.branchId;
                                    if (branchId != null) {
                                      await _reloadContent();
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1C1917),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFD6D3D1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat('MMM yyyy')
                                        .format(_advanceMonth),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.calendar_month_outlined,
                                    size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isActionInProgress
                                ? null
                                : _openAddAdvanceDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.starColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Advance'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1EBE6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: filteredAdvances.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No advances found for the selected month.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 620) {
                            return Column(
                              children:
                                  filteredAdvances.asMap().entries.map((entry) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        entry.key == filteredAdvances.length - 1
                                            ? 0
                                            : 12,
                                  ),
                                  child: _AdvanceRecordCard(
                                    advance: entry.value,
                                    isBusy: _isActionInProgress,
                                    onEdit: () =>
                                        _openEditAdvanceDialog(entry.value),
                                    onDelete: () => _deleteAdvance(entry.value),
                                  ),
                                );
                              }).toList(),
                            );
                          }

                          return RawScrollbar(
                            controller: _advanceTableScrollController,
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
                              controller: _advanceTableScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth:
                                      MediaQuery.of(context).size.width - 60,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8F5F2),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(10),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          _AdvanceHeaderCell(
                                            'TEAM MEMBER',
                                            width: 140,
                                          ),
                                          _AdvanceHeaderCell(
                                            'ADVANCE AMOUNT',
                                            width: 140,
                                          ),
                                          _AdvanceHeaderCell('DATE',
                                              width: 110),
                                          _AdvanceHeaderCell(
                                            'PAYMENT MODE',
                                            width: 120,
                                          ),
                                          _AdvanceHeaderCell(
                                            'PAYMENT REFERENCE',
                                            width: 160,
                                          ),
                                          _AdvanceHeaderCell('REMARKS',
                                              width: 140),
                                          _AdvanceHeaderCell('ACTION',
                                              width: 112),
                                        ],
                                      ),
                                    ),
                                    ...filteredAdvances
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final advance = entry.value;
                                      final isLast = entry.key ==
                                          filteredAdvances.length - 1;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isLast
                                                  ? Colors.transparent
                                                  : const Color(0xFFF1EBE6),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _AdvanceDataCell(
                                              advance.employeeName,
                                              width: 140,
                                              isBold: true,
                                            ),
                                            _AdvanceDataCell(
                                              _formatCurrency(advance.amount),
                                              width: 140,
                                            ),
                                            _AdvanceDataCell(
                                              _formatDate(advance.givenDate),
                                              width: 110,
                                            ),
                                            _AdvanceDataCell(
                                              AdvancePaymentModes.label(
                                                advance.paymentMode,
                                              ),
                                              width: 120,
                                            ),
                                            _AdvanceDataCell(
                                              advance.paymentReference.isEmpty
                                                  ? '-'
                                                  : advance.paymentReference,
                                              width: 160,
                                            ),
                                            _AdvanceDataCell(
                                              advance.remarks.isEmpty
                                                  ? '-'
                                                  : advance.remarks,
                                              width: 140,
                                            ),
                                            _AdvanceActionCell(
                                              width: 112,
                                              isBusy: _isActionInProgress,
                                              onEdit: () =>
                                                  _openEditAdvanceDialog(
                                                advance,
                                              ),
                                              onDelete: () =>
                                                  _deleteAdvance(advance),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (_isActionInProgress)
          const Positioned.fill(
            child: _AdvanceBlockingLoader(),
          ),
      ],
    );
  }

  Future<void> _openAdvanceDialog({
    PayrollAdvanceRecord? initialAdvance,
  }) async {
    if (_selectedBranch == null) {
      return;
    }
    final activeMembers = List<ProfileTeamMember>.from(_activeTeamMembers);
    if (initialAdvance != null &&
        !activeMembers
            .any((member) => member.id == initialAdvance.employeeId)) {
      for (final member in _teamMembers) {
        if (member.id == initialAdvance.employeeId) {
          activeMembers.add(member);
          break;
        }
      }
    }
    if (activeMembers.isEmpty) {
      _showToast('No active team members found', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AddAdvanceDialog(
          members: activeMembers,
          initialDate: DateTime.now(),
          initialAdvance: initialAdvance,
          onSave: (advance) async {
            try {
              if (initialAdvance == null) {
                await _createAdvance(advance);
              } else {
                await _updateAdvance(advance);
              }
            } catch (error) {
              _showToast(_errorText(error), isError: true);
              rethrow;
            }
          },
        );
      },
    );
  }

  Future<void> _openAddAdvanceDialog() {
    return _openAdvanceDialog();
  }

  Future<void> _openEditAdvanceDialog(PayrollAdvanceRecord advance) {
    return _openAdvanceDialog(initialAdvance: advance);
  }

  Future<bool> _confirmDeleteAdvance(PayrollAdvanceRecord advance) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      requestFocus: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            context.t('Delete Advance'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${context.t('Are you sure you want to delete the advance of')} '
              '${_formatCurrency(advance.amount)} ${context.t('for')} '
              '${advance.employeeName}?',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.starColor,
              ),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(context.t('Delete')),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }
}

class _AdvanceActionCell extends StatelessWidget {
  const _AdvanceActionCell({
    required this.width,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final double width;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _AdvanceIconButton(
              icon: Icons.edit_outlined,
              color: AppColors.starColor,
              onPressed: isBusy ? null : onEdit,
            ),
            const SizedBox(width: 8),
            _AdvanceIconButton(
              icon: Icons.delete_outline,
              color: AppColors.red,
              onPressed: isBusy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceIconButton extends StatelessWidget {
  const _AdvanceIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _AdvanceRecordCard extends StatelessWidget {
  const _AdvanceRecordCard({
    required this.advance,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final PayrollAdvanceRecord advance;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: AppColors.starColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advance.employeeName.isEmpty
                          ? context.t('Team member')
                          : advance.employeeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(advance.givenDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatCurrency(advance.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.starColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AdvanceInfoLine(
            label: 'Payment mode',
            value: AdvancePaymentModes.label(advance.paymentMode),
          ),
          _AdvanceInfoLine(
            label: 'Payment reference',
            value: advance.paymentReference.isEmpty
                ? '-'
                : advance.paymentReference,
          ),
          _AdvanceInfoLine(
            label: 'Remarks',
            value: advance.remarks.isEmpty ? '-' : advance.remarks,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(context.t('Edit')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: Color(0xFFF2B8B5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(context.t('Delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvanceInfoLine extends StatelessWidget {
  const _AdvanceInfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF78716C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1C1917),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvanceHeaderCell extends StatelessWidget {
  const _AdvanceHeaderCell(this.label, {required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _AdvanceMonthPickerDialog extends StatefulWidget {
  const _AdvanceMonthPickerDialog({
    required this.initialValue,
  });

  final DateTime initialValue;

  @override
  State<_AdvanceMonthPickerDialog> createState() =>
      _AdvanceMonthPickerDialogState();
}

class _AdvanceMonthPickerDialogState extends State<_AdvanceMonthPickerDialog> {
  static const List<String> _monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialValue.year;
    _selectedMonth = widget.initialValue.month;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      11,
      (index) => DateTime.now().year - 5 + index,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DropdownButton<int>(
                    value: _selectedYear,
                    underline: const SizedBox.shrink(),
                    items: years
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              '$year',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedYear = value);
                      }
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final now = DateTime.now();
                      Navigator.pop(context, DateTime(now.year, now.month));
                    },
                    child: const Text('This month'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == _selectedMonth;
                  return Material(
                    color: isSelected
                        ? AppColors.starColor
                        : const Color(0xFFF8F5F2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(
                          context,
                          DateTime(_selectedYear, month),
                        );
                      },
                      child: Center(
                        child: Text(
                          _monthLabels[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1C1917),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvanceDataCell extends StatelessWidget {
  const _AdvanceDataCell(
    this.value, {
    required this.width,
    this.isBold = false,
  });

  final String value;
  final double width;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF1C1917),
          ),
        ),
      ),
    );
  }
}

class _AddAdvanceDialog extends StatefulWidget {
  const _AddAdvanceDialog({
    required this.members,
    required this.initialDate,
    required this.onSave,
    this.initialAdvance,
  });

  final List<ProfileTeamMember> members;
  final DateTime initialDate;
  final PayrollAdvanceRecord? initialAdvance;
  final Future<void> Function(PayrollAdvanceRecord advance) onSave;

  @override
  State<_AddAdvanceDialog> createState() => _AddAdvanceDialogState();
}

class _AddAdvanceDialogState extends State<_AddAdvanceDialog> {
  final ScrollController _dialogScrollController = ScrollController();
  ProfileTeamMember? _selectedMember;
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _remarksController;
  DateTime? _givenDate;
  String? _paymentMode;
  bool _isSaving = false;
  String? _memberError;
  String? _amountError;
  String? _dateError;
  String? _paymentModeError;
  String? _referenceError;

  bool get _isEditing => widget.initialAdvance != null;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialAdvance;
    final initialPaymentMode = initial?.paymentMode ?? '';
    _selectedMember = _memberForAdvance(initial);
    _givenDate = initial?.givenDate ?? widget.initialDate;
    _paymentMode = AdvancePaymentModes.values.contains(initialPaymentMode)
        ? initialPaymentMode
        : AdvancePaymentModes.values.first;
    _amountController = TextEditingController(
      text: initial == null ? '' : _minorAmountToInput(initial.amount),
    );
    _referenceController = TextEditingController(
      text: initial?.paymentReference ?? '',
    );
    _remarksController = TextEditingController(
      text: initial?.remarks ?? '',
    );
  }

  @override
  void dispose() {
    _dialogScrollController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  ProfileTeamMember? _memberForAdvance(PayrollAdvanceRecord? advance) {
    if (advance == null) return null;
    for (final member in widget.members) {
      if (member.id == advance.employeeId) {
        return member;
      }
    }
    return null;
  }

  String _minorAmountToInput(int value) {
    final rupees = minorAmountToRupees(value);
    if (rupees == null || rupees <= 0) return '';
    if (rupees == rupees.roundToDouble()) {
      return rupees.toStringAsFixed(0);
    }
    return rupees.toStringAsFixed(2);
  }

  bool _validateForSubmit() {
    final amount = int.tryParse(_amountController.text.trim());
    setState(() {
      _memberError = _selectedMember == null ? 'Team member is required' : null;
      _amountError =
          amount == null || amount <= 0 ? 'Enter a valid advance amount' : null;
      _dateError = _givenDate == null ? 'Date is required' : null;
      _paymentModeError =
          _paymentMode == null ? 'Payment mode is required' : null;
      _referenceError = _referenceController.text.trim().isEmpty
          ? 'Payment reference is required'
          : null;
    });

    return _memberError == null &&
        _amountError == null &&
        _dateError == null &&
        _paymentModeError == null &&
        _referenceError == null;
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    if (!_validateForSubmit()) {
      return;
    }

    final amount = int.parse(_amountController.text.trim());
    final selectedMember = _selectedMember;
    final paymentMode = _paymentMode;
    final givenDate = _givenDate;
    if (selectedMember == null || paymentMode == null || givenDate == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      debugPrint('[AddAdvanceDialog] submit givenDate=$givenDate');

      await widget.onSave(
        PayrollAdvanceRecord(
          id: widget.initialAdvance?.id ?? 0,
          branchId: widget.initialAdvance?.branchId ?? 0,
          employeeId: selectedMember.id,
          employeeName: selectedMember.name,
          amount: rupeesToMinorAmount(amount),
          remainingAmount: widget.initialAdvance?.remainingAmount ??
              rupeesToMinorAmount(amount),
          givenDate: givenDate,
          paymentMode: paymentMode,
          paymentReference: _referenceController.text.trim(),
          status: widget.initialAdvance?.status ?? 'ACTIVE',
          remarks: _remarksController.text.trim(),
          createdAt: widget.initialAdvance?.createdAt ?? DateTime.now(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Advance' : 'Add Advance';
    final helper = _isEditing
        ? 'Update the advance amount, date, payment mode, or notes.'
        : 'Record a payroll advance for an active team member.';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: const Color(0xFFFFFCF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8DED6)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              RawScrollbar(
                controller: _dialogScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 4,
                radius: const Radius.circular(10),
                thumbColor: AppColors.starColor.withValues(alpha: 0.72),
                trackColor: const Color(0xFFFFF3D5),
                trackBorderColor: const Color(0xFFE8C774),
                padding: const EdgeInsets.only(top: 8, right: 6, bottom: 8),
                child: SingleChildScrollView(
                  controller: _dialogScrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 28, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE8C774),
                              ),
                            ),
                            child: Icon(
                              Icons.payments_outlined,
                              color: AppColors.starColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  helper,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProfileTeamMember>(
                        initialValue: _selectedMember,
                        isExpanded: true,
                        decoration: _advanceInputDecoration(
                          'Team Member *',
                          errorText: _memberError,
                        ),
                        items: widget.members
                            .map(
                              (member) => DropdownMenuItem<ProfileTeamMember>(
                                value: member,
                                child: Text(
                                  member.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) {
                          return widget.members
                              .map(
                                (member) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    member.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedMember = value;
                                  _memberError = null;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        maxLength: 6,
                        controller: _amountController,
                        cursorColor: AppColors.starColor,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _advanceInputDecoration(
                          'Advance Amount *',
                          errorText: _amountError,
                        ),
                        onChanged: (_) => setState(() => _amountError = null),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _isSaving
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _givenDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialEntryMode:
                                      DatePickerEntryMode.calendarOnly,
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: Theme.of(context)
                                            .colorScheme
                                            .copyWith(
                                              primary: AppColors.starColor,
                                            ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null && mounted) {
                                  setState(() {
                                    _givenDate = date;
                                    _dateError = null;
                                  });
                                }
                              },
                        child: InputDecorator(
                          decoration: _advanceInputDecoration(
                            'Date *',
                            errorText: _dateError,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _givenDate == null
                                      ? 'Select date'
                                      : DateFormat('dd/MM/yyyy')
                                          .format(_givenDate!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.starColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMode,
                        isExpanded: true,
                        decoration: _advanceInputDecoration(
                          'Payment Mode *',
                          errorText: _paymentModeError,
                        ),
                        items: AdvancePaymentModes.values
                            .map(
                              (mode) => DropdownMenuItem<String>(
                                value: mode,
                                child: Text(
                                  AdvancePaymentModes.label(mode),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) {
                          return AdvancePaymentModes.values
                              .map(
                                (mode) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AdvancePaymentModes.label(mode),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _paymentMode = value;
                                  _paymentModeError = null;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        maxLength: 50,
                        controller: _referenceController,
                        cursorColor: AppColors.starColor,
                        enabled: !_isSaving,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9 -]'),
                          ),
                        ],
                        decoration: _advanceInputDecoration(
                          'Payment Reference *',
                          hintText: 'Enter UPI / transaction reference',
                          errorText: _referenceError,
                        ),
                        onChanged: (_) =>
                            setState(() => _referenceError = null),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        maxLength: 50,
                        controller: _remarksController,
                        cursorColor: AppColors.starColor,
                        enabled: !_isSaving,
                        maxLines: 1,
                        decoration: _advanceInputDecoration(
                          'Remarks',
                          hintText: 'Optional remarks',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8DED6)),
                        ),
                        child: Text(
                          'Preview: ${_selectedMember?.name ?? 'Select team member'} • ${formatRupeeAmount(int.tryParse(_amountController.text.trim()) ?? 0, trimZeroDecimals: true)} on ${_givenDate == null ? 'Select date' : DateFormat('dd MMM yyyy').format(_givenDate!)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF78716C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.starColor,
                                side: BorderSide(color: AppColors.starColor),
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.starColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _isEditing
                                          ? 'Update Advance'
                                          : 'Save Advance',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSaving)
                const Positioned.fill(
                  child: _AdvanceBlockingLoader(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _advanceInputDecoration(
    String label, {
    String? hintText,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      counterStyle: const TextStyle(color: Color(0xFF78716C)),
      errorStyle: const TextStyle(
        color: Color(0xFFD32F2F),
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8DED6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.starColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8DED6)),
      ),
    );
  }
}

class _AdvanceBlockingLoader extends StatelessWidget {
  const _AdvanceBlockingLoader();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: const Color(0x66FFFCF8),
        alignment: Alignment.center,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8DED6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            color: AppColors.starColor,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
