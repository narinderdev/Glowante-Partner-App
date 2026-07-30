part of 'profile_compensation_screen.dart';

const Color _leaveGold = Color(0xFF8B6500);
const Color _leaveGoldLight = Color(0xFFD0A244);
const Color _leaveInk = Color(0xFF1F1B18);
const Color _leaveMuted = Color(0xFF6F665E);
const Color _leaveBorder = Color(0xFFE8DED6);
const Color _leaveFieldFill = Color(0xFFF7F4F3);
const Color _leaveSoftGold = Color(0xFFF5EAD2);

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
                      '${attendance?.employeesWithAttendance ?? 0} ${context.t('staff with attendance')}',
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
                  subtitle:
                      '${attendance?.totalEmployees ?? 0} ${context.t('employees')}',
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
        : branch?.label ?? context.t('Selected branch');

    return _buildLeaveModuleScaffold(
      title: 'Leaves',
      description: 'Manage default paid leaves for the selected branch.',
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _leaveBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 6),
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
                      translateText('Default Paid Leaves'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _leaveInk,
                      ),
                    ),
                  ),
                  _LeaveEditButton(
                    label: context.t('Edit'),
                    onPressed: branch == null
                        ? null
                        : () {
                            _openBranchPaidLeaveConfigDialog();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _leaveBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText('DEFAULT PAID LEAVES'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _leaveGold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${config?.paidLeaveDays ?? 0}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _leaveInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      branchName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _leaveMuted,
                        fontWeight: FontWeight.w600,
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
                    : context.t('selected salon'),
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
                          : context.t('selected payroll'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _MetricCard(
                  label: 'Attendance days',
                  value: '${attendance?.daysAttended ?? 0}',
                  subtitle:
                      '${attendance?.employeesWithAttendance ?? 0} ${context.t('staff with attendance')}',
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
                      : context.t('selected salon'),
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
    return RefreshIndicator(
      color: AppColors.starColor,
      backgroundColor: const Color(0xFFFFFCF8),
      onRefresh: () => RefreshFeedback.playAndDetach(
        () => _reloadContent(showLoader: false),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _leaveBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 14,
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
                        context.t(title),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _leaveInk,
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
                  context.t(description),
                  style: const TextStyle(
                    fontSize: 13,
                    color: _leaveMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showPayrollDropdown && _payrollRuns.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedLeavePayrollId ?? _payrollRuns.first.id,
                    decoration: InputDecoration(
                      labelText: context.t('Payroll run'),
                      filled: true,
                      fillColor: _leaveFieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: _leaveBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: _leaveBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(
                          color: _leaveGoldLight,
                          width: 1.2,
                        ),
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
      ),
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
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _leaveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  translateText('Paid Leaves'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _leaveInk,
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
                ? context.t('Paid leaves for selected branch')
                : '${context.t('Payroll')}: ${paidLeaves.payrollName}',
            style: const TextStyle(
              fontSize: 13,
              color: _leaveMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (paidLeaves.employees.isEmpty)
            Text(
              translateText('No employees found for paid leaves.'),
              style: TextStyle(
                fontSize: 13,
                color: _leaveMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...paidLeaves.employees.map((employee) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _leaveFieldFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _leaveBorder),
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
                                fontWeight: FontWeight.w900,
                                color: _leaveInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${employee.role} • ${context.t('Paid leave')} ${employee.paidLeaveDays} • ${context.t('Unpaid leave')} ${employee.leaveDays}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _leaveMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LeaveEditButton(
                        label: context.t('Edit'),
                        onPressed: employee.payrollEmployeeId <= 0
                            ? null
                            : () {
                                _openPaidLeaveDialog(employee);
                              },
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
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _leaveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText('Branch Attendance'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _leaveInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${attendance.recordsCount} ${context.t('records')} • ${attendance.totalEmployees} ${context.t('employees')}',
            style: const TextStyle(
              fontSize: 13,
              color: _leaveMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (attendance.employees.isEmpty)
            Text(
              translateText('No attendance records found for this month.'),
              style: TextStyle(
                fontSize: 13,
                color: _leaveMuted,
                fontWeight: FontWeight.w600,
              ),
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
                    color: _leaveFieldFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _leaveBorder),
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
                                fontWeight: FontWeight.w900,
                                color: _leaveInk,
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
                        '${employee.role} • ${context.t('Attended')} ${employee.daysAttended} • ${context.t('Leaves')} ${employee.leaves}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _leaveMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (lastRecord != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${context.t('Last record')}: ${lastRecord.checkedInAtIndianTime.isEmpty ? _formatDate(lastRecord.checkedInAt ?? DateTime.now()) : lastRecord.checkedInAtIndianTime}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _leaveInk,
                            fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _leaveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  translateText('Holiday Calendar'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _leaveInk,
                  ),
                ),
              ),
              _ActionChipButton(
                label: context.t('Add Holiday'),
                filled: true,
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
                ? context.t('Selected salon')
                : holidayCalendar.salonName,
            style: const TextStyle(
              fontSize: 13,
              color: _leaveMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (holidayCalendar.holidays.isEmpty)
            Text(
              translateText('No holidays added for this month.'),
              style: TextStyle(
                fontSize: 13,
                color: _leaveMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...holidayCalendar.holidays.map((holiday) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _leaveFieldFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _leaveBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holiday.title.isEmpty
                                  ? context.t('Holiday')
                                  : holiday.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: _leaveInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(holiday.holidayDate)}${holiday.description.isEmpty ? '' : ' • ${holiday.description}'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _leaveMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _LeaveEditButton(
                            label: context.t('Edit'),
                            onPressed: () => _openEditHolidayDialog(holiday),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            tooltip: context.t('Delete'),
                            onPressed: () => _confirmDeleteHoliday(holiday),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF1F1),
                              foregroundColor: const Color(0xFFB02A37),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFFFD6D6),
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
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
          title: Text(context.t('Delete holiday')),
          content: Text(
            context.t(
              'Delete "{name}" from the calendar?',
              params: {
                'name': holiday.title.isEmpty
                    ? context.t('Holiday')
                    : holiday.title,
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB02A37),
                foregroundColor: Colors.white,
              ),
              child: Text(context.t('Delete')),
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
      title: Text(context.t('Select month')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              decoration: InputDecoration(
                labelText: context.t('Month'),
                border: OutlineInputBorder(),
              ),
              items: List<DropdownMenuItem<int>>.generate(
                12,
                (index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(
                    DateFormat.MMMM(
                      Localizations.localeOf(context).languageCode,
                    ).format(DateTime(2026, index + 1)),
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
              decoration: InputDecoration(
                labelText: context.t('Year'),
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
          child: Text(context.t('Cancel')),
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
          child: Text(context.t('Apply')),
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
    return _LeaveDialogShell(
      title: context.t('Paid leaves'),
      subtitle: widget.employeeName,
      icon: Icons.beach_access_outlined,
      child: Form(
        key: _formKey,
        child: _LabeledTextField(
          label: context.t('Paid leave days'),
          controller: _controller,
          keyboardType: TextInputType.number,
          maxLength: 3,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final days = int.tryParse(value?.trim() ?? '');
            if (days == null || days < 0) {
              return context.t('Enter 0 or a positive number');
            }
            return null;
          },
        ),
      ),
      actions: [
        _LeaveDialogButton(
          label: context.t('Cancel'),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 12),
        _LeaveDialogButton(
          label: context.t('Save'),
          onPressed: _submit,
          primary: true,
          icon: Icons.check_rounded,
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

class _LeaveEditButton extends StatelessWidget {
  const _LeaveEditButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? Colors.white : const Color(0xFF9CA3AF);
    final background = enabled ? _leaveGold : const Color(0xFFF3F0EC);
    final border = enabled ? _leaveGold : _leaveBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x1A8B6500),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveDialogShell extends StatelessWidget {
  const _LeaveDialogShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _leaveBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: _leaveBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: _leaveSoftGold,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: _leaveGold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _leaveInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _leaveMuted,
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: _leaveMuted,
                        tooltip: context.t('Close'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: child,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Row(
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveDialogButton extends StatelessWidget {
  const _LeaveDialogButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary ? _leaveGold : Colors.white,
            foregroundColor: primary ? Colors.white : _leaveInk,
            elevation: primary ? 8 : 0,
            shadowColor: const Color(0x338B6500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: primary ? _leaveGold : _leaveBorder,
              ),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    return _LeaveDialogShell(
      title: context.t(widget.isEdit ? 'Edit Holiday' : 'Add Holiday'),
      subtitle: context.t('Manage salon holidays for the selected month.'),
      icon: widget.isEdit
          ? Icons.edit_calendar_outlined
          : Icons.add_circle_outline_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateFieldButton(
              label: context.t('Holiday date'),
              value: _selectedDate,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: context.t('Title'),
              controller: _titleController,
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return context.t('Title is required');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: context.t('Description'),
              controller: _descriptionController,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        _LeaveDialogButton(
          label: context.t('Cancel'),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 12),
        _LeaveDialogButton(
          label: context.t('Save'),
          onPressed: _submit,
          primary: true,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}
