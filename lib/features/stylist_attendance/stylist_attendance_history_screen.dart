import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/features/stylist_attendance/stylist_face_attendance_service.dart';
import 'package:bloc_onboarding/utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StylistAttendanceHistoryScreen extends StatefulWidget {
  const StylistAttendanceHistoryScreen({
    super.key,
    required this.service,
    required this.branchId,
    required this.userId,
    required this.displayName,
    required this.branchName,
  });

  final StylistFaceAttendanceService service;
  final int branchId;
  final int userId;
  final String displayName;
  final String branchName;

  @override
  State<StylistAttendanceHistoryScreen> createState() =>
      _StylistAttendanceHistoryScreenState();
}

class _StylistAttendanceHistoryScreenState
    extends State<StylistAttendanceHistoryScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _isLoading = true;
  String? _errorMessage;
  List<StylistAttendanceHistoryEntry> _history =
      const <StylistAttendanceHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadHistory();
  }

  Future<void> _loadHistory({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final history = await widget.service.loadAttendanceHistory(
        branchId: widget.branchId,
        userId: widget.userId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _history = history;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  void _selectMonth(int? month) {
    if (month == null || month == _selectedMonth) {
      return;
    }
    setState(() {
      _selectedMonth = month;
    });
    _loadHistory();
  }

  void _selectYear(int? year) {
    if (year == null || year == _selectedYear) {
      return;
    }
    setState(() {
      _selectedYear = year;
    });
    _loadHistory();
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    if (raw.startsWith(badStatePrefix)) {
      return raw.substring(badStatePrefix.length).trim();
    }
    return raw.isEmpty
        ? translateText('Unable to load attendance history right now.')
        : raw;
  }

  List<StylistAttendanceHistoryEntry> get _presentEntries {
    return _history.where((entry) {
      final date =
          entry.checkedInAt ?? entry.checkedOutAt ?? entry.attendanceDate;
      return entry.hasAttendance && date != null;
    }).toList();
  }

  Set<String> get _presentDateKeys {
    return _presentEntries.map((entry) {
      final date =
          (entry.checkedInAt ?? entry.checkedOutAt ?? entry.attendanceDate)!
              .toLocal();
      return _dateKey(date);
    }).toSet();
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month}-${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final presentEntries = _presentEntries;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('Attendance History'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(showLoader: false),
        color: AppColors.starColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _HistoryHeroCard(
              displayName: widget.displayName,
              branchName: widget.branchName,
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
              presentDays: _presentDateKeys.length,
            ),
            const SizedBox(height: 14),
            _MonthYearSelector(
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
              onMonthChanged: _selectMonth,
              onYearChanged: _selectYear,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _HistoryMessageCard(
                icon: Icons.error_outline_rounded,
                title:
                    context.t('Unable to load attendance history right now.'),
                message: _errorMessage!,
              )
            else if (presentEntries.isEmpty)
              _HistoryMessageCard(
                icon: Icons.event_busy_outlined,
                title: context.t('No attendance present for this month'),
                message: DateFormat('MMMM yyyy').format(
                  DateTime(_selectedYear, _selectedMonth),
                ),
              )
            else
              _AttendanceMonthGrid(
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
                presentDateKeys: _presentDateKeys,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeroCard extends StatelessWidget {
  const _HistoryHeroCard({
    required this.displayName,
    required this.branchName,
    required this.selectedMonth,
    required this.selectedYear,
    required this.presentDays,
  });

  final String displayName;
  final String branchName;
  final int selectedMonth;
  final int selectedYear;
  final int presentDays;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(
      DateTime(selectedYear, selectedMonth),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1E7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            branchName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$monthLabel • ${context.t('Present')} $presentDays',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthYearSelector extends StatelessWidget {
  const _MonthYearSelector({
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List<int>.generate(7, (index) => now.year - 5 + index);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _SelectorShell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedMonth,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: List<DropdownMenuItem<int>>.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem<int>(
                    value: month,
                    child: Text(DateFormat.MMMM().format(DateTime(0, month))),
                  );
                }),
                onChanged: onMonthChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _SelectorShell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: years
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
                onChanged: onYearChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorShell extends StatelessWidget {
  const _SelectorShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: child,
    );
  }
}

class _AttendanceMonthGrid extends StatelessWidget {
  const _AttendanceMonthGrid({
    required this.selectedMonth,
    required this.selectedYear,
    required this.presentDateKeys,
  });

  final int selectedMonth;
  final int selectedYear;
  final Set<String> presentDateKeys;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(selectedYear, selectedMonth);
    final totalDays = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final leadingEmptyCells = firstDay.weekday % DateTime.daysPerWeek;
    final totalCells = leadingEmptyCells + totalDays;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(firstDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              const _LegendDot(
                color: Color(0xFF16A34A),
                label: 'Present',
              ),
              const SizedBox(width: 10),
              const _LegendDot(
                color: Color(0xFFE5E7EB),
                label: 'Absent',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              _WeekdayLabel('S'),
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: DateTime.daysPerWeek,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyCells) {
                return const SizedBox.shrink();
              }
              final day = index - leadingEmptyCells + 1;
              final date = DateTime(selectedYear, selectedMonth, day);
              final dateKey = '${date.year}-${date.month}-${date.day}';
              final isPresent = presentDateKeys.contains(dateKey);
              final isFuture = _isAfterToday(date, today);
              return _AttendanceDayBox(
                day: day,
                isPresent: isPresent,
                isFuture: isFuture,
                isToday: _isSameDay(date, today),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isAfterToday(DateTime date, DateTime today) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return normalizedDate.isAfter(normalizedToday);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF78716C),
          ),
        ),
      ),
    );
  }
}

class _AttendanceDayBox extends StatelessWidget {
  const _AttendanceDayBox({
    required this.day,
    required this.isPresent,
    required this.isFuture,
    required this.isToday,
  });

  final int day;
  final bool isPresent;
  final bool isFuture;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPresent
        ? const Color(0xFF16A34A)
        : isFuture
            ? Colors.white
            : const Color(0xFFE5E7EB);
    final borderColor = isToday
        ? const Color(0xFFB45309)
        : isFuture
            ? const Color(0xFFE7E5E4)
            : backgroundColor;
    final textColor = isPresent
        ? Colors.white
        : isFuture
            ? const Color(0xFF78716C)
            : const Color(0xFF57534E);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
      ),
      child: Text(
        day.toString(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: color == Colors.white
                ? Border.all(color: const Color(0xFFE7E5E4))
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          context.t(label),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF57534E),
          ),
        ),
      ],
    );
  }
}

class _HistoryMessageCard extends StatelessWidget {
  const _HistoryMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 30,
            color: const Color(0xFF78716C),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF57534E),
            ),
          ),
        ],
      ),
    );
  }
}
