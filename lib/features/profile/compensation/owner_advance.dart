part of 'profile_compensation_screen.dart';

extension _OwnerAdvanceUi on _ProfileCompensationScreenState {
  Widget _buildAdvanceScreen() {
    final filteredAdvances = _filteredAdvances;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        const SizedBox(height: 14),
        Text(
          context.t('Advance'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Track staff payroll advances for team members. Team member names in the form are loaded from the branch team API.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Branch Advances : ${_advances.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _advanceSearchController,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Search by team member',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isActionInProgress
                    ? null
                    : () async {
                        final selected = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => _AdvanceMonthPickerDialog(
                            initialValue: _advanceMonth,
                          ),
                        );
                        if (selected == null || !mounted) {
                          return;
                        }
                        _advanceMonth = DateTime(selected.year, selected.month);
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MMM yyyy').format(_advanceMonth),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_month_outlined, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : _openAddAdvanceDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Advance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8F5F2),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _AdvanceHeaderCell('TEAM MEMBER', width: 140),
                              _AdvanceHeaderCell('ADVANCE AMOUNT', width: 140),
                              _AdvanceHeaderCell('DATE', width: 110),
                              _AdvanceHeaderCell('PAYMENT MODE', width: 120),
                              _AdvanceHeaderCell(
                                'PAYMENT REFERENCE',
                                width: 160,
                              ),
                              _AdvanceHeaderCell('REMARKS', width: 140),
                            ],
                          ),
                        ),
                        ...filteredAdvances.asMap().entries.map((entry) {
                          final advance = entry.value;
                          final isLast =
                              entry.key == filteredAdvances.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
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
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openAddAdvanceDialog() async {
    if (_selectedBranch == null) {
      return;
    }
    final activeMembers = _activeTeamMembers;
    if (activeMembers.isEmpty) {
      _showToast('No active team members found', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AddAdvanceDialog(
          members: activeMembers,
          initialDate: _advanceMonth,
          onSave: (advance) async {
            try {
              await _createAdvance(advance);
            } catch (error) {
              _showToast(_errorText(error), isError: true);
              rethrow;
            }
          },
        );
      },
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
                        ? const Color(0xFF2563EB)
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
  });

  final List<ProfileTeamMember> members;
  final DateTime initialDate;
  final Future<void> Function(PayrollAdvanceRecord advance) onSave;

  @override
  State<_AddAdvanceDialog> createState() => _AddAdvanceDialogState();
}

class _AddAdvanceDialogState extends State<_AddAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  ProfileTeamMember? _selectedMember;
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _remarksController;
  DateTime? _givenDate;
  String? _paymentMode;
  bool _isSaving = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();
    _referenceController = TextEditingController();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _validateIfNeeded() {
    if (_autoValidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
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
          id: 0,
          branchId: 0,
          employeeId: selectedMember.id,
          employeeName: selectedMember.name,
          amount: rupeesToMinorAmount(amount),
          remainingAmount: rupeesToMinorAmount(amount),
          givenDate: givenDate,
          paymentMode: paymentMode,
          paymentReference: _referenceController.text.trim(),
          status: 'ACTIVE',
          remarks: _remarksController.text.trim(),
          createdAt: DateTime.now(),
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
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.all(18),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Advance',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Team member options come from the API. Saving will create an advance record.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProfileTeamMember>(
                  initialValue: _selectedMember,
                  decoration: const InputDecoration(
                    labelText: 'Team Member *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null
                      ? 'Team member is required'
                      : null,
                  items: widget.members
                      .map(
                        (member) => DropdownMenuItem<ProfileTeamMember>(
                          value: member,
                          child: Text(member.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _selectedMember = value);
                          _validateIfNeeded();
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLength: 10,
                  controller: _amountController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Advance Amount *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = int.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid advance amount';
                    }
                    return null;
                  },
                  onChanged: (_) => _validateIfNeeded(),
                ),
                const SizedBox(height: 12),
                FormField<DateTime>(
                  initialValue: _givenDate,
                  validator: (value) =>
                      value == null ? 'Date is required' : null,
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _isSaving
                              ? null
                              : () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _givenDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null && mounted) {
                                    setState(() => _givenDate = date);
                                    field.didChange(date);
                                    _validateIfNeeded();
                                  }
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date *',
                              border: const OutlineInputBorder(),
                              errorText: field.errorText,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _givenDate == null
                                        ? 'Select date'
                                        : DateFormat('dd/MM/yyyy')
                                            .format(_givenDate!),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ? 'Payment mode is required' : null,
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
                          setState(() => _paymentMode = value);
                          _validateIfNeeded();
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLength: 120,
                  controller: _referenceController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Payment Reference *',
                    hintText: 'Enter UPI / transaction reference',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Payment reference is required';
                    }
                    return null;
                  },
                  onChanged: (_) => _validateIfNeeded(),
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLength: 120,
                  controller: _remarksController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Preview: ${_selectedMember?.name ?? 'Select team member'} • ${formatRupeeAmount(int.tryParse(_amountController.text.trim()) ?? 0, trimZeroDecimals: true)} on ${_givenDate == null ? 'Select date' : DateFormat('dd MMM yyyy').format(_givenDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.starColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Saving...'),
                                ],
                              )
                            : const Text('Save Advance'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
