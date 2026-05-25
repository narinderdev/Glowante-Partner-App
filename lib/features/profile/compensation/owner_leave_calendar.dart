part of 'profile_compensation_screen.dart';

extension _OwnerLeaveCalendarUi on _ProfileCompensationScreenState {
  Widget _buildAttendanceScreen() {
    final attendance = _attendanceOverview;

    return _buildLeaveModuleScaffold(
      title: 'Attendance',
      description: 'View team member attendance and leaves by month and year.',
      showMonthPicker: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Attendance days',
                  value: '${attendance?.daysAttended ?? 0}',
                  subtitle:
                      '${attendance?.employeesWithAttendance ?? 0} staff with attendance',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Leave days',
                  value: '${attendance?.leaves ?? 0}',
                  subtitle: DateFormat('MMMM yyyy').format(_leaveMonth),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Records',
                  value: '${attendance?.recordsCount ?? 0}',
                  subtitle: '${attendance?.totalEmployees ?? 0} employees',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAttendanceSection(attendance),
      ],
    );
  }

  Widget _buildLeavesScreen() {
    final branch = _selectedBranch;
    final config = _branchPaidLeaveConfig;
    final branchName = config?.branchName.isNotEmpty == true
        ? config!.branchName
        : branch?.label ?? 'Selected branch';

    return _buildLeaveModuleScaffold(
      title: 'Leaves',
      description: 'Manage default paid leaves for the selected branch.',
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Default Paid Leaves',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: branch == null
                        ? null
                        : () {
                            _openBranchPaidLeaveConfigDialog();
                          },
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE9DFD1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEFAULT PAID LEAVES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A6B00),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${config?.paidLeaveDays ?? 0}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      branchName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHolidaysScreen() {
    final holidayCalendar = _holidayCalendar;

    return _buildLeaveModuleScaffold(
      title: 'Holidays Calendar',
      description: 'Manage salon holidays for the selected month.',
      showMonthPicker: true,
      children: [
        SizedBox(
          width: 190,
          child: _MetricCard(
            label: 'Holidays',
            value: '${holidayCalendar?.totalHolidays ?? 0}',
            subtitle:
                holidayCalendar != null && holidayCalendar.salonName.isNotEmpty
                    ? holidayCalendar.salonName
                    : 'selected salon',
          ),
        ),
        const SizedBox(height: 16),
        _buildHolidayCalendarSection(holidayCalendar),
      ],
    );
  }

  Widget _buildLeaveCalendarScreen() {
    final attendance = _attendanceOverview;
    final paidLeaves = _paidLeavesReview;
    final holidayCalendar = _holidayCalendar;

    return _buildLeaveModuleScaffold(
      title: 'Leaves & Holidays',
      description:
          'Track attendance-based leaves, set paid leaves for payroll, and manage the salon holiday calendar.',
      showMonthPicker: true,
      showPayrollDropdown: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Paid leaves',
                  value: '${paidLeaves?.totalPaidLeaveDays ?? 0}',
                  subtitle:
                      paidLeaves != null && paidLeaves.payrollName.isNotEmpty
                          ? paidLeaves.payrollName
                          : 'selected payroll',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Attendance days',
                  value: '${attendance?.daysAttended ?? 0}',
                  subtitle:
                      '${attendance?.employeesWithAttendance ?? 0} staff with attendance',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Leave days',
                  value: '${attendance?.leaves ?? 0}',
                  subtitle: DateFormat('MMMM yyyy').format(_leaveMonth),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Holidays',
                  value: '${holidayCalendar?.totalHolidays ?? 0}',
                  subtitle: holidayCalendar != null &&
                          holidayCalendar.salonName.isNotEmpty
                      ? holidayCalendar.salonName
                      : 'selected salon',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPaidLeavesSection(paidLeaves),
        const SizedBox(height: 16),
        _buildAttendanceSection(attendance),
        const SizedBox(height: 16),
        _buildHolidayCalendarSection(holidayCalendar),
      ],
    );
  }

  Widget _buildLeaveModuleScaffold({
    required String title,
    required String description,
    required List<Widget> children,
    bool showMonthPicker = false,
    bool showPayrollDropdown = false,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                  ),
                  if (showMonthPicker)
                    _ActionChipButton(
                      label: DateFormat('MMMM yyyy').format(_leaveMonth),
                      icon: Icons.calendar_month_outlined,
                      onTap: () {
                        _openLeaveMonthPicker();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (showPayrollDropdown && _payrollRuns.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedLeavePayrollId ?? _payrollRuns.first.id,
                  decoration: InputDecoration(
                    labelText: 'Payroll run',
                    filled: true,
                    fillColor: const Color(0xFFFCFAF8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  items: _payrollRuns
                      .map(
                        (run) => DropdownMenuItem<String>(
                          value: run.id,
                          child: Text(run.periodLabel),
                        ),
                      )
                      .toList(),
                  onChanged: _isActionInProgress
                      ? null
                      : (value) {
                          _changeLeavePayroll(value);
                        },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildPaidLeavesSection(PayrollPaidLeavesReview? paidLeaves) {
    if (paidLeaves == null) {
      return const _EmptyStateCard(
        title: 'Paid leaves unavailable',
        subtitle: 'Select a payroll run to review and update paid leaves.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Paid Leaves',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              if (paidLeaves.payrollStatus.isNotEmpty)
                _StatusPill(
                  label: paidLeaves.payrollStatus.toUpperCase() == 'PAID'
                      ? 'Paid'
                      : 'Pending',
                  color: paidLeaves.payrollStatus.toUpperCase() == 'PAID'
                      ? const Color(0xFF157347)
                      : const Color(0xFFB26A00),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            paidLeaves.payrollName.isEmpty
                ? 'Paid leaves for selected branch'
                : 'Payroll: ${paidLeaves.payrollName}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          if (paidLeaves.employees.isEmpty)
            const Text(
              'No employees found for paid leaves.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            )
          else
            ...paidLeaves.employees.map((employee) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DFD1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.employeeName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C1917),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${employee.role} • Paid ${employee.paidLeaveDays} • Unpaid ${employee.leaveDays}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: employee.payrollEmployeeId <= 0
                            ? null
                            : () {
                                _openPaidLeaveDialog(employee);
                              },
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(BranchAttendanceOverview? attendance) {
    if (attendance == null) {
      return const _EmptyStateCard(
        title: 'Attendance unavailable',
        subtitle: 'Attendance history by month could not be loaded.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Branch Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${attendance.recordsCount} records • ${attendance.totalEmployees} employees',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          if (attendance.employees.isEmpty)
            const Text(
              'No attendance records found for this month.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            )
          else
            ...attendance.employees.map((employee) {
              final lastRecord =
                  employee.records.isEmpty ? null : employee.records.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DFD1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: employee.active ? 'Active' : 'Inactive',
                            color: employee.active
                                ? const Color(0xFF157347)
                                : const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${employee.role} • Attended ${employee.daysAttended} • Leaves ${employee.leaves}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (lastRecord != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last record: ${lastRecord.checkedInAtIndianTime.isEmpty ? _formatDate(lastRecord.checkedInAt ?? DateTime.now()) : lastRecord.checkedInAtIndianTime}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1C1917),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHolidayCalendarSection(
      HolidayCalendarOverview? holidayCalendar) {
    if (holidayCalendar == null) {
      return const _EmptyStateCard(
        title: 'Holiday calendar unavailable',
        subtitle: 'Salon holidays could not be loaded right now.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Holiday Calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              _ActionChipButton(
                label: 'Add Holiday',
                icon: Icons.add_circle_outline,
                onTap: () {
                  _openCreateHolidayDialog();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            holidayCalendar.salonName.isEmpty
                ? 'Selected salon'
                : holidayCalendar.salonName,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          if (holidayCalendar.holidays.isEmpty)
            const Text(
              'No holidays added for this month.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            )
          else
            ...holidayCalendar.holidays.map((holiday) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DFD1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holiday.title.isEmpty ? 'Holiday' : holiday.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(holiday.holidayDate)}${holiday.description.isEmpty ? '' : ' • ${holiday.description}'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditHolidayDialog(holiday);
                            return;
                          }
                          if (value == 'delete') {
                            _confirmDeleteHoliday(holiday);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openLeaveMonthPicker() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _LeaveMonthPickerDialog(initialMonth: _leaveMonth),
    );
    if (selected == null) {
      return;
    }
    await _changeLeaveMonth(selected);
  }

  Future<void> _openPaidLeaveDialog(
    PayrollPaidLeaveEmployeeRecord employee,
  ) async {
    final paidLeaveDays = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _PaidLeaveDialog(
          employeeName: employee.employeeName,
          initialPaidLeaveDays: employee.paidLeaveDays,
        );
      },
    );
    if (paidLeaveDays == null) {
      return;
    }
    await _setPaidLeaveDays(
      payrollEmployeeId: employee.payrollEmployeeId,
      paidLeaveDays: paidLeaveDays,
    );
  }

  Future<void> _openBranchPaidLeaveConfigDialog() async {
    final branch = _selectedBranch;
    if (branch == null) {
      return;
    }
    final paidLeaveDays = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _PaidLeaveDialog(
          employeeName: branch.label,
          initialPaidLeaveDays: _branchPaidLeaveConfig?.paidLeaveDays ?? 0,
        );
      },
    );
    if (paidLeaveDays == null) {
      return;
    }
    await _setBranchPaidLeaveDays(
      branchId: branch.branchId,
      paidLeaveDays: paidLeaveDays,
    );
  }

  Future<void> _openCreateHolidayDialog() async {
    await _openHolidayDialog();
  }

  Future<void> _openEditHolidayDialog(HolidayCalendarEntry holiday) async {
    await _openHolidayDialog(holiday: holiday);
  }

  Future<void> _openHolidayDialog({HolidayCalendarEntry? holiday}) async {
    final result = await showDialog<_HolidayFormResult>(
      context: context,
      builder: (dialogContext) {
        return _HolidayDialog(
          initialDate: holiday?.holidayDate ?? _leaveMonth,
          initialTitle: holiday?.title ?? '',
          initialDescription: holiday?.description ?? '',
          isEdit: holiday != null,
        );
      },
    );
    if (result == null) {
      return;
    }
    await _saveHoliday(
      holidayDate: result.holidayDate,
      title: result.title,
      description: result.description,
      holidayId: holiday?.id,
    );
  }

  Future<void> _confirmDeleteHoliday(HolidayCalendarEntry holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete holiday'),
          content: Text(
            'Delete "${holiday.title.isEmpty ? 'Holiday' : holiday.title}" from the calendar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB02A37),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _deleteHoliday(holiday.id);
  }
}

class _LeaveMonthPickerDialog extends StatefulWidget {
  const _LeaveMonthPickerDialog({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_LeaveMonthPickerDialog> createState() =>
      _LeaveMonthPickerDialogState();
}

class _LeaveMonthPickerDialogState extends State<_LeaveMonthPickerDialog> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth.month;
    _selectedYear = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final years =
        List<int>.generate(6, (index) => DateTime.now().year - 2 + index);
    return AlertDialog(
      title: const Text('Select month'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              decoration: const InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(),
              ),
              items: List<DropdownMenuItem<int>>.generate(
                12,
                (index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(
                    DateFormat('MMMM').format(DateTime(2026, index + 1)),
                  ),
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
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            DateTime(_selectedYear, _selectedMonth, 1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _PaidLeaveDialog extends StatefulWidget {
  const _PaidLeaveDialog({
    required this.employeeName,
    required this.initialPaidLeaveDays,
  });

  final String employeeName;
  final int initialPaidLeaveDays;

  @override
  State<_PaidLeaveDialog> createState() => _PaidLeaveDialogState();
}

class _PaidLeaveDialogState extends State<_PaidLeaveDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialPaidLeaveDays.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Paid leaves • ${widget.employeeName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Paid leave days',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final days = int.tryParse(value?.trim() ?? '');
            if (days == null || days < 0) {
              return 'Enter 0 or a positive number';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HolidayFormResult {
  const _HolidayFormResult({
    required this.holidayDate,
    required this.title,
    required this.description,
  });

  final DateTime holidayDate;
  final String title;
  final String description;
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({
    required this.initialDate,
    required this.initialTitle,
    required this.initialDescription,
    required this.isEdit,
  });

  final DateTime initialDate;
  final String initialTitle;
  final String initialDescription;
  final bool isEdit;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _HolidayFormResult(
        holidayDate: _selectedDate,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Holiday' : 'Add Holiday'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateFieldButton(
                label: 'Holiday date',
                value: _selectedDate,
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
